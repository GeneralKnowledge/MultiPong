//! Loads specs/pong/constants.json relative to the repo (via CARGO_MANIFEST_DIR).

use serde::Deserialize;
use std::path::PathBuf;
use std::sync::LazyLock;

#[derive(Debug, Deserialize)]
struct Raw {
    playfield: Playfield,
    simulation: Simulation,
    ball: Ball,
    paddle: Paddle,
    scoring: Scoring,
    comparison: Comparison,
}

#[derive(Debug, Deserialize)]
struct Playfield {
    width: f64,
    height: f64,
}

#[derive(Debug, Deserialize)]
struct Simulation {
    tick_rate: u32,
}

#[derive(Debug, Deserialize)]
struct Ball {
    radius: f64,
    speed_initial: f64,
    speed_max: f64,
    speed_increment: f64,
    separation_epsilon: f64,
}

#[derive(Debug, Deserialize)]
struct Paddle {
    width: f64,
    height: f64,
    speed: f64,
    p1_x: f64,
    p2_x: f64,
    max_bounce_angle_deg: f64,
}

#[derive(Debug, Deserialize)]
struct Scoring {
    score_to_win: i32,
    point_pause_duration: f64,
}

#[derive(Debug, Deserialize)]
struct Comparison {
    position_epsilon: f64,
    velocity_epsilon: f64,
}

pub struct Constants {
    pub spec_dir: PathBuf,
    pub playfield_width: f64,
    pub playfield_height: f64,
    pub tick_rate: u32,
    pub dt: f64,
    pub ball_radius: f64,
    pub ball_speed_initial: f64,
    pub ball_speed_max: f64,
    pub ball_speed_increment: f64,
    pub separation_epsilon: f64,
    pub paddle_width: f64,
    pub paddle_height: f64,
    pub paddle_speed: f64,
    pub paddle_p1_x: f64,
    pub paddle_p2_x: f64,
    pub max_bounce_angle_deg: f64,
    pub paddle_y_min: f64,
    pub paddle_y_max: f64,
    pub score_to_win: i32,
    pub point_pause_duration: f64,
    pub position_epsilon: f64,
    pub velocity_epsilon: f64,
}

fn load() -> Constants {
    let spec_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../specs/pong")
        .canonicalize()
        .expect("resolve specs/pong");
    let raw_text = std::fs::read_to_string(spec_dir.join("constants.json"))
        .expect("read constants.json");
    let raw: Raw = serde_json::from_str(&raw_text).expect("parse constants.json");
    Constants {
        playfield_width: raw.playfield.width,
        playfield_height: raw.playfield.height,
        tick_rate: raw.simulation.tick_rate,
        dt: 1.0 / f64::from(raw.simulation.tick_rate),
        ball_radius: raw.ball.radius,
        ball_speed_initial: raw.ball.speed_initial,
        ball_speed_max: raw.ball.speed_max,
        ball_speed_increment: raw.ball.speed_increment,
        separation_epsilon: raw.ball.separation_epsilon,
        paddle_width: raw.paddle.width,
        paddle_height: raw.paddle.height,
        paddle_speed: raw.paddle.speed,
        paddle_p1_x: raw.paddle.p1_x,
        paddle_p2_x: raw.paddle.p2_x,
        max_bounce_angle_deg: raw.paddle.max_bounce_angle_deg,
        paddle_y_min: raw.paddle.height / 2.0,
        paddle_y_max: raw.playfield.height - raw.paddle.height / 2.0,
        score_to_win: raw.scoring.score_to_win,
        point_pause_duration: raw.scoring.point_pause_duration,
        position_epsilon: raw.comparison.position_epsilon,
        velocity_epsilon: raw.comparison.velocity_epsilon,
        spec_dir,
    }
}

pub static C: LazyLock<Constants> = LazyLock::new(load);
