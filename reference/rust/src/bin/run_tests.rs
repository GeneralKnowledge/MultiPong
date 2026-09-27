//! Run canonical specs/pong/tests against the Rust reference simulation.

use pong_sim::{
    boot_merged, collect_expect_paths, get_path, state_to_value, step, C,
};
use serde::Deserialize;
use serde_json::Value;
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Debug, Deserialize)]
struct TestFile {
    initial: Option<Value>,
    steps: Option<Vec<StepSpec>>,
    expect: Option<Expect>,
}

#[derive(Debug, Deserialize)]
struct StepSpec {
    held: Option<Vec<String>>,
    pressed: Option<Vec<String>>,
    repeat: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct Expect {
    state: Option<Value>,
    events: Option<Vec<String>>,
    events_ordered: Option<bool>,
    position_epsilon: Option<f64>,
    velocity_epsilon: Option<f64>,
}

fn expand_steps(steps: &[StepSpec]) -> Vec<(Vec<String>, Vec<String>)> {
    let mut frames = Vec::new();
    for s in steps {
        let repeat = s.repeat.unwrap_or(1);
        let held = s.held.clone().unwrap_or_default();
        let pressed = s.pressed.clone().unwrap_or_default();
        for _ in 0..repeat {
            frames.push((held.clone(), pressed.clone()));
        }
    }
    frames
}

fn values_close(expected: &Value, actual: Option<&Value>, pos_eps: f64, vel_eps: f64, path: &[String]) -> bool {
    let Some(actual) = actual else {
        return false;
    };
    if expected.is_boolean() || expected.is_null() {
        return expected == actual;
    }
    if let Some(ei) = expected.as_i64() {
        if let Some(ai) = actual.as_i64() {
            return ei == ai;
        }
        if let Some(af) = actual.as_f64() {
            return (af - ei as f64).abs() < 1e-9;
        }
        return false;
    }
    if expected.is_u64() {
        return expected.as_u64() == actual.as_u64()
            || (expected.as_u64().unwrap() as f64 - actual.as_f64().unwrap_or(f64::NAN)).abs() < 1e-9;
    }
    if expected.is_f64() || actual.is_f64() {
        let leaf = path.last().map(|s| s.as_str()).unwrap_or("");
        let mut eps = if leaf == "vx" || leaf == "vy" {
            vel_eps
        } else {
            pos_eps
        };
        if leaf == "elapsed_time" || leaf == "point_pause_remaining" {
            eps = pos_eps;
        }
        let e = expected.as_f64().unwrap_or(f64::NAN);
        let a = actual.as_f64().unwrap_or(f64::NAN);
        return (a - e).abs() <= eps;
    }
    if expected.is_string() {
        return expected.as_str() == actual.as_str();
    }
    expected == actual
}

fn run_test(path: &PathBuf) -> Result<(), String> {
    let data: TestFile = serde_json::from_str(
        &fs::read_to_string(path).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;

    let overlay = data.initial.unwrap_or(Value::Object(Default::default()));
    let mut state = boot_merged(&overlay);
    let mut events: Vec<String> = Vec::new();
    for (held, pressed) in expand_steps(data.steps.as_deref().unwrap_or(&[])) {
        let held_refs: Vec<&str> = held.iter().map(|s| s.as_str()).collect();
        let pressed_refs: Vec<&str> = pressed.iter().map(|s| s.as_str()).collect();
        events.extend(step(&mut state, &held_refs, &pressed_refs));
    }

    let expect = data.expect.unwrap_or(Expect {
        state: None,
        events: None,
        events_ordered: None,
        position_epsilon: None,
        velocity_epsilon: None,
    });
    let pos_eps = expect.position_epsilon.unwrap_or(C.position_epsilon);
    let vel_eps = expect.velocity_epsilon.unwrap_or(C.velocity_epsilon);
    let state_val = state_to_value(&state);

    if let Some(Value::Object(map)) = expect.state {
        for (path_keys, expected) in collect_expect_paths(&map, &[]) {
            let actual = get_path(&state_val, &path_keys);
            if !values_close(&expected, actual, pos_eps, vel_eps, &path_keys) {
                return Err(format!(
                    "{}: expected {:?}, got {:?}",
                    path_keys.join("."),
                    expected,
                    actual
                ));
            }
        }
    }

    if let Some(expected_events) = expect.events {
        if expect.events_ordered.unwrap_or(false) {
            if events != expected_events {
                return Err(format!(
                    "events: expected {:?}, got {:?}",
                    expected_events, events
                ));
            }
        } else {
            for name in &expected_events {
                if !events.iter().any(|e| e == name) {
                    return Err(format!("missing event {:?}; got {:?}", name, events));
                }
            }
        }
    }
    Ok(())
}

fn main() -> ExitCode {
    let tests_dir = C.spec_dir.join("tests");
    let mut files: Vec<PathBuf> = fs::read_dir(&tests_dir)
        .expect("tests dir")
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.extension().and_then(|s| s.to_str()) == Some("json"))
        .collect();
    files.sort();
    if files.is_empty() {
        eprintln!("No tests found");
        return ExitCode::FAILURE;
    }

    let mut passed = 0u32;
    let mut failed = 0u32;
    for path in &files {
        let id = path.file_stem().unwrap().to_string_lossy();
        match run_test(path) {
            Ok(()) => {
                println!("PASS  {id}");
                passed += 1;
            }
            Err(detail) => {
                println!("FAIL  {id}  {detail}");
                failed += 1;
            }
        }
    }
    println!("\n{passed}/{} passed", passed + failed);
    if failed == 0 {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}
