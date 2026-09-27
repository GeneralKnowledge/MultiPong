# Test runner (future)

Design target: thin helpers that validate test JSON against schemas and document the per-engine CLI contract.

Primary runners live **inside each implementation** (they must call that engine’s simulation). This folder may later hold:

- JSON Schema validation scripts
- A wrapper that invokes known engine CLIs
- Fixtures shared by CI

See [TESTING.md](../../TESTING.md).
