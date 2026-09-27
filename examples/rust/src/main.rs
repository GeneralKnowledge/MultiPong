//! Minimal MultiPong client for Rust / Bevy integration.
//! Run with the backend: `cargo run -- --name rust1`
//! In Bevy: call the same join/input JSON from a networking system; render `GameState`.

use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use serde_json::json;
use std::env;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::sync::mpsc;
use tokio_tungstenite::{connect_async, tungstenite::Message};

#[derive(Debug, Deserialize)]
struct Envelope {
    #[serde(rename = "type")]
    kind: String,
    player: Option<u8>,
    you: Option<u8>,
    message: Option<String>,
    state: Option<serde_json::Value>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut url = "ws://127.0.0.1:8765".to_string();
    let mut room = "demo".to_string();
    let mut name = "rust".to_string();
    let mut args = env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--url" => url = args.next().unwrap_or(url),
            "--room" => room = args.next().unwrap_or(room),
            "--name" => name = args.next().unwrap_or(name),
            _ => {}
        }
    }

    let (ws, _) = connect_async(&url).await?;
    let (mut write, mut read) = ws.split();
    write
        .send(Message::Text(
            json!({"type":"join","room":room,"name":name}).to_string(),
        ))
        .await?;

    let (tx, mut rx) = mpsc::unbounded_channel::<String>();
    tokio::spawn(async move {
        let stdin = BufReader::new(tokio::io::stdin());
        let mut lines = stdin.lines();
        println!("Commands: up / down / stop / confirm / pause / restart / quit");
        while let Ok(Some(line)) = lines.next_line().await {
            if tx.send(line).is_err() {
                break;
            }
        }
    });

    let mut held: Vec<&str> = vec![];
    let mut you = 0u8;
    loop {
        tokio::select! {
            msg = read.next() => {
                match msg {
                    Some(Ok(Message::Text(t))) => {
                        if let Ok(env) = serde_json::from_str::<Envelope>(&t) {
                            match env.kind.as_str() {
                                "welcome" => {
                                    you = env.player.unwrap_or(0);
                                    println!("Joined as player {you}");
                                }
                                "state" => {
                                    if let Some(s) = env.state {
                                        let mode = s["mode"].as_str().unwrap_or("?");
                                        let tck = s["tick"].as_i64().unwrap_or(0);
                                        if tck % 60 == 0 {
                                            println!(
                                                "tick={tck} mode={mode} score={}-{} ball=({:.0},{:.0})",
                                                s["player1"]["score"],
                                                s["player2"]["score"],
                                                s["ball"]["x"].as_f64().unwrap_or(0.0),
                                                s["ball"]["y"].as_f64().unwrap_or(0.0),
                                            );
                                        }
                                    }
                                }
                                "error" => eprintln!("error: {:?}", env.message),
                                _ => {}
                            }
                        }
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Err(e)) => { eprintln!("ws error: {e}"); break; }
                    _ => {}
                }
            }
            cmd = rx.recv() => {
                let Some(line) = cmd else { break; };
                let mut pressed: Vec<&str> = vec![];
                match line.trim() {
                    "up" => held = vec!["UP"],
                    "down" => held = vec!["DOWN"],
                    "stop" => held = vec![],
                    "confirm" => pressed.push("CONFIRM"),
                    "pause" => pressed.push("PAUSE"),
                    "restart" => pressed.push("RESTART"),
                    "quit" => break,
                    _ => println!("unknown command"),
                }
                let payload = json!({"type":"input","held": held, "pressed": pressed});
                write.send(Message::Text(payload.to_string())).await?;
            }
        }
    }
    Ok(())
}
