//! Protocol types matching specs/pong/PROTOCOL.md and state.schema.json.

use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)] // protocol mirror of specs/pong/state.schema.json
pub struct Ball {
    pub x: f64,
    pub y: f64,
    pub vx: f64,
    pub vy: f64,
    pub active: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Player {
    pub y: f64,
    pub score: i32,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
pub struct GameState {
    pub mode: String,
    pub tick: u64,
    pub elapsed_time: f64,
    pub point_pause_remaining: f64,
    pub mode_before_pause: Option<String>,
    pub ball: Ball,
    pub player1: Player,
    pub player2: Player,
    pub serving_player: u8,
    pub winner: u8,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
pub struct RoomInfo {
    pub room: String,
    pub players: u8,
}

#[derive(Debug, Deserialize)]
pub struct Envelope {
    #[serde(rename = "type")]
    pub kind: String,
    pub player: Option<u8>,
    pub you: Option<u8>,
    pub message: Option<String>,
    pub room: Option<String>,
    pub players: Option<u8>,
    pub state: Option<GameState>,
}
