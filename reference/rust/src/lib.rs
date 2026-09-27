//! Canonical Pong simulation — faithful port of reference/pong/pong_sim.

mod constants;

pub use constants::C;

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use std::collections::HashSet;

pub const MODE_MENU: &str = "MENU";
pub const MODE_PLAYING: &str = "PLAYING";
pub const MODE_POINT_SCORED: &str = "POINT_SCORED";
pub const MODE_PAUSED: &str = "PAUSED";
pub const MODE_GAME_OVER: &str = "GAME_OVER";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ball {
    pub x: f64,
    pub y: f64,
    pub vx: f64,
    pub vy: f64,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Player {
    pub y: f64,
    pub score: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
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

fn clamp(value: f64, lo: f64, hi: f64) -> f64 {
    if value < lo {
        lo
    } else if value > hi {
        hi
    } else {
        value
    }
}

pub fn boot_state() -> GameState {
    GameState {
        mode: MODE_MENU.into(),
        tick: 0,
        elapsed_time: 0.0,
        point_pause_remaining: 0.0,
        mode_before_pause: None,
        ball: Ball {
            x: C.playfield_width / 2.0,
            y: C.playfield_height / 2.0,
            vx: 0.0,
            vy: 0.0,
            active: false,
        },
        player1: Player {
            y: C.playfield_height / 2.0,
            score: 0,
        },
        player2: Player {
            y: C.playfield_height / 2.0,
            score: 0,
        },
        serving_player: 1,
        winner: 0,
    }
}

/// Deep-merge a JSON overlay onto boot state (for tests).
pub fn boot_merged(overlay: &Value) -> GameState {
    let mut base = serde_json::to_value(boot_state()).expect("serialize boot");
    deep_merge_value(&mut base, overlay);
    serde_json::from_value(base).expect("deserialize merged state")
}

fn deep_merge_value(base: &mut Value, overlay: &Value) {
    match (base, overlay) {
        (Value::Object(base_map), Value::Object(over_map)) => {
            for (k, v) in over_map {
                match base_map.get_mut(k) {
                    Some(bv) if bv.is_object() && v.is_object() => deep_merge_value(bv, v),
                    _ => {
                        base_map.insert(k.clone(), v.clone());
                    }
                }
            }
        }
        (base, overlay) => *base = overlay.clone(),
    }
}

fn reset_ball_for_serve(state: &mut GameState, serving_player: u8) {
    state.ball.x = C.playfield_width / 2.0;
    state.ball.y = C.playfield_height / 2.0;
    state.ball.active = false;
    let speed = C.ball_speed_initial;
    if serving_player == 1 {
        state.ball.vx = speed;
        state.ball.vy = 0.0;
    } else {
        state.ball.vx = -speed;
        state.ball.vy = 0.0;
    }
    state.serving_player = serving_player;
}

fn start_match(state: &mut GameState) -> Vec<String> {
    state.player1.score = 0;
    state.player2.score = 0;
    state.player1.y = C.playfield_height / 2.0;
    state.player2.y = C.playfield_height / 2.0;
    state.winner = 0;
    state.tick = 0;
    state.elapsed_time = 0.0;
    state.point_pause_remaining = 0.0;
    state.mode_before_pause = None;
    reset_ball_for_serve(state, 1);
    state.ball.active = true;
    state.mode = MODE_PLAYING.into();
    vec!["ui_confirm".into()]
}

fn full_reset(state: &mut GameState) {
    *state = boot_state();
}

fn move_paddles(state: &mut GameState, held: &HashSet<&str>) {
    let mut dy1 = 0.0;
    if held.contains("P1_UP") {
        dy1 -= C.paddle_speed * C.dt;
    }
    if held.contains("P1_DOWN") {
        dy1 += C.paddle_speed * C.dt;
    }
    state.player1.y = clamp(state.player1.y + dy1, C.paddle_y_min, C.paddle_y_max);

    let mut dy2 = 0.0;
    if held.contains("P2_UP") {
        dy2 -= C.paddle_speed * C.dt;
    }
    if held.contains("P2_DOWN") {
        dy2 += C.paddle_speed * C.dt;
    }
    state.player2.y = clamp(state.player2.y + dy2, C.paddle_y_min, C.paddle_y_max);
}

fn wall_collisions(state: &mut GameState, events: &mut Vec<String>) {
    let ball = &mut state.ball;
    if ball.y - C.ball_radius < 0.0 {
        ball.y = C.ball_radius;
        ball.vy = ball.vy.abs();
        events.push("wall_hit".into());
    }
    if ball.y + C.ball_radius > C.playfield_height {
        ball.y = C.playfield_height - C.ball_radius;
        ball.vy = -ball.vy.abs();
        events.push("wall_hit".into());
    }
}

fn paddle_overlap(ball: &Ball, paddle_x: f64, paddle_y: f64) -> bool {
    let left = paddle_x - C.paddle_width / 2.0;
    let right = paddle_x + C.paddle_width / 2.0;
    let top = paddle_y - C.paddle_height / 2.0;
    let bottom = paddle_y + C.paddle_height / 2.0;
    let closest_x = clamp(ball.x, left, right);
    let closest_y = clamp(ball.y, top, bottom);
    let dx = ball.x - closest_x;
    let dy = ball.y - closest_y;
    dx * dx + dy * dy <= C.ball_radius * C.ball_radius
}

fn paddle_hit(state: &mut GameState, which: u8, events: &mut Vec<String>) {
    let (paddle_x, paddle_y, direction) = if which == 1 {
        if state.ball.vx >= 0.0 {
            return;
        }
        (C.paddle_p1_x, state.player1.y, 1.0)
    } else {
        if state.ball.vx <= 0.0 {
            return;
        }
        (C.paddle_p2_x, state.player2.y, -1.0)
    };

    if !paddle_overlap(&state.ball, paddle_x, paddle_y) {
        return;
    }

    events.push("paddle_hit".into());
    let mut offset = (state.ball.y - paddle_y) / (C.paddle_height / 2.0);
    offset = clamp(offset, -1.0, 1.0);
    let old_speed = (state.ball.vx * state.ball.vx + state.ball.vy * state.ball.vy).sqrt();
    let new_speed = (old_speed + C.ball_speed_increment).min(C.ball_speed_max);
    let angle_rad = offset * C.max_bounce_angle_deg * std::f64::consts::PI / 180.0;
    state.ball.vx = new_speed * angle_rad.cos() * direction;
    state.ball.vy = new_speed * angle_rad.sin();
    if which == 1 {
        state.ball.x = paddle_x + C.paddle_width / 2.0 + C.ball_radius + C.separation_epsilon;
    } else {
        state.ball.x = paddle_x - C.paddle_width / 2.0 - C.ball_radius - C.separation_epsilon;
    }
}

fn handle_point_scored(state: &mut GameState, scored_by: u8, events: &mut Vec<String>) {
    if state.player1.score >= C.score_to_win || state.player2.score >= C.score_to_win {
        state.mode = MODE_GAME_OVER.into();
        state.winner = if state.player1.score >= C.score_to_win {
            1
        } else {
            2
        };
        state.ball.active = false;
        events.push("game_over".into());
        return;
    }
    state.mode = MODE_POINT_SCORED.into();
    state.point_pause_remaining = C.point_pause_duration;
    let serving = if scored_by == 1 { 2 } else { 1 };
    reset_ball_for_serve(state, serving);
}

fn check_scoring(state: &mut GameState, events: &mut Vec<String>) {
    if state.ball.x + C.ball_radius < 0.0 {
        state.player2.score += 1;
        events.push("score".into());
        handle_point_scored(state, 2, events);
        return;
    }
    if state.ball.x - C.ball_radius > C.playfield_width {
        state.player1.score += 1;
        events.push("score".into());
        handle_point_scored(state, 1, events);
    }
}

fn playing_physics(state: &mut GameState, held: &HashSet<&str>, events: &mut Vec<String>) {
    move_paddles(state, held);
    if state.ball.active {
        state.ball.x += state.ball.vx * C.dt;
        state.ball.y += state.ball.vy * C.dt;
        wall_collisions(state, events);
        paddle_hit(state, 1, events);
        paddle_hit(state, 2, events);
        check_scoring(state, events);
    }
    if state.mode == MODE_PLAYING || state.mode == MODE_POINT_SCORED {
        state.tick += 1;
        state.elapsed_time = state.tick as f64 * C.dt;
    }
}

/// Advance one fixed tick. Mutates state. Returns events.
pub fn step(state: &mut GameState, held: &[&str], pressed: &[&str]) -> Vec<String> {
    let held_set: HashSet<&str> = held
        .iter()
        .copied()
        .filter(|a| matches!(*a, "P1_UP" | "P1_DOWN" | "P2_UP" | "P2_DOWN"))
        .collect();
    let pressed_set: HashSet<&str> = pressed
        .iter()
        .copied()
        .filter(|a| matches!(*a, "CONFIRM" | "PAUSE" | "RESTART"))
        .collect();
    let mut events = Vec::new();
    let mode = state.mode.clone();

    if mode == MODE_MENU {
        if pressed_set.contains("RESTART") {
            full_reset(state);
            return events;
        }
        if pressed_set.contains("CONFIRM") {
            events.extend(start_match(state));
        }
        return events;
    }

    if mode == MODE_PLAYING {
        if pressed_set.contains("RESTART") {
            full_reset(state);
            return events;
        }
        if pressed_set.contains("PAUSE") {
            state.mode_before_pause = Some(MODE_PLAYING.into());
            state.mode = MODE_PAUSED.into();
            return events;
        }
        playing_physics(state, &held_set, &mut events);
        return events;
    }

    if mode == MODE_POINT_SCORED {
        if pressed_set.contains("RESTART") {
            full_reset(state);
            return events;
        }
        if pressed_set.contains("PAUSE") {
            state.mode_before_pause = Some(MODE_POINT_SCORED.into());
            state.mode = MODE_PAUSED.into();
            return events;
        }
        move_paddles(state, &held_set);
        state.point_pause_remaining -= C.dt;
        if state.point_pause_remaining <= 0.0 {
            state.point_pause_remaining = 0.0;
            state.mode = MODE_PLAYING.into();
            state.ball.active = true;
        }
        state.tick += 1;
        state.elapsed_time = state.tick as f64 * C.dt;
        return events;
    }

    if mode == MODE_PAUSED {
        if pressed_set.contains("RESTART") {
            full_reset(state);
            return events;
        }
        if pressed_set.contains("PAUSE") {
            state.mode = state
                .mode_before_pause
                .clone()
                .unwrap_or_else(|| MODE_PLAYING.into());
            state.mode_before_pause = None;
        }
        return events;
    }

    if mode == MODE_GAME_OVER {
        if pressed_set.contains("CONFIRM") {
            events.push("ui_confirm".into());
            full_reset(state);
            return events;
        }
        if pressed_set.contains("RESTART") {
            full_reset(state);
        }
    }

    events
}

pub fn state_to_value(state: &GameState) -> Value {
    serde_json::to_value(state).expect("state to json")
}

pub fn get_path<'a>(obj: &'a Value, path: &[String]) -> Option<&'a Value> {
    let mut cur = obj;
    for key in path {
        cur = cur.as_object()?.get(key)?;
    }
    Some(cur)
}

pub fn collect_expect_paths(node: &Map<String, Value>, prefix: &[String]) -> Vec<(Vec<String>, Value)> {
    let mut out = Vec::new();
    for (key, value) in node {
        let mut path = prefix.to_vec();
        path.push(key.clone());
        if let Some(map) = value.as_object() {
            out.extend(collect_expect_paths(map, &path));
        } else {
            out.push((path, value.clone()));
        }
    }
    out
}
