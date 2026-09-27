//! Polished Rust multiplayer client for MultiPong.
//! Online-only: renders authoritative `GameState` from the WebSocket server.
//! Presentation mirrors `specs/pong/constants.json`.

mod net;
mod protocol;

use macroquad::prelude::*;
use protocol::{GameState, RoomInfo};
use std::sync::{Arc, Mutex};

const W: f32 = 800.0;
const H: f32 = 600.0;
const BG: Color = Color::from_rgba(0x0b, 0x0e, 0x14, 255);
const LINE: Color = Color::from_rgba(0x2a, 0x33, 0x44, 255);
const PAD: Color = Color::from_rgba(0xe8, 0xee, 0xf5, 255);
const BALL: Color = Color::from_rgba(0xf2, 0xf5, 0xf8, 255);
const TEXT: Color = Color::from_rgba(0xf2, 0xf5, 0xf8, 255);
const HUD: Color = Color::from_rgba(0x8b, 0x95, 0xa8, 255);
const YOU: Color = Color::from_rgba(0x7f, 0xd0, 0xc5, 255);

const PAD_W: f32 = 12.0;
const PAD_H: f32 = 80.0;
const P1_X: f32 = 40.0;
const P2_X: f32 = 760.0;
const BALL_R: f32 = 8.0;
const LINE_W: f32 = 4.0;
const DASH: f32 = 16.0;
const GAP: f32 = 12.0;

#[derive(Clone, Default)]
struct Shared {
    state: Option<GameState>,
    you: Option<u8>,
    seats: Option<RoomInfo>,
    status: String,
    held: Vec<String>,
    pressed: Vec<String>,
    quit: bool,
}

fn parse_args() -> (String, String, String) {
    let mut url = "ws://127.0.0.1:8765".to_string();
    let mut room = "demo".to_string();
    let mut name = "rust".to_string();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--url" => url = args.next().unwrap_or(url),
            "--room" => room = args.next().unwrap_or(room),
            "--name" => name = args.next().unwrap_or(name),
            "-h" | "--help" => {
                eprintln!(
                    "Usage: multipong_client [--url ws://host:port] [--room demo] [--name rust]"
                );
                std::process::exit(0);
            }
            _ => {}
        }
    }
    (url, room, name)
}

fn draw_centered(text: &str, x: f32, y: f32, size: f32, color: Color) {
    let dims = measure_text(text, None, size as u16, 1.0);
    draw_text(
        text,
        x - dims.width * 0.5,
        y + dims.height * 0.35,
        size,
        color,
    );
}

fn draw_paddle(cx: f32, cy: f32, highlight: bool) {
    draw_rectangle(cx - PAD_W * 0.5, cy - PAD_H * 0.5, PAD_W, PAD_H, PAD);
    if highlight {
        draw_rectangle_lines(
            cx - PAD_W * 0.5,
            cy - PAD_H * 0.5,
            PAD_W,
            PAD_H,
            2.0,
            YOU,
        );
    }
}

fn draw_playfield() {
    clear_background(BG);
    let mut y = 0.0;
    while y < H {
        draw_rectangle(W * 0.5 - LINE_W * 0.5, y, LINE_W, DASH, LINE);
        y += DASH + GAP;
    }
}

fn draw_frame(shared: &Shared) {
    draw_playfield();

    if let Some(state) = &shared.state {
        draw_paddle(P1_X, state.player1.y as f32, shared.you == Some(1));
        draw_paddle(P2_X, state.player2.y as f32, shared.you == Some(2));
        draw_circle(state.ball.x as f32, state.ball.y as f32, BALL_R, BALL);

        draw_centered(
            &state.player1.score.to_string(),
            300.0,
            48.0,
            32.0,
            TEXT,
        );
        draw_centered(
            &state.player2.score.to_string(),
            500.0,
            48.0,
            32.0,
            TEXT,
        );

        match state.mode.as_str() {
            "MENU" => {
                draw_centered("PONG", 400.0, 220.0, 48.0, TEXT);
                let waiting = shared
                    .seats
                    .as_ref()
                    .map(|s| s.players < 2)
                    .unwrap_or(true);
                let sub = if waiting {
                    "Waiting for opponent…"
                } else {
                    "Press Enter"
                };
                draw_centered(sub, 400.0, 300.0, 16.0, TEXT);
            }
            "PAUSED" => draw_centered("PAUSED", 400.0, 300.0, 48.0, TEXT),
            "GAME_OVER" => {
                let msg = if state.winner == 1 {
                    "PLAYER 1 WINS"
                } else {
                    "PLAYER 2 WINS"
                };
                draw_centered(msg, 400.0, 276.0, 48.0, TEXT);
                draw_centered("Press Enter", 400.0, 328.0, 16.0, TEXT);
            }
            "POINT_SCORED" => draw_centered("Point!", 400.0, 300.0, 16.0, TEXT),
            _ => {}
        }
    } else {
        draw_centered("MULTIPONG", 400.0, 280.0, 36.0, TEXT);
        draw_centered("Connecting…", 400.0, 324.0, 16.0, HUD);
    }

    let seat = shared
        .you
        .map(|y| format!("P{y}"))
        .unwrap_or_else(|| "—".into());
    let line = format!(
        "{}   seat {}   W/S or ↑/↓ move · Enter confirm · P pause · R restart",
        shared.status, seat
    );
    draw_text(&line, 12.0, H - 10.0, 14.0, HUD);
}

fn collect_input(shared: &mut Shared) {
    shared.held.clear();
    if is_key_down(KeyCode::W) || is_key_down(KeyCode::Up) {
        shared.held.push("UP".into());
    }
    if is_key_down(KeyCode::S) || is_key_down(KeyCode::Down) {
        shared.held.push("DOWN".into());
    }
    if is_key_pressed(KeyCode::Enter) || is_key_pressed(KeyCode::Space) {
        shared.pressed.push("CONFIRM".into());
    }
    if is_key_pressed(KeyCode::P) || is_key_pressed(KeyCode::Escape) {
        shared.pressed.push("PAUSE".into());
    }
    if is_key_pressed(KeyCode::R) {
        shared.pressed.push("RESTART".into());
    }
}

fn window_conf() -> Conf {
    Conf {
        window_title: "MultiPong — Rust".to_owned(),
        window_width: W as i32,
        window_height: H as i32,
        window_resizable: false,
        ..Default::default()
    }
}

#[macroquad::main(window_conf)]
async fn main() {
    let (url, room, name) = parse_args();
    let shared = Arc::new(Mutex::new(Shared {
        status: "Connecting…".into(),
        ..Default::default()
    }));

    {
        let s = Arc::clone(&shared);
        let title = format!("MultiPong — {name}");
        // macroquad sets title via Conf; keep name in status once connected
        let _ = title;
        net::spawn(url, room, name, s);
    }

    loop {
        if is_key_pressed(KeyCode::Q) && is_key_down(KeyCode::LeftControl) {
            if let Ok(mut g) = shared.lock() {
                g.quit = true;
            }
            break;
        }

        {
            let mut g = shared.lock().expect("shared lock");
            collect_input(&mut g);
            draw_frame(&g);
            if g.quit {
                break;
            }
        }

        next_frame().await;
    }
}
