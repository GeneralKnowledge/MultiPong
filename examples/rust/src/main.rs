//! Polished Rust multiplayer / offline client for MultiPong.
//! Online: renders authoritative `GameState` from the WebSocket server.
//! Offline: local `pong_sim` + canonical `simple_track` AI (seat 2).

mod net;
mod protocol;

use macroquad::prelude::*;
use pong_sim::{ai_held, boot_state, step, C as SIM};
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
const MAX_STEPS: u32 = 5;
const MAX_FRAME: f64 = 0.25;

#[derive(Clone, Copy, PartialEq, Eq)]
enum ClientMode {
    Online,
    Offline,
}

#[derive(Clone)]
struct Shared {
    mode: ClientMode,
    state: Option<GameState>,
    you: Option<u8>,
    seats: Option<RoomInfo>,
    status: String,
    held: Vec<String>,
    pressed: Vec<String>,
    quit: bool,
}

impl Default for Shared {
    fn default() -> Self {
        Self {
            mode: ClientMode::Online,
            state: None,
            you: None,
            seats: None,
            status: String::new(),
            held: Vec::new(),
            pressed: Vec::new(),
            quit: false,
        }
    }
}

struct Args {
    offline: bool,
    url: String,
    room: String,
    name: String,
}

fn parse_args() -> Args {
    let mut offline = false;
    let mut url = "ws://127.0.0.1:8765".to_string();
    let mut room = "demo".to_string();
    let mut name = "rust".to_string();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--offline" => offline = true,
            "--url" => url = args.next().unwrap_or(url),
            "--room" => room = args.next().unwrap_or(room),
            "--name" => name = args.next().unwrap_or(name),
            "-h" | "--help" => {
                eprintln!(
                    "Usage: multipong_client [--offline] [--url ws://host:port] [--room demo] [--name rust]"
                );
                std::process::exit(0);
            }
            _ => {}
        }
    }
    Args {
        offline,
        url,
        room,
        name,
    }
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
                let sub = if shared.mode == ClientMode::Offline {
                    "Press Enter"
                } else {
                    let waiting = shared
                        .seats
                        .as_ref()
                        .map(|s| s.players < 2)
                        .unwrap_or(true);
                    if waiting {
                        "Waiting for opponent…"
                    } else {
                        "Press Enter"
                    }
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

async fn run_offline() {
    let mut state = boot_state();
    let mut shared = Shared {
        mode: ClientMode::Offline,
        state: Some(state.clone()),
        you: Some(SIM.ai_default_human_seat),
        status: "Offline vs AI".into(),
        ..Default::default()
    };
    let mut accum = 0.0_f64;

    loop {
        if is_key_pressed(KeyCode::Q) && is_key_down(KeyCode::LeftControl) {
            break;
        }

        collect_input(&mut shared);
        let frame_dt = get_frame_time() as f64;
        accum += frame_dt.min(MAX_FRAME);

        let mut steps = 0u32;
        let edge = std::mem::take(&mut shared.pressed);
        while accum >= SIM.dt && steps < MAX_STEPS {
            let mut held_owned: Vec<String> = Vec::new();
            if shared.held.iter().any(|h| h == "UP") {
                held_owned.push("P1_UP".into());
            }
            if shared.held.iter().any(|h| h == "DOWN") {
                held_owned.push("P1_DOWN".into());
            }
            for a in ai_held(&state, SIM.ai_default_ai_seat) {
                if !held_owned.contains(&a) {
                    held_owned.push(a);
                }
            }
            let held_refs: Vec<&str> = held_owned.iter().map(String::as_str).collect();
            let pressed_refs: Vec<&str> = if steps == 0 {
                edge.iter().map(String::as_str).collect()
            } else {
                Vec::new()
            };
            step(&mut state, &held_refs, &pressed_refs);
            accum -= SIM.dt;
            steps += 1;
        }

        shared.state = Some(state.clone());
        draw_frame(&shared);
        next_frame().await;
    }
}

async fn run_online(url: String, room: String, name: String) {
    let shared = Arc::new(Mutex::new(Shared {
        mode: ClientMode::Online,
        status: "Connecting…".into(),
        ..Default::default()
    }));

    {
        let s = Arc::clone(&shared);
        let _ = format!("MultiPong — {name}");
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

#[macroquad::main(window_conf)]
async fn main() {
    let args = parse_args();
    if args.offline {
        run_offline().await;
    } else {
        run_online(args.url, args.room, args.name).await;
    }
}
