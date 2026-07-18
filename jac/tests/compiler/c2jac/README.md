# tests/compiler/c2jac

This directory holds tests for **both** C-interop legs, despite the `c2jac`
name. The directory name reflects the lift leg only; the emit-leg tests share it
for historical reasons.

- **c2jac (lift): C to Jac** (code under `jac/jaclang/compiler/cfront/`)
  - `test_cast_breadth.jac` - breadth matrix: lifted fixtures recompile with the
    expected diagnostic codes.
  - `test_cast_ingest.jac`, `test_cast_slice.jac` - ingest + slicing behavior.
  - `test_c2jac_containment.jac` - fidelity containment (function-level
    quarantine).
  - `test_c2jac_lift_oracle.jac` + `lift_oracle.jac` - behavioral oracle:
    original C under `cc` vs lifted Jac under the bytecode interpreter
    (MATCH/TRAP auto-derived from quarantine).
  - `test_bindgen.jac`, `test_clib_import.jac` - extern/clib binding.
  - `support.jac` - lift-side test helpers (`BREADTH`, `recompile_errors`, ...).

- **jac2c (emit): Jac to C** (code under `jac/jaclang/compiler/passes/c/` and
  the shared products in `jac/jaclang/compiler/passes/main/`)
  - `test_jac2c_differential.jac` - emitted C vs stock interpreter.
  - `test_jac2c_multimodule.jac`, `test_jac2c_transitive.jac`,
    `test_jac2c_xmod_vdispatch.jac` - cross-module emit / vtable dispatch.
  - `test_jac2c_value_arch.jac` - value vs reference archetype semantics.
  - `test_jac2c_name_collision.jac` - module-qualified type identity (same-named
    types across modules).
  - `test_jac2c_runtime.jac`, `test_jac2c_roundtrip.jac` - runtime + round-trip.
  - `emit_support.jac` - emit-side differential oracle helpers.

- `fixtures/` - shared C fixtures (`*.c`, `*.i`), expected Jac (`*.expected.jac`),
  and emit fixtures. Fixtures are excluded from `jac-format` and from the deslop
  lint rules.

See `IMPLEMENTATION.md` at the repo root for the architecture of both legs.
