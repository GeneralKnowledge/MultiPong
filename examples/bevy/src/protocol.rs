//! Protocol types matching specs/pong/PROTOCOL.md.

pub use pong_sim::GameState;

use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
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
