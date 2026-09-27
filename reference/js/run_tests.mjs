#!/usr/bin/env node
/** Run canonical specs/pong/tests against the JS reference simulation. */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { bootState, deepMerge, step, aiHeld, C } from "./pong_sim.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TESTS_DIR = path.resolve(__dirname, "../../specs/pong/tests");

function expandSteps(steps) {
  const frames = [];
  for (const stepSpec of steps) {
    const repeat = stepSpec.repeat ?? 1;
    const frame = {
      held: [...(stepSpec.held ?? [])],
      pressed: [...(stepSpec.pressed ?? [])],
    };
    for (let i = 0; i < repeat; i++) frames.push(frame);
  }
  return frames;
}

function getPath(obj, keys) {
  let cur = obj;
  for (const key of keys) {
    if (cur == null || typeof cur !== "object" || !(key in cur)) return undefined;
    cur = cur[key];
  }
  return cur;
}

function collectExpectPaths(node, prefix = []) {
  const out = [];
  for (const [key, value] of Object.entries(node)) {
    const p = [...prefix, key];
    if (value && typeof value === "object" && !Array.isArray(value)) {
      out.push(...collectExpectPaths(value, p));
    } else {
      out.push([p, value]);
    }
  }
  return out;
}

function valuesClose(expected, actual, posEps, velEps, pathKeys) {
  if (typeof expected === "boolean" || expected === null) return actual === expected;
  if (Number.isInteger(expected) && typeof expected === "number") {
    if (typeof actual === "number" && Number.isInteger(actual)) return actual === expected;
    if (typeof actual === "number" && Math.abs(actual - expected) < 1e-9) {
      return Math.round(actual) === expected;
    }
    return actual === expected;
  }
  if (typeof expected === "number" || typeof actual === "number") {
    const leaf = pathKeys[pathKeys.length - 1] ?? "";
    let eps = leaf === "vx" || leaf === "vy" ? velEps : posEps;
    if (leaf === "elapsed_time" || leaf === "point_pause_remaining") eps = posEps;
    return Math.abs(Number(actual) - Number(expected)) <= eps;
  }
  return actual === expected;
}

function sameHeld(a, b) {
  const sa = [...a].sort();
  const sb = [...b].sort();
  return JSON.stringify(sa) === JSON.stringify(sb);
}

function runTest(filePath) {
  const data = JSON.parse(fs.readFileSync(filePath, "utf8"));
  const state = deepMerge(bootState(), data.initial ?? {});

  if (data.ai_seat != null && data.expect?.ai_held) {
    const held = aiHeld(state, data.ai_seat);
    if (!sameHeld(held, data.expect.ai_held)) {
      return [false, `ai_held: expected ${JSON.stringify(data.expect.ai_held)}, got ${JSON.stringify(held)}`];
    }
  }

  const events = [];
  const useAi = data.ai_seat != null && (data.steps?.length ?? 0) > 0;
  for (const frame of expandSteps(data.steps ?? [])) {
    let held = [...frame.held];
    if (useAi) {
      held = [...new Set([...held, ...aiHeld(state, data.ai_seat)])];
    }
    events.push(...step(state, held, frame.pressed));
  }
  const expect = data.expect ?? {};
  const posEps = expect.position_epsilon ?? C.POSITION_EPSILON;
  const velEps = expect.velocity_epsilon ?? C.VELOCITY_EPSILON;

  for (const [pathKeys, expected] of collectExpectPaths(expect.state ?? {})) {
    const actual = getPath(state, pathKeys);
    if (!valuesClose(expected, actual, posEps, velEps, pathKeys)) {
      return [false, `${pathKeys.join(".")}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`];
    }
  }

  if (expect.events) {
    if (expect.events_ordered) {
      if (JSON.stringify(events) !== JSON.stringify(expect.events)) {
        return [false, `events: expected ${JSON.stringify(expect.events)}, got ${JSON.stringify(events)}`];
      }
    } else {
      for (const name of expect.events) {
        if (!events.includes(name)) {
          return [false, `missing event ${JSON.stringify(name)}; got ${JSON.stringify(events)}`];
        }
      }
    }
  }
  return [true, "PASS"];
}

function main() {
  const files = fs
    .readdirSync(TESTS_DIR)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .map((f) => path.join(TESTS_DIR, f));
  if (!files.length) {
    console.error("No tests found");
    process.exit(1);
  }
  let passed = 0;
  let failed = 0;
  for (const file of files) {
    const id = path.basename(file, ".json");
    const [ok, detail] = runTest(file);
    console.log(`${ok ? "PASS" : "FAIL"}  ${id}${ok ? "" : "  " + detail}`);
    if (ok) passed++;
    else failed++;
  }
  console.log(`\n${passed}/${passed + failed} passed`);
  process.exit(failed === 0 ? 0 : 1);
}

main();
