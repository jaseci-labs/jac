# EXAMPLE-PASS: the primary north-star metric

Status: design + proof-of-concept (2 seeds verified green, 2 seeded-but-blocked).
Author-context: response to the "item-coverage % measures the wrong thing" critique.

## 1. The problem with item-coverage %

Today's north star is **binder item-coverage %** (`bridges/jac-bridge-binder/`,
gated by `tests/corpus.rs::coverage_does_not_regress` against
`tests/corpus/coverage-baseline.toml`, enforced by `.github/workflows/rust-bridges.yml`).
It counts `bridged / (bridged + skipped + dropped)` public items per crate and
fails a merge if any crate's `bridged` drops below its floor.

That number weights `Regex::find` and an obscure `RegexBuilder` knob equally. A
crate at 80% that happens to miss `find` is useless; a crate at 40% that covers
the README example ships. Item-% is a good **trend line for binder breadth** but
a bad **definition of done**.

## 2. The metric: does the canonical example run and print the right thing?

Add a SECOND, **primary** gate: for each corpus crate, translate its docs.rs /
README canonical example to a Jac program, capture the expected output as a
**golden**, and assert that golden is reproduced under **both** runtimes
(na `nacompile` + CPython loader). Pass/fail per crate.

- **item-% stays** as a ratcheted trend line (unchanged).
- **example-pass becomes the north star**: a red example blocks merge.
- It auto-prioritizes lanes: whatever unblocks a real example is what to build
  next (e.g. uuid/sha2 below are blocked only on *building the bridge crate*, not
  a missing lane -- that is the signal).

### Why golden, not just na == cpython

The existing `*_conformance.jac` verticals already run both runtimes and assert
`na_side() == cpython_side()`. That catches runtime *divergence* but a
**shared-wrong** answer (both runtimes wrong the same way, or a wrong-but-stable
bridge) still passes. An example test pins
`EXPECTED == cpython_side()` **and** `EXPECTED == na_side()`, where `EXPECTED` is
copied from the crate's published docs. That is the "produces the expected
output" half of the metric the conformance suite does not assert.

## 3. What already exists (survey)

- **Coverage gate**: `coverage-baseline.toml` (per-crate `bridged`/`total`/
  `dropped` floors) + `corpus.rs`. Rust-only, runs in the `bridges` CI job.
- **End-to-end dual-runtime harness**: `bridges/jac-bridge-loader/tests/na/`.
  `_harness.jac` is the reusable engine:
  - `synthesize_source(so)` renders a na Jac module from a bridge `.so`'s
    `.jac_bridge` metadata section.
  - `run_na_probe(so, probe_lines, ...)` appends a probe `with entry { ... }`,
    `nacompile`s it, runs the binary, returns stdout lines.
  - `load_bridge(str(so))` gives the CPython side the same class surface.
  - `skip_gate(so, shim)` returns True (test no-ops) when the `.so` or the LLVM
    shim is absent.
  - Every `*_conformance.jac` (scalar/map/list/owning/async/regex/semver/...)
    follows the same `cpython_side()` / `na_side()` / `assert equal` shape.
- **CI discovery**: the `bridges-na` job runs
  `jac test -d bridges/jac-bridge-loader/tests` -- directory-mode auto-discovery,
  so any new `.jac` test under that tree is picked up with no workflow edit.
  Serial (`JAC_TEST_JOBS=0`): each na probe `nacompile`s, and the xdist runner
  OOMs the GitHub runner otherwise.

### Dev-env constraints (verified)

- Full `jac test` fan-out OOMs; **validate single-file**.
- na needs `JAC_LLVM_SHIM` (in-tree at
  `jac/jaclang/compiler/passes/native/llvm/libjacllvm.so`) + `PYTHONPATH=jac`.
- Single-file invocation that works here:

  ```
  JAC_LLVM_SHIM=$PWD/jac/jaclang/compiler/passes/native/llvm/libjacllvm.so \
  PYTHONPATH=$PWD/jac \
  LD_LIBRARY_PATH=$PWD/bridges/target/release \
  ../jaseci/.venv/bin/python -m jaclang test \
    bridges/jac-bridge-loader/tests/na/example_semver.jac
  ```

- Only `semver` and `regex_binder` have built `.so` in `bridges/target/release`.
  `uuid`, `sha2`, `base64`, `chrono` exist **only as rustdoc-JSON fixtures**
  under `bridges/jac-bridge-binder/tests/fixtures/` -- no standing cdylib.

## 4. Design of the example-pass harness

**Location.** Example tests live beside the conformance verticals as
`bridges/jac-bridge-loader/tests/na/example_<crate>.jac`. This keeps the
`from _harness { ... }` import resolving and lands them inside the CI
`jac test -d .../tests` sweep with zero workflow change to *run* them.

**Shape** (mirrors conformance, adds a golden):

