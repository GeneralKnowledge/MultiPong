# Reference simulations — Pong

Headless canonical `step()` ports. Each loads numbers from `specs/pong/constants.json` and must pass the same test pack.

| Language | Path | Run tests |
| --- | --- | --- |
| Python | [pong/](pong/) | `python3 reference/pong/run_tests.py` |
| JavaScript (Node) | [js/](js/) | `node reference/js/run_tests.mjs` |
| Rust | [rust/](rust/) | `cd reference/rust && cargo run --release --bin run_tests` |

Run all three:

```bash
./tools/comparison/run_all_tests.sh
```

The **spec** is normative. Python also powers `backend/server.py` for online play.
