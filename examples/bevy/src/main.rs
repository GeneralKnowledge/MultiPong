//! Bevy dual-mode MultiPong client.
//! Offline: local `pong_sim` + canonical `simple_track` AI (seat 2).
//! Online: authoritative WebSocket server.
//! Rendering only — no Bevy physics for gameplay.

mod net;
mod protocol;

use bevy::prelude::*;
use bevy::sprite::Anchor;
use bevy::text::{Text2d, TextColor, TextFont};
use bevy::window::WindowResolution;
use net::NetHandle;
use pong_sim::{ai_held, boot_state, step, C as SIM, GameState};
use protocol::RoomInfo;
use std::sync::{Arc, Mutex};

const W: f32 = 800.0;
const H: f32 = 600.0;
const MAX_STEPS: u32 = 5;
const MAX_FRAME: f64 = 0.25;

#[derive(Clone, Copy, PartialEq, Eq, Resource)]
enum ClientMode {
    Online,
    Offline,
}

#[derive(Clone)]
pub struct Shared {
    pub state: Option<GameState>,
    pub you: Option<u8>,
    pub seats: Option<RoomInfo>,
    pub status: String,
    pub held: Vec<String>,
    pub pressed: Vec<String>,
    pub quit: bool,
}

impl Default for Shared {
    fn default() -> Self {
        Self {
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

#[derive(Resource)]
struct OfflineSim {
    state: GameState,
    accum: f64,
}

#[derive(Resource)]
struct Args {
    offline: bool,
    url: String,
    room: String,
    name: String,
}

/// Entity handles for presentation — avoids conflicting multi-Visibility queries.
#[derive(Resource)]
struct View {
    p1: Entity,
    p2: Entity,
    outline1: Entity,
    outline2: Entity,
    ball: Entity,
    score1: Entity,
    score2: Entity,
    menu_title: Entity,
    menu_sub: Entity,
    overlay: Entity,
    overlay_hint: Entity,
    idle_brand: Entity,
    idle_hint: Entity,
    hud: Entity,
}

fn parse_args() -> Args {
    let mut offline = false;
    let mut url = "ws://127.0.0.1:8765".to_string();
    let mut room = "demo".to_string();
    let mut name = "bevy".to_string();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--offline" => offline = true,
            "--url" => url = args.next().unwrap_or(url),
            "--room" => room = args.next().unwrap_or(room),
            "--name" => name = args.next().unwrap_or(name),
            "-h" | "--help" => {
                eprintln!(
                    "Usage: multipong_bevy [--offline] [--url ws://host:port] [--room demo] [--name bevy]"
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

/// Spec is Y-down, origin top-left. Bevy 2D is Y-up, origin centre.
fn to_bevy(x: f64, y: f64) -> Vec3 {
    Vec3::new((x as f32) - W * 0.5, H * 0.5 - (y as f32), 0.0)
}

fn color_hex(r: u8, g: u8, b: u8) -> Color {
    Color::srgb_u8(r, g, b)
}

fn set_vis(q: &mut Query<&mut Visibility>, entity: Entity, visible: bool) {
    if let Ok(mut v) = q.get_mut(entity) {
        *v = if visible {
            Visibility::Visible
        } else {
            Visibility::Hidden
        };
    }
}

fn main() {
    let args = parse_args();
    let mode = if args.offline {
        ClientMode::Offline
    } else {
        ClientMode::Online
    };

    let shared = Arc::new(Mutex::new(Shared {
        status: if args.offline {
            "Offline vs AI".into()
        } else {
            "Connecting…".into()
        },
        you: if args.offline {
            Some(SIM.ai_default_human_seat)
        } else {
            None
        },
        state: if args.offline {
            Some(boot_state())
        } else {
            None
        },
        ..Default::default()
    }));

    let mut app = App::new();
    let window_title = if args.offline {
        "MultiPong — offline vs AI"
    } else {
        "MultiPong — Bevy"
    };

    app.insert_resource(ClearColor(color_hex(0x0b, 0x0e, 0x14)))
        .insert_resource(mode)
        .insert_resource(Args {
            offline: args.offline,
            url: args.url.clone(),
            room: args.room.clone(),
            name: args.name.clone(),
        })
        .insert_resource(NetHandle(Arc::clone(&shared)))
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: window_title.into(),
                resolution: WindowResolution::new(W, H),
                resizable: false,
                ..default()
            }),
            ..default()
        }))
        .add_systems(Startup, setup);

    if args.offline {
        app.insert_resource(OfflineSim {
            state: boot_state(),
            accum: 0.0,
        })
        .add_systems(Update, (collect_input, offline_step, sync_view).chain());
    } else {
        net::spawn(args.url, args.room, args.name, Arc::clone(&shared));
        app.add_systems(Update, (collect_input, sync_view).chain());
    }

    app.run();
}

fn setup(mut commands: Commands) {
    commands.spawn(Camera2d);

    let mut y = 0.0_f32;
    while y < H {
        let cy = y + 8.0;
        commands.spawn((
            Sprite {
                color: color_hex(0x2a, 0x33, 0x44),
                custom_size: Some(Vec2::new(4.0, 16.0)),
                ..default()
            },
            Transform::from_translation(to_bevy(400.0, cy as f64)),
        ));
        y += 16.0 + 12.0;
    }

    let p1 = commands
        .spawn((
            Sprite {
                color: color_hex(0xe8, 0xee, 0xf5),
                custom_size: Some(Vec2::new(SIM.paddle_width as f32, SIM.paddle_height as f32)),
                ..default()
            },
            Transform::from_translation(to_bevy(SIM.paddle_p1_x, SIM.playfield_height / 2.0)),
        ))
        .id();
    let p2 = commands
        .spawn((
            Sprite {
                color: color_hex(0xe8, 0xee, 0xf5),
                custom_size: Some(Vec2::new(SIM.paddle_width as f32, SIM.paddle_height as f32)),
                ..default()
            },
            Transform::from_translation(to_bevy(SIM.paddle_p2_x, SIM.playfield_height / 2.0)),
        ))
        .id();
    let outline1 = commands
        .spawn((
            Sprite {
                color: Color::srgba(0.5, 0.82, 0.77, 0.35),
                custom_size: Some(Vec2::new(
                    SIM.paddle_width as f32 + 4.0,
                    SIM.paddle_height as f32 + 4.0,
                )),
                ..default()
            },
            Transform::from_translation(
                to_bevy(SIM.paddle_p1_x, SIM.playfield_height / 2.0) + Vec3::new(0.0, 0.0, -0.1),
            ),
            Visibility::Hidden,
        ))
        .id();
    let outline2 = commands
        .spawn((
            Sprite {
                color: Color::srgba(0.5, 0.82, 0.77, 0.35),
                custom_size: Some(Vec2::new(
                    SIM.paddle_width as f32 + 4.0,
                    SIM.paddle_height as f32 + 4.0,
                )),
                ..default()
            },
            Transform::from_translation(
                to_bevy(SIM.paddle_p2_x, SIM.playfield_height / 2.0) + Vec3::new(0.0, 0.0, -0.1),
            ),
            Visibility::Hidden,
        ))
        .id();
    let ball = commands
        .spawn((
            Sprite {
                color: color_hex(0xf2, 0xf5, 0xf8),
                custom_size: Some(Vec2::splat(SIM.ball_radius as f32 * 2.0)),
                ..default()
            },
            Transform::from_translation(to_bevy(
                SIM.playfield_width / 2.0,
                SIM.playfield_height / 2.0,
            )),
        ))
        .id();

    let font32 = TextFont {
        font_size: 32.0,
        ..default()
    };
    let score1 = commands
        .spawn((
            Text2d::new("0"),
            font32.clone(),
            TextColor(color_hex(0xf2, 0xf5, 0xf8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(300.0, 48.0) + Vec3::Z * 2.0),
        ))
        .id();
    let score2 = commands
        .spawn((
            Text2d::new("0"),
            font32,
            TextColor(color_hex(0xf2, 0xf5, 0xf8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(500.0, 48.0) + Vec3::Z * 2.0),
        ))
        .id();

    let menu_title = commands
        .spawn((
            Text2d::new("PONG"),
            TextFont {
                font_size: 48.0,
                ..default()
            },
            TextColor(color_hex(0xf2, 0xf5, 0xf8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(400.0, 220.0) + Vec3::Z * 2.0),
            Visibility::Hidden,
        ))
        .id();
    let menu_sub = commands
        .spawn((
            Text2d::new("Press Enter"),
            TextFont {
                font_size: 16.0,
                ..default()
            },
            TextColor(color_hex(0xf2, 0xf5, 0xf8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(400.0, 300.0) + Vec3::Z * 2.0),
            Visibility::Hidden,
        ))
        .id();
    let overlay = commands
        .spawn((
            Text2d::new(""),
            TextFont {
                font_size: 48.0,
                ..default()
            },
            TextColor(color_hex(0xf2, 0xf5, 0xf8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(400.0, 300.0) + Vec3::Z * 2.0),
            Visibility::Hidden,
        ))
        .id();
    let overlay_hint = commands
        .spawn((
            Text2d::new(""),
            TextFont {
                font_size: 16.0,
                ..default()
            },
            TextColor(color_hex(0xf2, 0xf5, 0xf8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(400.0, 328.0) + Vec3::Z * 2.0),
            Visibility::Hidden,
        ))
        .id();
    let idle_brand = commands
        .spawn((
            Text2d::new("MULTIPONG"),
            TextFont {
                font_size: 36.0,
                ..default()
            },
            TextColor(color_hex(0xf2, 0xf5, 0xf8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(400.0, 280.0) + Vec3::Z * 2.0),
        ))
        .id();
    let idle_hint = commands
        .spawn((
            Text2d::new("Offline vs AI · or waiting…"),
            TextFont {
                font_size: 16.0,
                ..default()
            },
            TextColor(color_hex(0x8b, 0x95, 0xa8)),
            TextLayout::new_with_justify(JustifyText::Center),
            Anchor::Center,
            Transform::from_translation(to_bevy(400.0, 324.0) + Vec3::Z * 2.0),
        ))
        .id();
    let hud = commands
        .spawn((
            Text2d::new(""),
            TextFont {
                font_size: 14.0,
                ..default()
            },
            TextColor(color_hex(0x8b, 0x95, 0xa8)),
            TextLayout::new_with_justify(JustifyText::Left),
            Anchor::BottomLeft,
            Transform::from_translation(to_bevy(12.0, 588.0) + Vec3::Z * 3.0),
        ))
        .id();

    commands.insert_resource(View {
        p1,
        p2,
        outline1,
        outline2,
        ball,
        score1,
        score2,
        menu_title,
        menu_sub,
        overlay,
        overlay_hint,
        idle_brand,
        idle_hint,
        hud,
    });
}

fn collect_input(
    keys: Res<ButtonInput<KeyCode>>,
    net: Res<NetHandle>,
    mut exit: EventWriter<AppExit>,
) {
    let Ok(mut g) = net.0.lock() else {
        return;
    };
    if keys.pressed(KeyCode::ControlLeft) && keys.just_pressed(KeyCode::KeyQ) {
        g.quit = true;
        exit.send(AppExit::Success);
        return;
    }
    g.held.clear();
    if keys.pressed(KeyCode::KeyW) || keys.pressed(KeyCode::ArrowUp) {
        g.held.push("UP".into());
    }
    if keys.pressed(KeyCode::KeyS) || keys.pressed(KeyCode::ArrowDown) {
        g.held.push("DOWN".into());
    }
    if keys.just_pressed(KeyCode::Enter) || keys.just_pressed(KeyCode::Space) {
        g.pressed.push("CONFIRM".into());
    }
    if keys.just_pressed(KeyCode::KeyP) || keys.just_pressed(KeyCode::Escape) {
        g.pressed.push("PAUSE".into());
    }
    if keys.just_pressed(KeyCode::KeyR) {
        g.pressed.push("RESTART".into());
    }
}

fn offline_step(time: Res<Time>, net: Res<NetHandle>, mut sim: ResMut<OfflineSim>) {
    let Ok(mut g) = net.0.lock() else {
        return;
    };
    let mut frame_dt = time.delta_secs_f64();
    if frame_dt > MAX_FRAME {
        frame_dt = MAX_FRAME;
    }
    sim.accum += frame_dt;

    let mut steps = 0u32;
    let edge = std::mem::take(&mut g.pressed);
    while sim.accum >= SIM.dt && steps < MAX_STEPS {
        let mut held_owned: Vec<String> = Vec::new();
        if g.held.iter().any(|h| h == "UP") {
            held_owned.push("P1_UP".into());
        }
        if g.held.iter().any(|h| h == "DOWN") {
            held_owned.push("P1_DOWN".into());
        }
        for a in ai_held(&sim.state, SIM.ai_default_ai_seat) {
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
        step(&mut sim.state, &held_refs, &pressed_refs);
        sim.accum -= SIM.dt;
        steps += 1;
    }
    g.state = Some(sim.state.clone());
    g.you = Some(SIM.ai_default_human_seat);
    g.status = "Offline vs AI".into();
}

fn sync_view(
    mode: Res<ClientMode>,
    net: Res<NetHandle>,
    view: Res<View>,
    mut q_vis: Query<&mut Visibility>,
    mut q_tf: Query<&mut Transform>,
    mut q_text: Query<&mut Text2d>,
    mut q_font: Query<&mut TextFont>,
) {
    let Ok(g) = net.0.lock() else {
        return;
    };
    let you = g.you;
    let seats = g.seats.clone();
    let status = g.status.clone();
    let state = g.state.clone();

    if let Ok(mut hud_text) = q_text.get_mut(view.hud) {
        let seat = you.map(|y| format!("P{y}")).unwrap_or_else(|| "—".into());
        **hud_text = format!("{status}   seat {seat}   W/S or ↑/↓ · Enter · P · R");
    }

    let Some(state) = state else {
        for e in [
            view.p1,
            view.p2,
            view.outline1,
            view.outline2,
            view.ball,
            view.score1,
            view.score2,
            view.menu_title,
            view.menu_sub,
            view.overlay,
            view.overlay_hint,
        ] {
            set_vis(&mut q_vis, e, false);
        }
        set_vis(&mut q_vis, view.idle_brand, true);
        set_vis(&mut q_vis, view.idle_hint, true);
        return;
    };

    set_vis(&mut q_vis, view.idle_brand, false);
    set_vis(&mut q_vis, view.idle_hint, false);

    set_vis(&mut q_vis, view.p1, true);
    set_vis(&mut q_vis, view.p2, true);
    set_vis(&mut q_vis, view.ball, true);
    set_vis(&mut q_vis, view.score1, true);
    set_vis(&mut q_vis, view.score2, true);
    set_vis(&mut q_vis, view.outline1, you == Some(1));
    set_vis(&mut q_vis, view.outline2, you == Some(2));

    if let Ok(mut tf) = q_tf.get_mut(view.p1) {
        *tf = Transform::from_translation(to_bevy(SIM.paddle_p1_x, state.player1.y));
    }
    if let Ok(mut tf) = q_tf.get_mut(view.p2) {
        *tf = Transform::from_translation(to_bevy(SIM.paddle_p2_x, state.player2.y));
    }
    if let Ok(mut tf) = q_tf.get_mut(view.outline1) {
        *tf = Transform::from_translation(
            to_bevy(SIM.paddle_p1_x, state.player1.y) + Vec3::new(0.0, 0.0, -0.1),
        );
    }
    if let Ok(mut tf) = q_tf.get_mut(view.outline2) {
        *tf = Transform::from_translation(
            to_bevy(SIM.paddle_p2_x, state.player2.y) + Vec3::new(0.0, 0.0, -0.1),
        );
    }
    if let Ok(mut tf) = q_tf.get_mut(view.ball) {
        *tf = Transform::from_translation(to_bevy(state.ball.x, state.ball.y));
    }
    if let Ok(mut t) = q_text.get_mut(view.score1) {
        **t = state.player1.score.to_string();
    }
    if let Ok(mut t) = q_text.get_mut(view.score2) {
        **t = state.player2.score.to_string();
    }

    set_vis(&mut q_vis, view.menu_title, false);
    set_vis(&mut q_vis, view.menu_sub, false);
    set_vis(&mut q_vis, view.overlay, false);
    set_vis(&mut q_vis, view.overlay_hint, false);

    match state.mode.as_str() {
        "MENU" => {
            set_vis(&mut q_vis, view.menu_title, true);
            set_vis(&mut q_vis, view.menu_sub, true);
            if let Ok(mut text) = q_text.get_mut(view.menu_sub) {
                let waiting = if *mode == ClientMode::Offline {
                    false
                } else {
                    seats.as_ref().map(|s| s.players < 2).unwrap_or(true)
                };
                **text = if waiting {
                    "Waiting for opponent…".into()
                } else {
                    "Press Enter".into()
                };
            }
        }
        "PAUSED" => {
            set_vis(&mut q_vis, view.overlay, true);
            if let Ok(mut text) = q_text.get_mut(view.overlay) {
                **text = "PAUSED".into();
            }
            if let Ok(mut font) = q_font.get_mut(view.overlay) {
                font.font_size = 48.0;
            }
            if let Ok(mut tf) = q_tf.get_mut(view.overlay) {
                *tf = Transform::from_translation(to_bevy(400.0, 300.0) + Vec3::Z * 2.0);
            }
        }
        "GAME_OVER" => {
            set_vis(&mut q_vis, view.overlay, true);
            set_vis(&mut q_vis, view.overlay_hint, true);
            if let Ok(mut text) = q_text.get_mut(view.overlay) {
                **text = if state.winner == 1 {
                    "PLAYER 1 WINS".into()
                } else {
                    "PLAYER 2 WINS".into()
                };
            }
            if let Ok(mut font) = q_font.get_mut(view.overlay) {
                font.font_size = 48.0;
            }
            if let Ok(mut tf) = q_tf.get_mut(view.overlay) {
                *tf = Transform::from_translation(to_bevy(400.0, 276.0) + Vec3::Z * 2.0);
            }
            if let Ok(mut text) = q_text.get_mut(view.overlay_hint) {
                **text = "Press Enter".into();
            }
        }
        "POINT_SCORED" => {
            set_vis(&mut q_vis, view.overlay, true);
            if let Ok(mut text) = q_text.get_mut(view.overlay) {
                **text = "Point!".into();
            }
            if let Ok(mut font) = q_font.get_mut(view.overlay) {
                font.font_size = 16.0;
            }
            if let Ok(mut tf) = q_tf.get_mut(view.overlay) {
                *tf = Transform::from_translation(to_bevy(400.0, 300.0) + Vec3::Z * 2.0);
            }
        }
        _ => {}
    }
}
