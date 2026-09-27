//! Background WebSocket thread talking to the authoritative server.

use crate::protocol::{Envelope, RoomInfo};
use crate::Shared;
use serde_json::json;
use std::net::TcpStream;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use tungstenite::stream::MaybeTlsStream;
use tungstenite::{connect, Message};

pub fn spawn(url: String, room: String, name: String, shared: Arc<Mutex<Shared>>) {
    thread::spawn(move || {
        match run(&url, &room, &name, Arc::clone(&shared)) {
            Ok(()) => {
                if let Ok(mut g) = shared.lock() {
                    if g.status != "Disconnected" {
                        g.status = "Disconnected".into();
                    }
                    g.quit = true;
                }
            }
            Err(err) => {
                if let Ok(mut g) = shared.lock() {
                    g.status = format!("Connection failed: {err}");
                }
            }
        }
    });
}

fn run(
    url: &str,
    room: &str,
    name: &str,
    shared: Arc<Mutex<Shared>>,
) -> Result<(), Box<dyn std::error::Error>> {
    let (mut socket, _resp) = connect(url)?;

    socket.send(Message::Text(
        json!({"type":"join","room":room,"name":name}).to_string(),
    ))?;

    {
        let mut g = shared.lock().expect("lock");
        g.status = format!("Connected · room {room}");
    }

    loop {
        let (held, pressed, quit) = {
            let mut g = shared.lock().expect("lock");
            let held = g.held.clone();
            let pressed = std::mem::take(&mut g.pressed);
            (held, pressed, g.quit)
        };
        if quit {
            break;
        }

        socket.send(Message::Text(
            json!({"type":"input","held": held, "pressed": pressed}).to_string(),
        ))?;

        set_read_timeout(socket.get_mut(), Some(Duration::from_millis(8)));
        loop {
            match socket.read() {
                Ok(Message::Text(text)) => handle_text(&text, &shared),
                Ok(Message::Ping(data)) => {
                    let _ = socket.send(Message::Pong(data));
                }
                Ok(Message::Close(_)) => {
                    if let Ok(mut g) = shared.lock() {
                        g.status = "Disconnected".into();
                    }
                    return Ok(());
                }
                Ok(_) => {}
                Err(tungstenite::Error::Io(ref e))
                    if e.kind() == std::io::ErrorKind::WouldBlock
                        || e.kind() == std::io::ErrorKind::TimedOut =>
                {
                    break;
                }
                Err(e) => return Err(e.into()),
            }
        }

        thread::sleep(Duration::from_millis(4));
    }

    let _ = socket.close(None);
    Ok(())
}

fn set_read_timeout(stream: &mut MaybeTlsStream<TcpStream>, timeout: Option<Duration>) {
    match stream {
        MaybeTlsStream::Plain(tcp) => {
            let _ = tcp.set_read_timeout(timeout);
        }
        #[allow(unused_variables)]
        other => {
            // TLS variants unused for ws:// local server
            let _ = other;
        }
    }
}

fn handle_text(text: &str, shared: &Arc<Mutex<Shared>>) {
    let Ok(env) = serde_json::from_str::<Envelope>(text) else {
        return;
    };
    let Ok(mut g) = shared.lock() else {
        return;
    };
    match env.kind.as_str() {
        "welcome" => {
            g.you = env.player;
            if let Some(room) = env.room {
                g.status = format!(
                    "Connected · room {room} · you are P{}",
                    env.player.unwrap_or(0)
                );
            }
        }
        "state" => {
            if let Some(you) = env.you {
                g.you = Some(you);
            }
            g.state = env.state;
            // Keep footer in sync even if a room message was missed.
            if let Some(state) = &g.state {
                if state.mode != "MENU" {
                    let room = g
                        .seats
                        .as_ref()
                        .map(|s| s.room.as_str())
                        .unwrap_or("demo");
                    g.status = format!("Connected · room {room} · 2/2");
                }
            }
        }
        "room" => {
            let players = env.players.unwrap_or(0);
            let room = env.room.unwrap_or_else(|| "demo".into());
            g.seats = Some(RoomInfo {
                room: room.clone(),
                players,
            });
            if players < 2 {
                g.status = format!("Connected · waiting for opponent ({players}/2)");
            } else {
                g.status = format!("Connected · room {room} · 2/2");
            }
        }
        "error" => {
            g.status = format!("Error: {}", env.message.unwrap_or_default());
        }
        _ => {}
    }
}
