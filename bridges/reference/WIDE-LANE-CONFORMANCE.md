# Wide Lane (serde / TAG_WIDE) -- Codec Conformance Findings

Status of the serde wide lane (FFI-LANES-PLAN §2.5-2.7) and the differential
evidence that the Jac-side MessagePack codec is wire-compatible with real
`rmp_serde`. Written 2026-07-17.

## 1. What the wide lane is (and is not)

The binder resolves every value type to exactly **one** lane, per value, not per
signature (§2.7):

| Lane | Types | Jac representation | Static typing? |
|---|---|---|---|
| Tag lane | `{scalar, str, bytes, f64, bool}` | `int` / `str` / `float` / `bool` / `bytes` | full |
| Handle lane | opaque-bridged types | typed Jac class (ctypes) / handle | full |
| **Wide lane** (`TAG_WIDE=8`) | everything else: any `Serialize+Deserialize` document | see §2 | dynamic (by design) |

So the wide lane is **not** "no typing" -- it is the *dynamic-document* lane. A
value reaches it only when it is neither a scalar nor an opaque handle: e.g. a
`serde_json::Value`-shaped payload, a record whose wire shape is set by a manual
`Serialize` impl (chrono's `NaiveDate` -> ISO string), or fields invisible to
rustdoc. For those, a dynamic value **is** the correct representation.

The typed-record ergonomic (§2.6: synthesize a typed Jac `obj` with real fields
when the `Serialize` impl is `#[automatically_derived]` and has no stripped
fields) sits *in front of* the wide lane and is **not yet built** -- see §6.

## 2. Two-sided codec

The wire format is MessagePack via `rmp_serde::encode::to_vec_named` (structs as
maps with field-name keys). Because na and CPython have different type systems,
each side has its own decoder, from one shared wire contract:

- **na** (`jac/jaclang/compiler/rust_bridge/_msgpack.jac`): no `any` type, so a
  wide value is a `JacValue` tagged union (`kind + i/s/b/items/entries`). Floats
  are carried as the f64 **bit pattern in an int field** (na truncates float
  params/fields; only pure-local floats survive). Inlined into each synthesized
  bridge by `_synth.jac` (cross-module na import of user symbols does not
  resolve).
- **ctypes** (`jac/jaclang/compiler/rust_bridge/_ctypes_codegen.jac`,
  `_mp_encode` / `_mp_decode`): CPython is dynamically typed, so a wide value
  decodes **straight to native** `dict`/`list`/`int`/`float`/`str`/`bool`/`None`
  and encodes the same natives back. Floats stay native `float` -- no
  bit-pattern dance.

## 3. Differential methodology

Two shims exercise the ctypes path end-to-end through the real `build_module`
(no binder / rustdoc needed). Both live in the session scratchpad, not the repo.

1. **`wide_smoke.c`** -- a hand-written C library speaking the jac-bridge ABI
   (`JacBuf`, `free_buf`, opaque type drop/ctor, wide `echo`/`pack`/`tally`).
   `echo` copies the payload bytes verbatim, so it proves the *Jac ctypes glue*
   (`_wire` argtypes, `_call` encode/decode, `free_buf`) but **cannot** catch a
   wire mismatch against rmp_serde.
2. **`wide_rs`** -- a real Rust `cdylib` (`serde` derive + `rmp-serde 1.3.1`,
   built offline) whose functions **deserialize the payload into a typed
   `Widget` struct** and re-serialize with `to_vec_named`:
   - `pack` (no param -> wide): `rmp_serde::to_vec_named(&Widget{..})`.
   - `tally` (wide -> int): `rmp_serde::from_slice::<Widget>(..)`, returns a field.
   - `echo` (wide -> wide): decode into `Widget` then re-encode.

## 4. Results

All green (drive scripts `wide_smoke.jac`, `wide_diff.jac` via `jaclang run`):

| Leg | What it proves | Result |
|---|---|---|
| C `echo` round-trip of a nested doc | ctypes glue + codec self-consistency; native float/None/list preserved | PASS |
| (A) `pack`: rmp `to_vec_named` -> `_mp_decode` == doc | **rmp encoder output is readable by the Jac decoder** | PASS |
| (B) `tally`: `_mp_encode` -> rmp `from_slice::<Widget>`, count==3 | **Jac encoder output deserializes into a typed Rust struct** | PASS |
| (C) `echo`: `_mp_encode` -> rmp decode -> rmp re-encode -> `_mp_decode` == doc | both directions in one call | PASS |

**Byte-identity (strongest result):** for the doc
`{name:"widget", count:3, ratio:3.14159, tags:["a","b"], nested:{ok:true, items:[1,2,3]}}`,
the Jac `_mp_encode` output is **byte-for-byte identical** to
`rmp_serde::to_vec_named(&Widget)`:

```
85 a4 6e616d65 a6 776964676574 a5 636f756e74 03 a5 726174696f
cb 400921f9f01b866e a4 74616773 92 a161 a162 a6 6e6573746564
82 a26f6b c3 a5 6974656d73 93 010203
```

(fixmap/5, fixstr keys, fixint ints, `cb`+f64 for `ratio`, fixarray/fixmap for
the nested containers). Confirmed by reading `pack()`'s raw `JacBuf` before decode.

## 5. Known-and-harmless divergences

- **Non-minimal int widths (Jac encoder only).** `_mp_encode` emits `0xcf` (u64)
  for positives >= 128 and `0xd3` (i64) for negatives < -32, where rmp uses the
  minimal width (`0xcc`/`0xcd`/`0xce`/`0xd0`...). Both are valid MessagePack;
  rmp's decoder and the Jac decoder each accept all widths, and serde narrows a
  wider int into a smaller field. So this is **wire-compatible but not
  byte-identical for out-of-fixint ints** -- intentional (the na codec made the
  same choice; a lead-byte-literal encoder is simpler and rmp accepts it). The
  §4 doc is byte-identical only because every int in it is a fixint.
- **Float representation is per-side.** ctypes keeps native `float`; na carries
  the f64 bit pattern in an int field. Same wire bytes (`0xcb`+8), different
  in-language value model.
- **u64 above i64::MAX** decodes to a Python `int` (ctypes) with no loss -- the
  same exposure `TAG_UINT` already documents.

## 6. Full binder path -- PROVEN end-to-end (2026-07-17)

A real serde crate was run through the **entire production pipeline** and a wide
method called from Jac -- nothing hand-authored past the source crate:

1. `demo` source crate: an opaque `Shifter` handle with
   `shift(&self, p: Point, dx, dy) -> Point`, where `Point{x:i64, y:i64,
   label:String}` derives `Serialize + Deserialize`.
2. `cargo +nightly rustdoc --output-format json` (format_version 60, matches the
   binder's `rustdoc-types 0.60`).
3. `jac-bridge-binder` classified `Point` into the wide lane and emitted
   `shift(&self, p: Wide<demo::Point>, dx: i64, dy: i64) -> Wide<demo::Point>`
   (100% of public API bridged, 0 skips) -- **the lane conflict rule fired
   correctly**: `Point` is not opaque-bridged, so it is wide, not a handle.
4. `#[bridge]` macro + `cargo build --release` produced `libjac_bridge_demo.so`
   with the real rmp_serde codec.
5. Jac read the ABI blob from the `.so` (`read_jac_bridge_section` -> `parse`),
   `build_module`, and called `Shifter(100).shift({"x":1,"y":2,"label":"origin"},
   5, 7)` -> `{"x":106, "y":9, "label":"origin"}`. State (the handle's `base`)
   persisted across a second call. **PASS.**

**Gap found and fixed by this exercise (commit `fix(binder): ... serde +
rmp-serde`):** the `#[bridge]` macro expands wide slots to `::serde` /
`::rmp_serde` *absolute* paths, so the generated crate must depend on both
directly. `jac-bridge` declared them only as **dev-dependencies** (for its own
tests), which do not flow downstream, so the first real wide bridge failed to
compile with `could not find`rmp_serde``. `emit_cargo_toml` now adds
`serde`/`rmp-serde` whenever `spec_has_wide(spec)` (mirroring the tokio-for-async
rule); non-wide bridges stay minimal. Pinned by
`jac-bridge-binder/src/tests/wide_lane.rs`
(`wide_bridge_cargo_toml_declares_serde_and_rmp`, `non_wide_bridge_omits_serde_deps`).

Only accommodation for the local/offline run: the generated `Cargo.toml`'s source
dep was retargeted from the crates.io pin (`demo = "=0.1.0"`) to a path dep --
an environment concern, not binder logic (classification/codegen are unmodified).

## 6b. na wide e2e -- PROVEN end-to-end, AOT-linked (2026-07-17)

The §6 run drove the *ctypes* loader. The **na** side is now proven natively too:
`render_na_source(widget_meta, libwide_rs.so)` was emitted, a `with entry` driver
appended, and the module `jac nacompile`d to a **standalone ELF that DT_NEEDED-links
the real rmp_serde `.so`** (`readelf -d` shows `NEEDED libwide_rs.so`, `RUNPATH
$ORIGIN`). Running it:

- **pack** (wide return): rmp `to_vec_named` -> na `msgpack_decode` -> the full
  nested doc (`count=3`, `ratio~3.14159` via the f64-bits carry, `nested.ok=True`,
  `nested.items[2]=3`, `tags` len 2).
- **echo** (wide param + wide return): na `msgpack_encode` -> rmp deserialize into
  the typed `Widget` struct -> re-serialize -> na `msgpack_decode`; round-trips.
- **tally** (wide param -> int): na encode -> rmp `from_slice::<Widget>` -> count 3.

**All PASS.** This exercises the na consumer surface (`JacValue` obj + inlined codec

- shim out-buffer decode + `#7472` bytes-payload param) against a genuine
`serde`/`rmp_serde` export -- the na analogue of §6.

**Execution-path finding:** na foreign bridges must be **AOT-linked**, not
JIT-run. The in-process JIT engine (`ir.gen.native_engine`, MCJIT) *cannot* execute
a module that both allocates heap objects and carries the full foreign-import
block: once the `Widget` FFI/panic surface is present, MCJIT object finalization
poisons the whole module and even a non-FFI `JacValue()` allocation segfaults on a
null call (a minimal `obj` + single `import from "…so"` decl survives; the full
generated bridge does not). This matches how na foreign is validated everywhere
else -- `test_shared_lib.jac` loads a *produced* `.so`, it does not JIT-call one.
The AOT recipe (nacompile -> ELF -> run) is therefore the supported path and is
what the e2e above uses. Local build note: nacompile's compile-time
`_register_bridge_metadata` imports `rust_bridge._elf` through the runtime
meta-importer, which needs the module pre-seeded in `sys.modules` locally (the
`_finder.jac`-no-bytecode quirk); driving `nacompile()` in-process after seeding
`_elf` sidesteps it (CI has the bytecode cached).

## 7. Remaining gaps

- **§2.6 typed-obj synthesis is unbuilt** on both sides: derived records still
  cross as a `JacValue` union (na) / `dict` (ctypes) rather than a typed Jac
  `obj` with checked fields. This is the "does the wide lane keep typing"
  ergonomic and is the natural next piece.
- **Sealed/wheel install: CONFIRMED (2026-07-17).** `_synth._codec_source()` reads
  the sibling `_msgpack.jac` `__file__`-relative. Both packaging paths ship it: the
  setuptools wheel packs `.jac` via a recursive glob (`Root-Is-Purelib` -> real
  files, so `os.path.dirname(__file__)`+`open()` resolves -- verified reading the
  codec from an install-like tree outside the dev checkout), and mkpayload's
  `skipJaclang` copies every `.jac` (no extension filter) into the sealed payload.
  `_codec_source()` itself runs at synth/build time, not in the final sealed binary.

## 8. Reproduce

```sh
# rmp_serde cdylib (offline; crates cached under ~/.cargo)
cd <scratch>/wide_rs && CARGO_NET_OFFLINE=true cargo build --release --offline

# drive the differential through the real build_module
sed "s|__SO_PATH__|<scratch>/wide_rs/target/release/libwide_rs.so|" wide_diff.jac > run.jac
PYTHONPATH=jac JAC_LLVM_SHIM=jac/zig-out/lib/libjacllvm.so \
  .venv/bin/python -m jaclang run run.jac

# full binder end-to-end (demo source crate -> bridge -> .so -> live wide call)
cargo build --release -p jac-bridge-binder --offline
cd <scratch>/demo && RUSTC_BOOTSTRAP=1 cargo +nightly rustdoc --lib --offline \
  -- -Zunstable-options --output-format json
bridges/target/release/jac-bridge-binder <scratch>/demo/target/doc/demo.json \
  --out <scratch>/demo_bridge --jac-bridge bridges/jac-bridge
# offline-only: retarget the crates.io pin to a path dep, then build + call
sed -i 's|^demo = "=0.1.0"|demo = { path = "<scratch>/demo" }|' <scratch>/demo_bridge/Cargo.toml
cd <scratch>/demo_bridge && cargo build --release --offline
sed "s|__SO_PATH__|<scratch>/demo_bridge/target/release/libjac_bridge_demo.so|" \
  wide_e2e.jac > e2e.jac
PYTHONPATH=jac JAC_LLVM_SHIM=jac/zig-out/lib/libjacllvm.so \
  .venv/bin/python -m jaclang run e2e.jac

# na wide e2e (AOT): render the na bridge against the live .so, append a
# `with entry` driver, nacompile to an ELF that DT_NEEDED-links it, run.
#   render.py     -> render_na_source(widget_meta, libwide_rs.so) -> wide_e2e_aot.na.jac
#   build_aot.py  -> seed rust_bridge._elf into sys.modules, then nacompile() in-process
PYTHONPATH=jac JAC_LLVM_SHIM=jac/zig-out/lib/libjacllvm.so .venv/bin/python build_aot.py
LD_LIBRARY_PATH=<scratch> <scratch>/wide_e2e_aot   # -> pack/echo/tally OK; ALL PASS
```

Codec unit tests (committed): `jac/tests/compiler/test_rust_wide_ctypes.jac`
(ctypes), `jac/tests/compiler/test_rust_wide_lane.jac` (na synth wiring).