```
glob SO = bridge_so("<crate>"), SHIM = llvm_shim(),
     EXPECTED = [ ...lines copied from docs.rs... ];
def cpython_side -> list { load_bridge(SO); ...; return lines; }
def na_side -> list { run_na_probe(SO, probe, ...); }
test "example: <crate> <title>" {
    if skip_gate(SO, SHIM) { return; }
    assert cpython_side() == EXPECTED;   # docs golden, CPython path
    assert na_side()      == EXPECTED;   # docs golden, native path
}
```

Both runtimes reuse the existing `_harness` machinery verbatim -- no new engine.

**The canonical program.** Authored to the crate's README/docs example, adjusted
only where a construct cannot cross na (documented inline): e.g. `Version::parse`
and `Uuid::new_v4` are `#[jac(assoc)]` statics (na-gated), so the na-runnable
canonical form uses the equivalent `new`/`from_slice` ctor for the identical
observable result. This adjustment is itself a lane-priority signal (statics on
na is a known gap).

**The golden.** `EXPECTED` is captured from the crate's published output, not
from a runtime dump, so a wrong-but-stable bridge fails.

**Roster + skip honesty.** `examples.toml` (next to the tests) lists `required`
(built crates whose example MUST run green) vs `pending` (seeded programs blocked
on a missing cdylib -- they `skip_gate`-skip today). Because a skip is a trivial
pass, the gate must independently assert each `required` crate's `.so` exists, or
a broken required example could hide behind a skip.

## 5. CI gate change (exact)

The example tests already execute inside the existing `bridges-na` step (dir
auto-discovery). Add **one guard step before it** so a `required` crate that
fails to build can't mask its example as a skip-pass:

```yaml
      # NORTH-STAR (example-pass): every crate marked `required` in
      # examples.toml must have a built cdylib, so its example_<crate>.jac runs
      # for real instead of skip_gate-skipping. A missing .so here fails the
      # merge -- the example gate cannot be satisfied by a skip.
      - name: Assert required example bridges are built
        working-directory: bridges
        run: |
          req=$(python3 -c "import tomllib,sys; \
            print(' '.join(tomllib.load(open('jac-bridge-loader/tests/na/examples.toml','rb'))['examples']['required']))")
          for c in $req; do
            ls target/release/libjac_bridge_${c}.so >/dev/null \
              || { echo "::error::required example crate '$c' has no built .so"; exit 1; }
          done
```

The subsequent `jac test -d bridges/jac-bridge-loader/tests` step then runs the
`example_*.jac` tests; a golden mismatch fails that step (a real red, not a
skip). No change to the coverage-floor gate -- it stays as the trend line.

**Promotion loop.** When a `pending` crate gets a standing `bridges/jac-bridge-<c>`
cdylib, move it `pending -> required` in `examples.toml`; CI immediately demands
its example run green.

## 6. Proof-of-concept: seeds + verification

Four seed examples written (`bridges/jac-bridge-loader/tests/na/example_*.jac`):

| crate        | example                              | result | evidence |
|--------------|--------------------------------------|--------|----------|
| semver       | compare two versions                 | GREEN  | `1 passed in 5.05s`, single-file run |
| regex_binder | find + single literal replace        | GREEN  | `1 passed in 11.02s`, single-file run |
| uuid         | from_slice -> hyphenated + version   | BLOCKED| skips (no `.so`); `1 passed` trivially |
| sha2         | SHA-256 digest of a byte string      | BLOCKED| skips (no `.so`); `1 passed` trivially |

**Verified green (real na + CPython, golden-matched):**

- `example_semver.jac` -- `EXPECTED` = Display forms + `cmp` sign
  (`v1 < v2 = 1`, etc.), matched by both runtimes.
- `example_regex.jac` -- `EXPECTED` = `find` text+span (`[123] 3..6`), `None`
  miss, and `replacen` result (`[a|b,c]`), matched by both runtimes.

**Blocked, and by what:** `example_uuid.jac` and `example_sha2.jac` are written
against surface the coverage baseline says is **already bridged**
(uuid `from_slice`/`hyphenated`/`get_version_num`; sha2 `new`/`update`/`finalize`).
Their ONLY blocker is that `uuid` and `sha2` are corpus **rustdoc fixtures with
no standing cdylib** -- there is no `bridges/jac-bridge-uuid` / `-sha2` crate, so
no `.so` is built and `skip_gate` short-circuits. Add those two cdylibs
(`#[jac_bridge] pub use uuid::*;` shell, as `jac-bridge-semver` does) and both
examples should run without a new binder lane. That is the metric doing its job:
it points at "build the crate" as the next unblock, not at binder breadth.

## 7. Files

- `bridges/jac-bridge-loader/tests/na/example_semver.jac` (green)
- `bridges/jac-bridge-loader/tests/na/example_regex.jac` (green)
- `bridges/jac-bridge-loader/tests/na/example_uuid.jac` (blocked: no cdylib)
- `bridges/jac-bridge-loader/tests/na/example_sha2.jac` (blocked: no cdylib)
- `bridges/jac-bridge-loader/tests/na/examples.toml` (roster / required-vs-pending)
- this doc.
