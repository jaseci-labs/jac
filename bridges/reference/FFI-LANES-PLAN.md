# The Lanes Plan -- Rust interop endgame for Jac

Status: ADOPTED (2026-07-10). Decision recorded in Claude Code session `c48344d3`
(evaluated options, concluded serde wide lane + py-interop tier replace the
recursive type-table approach). Supersedes TYPE-MODEL-V2 (the recursive type-table
plan), which is **cancelled** -- see "Why V2 dies" below. PLAN.md, IMPLEMENTATION.md,
and REMAINING.md references to `TYPE-MODEL-V2-PLAN.md` should be repointed here.

Product priorities this plan is optimized for (stated 2026-07):

1. **Maximum crate variety** -- install as many packages as we want.
2. **No bridge authors** -- principle zero stands; nobody hand-writes per-crate shims.
3. **Performance is tradeable** -- keep the native advantage where cheap, but variety
   beats peak performance when they conflict.

Every claim below is backed by one of four investigations run against this repo on
2026-07-10: (T) trait-flattening scored on the checked-in rustdoc fixtures with a
reimplementation of classify.rs's rules; (S) serde wide-lane feasibility incl. a live
regeneration of chrono's rustdoc JSON with `--features serde`; (P) py-interop tier
scoped against the actual launcher/linker/desktop-host code; (W) WIT/wasmtime
assessed against July-2026 upstream state with sources.

---

## Part I -- The decision

### How everyone else gets crate variety (and why we can't copy them directly)

No ecosystem auto-binds arbitrary Rust crates. The variety champions got there two
ways: **borrowed authored ecosystems** (Python/Node don't bind Rust; Rust authors
publish PyO3/napi-rs packages) or **universal data layers** maintained by someone
else (serde; the wasm component model's WIT). Author-side tools (cxx, Diplomat,
UniFFI) require the humans principle zero says we don't have. autocxx -- the one real
author-less attempt -- needs so much per-library steering it's authoring by another
name.

So the strategy is: **borrow both.** serde is the ecosystem's already-authored type
model (the derive is on most public data types on crates.io, maintained by the crate
authors themselves -- our missing bridge authors, found). The PyO3 wheel catalog is
the ecosystem's already-authored *binding* layer, and jac already ships the CPython
needed to host it.

### Options evaluated

| Option | Verdict | One-line reason |
|---|---|---|
| Hand-built recursive type table (TYPE-MODEL-V2) | **CANCEL** | The serde wide lane delivers its entire type wishlist (floats, bytes, nested containers, tuples, records, data enums, Option/Result compositions) as a self-describing payload behind **one new tag**, with the type model maintained by serde, not us. (S) |
| Trait-impl flattening in the binder | **ADOPT** | Measured on fixtures: chrono 33→68 bridged from local traits alone; sha2's blanket `Digest` impl materializes in rustdoc JSON and flattening + two small lanes takes sha2 0→62 usable methods. ~200–250 binder lines. (T) |
| Dyn-trait resources (`impl Trait`/`Box<dyn Trait>` returns as synthesized objects) | **DEFER** | Measured zero `impl Trait` returns and ~2 `dyn` returns across all five fixture crates. No corpus demand. (T) |
| serde wide lane (MessagePack payloads for any `Serialize+Deserialize` type) | **ADOPT** | One ABI constant (`TAG_WIDE`), ~150-line na decoder using the existing `struct.unpack` intrinsic, ~120-line ctypes decoder, all JacBuf/panic/error plumbing reused. Kills the need for a recursive blob schema. (S) |
| py-interop tier (na binaries load PyO3 wheels via the bundled CPython) | **ADOPT** | ~60% already exists and ships today as the desktop host (`libjacpyembed.so`, trailer payload, GIL patterns, PEP-741 hermetic init). 5–7 engineer-weeks, no blockers. This is the *only* option that reaches "vast majority of crates". (P) |
| WIT as bridge IDL / wit-bindgen shims | **REJECT (steal the grammar only)** | wit-bindgen is guest-only (no host-side C generator exists); the canonical ABI is 32-bit-wasm-shaped and a "lazy ABI" revision is incoming; WIT has **no first-class function type** -- our `{call,ctx}` closure ABI has no standard equivalent, so the custom extension survives regardless. (W) |
| wasmtime-embedded sandboxed tier | **REJECT for now** | 1.5–2.5× slower on exactly the compute (regex/hashing) that motivates Rust bridges (libsodium suite: wasmtime 2.41× native, June 2026); wasmtime C API still lacks component resources (#11437); no authored ecosystem of library components exists -- the binder problem would be retargeted, not removed. Revisit only if an "untrusted crate" requirement appears. (W) |

### The endgame architecture: three lanes + a tier

```text
                     jac add rust:<crate>            jac add py:<pkg>
                          │                                │
              deterministic binder (rustdoc JSON           │
              + trait flattening + serde detection         │
              + overlays)                                  │
                          │                                │
        ┌─────────────────┼──────────────────┐             │
        ▼                 ▼                  ▼             ▼
   FAST LANE         HANDLE LANE        WIDE LANE      PY TIER (opt-in)
   scalars, str,     opaque resources,  any Serialize+ PyO3/abi3 wheels via
   bytes, f64        methods, ctors,    Deserialize    bundled libpython
   (existing tags    dtors, cursors,    type crosses   (polars, orjson,
   + TAG_F64,        owning wrappers,   as MessagePack cryptography,
   TAG_BYTES)        callbacks          (TAG_WIDE)     tokenizers, ...)
        │                 │                  │             │
        └────────── one shim ABI, one blob, ─┘             │
                    one shared marshal layer      GIL-managed C shim
                          │                       (exists: pyembed.zig)
                    nacompile / jac bundle ────────────────┘
```

Lane selection is **per-value, not per-signature**: each param/return independently
takes the cheapest lane its type fits (a scalar beside a struct stays fast). (S)

**One-canonical-representation rule** (load-bearing): a type that is both
opaque-bridged and serde-capable (e.g. chrono's `NaiveDate`) has exactly one Jac
representation -- **the handle wins** wherever the type is bridged; the wide lane
applies only to types/compositions outside the handle surface. Without this rule the
Jac API becomes incoherent (sometimes an object with 33 methods, sometimes a bare ISO
string). (S)

### Why V2 dies

The recursive type table existed to express what the flat tag bitfield can't. The
wide lane expresses all of it *inside a self-describing payload* -- the blob schema
stays flat forever: `{scalars, str, bytes, f64, handle-ref, fn, wide}` plus the
existing OPT/RESULT composition for the legacy shapes. Nesting ambiguity
(`Map(List)` vs `List(Map)`) becomes a non-problem because structure lives in
MessagePack, not in tag bits. What we maintain shrinks to: one msgpack
encoder/decoder pair per loader, written once.

### Predicted corpus movement (fixtures-measured where possible)

| crate | today | after Phase 1 (traits + small lanes) | after Phase 2 (wide lane) | notes |
|---|---|---|---|---|
| regex | 31/84 (37%) | ~35/92 | ~flat | residual is lifetime-borrows → owning-wrapper lane (exists) |
| chrono | 33/181 (18%) | ~90/273 (local traits +35, Option\<Self\> +22, String-ret +8) | **~145+/… (≈80% of the original 181)** | ~100 of the wide-lane rescues are equally reachable by ref-lane generalization; do both |
| sha2 | 0/0 | **62 usable methods** (flattening + bytes params + digest-output returns) | -- | requires blanket-generic substitution + consuming-`self` clone-out |
| uuid | 0/6 | **+8–10** (tuple-struct candidates -- orthogonal, cheap) | + `Uuid` as value type | u128 stays out (no msgpack u128) |
| base64 | 1/11 (9%) | +2 useful (encode/decode via local-trait provided defaults + bytes lane) | flat | |

Denominators shift when trait methods enter the count -- baselines get re-ratcheted
with a documented policy (see Phase 1). Percentages are less meaningful across the
change than absolute usable-method counts; the baseline TOML narrates both.

---

## Part II -- The plan, phase by phase

Effort assumes one engineer full-time unless noted; phases 3 runs in parallel with
1–2 if a second person exists. Total critical path ≈ 9–11 weeks; with parallelism
≈ 8–9 weeks to all lanes + tier landed.

### Phase 0 -- Soundness and debt paydown (BLOCKING; ~2–3 weeks)

Nothing new gets built on the current seams. These are the red-team findings
(2026-07-10 review) that become load-bearing under every later phase.

**0.1 Callback dispatch becomes metadata-driven (kills the heuristic).**

- `bridges/jac-bridge-schema/src/lib.rs`: `TAG_FN` already exists as a param tag --
  ensure the binder/macro emit it on every callback param (they do for the regex
  vertical; make it universal).
- `jac/jaclang/compiler/passes/native/na_ir_gen_pass.impl/calls.impl.jac`: replace
  `_lambda_arg_is_callback` (line ~104) with callee-driven dispatch -- the arg is a
  callback **iff** the callee symbol is a registered bridge fn AND the param's
  metadata tag is `TAG_FN`. The bridge metadata is already parsed per-.so by
  `_register_bridge_metadata`; extend the registration to keep a
  `sym → [param tags]` map instead of only a make_buf sink. Deletes the
  lambda+IntType+module-global-flag heuristic and its false-positive class
  (user lambdas passed to non-bridge fns being rewritten into `{call,ctx}`
  records).
- Make the buf sink **per-crate** -- DONE (0.1.1). `_note_bridge_sink` now keys
  each make_buf `ir.Function` by symbol (`_bridge_make_buf_fns`) and
  `_register_bridge_metadata` records `type → owning module` (`_bridge_type_crate`);
  `_callback_make_buf_for(func)` selects the callee's crate allocator. The single
  `_callback_make_buf` slot survives only as the gate + single-crate fallback.
- Trampoline fixes (all in `calls.impl.jac`):
  - identity-lambda double-release (~line 296): retain-on-return or a runtime
    pointer-equality guard before the two `_emit_rc_release_simple` calls;
  - arity check: lambda must be unary (declared) -- else recorded error, not
    miscompile/ICE (~line 263);
  - non-str lambda return → compile error, not `strlen` on an inttoptr'd int;
  - zero `out_err` (tramp.args[4]) explicitly.

**0.2 Handle soundness (the aliasing fix).**

- `bridges/jac-bridge/src/lib.rs` method shims (~line 982): add (a) `handle != 0`
  guard → status 1 with message (drop shims already guard; call shims don't --
  use-after-close is currently instant UB), and (b) a **per-handle reentrancy
  guard**: an `AtomicBool` try-lock around `&mut self` access; contention →
  status-coded error ("object is already in use -- reentrant or concurrent call").
  This closes the safe-Jac-triggers-Rust-UB hole (two live `&mut T` via
  callback-reentry or aliased fields) at ~1 atomic op per call. Full `Mutex` is
  not needed for the v1 same-thread rule; the atomic flag is sufficient and
  documents the contract.
- `string_to_jacbuf`/`vec_to_jacbuf` (~line 658): assert len/cap ≤ u32::MAX
  (currently silent truncation → `Vec::from_raw_parts` with wrong capacity = UB
  at dealloc for >4 GiB buffers).
- `parse_module_name`/`BridgeAttr::parse` (~line 86): validate the attribute key --
  `#[bridge(modle = "x")]` currently compiles silently with wrong symbol names.
- Preserve panic payloads: downcast `&str`/`String` in the `catch_unwind` `Err`
  arm instead of discarding (~line 1051).

**0.3 Binder honesty fixes.**

- `bridges/jac-bridge-binder/src/classify.rs:515-517`: multiple ctors -- first wins
  (deterministically), losers become recorded skips (currently silently
  overwritten; uuid is affected and the coverage denominator is corrupted).

**0.4 Generated-source safety.**

- `jac/jaclang/compiler/rust_bridge/_synth.jac`: sanitize spliced Rust identifiers
  against Jac reserved words incl. the silent killers `root`/`node` (rename with a
  `r#`-style suffix + record in the module header, or skip-with-reason); round-trip
  parse the rendered module before caching (`materialize_bridge`).
- `_drain_and_raise`: branch on status like the ctypes side does -- stop relying on
  the error-handle-and-panic-handle-are-both-`Box<String>` coincidence; document
  the invariant in `jac-bridge-schema`.

**0.5 The shared marshal layer (the multiplier for everything after).**

- New: `jac/jaclang/compiler/rust_bridge/_marshal.jac` -- ONE tag→slot lowering
  (`lower_signature(fd) -> list[Slot]` where `Slot` is an enum-tagged obj:
  `STR_PTR+LEN`, `BYTES_PTR+LEN`, `U64`, `U8_BOOL`, `F64`, `OUT_BUF`, `OUT_U64`,
  `OUT_ERR`, `WIDE_PTR+LEN`...). Consumed by:
  - `_synth.jac` -- `_shim_decl`, `_method_body`, `_ctor_body` (the latter two are
    verbatim copies today; both collapse onto the shared lowering),
  - `_ctypes_codegen.jac` -- `_wire` and `_call` (must agree slot-for-slot today
    with zero shared code).
  Also home the symbol-name constructors (`make_buf_sym(mod)`, `free_buf_sym`,
  `panic_message_sym`, ...) and the status-code constants
  (`STATUS_OK/ERR/PANIC/CB_ERR`) -- each currently format-string'd independently in
  3+ files.
- Collapse the three copies of the `rust.` namespace predicate
  (`codeinfo.jac:113`, `_finder.jac:47`, `imported.impl.jac`) onto
  `_finder.is_bridge_module`.
- na backend: unify the dual type-lowering paths -- `_resolve_container_ast`
  (raw-AST walker, `types.impl.jac:577-684`) folds into a single entry that
  normalizes AST→semantic before one shared lowering; thread an `expected_type`
  parameter into `_codegen_expr` so the empty-container fix stops being
  assignment-only.

**0.6 CI stops being dark.**

- `.github/workflows/rust-bridges.yml`: run the loader suites by directory
  (`jac test bridges/jac-bridge-loader/tests`), build `jac-bridge-regex` in the na
  job (the flagship end-to-end path is currently untested by ANY workflow), gate
  the na coverage floor (`test_na_coverage_floor.jac`).
- `rust-bridges-artifacts.yml`: install jaclang **from the checkout**, not PyPI
  (currently imports branch-only modules from a released package -- dead on
  arrival).

**Phase 0 exit criteria:** existing conformance suites green; the adversarial suite
(`tests/na/adversarial_conformance.jac`, task 0.6.3) passes: user lambda →
non-bridge fn (must NOT be rewritten -- IR-asserted, see 0.1.2 note), two bridge
crates in one module (correct allocators -- requires the 0.0.1 crate), identity
replacer (no double-free), reentrant method call (status error, not UB -- requires
the 0.0.2 crate), use-after-close incl. the aliasing variant (status error, not
segfault). Two of these five gates are untestable until the 0.0 reference crates
exist -- build 0.0 first.
ABI v1 declared **frozen except** the Phase-1/2 append-only additions listed below.

### Phase 1 -- Binder rules: trait flattening + small lanes (~3–4 weeks)

All measured effects from investigation (T). Work is almost entirely in
`bridges/jac-bridge-binder/src/` + small macro/schema deltas.

**1.1 Trait flattening** (`classify.rs`, ~200–250 lines total):

- Replace the wholesale `if impl_block.trait_.is_some() { continue }`
  (classify.rs:470) with `trait_disposition()`:
  - skip `is_synthetic` / negative impls / a NOISE set of std traits resolved via
    the paths table (Borrow, Into, TryFrom, Any, ToOwned, CloneToUninit, ... --
    same canonical-path pattern as `is_std_error_path`, classify.rs:431);
  - **local traits**: flatten concrete items AND provided-default methods
    (resolvable -- the trait def is in the index). This alone is chrono +35
    (Datelike/Timelike on NaiveDate/NaiveDateTime/NaiveTime/TimeDelta).
  - **external/blanket traits**: flatten concrete + blanket items only (external
    provided-defaults are UNRESOLVABLE -- `provided_trait_methods` gives names
    only, the trait def isn't in the index; excluding them from numerator AND
    denominator is the documented counting policy, else Iterator's ~80 defaults
    flood the denominator: chrono 25%→19% garbage).
- **Blanket-generic substitution**: sha2's `impl<D> Digest for D` materializes on
  each hasher but signatures keep `D`/`OutputSize<D>` unsubstituted -- thread
  `self_aliases: &[&str]` through `classify_fn`/`classify_param_type`/
  `classify_return`/`returns_self` (~40 lines, touches the four rescue rules).
- Per-type `seen_names` first-wins dedup (18 cross-trait collisions in sha2 alone:
  `reset`/`output_size` in Digest+DynDigest+Reset), losers = recorded skips.
- `types.rs`: `via_trait: Option<String>` on BridgeFn.
- `codegen.rs`: emit `use <trait_path>;` for via_trait methods; **the generated
  crate must depend on the trait-defining crate** (`digest`, not just `sha2`) --
  Cargo.toml emission gains a deps set derived from via_trait paths;
  **consuming-receiver arm**: `finalize(self)`-style methods clone out of the Box
  (gated on a Clone impl; else skip-with-reason).

**1.2 Small type lanes (append-only ABI additions, then freeze):**

- `TAG_F64` (param + return) -- schema + macro + `_blob.jac` + `_marshal.jac` +
  na (f64 is already a first-class na type) + ctypes (`c_double`). Floats stop
  being macro-rejected.
- `TAG_BYTES` (param + return) -- `(ptr, len)` pairs, `&[u8]`/`impl AsRef<[u8]>`
  params and `Vec<u8>`/digest-output returns. na side: `__jac_bytes_from_raw`
  intrinsic already exists; params cross as `bytes` buffers with explicit len
  (NEVER the strlen idiom -- msgpack/binary data contains NULs; this is also the
  Phase-2 payload carrier).
- `-> String` return arm (no new tag -- JacBuf machinery exists; classify_return
  simply lacks the arm today, classify.rs:663-718).
- **Ref-lane generalization** (no new tags -- `TAG_REF|idx` and `TAG_OPT_BIT`
  already exist; the binder just never emits them for non-Self): cross-type
  handle returns (`NaiveDate::and_time -> NaiveDateTime`), `Option<Self>` /
  `Option<OtherBridgedType>` returns (chrono's `with_year/with_month` family:
  +22), `Result<OtherBridgedType, E>`.
- **Tuple-struct candidates** (`classify_type`): admit single-field tuple structs
  as opaque types -- this is the entire uuid fix (+8 inherent methods: nil, max,
  parse_str, ...).

**1.3 Baseline policy + re-ratchet.** Document the denominator rules (local-trait
provided-defaults counted; external provided-defaults excluded; flattened methods
flow through the existing Ok→methods / Err→skips funnel -- coverage accounting
extends cleanly). Re-ratchet `coverage-baseline.toml` with narrated rationale per
crate (the file is already an audit log; keep it that way).

**Phase 1 exit criteria (hard numbers, from (T)):** chrono ≥ 85 bridged (MET, 145);
uuid ≥ 8 (MET, 17); sha2 usable hashing surface complete -- `new`/`update`/`digest`/
`finalize`/`finalize_reset`/`reset`/`output_size` all bridged (MET at 54), proven by a
hash-equivalence conformance test; determinism test still byte-identical cross-process;
every flattened method or its skip visible in the coverage report.

> **sha2 ≥ 60 RETIRED (2026-07-15).** The original 60 was set before we knew what the
> remaining 6 hashers' surface actually was. Verified against the real `sha2-0.11.0`
> fixture: sha2 tops out at **54 bridged**, and its *entire* useful hashing surface is
> already in that 54. The gap to 60 is NOT new capability -- it is (a) the 12
> `DynDigest::finalize`/`finalize_reset` methods, which are exact twins of the already
> bridged `Digest::finalize`/`finalize_reset` (sha2 exposes each op through two traits;
> the binder's `seen_names` first-wins dedup skips the second copy on purpose -- bridging
> the `Box<[u8]>` return would only turn an "unsupported Box" skip into a "duplicate
> method name" skip, net **0**); (b) 6 `box_clone -> Box<dyn DynDigest>` returns, an
> anonymous trait object that is genuinely unbridgeable. The ONLY new-capability surface
> left is the `finalize_into(&mut self, out: &mut [u8]) -> Result<(), InvalidBufferSize>`
> family -- a write-into-caller-buffer out-param lane. It adds no hashing power the 54
> don't already provide, so it is **not** a Phase 1 gate; if the out-buffer lane is ever
> built it belongs with the serde/ref wide-lanes, not here.

### Phase 2 -- The serde wide lane (~3–4 weeks)

All mechanics from investigation (S).

**2.1 ABI delta (final v1 addition, then hard freeze):** `TAG_WIDE: u32 = 8` in
`jac-bridge-schema/src/lib.rs` (slots 6/7 were taken by `TAG_F64`/`TAG_BYTES`
in Phase 1 -- see Step 0 reconciliation in `PHASE-1-TASKS.md`; the plan's
original `TAG_WIDE = 6` is stale) + mirror in `_blob.jac` + `test_abi_drift.jac`
update. Param wire shape: `(payload_ptr, payload_len: u32)`. Return wire shape:
existing JacBuf out-slot + `free_buf` (allocator discipline unchanged,
`vec_to_jacbuf` at lib.rs:669 reused as-is). Option/Result/nesting live INSIDE the
payload (msgpack nil etc.) -- no tag composition.

**2.2 Wire format: MessagePack via `rmp_serde::encode::to_vec_named`** (structs as
name→value maps). Rationale (S): self-describing; exact i64/u64/f64 lead-byte
dispatch; real `bin` type; data-carrying enums decode naturally
(`{"Variant": …}` one-entry maps); rejected alternatives -- postcard (NOT
self-describing: rebuilding V2 through the back door), ciborium (emits f16
half-floats na can't unpack), serde_json (text, NaN/Inf fail, bytes need base64).
Caveat accepted for v1: `Vec<u8>` through plain Serialize is an int array, not bin
(serde_bytes would fix; fatter but correct).

**2.3 Macro arm:** the binder marks wide values with a `jac_bridge::Wide<T>`
newtype in generated source; the macro adds ONE classifier arm:

- param: `let arg: T = rmp_serde::from_slice(slice::from_raw_parts(p, len as
  usize)).map_err(|e| /* status 1 + error handle */)?;` inside the existing
  `catch_unwind`;
- return: `rmp_serde::to_vec_named(&v)` → `vec_to_jacbuf`.
Deps added to generated crates: `rmp`, `rmp-serde` (small, mature). Panic path,
error handles, free_buf: all existing plumbing, untouched.

**2.4 Binder serde detection** (`classify.rs`, template = `implements_error_trait`
at :381-445):

- accept BOTH trait roots: `serde::ser::Serialize` AND `serde_core::ser::Serialize`
  (serde ≥1.0.220 split -- matching only `serde::` finds NOTHING);
- structural whitelist for external types (rustdoc only covers the local crate):
  primitives, String, Vec\<T\>, HashMap\<String,T\>, Option\<T\>, tuples,
  `std::time::Duration`, Range/RangeInclusive -- recursing into type args with
  local-impl lookup at leaves; overlay as escape hatch;
- **feature plumbing**: `gen-fixtures.sh` gains a per-crate feature column
  (`chrono@0.4.45:serde`, `uuid@1.23.4:serde`) -- verified: default-features
  fixtures contain ZERO serde impls; `--all-features` is NOT safe (chrono's rkyv
  size features are mutually exclusive and break the build). The same feature
  list flows into: the overlay format (`[crate] features = [...]`), the
  build-on-miss pipeline (`_build_core.jac` rustdoc + cargo build invocations),
  and the registry artifact manifest (features are part of the artifact
  identity).

**2.5 Jac-side codecs (the whole "type model" we maintain):**

- na: `~150-line` msgpack decoder+encoder as a shared runtime `.na.jac` module
  (emitted once, imported by synthesized bridges). Verified feasible: na's
  `struct.unpack` intrinsic supports all int widths + f32/f64 + big-endian --
  constraint: format strings must be compile-time literals, which a lead-byte
  dispatch decoder naturally satisfies (`struct.unpack(">I", buf[off:off+4])` --
  the exact idiom `_synth.jac:170-220` already generates).
- ctypes: ~120-line pure-Python decoder (`struct.unpack_from`), zero new deps.
- Decode targets: msgpack map→dict, array→list, str/int/float/bool/nil→native.
  Guard: u64 > i64::MAX (same exposure TAG_UINT already has -- document), bounded
  recursion depth.

**2.6 Typed obj synthesis (ergonomics, gated):** synthesize a typed Jac `obj` with
real fields ONLY when the Serialize impl carries `automatically_derived` AND
`has_stripped_fields == false` -- then rustdoc field names/types ARE the wire shape
and the na checker gets real field checking. Everything else (chrono's manual
impls serialize `NaiveDate` as an ISO-8601 *string*; uuid as a hyphenated string;
private fields are serialized but invisible to rustdoc) crosses as
dict/str/int/float per the impl's actual shape. **Never synthesize fields from
rustdoc for manual impls -- it would be wrong.**

- Wire-shape drift guard: manual serde impls are a crate's public contract but can
  change across versions with no blob-magic-style check -- pin per-crate
  round-trip fixtures (encode reference values, assert decoded shape) in the
  conformance suite.

**2.7 Lane conflict rule wired in:** binder resolves each value type to exactly one
lane: tag lane if it fits `{scalar, str, bytes, f64, bool}`; handle lane if the
type is opaque-bridged; wide lane otherwise. Per-value, not per-signature.

**Phase 2 exit criteria:** chrono ≥ 140 of the original 181 items usable (≈80%);
a data-shaped crate OUTSIDE the current corpus added as the 6th fixture (e.g.
`geojson` or `semver` -- something with derived Serialize records) and bridged at
>50% with zero overlay; round-trip fixtures green on na AND ctypes from one
source; perf gate: scalar-only signatures show NO regression vs Phase 0 (per-value
lane selection proven); a 10k-element `Vec<f64>` return measured ≤2× a
hypothetical memcpy floor (expected ~0.5–1.5 ms -- acceptable per priorities).
**ABI v1 frozen for good.**

### Phase 3 -- The py-interop tier (~5–7 weeks; parallelizable with 1–2)

From investigation (P): ~60% exists -- the native desktop host already embeds the
bundled CPython in na binaries. This phase promotes that private mechanism to a
supported feature. Weight: bundled CPython is python-build-standalone 3.14.6,
`libpython3.14.so` = 21 MB stripped; the launcher already dlopens it
`RTLD_NOW|GLOBAL` (exactly so C-extension wheels resolve), inits via PEP 741 fully
hermetic, and ships pip.

**3.0 De-risk spike (1 week, do FIRST):** strip the webview from the desktop
recipe: add 4 forwarders to `jac/launcher/pyembed.zig`
(`jpy_PyImport_ImportModule`, `jpy_PyObject_CallMethod`,
`jpy_PyBytes_FromStringAndSize`, `jpy_PyBytes_AsStringAndSize`); hand-write an na
program that boots `jac_engine_boot()`, imports **orjson** (abi3 Rust wheel
pip-installed into the materialized rt site), round-trips JSON, runs one polars
`read_csv` + `shape`; append the jac trailer via the `_bundle_runtime` snippet +
patchelf `$ORIGIN`; run on a machine with no system Python; measure per-call
latency (target < 2 µs scalar call). Everything hard (trailer, materialize, dlopen
GLOBAL, GIL, na FFI import) is already exercised by
`jac/tests/runtimelib/client/test_desktop_native_target.jac` /
`test_fused_runtime_boot.jac`.

**3.1 High-level embed surface (~2 wk):** `jac/launcher/pyinterop.zig` (into
libjacpyembed.so or a sibling): `jac_py_import(name) -> handle`,
`jac_py_getattr`, `jac_py_call(handle, args_payload, out_slot) -> status`,
`jac_py_from/to_{str,int,float,bytes}`, `jac_py_decref` -- **reusing the jac-bridge
status-code/JacBuf conventions** so na-side ergonomics match Rust bridges, and
keeping the forwarder count fixed (~15) instead of mirroring the C-API. (Constraint
honored: na links foreign symbols DT_NEEDED and can't call dlsym'd pointers -- all
dlopen/dlsym stays inside the shim; documented at pyembed.zig:5-8. The `jpy_`
prefix is load-bearing against RTLD_GLOBAL interposition -- keep it.)

- Synergy: the **wide lane's msgpack codec doubles as the arg-marshaling format**
  for `jac_py_call` (Python side: one small `msgpack`-decode helper or a
  hand-rolled ~50-line decoder in the shim's bootstrap) -- one wire format across
  both tiers.

**3.2 Jac wrapper (~1 wk):** `jaclang/runtimelib/.../python.na.jac`: `PyObj` obj
with `__del__` decref (the RC-dtor pattern proven in M3), conversions for
None/bool/int/float/str/bytes; lists/dicts stay opaque `PyObj` handles with
indexer helpers in v1 (avoids the known na dict/list-return backend gaps).
GIL: `PyGILState_Ensure/Release` per call (uncontended ~100 ns -- marshaling
dominates); v1 rule: main-thread only, documented (na-thread callbacks unproven;
CPython takes SIGINT -- make `install_signal_handlers` configurable in
`InitOpts`).

**3.3 Packaging (~1.5–2 wk):** `jac bundle --target binary --with-py-interop` in
`project.impl.jac` -- 90% is the existing `_bundle_binary` split/extract/re-tar/
re-append flow + `desktop_build.jac`'s `_stage_pyembed_shim` + `_patchelf_rpath`,
with `pip install --only-binary=:all: --target stage/site <wheels>` inserted and a
**slim-payload filter** (drop `site/jaclang` 257 MB + pytest; ship libpython 21 MB

- zipped stdlib + wheels -- polars ≈ 40–60 MB). Watch the known exec-bit-drop bug
in payload pack/materialize (open memory item) -- wheels ship .so files whose perms
must survive.

**3.4 `jac add py:<pkg>` (~0.5–1 wk):** `[py-interop]` stanza in jac.toml
mirroring `[rust-bridges]`; resolution = pip against the bundled interpreter's
tags (cp314/abi3); v1 host-platform-only (cross-platform wheel resolution via
`pip --platform` deferred, documented).

**3.5 Tests/CI/docs (~1 wk).** Flagship acceptance: an na binary using polars for
a groupby, shipped to a pythonless machine. Risks tracked: symbol interposition
(wheels vendoring openssl vs na NEEDED libs -- the `jpy_` lesson generalizes),
GIL-build only (pbs is not free-threaded), platform-tag availability per flagship
wheel on 3.14.

**Positioning (docs):** the py tier is the *variety* answer -- thousands of
author-maintained Rust bindings inherited at PyO3-boundary cost; the Rust-bridge
lanes are the *performance* answer. `jac add rust:` vs `jac add py:` makes the
trade explicit and user-chosen, which is exactly priority 3.

### Phase 4 -- Productionization (ongoing after 1–3)

- Seed the registry from the CI matrix (regex, chrono+serde, sha2, uuid, base64 +
  the new data-shaped fixture crate); overlays where rules miss.
- One real dogfood app on `nacompile` + `jac bundle` using ≥2 bridges + the py
  tier.
- macOS: implement the Mach-O `__DATA,__jac_bridge` section read in `_elf.jac`
  (the Rust side of the reader already exists in `jac-bridge-inspect`) -- today the
  finder advertises darwin and then hard-fails late; close or gate it.
- Windows na: reassess after the above; ctypes remains the interim Windows path.
- Fixture hygiene: assert `format_version` in `corpus.rs`; document the
  nightly-bump → regen-fixtures → re-ratchet procedure in `gen-fixtures.sh`.
- Registry/CLI polish from the review: urlopen timeout, missing-sha256 → warn or
  reject, index fetched once per install run, `_bundle_binary` respects the
  bridge-copy count, `jac remove rust:` symmetry, nightly-toolchain check in
  `toolchain_available()`.

---

## Part III -- Consolidated risk register

| Risk | Phase | Mitigation |
|---|---|---|
| Callback metadata dispatch misses a shape the heuristic caught | 0 | conformance suite runs both ways during the switch; heuristic deleted only when owning_conformance + adversarial suite green |
| ~~Capture-env under `try/except` segfaults (0.1.4)~~ RESOLVED 2026-07-10 | 0 | Was mis-diagnosed as capture-env; real cause = except-bound `e` slot RC-released uninitialized on the no-exception path (`exceptions.impl.jac` missing a null-init). Fixed with a 3-line entry-block `store null`; general na fix, unblocks 0.2.2. |
| Bare-soname bridge metadata not found at compile time → callbacks silently disabled | 0 | FIXED 0.0.0: resolve via JAC_RUST_BRIDGES_PATH/LD_LIBRARY_PATH; warn on present-but-unparseable blob instead of swallowing |
| Reentrancy guard breaks a legitimate pattern | 0 | status-coded error names the object + method; overlay can mark a method reentrant-safe (immutable `&self` methods skip the guard entirely) |
| ~~**Handle aliasing = double-free/UAF, UNDEFENDED in v1 (0.0.2/0.2.x, DEMONSTRATED 2026-07-11)**~~ RESOLVED 2026-07-13 (Phase S, Track A) | 0→S | The 0.2.2 busy-latch + 0.2.1 null-handle guards did NOT cover two live wrappers over one underlying object; the original `jac-bridge-reentrant` smuggled a `Box<i64>` through a `usize` and double-owned it, so closing one wrapper freed the inner under the other → `free(): double free`, exit 134. **Fixed by Phase S:** (1) Track A RC'd the handle box (`JacHandle<T>.rc: AtomicUsize`, `retain`/decref-drop shims) so a box shared by two wrappers frees at rc==0, and (2) the reference crate was rewritten to hold its counter behind an `Arc<Mutex<i64>>` (honestly shared ownership -- `owned` at the ABI, RC-safe at the Rust level). `aliasing_conformance.jac` test 3 flipped from asserting a crash to asserting a clean `["5","survived"]`; new test 4 pins that a shared alias outlives its closed originator and double-close is idempotent. The append-only `TAG_SHARED_BIT`/`TAG_BORROW_BIT` return tags (owned/shared/borrowed contract) are reserved for the binder-generated identity/interior-view returns (Track B, in progress); Rust-level-unsound aliasing APIs (a crate that hands out a second raw owner) are **skip-with-reason**, not defended. |
| ~~jac0core `codeinfo.jac` importing `_finder` deadlocks bootstrap~~ RESOLVED 2026-07-11 (0.5.4) | 0 | The `rust.` predicate consolidation initially routed jac0core's `_is_rust_bridge_module` through `_finder.is_bridge_module`. But `codeinfo` is reached from `boundary_analysis_pass` *while the compiler is compiling `_finder` itself* → self-referential circular import → every fresh-process native compile deadlocks (warm-process verify missed it; a sibling agent's cold compile caught it). Fixed by keeping the jac0core site an inline `rust.<crate>` mirror (comment-synced to `_finder`); only non-bootstrap sites consolidate. **Rule: nothing in jac0core may import the compiler's `rust_bridge` package.** |
| Blanket-generic substitution mis-substitutes | 1 | fixtures-verified per-crate; sha2 hash-equivalence test vs known digests |
| Denominator re-ratchet hides regressions | 1 | two-sided ratchet retained (bridged floor AND dropped ceiling); baseline TOML narrates every change |
| Manual serde impls change wire shape across crate versions | 2 | round-trip fixtures pinned per crate version; artifact identity includes features; typed objs only for `automatically_derived` |
| `--features` explosion (feature combinations per crate) | 2 | one feature set per crate in overlay/registry -- features are artifact identity, not a matrix |
| msgpack decode bugs in the hand-written na decoder | 2 | differential fuzz: same payload through rmp-serde (Rust), the ctypes decoder, and the na decoder -- byte-identical Jac values |
| Wide lane absorbs hot scalar paths | 2 | per-value lane rule + perf gate in CI (scalar signatures must hit tag lane; assert via generated-source inspection) |
| py tier: wheel .so exec bits dropped by payload repack | 3 | fix pack/materialize modes first (known open bug); spike validates on polars |
| py tier: allocator/symbol collisions (vendored openssl etc.) | 3 | RTLD_GLOBAL discipline documented; per-wheel smoke tests in CI for flagship wheels |
| serde/rustdoc/nightly churn | 1–2 | rustdoc-types pinned; format_version asserted; regen procedure documented; serde_core+serde dual root matching |
| Scope creep back toward "implement Rust semantics" | all | principle stands: traits flatten onto concrete types, generics monomorphize or skip, lifetimes never cross (owning wrappers); anything else = overlay or skip-with-reason |

## Part IV -- What dies, what survives

**Dies:** TYPE-MODEL-V2 (recursive blob schema) -- cancelled; the
`_lambda_arg_is_callback` heuristic; the single make_buf sink; the five hand-synced
copies of tag→slot lowering; the dual AST/semantic type-lowering split; the wasm/cl
consumer (stays dead); wasmtime embedding (not started, rejected).

**Survives (and is the foundation):** the deterministic binder + overlays + coverage
ratchet (extended, not replaced); the proc-macro → cdylib → metadata-blob pipeline;
the opaque-handle + RC-dtor model; the `{call,ctx}` closure ABI (validated by WIT's
own callback gap); owning wrappers and cursors; the M5 packaging/registry/cache; the
flat blob format itself -- permanently, since structure moved into payloads.

**Sequencing:**

```text
Phase 0 (soundness+debt, 2–3wk)
   ├─► Phase 1 (traits+lanes, 3–4wk) ─► Phase 2 (wide lane, 3–4wk) ─► Phase 4
   └─► Phase 3.0 spike (1wk) ─► Phase 3 (py tier, 4–6wk more)   [parallel track]
```

---

## Part V -- Execution checklist (work top to bottom)

Each task is sized to a sitting-to-a-day, names its files, and ends with a
verification step. Tasks within a numbered group are ordered; groups marked ∥ can
be reordered freely inside their phase. Local dev reminders: na tests need
`JAC_LLVM_SHIM=<worktree>/jac/zig-out/lib/libjacllvm.so` +
`PYTHONPATH=<worktree>/jac`; run bridge probes via single-process `jaclang run`
(not `jac test`, which OOMs on xdist); a `.impl.jac`-only edit doesn't bust the
bytecode cache -- touch the decl.

### Phase 0 -- Soundness + debt

**0.0.0 Base-green prerequisites (LANDED 2026-07-10, before any other Phase 0 work)**
Discovered by trying to run the na suite red-first; all three were silently
breaking the callback vertical:

- [x] The na conformance harness was DEAD at import: `_harness.jac` imported the
      removed `find_lib_in_dirs` (renamed to `find_bridge_lib` in the finder
      refactor) and `workspace()` was off-by-one (pointed at `jac-bridge-loader`,
      not the `bridges` workspace root). Fixed both -- this is why the suite was
      "dark" (0.6): nobody could run it, so the regressions below went unseen.
- [x] **Callbacks segfaulted in standalone nacompile.**
      `_register_bridge_metadata` was handed the BARE soname from the synthesized
      `import from "libjac_bridge_<crate>.so"`, `open()` failed under
      `cwd=jac_root`, the `except: return` swallowed it, `_callback_make_buf`
      stayed `None`, so `_lambda_arg_is_callback` returned False and the lambda
      was passed as a plain value where Rust expects `{call,ctx}` → the flagship
      `owning_conformance` SIGSEGV'd. Fixed: `_register_bridge_metadata` resolves
      bare sonames via `JAC_RUST_BRIDGES_PATH`/`LD_LIBRARY_PATH`
      (`_resolve_bridge_lib_path`), the harness's `compile_env` now exports
      `JAC_RUST_BRIDGES_PATH`, and a "present-but-unparseable" blob now logs a
      warning instead of silently disabling callbacks (the 0.1.1 anti-swallow
      rule, applied here). `owning_conformance` is GREEN again (32/32 obs
      na≡CPython). This is the true starting line for Phase 0; the plan's
      assumption "existing conformance suites green" was false on arrival.

**0.0 Reference crates (PREREQUISITE -- two exit-gate scenarios are untestable without them)**

The current tree ships neither a second callback-bearing crate nor any `&mut self`
method that invokes a callback, so the Phase 0 exit gates "two-crate allocators"
(0.1.1) and "reentrant method call" (0.2.2) cannot be exercised as written. Build
these first; the adversarial suite already contains skip-gated tests waiting on them.

- [x] 0.0.1 **DONE.** Second callback crate `bridges/jac-bridge-owning2` (module
      `owning2`, `Regex2::replace_all`) with a GUARDED `#[global_allocator]`
      (magic-tagged header, `abort()` on cross-crate free) so the two-crate module
      proves per-crate allocator keying as a deterministic crash, not silent UB.
      A third guarded crate `jac-bridge-owning3` (`Regex3`) was also added for an
      interleaved N-crate probe. All in the workspace members.
      Verified: `adversarial_conformance.jac` "two bridge crates ... per-crate
      allocators" was RED (SIGABRT) pre-0.1.1 and is GREEN post-0.1.1.
- [x] 0.0.2 Reentrancy crate `bridges/jac-bridge-reentrant`: an opaque type with a
      `&mut self` method that invokes a `JacCallback` (e.g. `Cell` with
      `bump(&mut self)` and `apply(&mut self, cb: JacCallback)` where the callback
      re-enters `bump`). This is the ONLY shape that reproduces the two-live-`&mut T`
      hole 0.2.2 closes. Also expose (or add to owning) a method that can mint TWO
      wrappers over ONE handle -- needed for the use-after-close *aliasing* variant
      (see 0.2.1 note). Verify: the reentrancy + aliasing tests un-skip.

**0.1 Callback dispatch (do first -- everything callback-related builds on it)**

- [x] 0.1.1 **Per-crate make_buf sink -- DONE 2026-07-10.** Replaced the single
      `_callback_make_buf` slot with a per-crate map. `_register_bridge_metadata`
      (`calls.impl.jac`) now records `_bridge_type_crate[type] = module` for every
      opaque type in each crate's blob; `_note_bridge_sink` records
      `_bridge_make_buf_fns[sym] = fn`. New `_callback_make_buf_for(func)` picks
      the make_buf by the callee's receiver type (na method wrapper is named
      `<Type>.<method>`, and the type names the owning crate); `_codegen_bound_args`
      resolves it once per call and threads it into `_codegen_callback_arg`, which
      routes the trampoline's return buffer through THAT crate's allocator. The
      `_callback_make_buf` scalar is retained only as the "some crate has
      callbacks" gate and single-crate fallback. Anti-swallow warning kept.
      **Verification (runtime, not just IR):** the second crate `jac-bridge-owning2`
      was given a GUARDED `#[global_allocator]` (magic-tagged header, `abort()` on
      cross-crate free), so a single-sink regression is a deterministic SIGABRT.
      Before the fix the merged two-crate probe aborted (`EXIT -6`,
      `free(): invalid pointer`); after, it is GREEN with correct per-crate output
      (`a=[HELLO WORLD]`, `b=[<foo> <bar>]`). A three-crate interleaved probe
      (`owning`→`owning3`→`owning2`→`owning`, each guarded) is also GREEN
      (`scratchpad/run_threecrate.py`). Single-crate callback path + reentrant +
      the `exceptions.na.jac` gen-pass suite unregressed. The `.jac` test
      "two bridge crates in one module use their own per-crate allocators" now
      passes.
- [x] 0.1.2 Replace `_lambda_arg_is_callback` (`calls.impl.jac:104-115`) with
      callee-driven dispatch at the three `_codegen_bound_args` call sites: arg is
      a callback iff (callee symbol ∈ registered bridge map) AND (that param's tag
      == TAG_FN). Delete the module-global heuristic. Requires the binder/macro to
      stamp TAG_FN on callback params universally -- check
      `bridges/jac-bridge/src/lib.rs` `ty_to_tag` and the binder's callback rule
      emit it (they do for the regex vertical; assert with
      `jac-bridge-inspect`-style blob dump or a unit test on the blob bytes).
      Verify: new adversarial test -- a user lambda passed to a *non-bridge*
      function in a module that imports a bridge compiles to ordinary lambda
      lowering. NOTE (adversarial finding): this must assert on the emitted IR
      (no `__jac_cb_tramp_` trampoline), NOT on runtime behavior -- a
      correctly-typed `Callable[[str],str]` HOF already dodges the current
      `IntType`-gated heuristic, and the only construction that misfires (a bare/
      untyped `Callable` → i64 slot) is one na can never indirect-call through a
      param, so the misfired lambda never executes either way. `owning_conformance.jac`
      stays green.
- [x] 0.1.3 Trampoline hardening (`calls.impl.jac` `_codegen_callback_arg`):
      (a) identity-return double-release -- guard the two
      `_emit_rc_release_simple` calls with a runtime pointer-equality check
      (`result == raw` → release once), or retain on return;
      (b) arity -- if the lambda's declared params ≠ 1, emit a compile error
      naming the callback signature (never index `function_type.args[0]` blind);
      (c) non-str declared return → compile error;
      (d) `builder.store(0, out_err)` explicitly before `ret 0`.
      Verify: conformance cases -- `lambda m: str -> str : m` in a 1000-iteration
      loop (no abort/leak), a 0-param lambda and a 2-param lambda both produce
      readable compile errors. NOTE (adversarial finding): the error *wording* is
      unspecified, so the tests currently assert diagnostic SHAPE (no binary
      produced, no `IndexError`/ICE traceback) rather than exact text -- tighten
      the assertion to match once the message string is chosen here.
- [x] 0.1.4 **`try/except ... as e` unconditionally RC-releases an uninitialized
      slot -- RESOLVED 2026-07-10** (`na_ir_gen_pass.impl/exceptions.impl.jac`).
      The original hypothesis (capture-env / stack-lifetime) was WRONG. Isolation
      matrix (capture × try × call × scope) proved capture is irrelevant: a
      `try/except` around a *pure-Jac* call with NO bridge and NO capture also
      crashed. Root cause: `_codegen_try` registers the except-bound name (`e`)
      as a function-scope local via `_entry_alloca` + `local_vars[name]`, so the
      function epilogue RC-releases its slot unconditionally -- but `e` is only
      *stored* on the exception path. On the no-exception path the slot holds
      uninitialized stack, and the cleanup `__rc_release_simple(garbage)` frees a
      wild pointer. Non-determinism = whether that stack garbage happens to look
      releasable (correct output first, then a crash at cleanup, flips on
      recompile -- the classic uninitialized-memory signature). Every other local
      gets a `store null`; `e` did not. Fix: null-init the except-var alloca in
      the entry block (3-line change). This is a GENERAL na correctness fix (all
      `try/except ... as e` in native code, not bridge-specific). Verified: all
      12 isolation variants + the reentrant `&mut` probe now deterministically
      green (were 100% SIGSEGV); the existing `exceptions.na.jac` gen-pass suite
      (incl. `except as binding`) still 12/12 green; the one `runtime_errors`
      failure is a pre-existing cast-attribute-access feature gap, unrelated.
      0.2.2 is now UNBLOCKED.

**0.2 Handle soundness (Rust side, `bridges/jac-bridge/src/lib.rs`)**

- [x] 0.2.1 Null-handle guards: method shims (~:982) and
      `error_message`/`panic_message` (~:826, :905) return status 1 with message
      `"null handle (use after close?)"` instead of dereferencing. Mirror in the
      hand-written crates only if their tests exercise it (they are frozen
      reference vectors -- prefer adding the guard to the macro path and noting the
      M0 crate's divergence in its README).
      NOTE (adversarial finding): plain use-after-close is ALREADY defended one
      level up -- the synthesized wrapper guards `__closed` and zeroes `__handle`
      on `close()`, so `x.close(); x.method()` raises at the Jac layer with no
      Rust call. This guard is therefore defense-in-depth for the raw-handle-0
      path. The genuinely dangerous, currently-undefended case is the *aliasing*
      variant: TWO live wrappers over ONE handle, where closing one leaves the
      other pointing at freed memory -- that needs the two-handle minting method
      from 0.0.2 to reproduce, and IS real UB today.
- [x] 0.2.2 Reentrancy guard: macro wraps each opaque type's handle in
      `struct JacHandle<T> { busy: AtomicBool, value: T }` (or equivalent field
      pair); every `&mut self` shim does try-lock → busy ⇒ status 1
      `"object already in use (reentrant call)"`; `&self`-only methods skip the
      guard. Update `Send` assertion accordingly.
      Verify: new trybuild/runtime test -- a callback that re-enters its own
      receiver gets a clean Jac exception, not UB.
- [x] 0.2.3 `string_to_jacbuf`/`vec_to_jacbuf` (~:658): assert
      `len <= u32::MAX && cap <= u32::MAX` (panic → existing status-2 path).
- [x] 0.2.4 Attribute parsing (~:86-100): unknown key in `#[bridge(...)]` → spanned
      compile error; add a trybuild case for `#[bridge(modle = "x")]`.
- [x] 0.2.5 Panic payload: in the shared `catch_unwind` wrapper (~:1051), downcast
      `&str`/`String` and store as the panic message.
- [x] 0.2.6 (opportunistic, same file) callback return path: replace
      `from_utf8_lossy` (~:735) with strict validation → callback_error status,
      matching param-side discipline.

**0.3 Binder honesty**

- [x] 0.3.1 `classify.rs:515-517`: multiple `-> Self` associated fns -- first (in
      deterministic sorted order) becomes ctor, the rest become recorded
      `Skip("additional constructor")` entries. Re-ratchet baselines.
      Verify: uuid fixture -- `nil`/`max`/`new_v4`/`parse_str` all appear as either
      ctor or skips; determinism test still byte-identical.

**0.4 Generated-source safety (`jac/jaclang/compiler/rust_bridge/`)**

- [x] 0.4.1 `_synth.jac`: identifier sanitizer -- blocklist of Jac keywords +
      `root`/`node`; blocked names get a trailing `_` rename recorded in the
      module header comment (or skip-with-reason if renaming would collide).
      Apply to type names, method names, param names.
- [x] 0.4.2 `materialize_bridge` (`__init__.jac:108-127`): round-trip parse the
      rendered source (compile to AST, check zero syntax errors) before writing
      the cache; on failure raise a readable error naming the crate + first
      diagnostic.
- [x] 0.4.3 `_synth.jac` `_drain_and_raise` (:140-163): branch on status --
      status 1 uses `error_msg_sym`/`error_drop`, status 2 uses
      `panic_message`/`panic_drop` (mirror `_ctypes_codegen.jac:354-361`); raise
      typed errors like the ctypes side does (or document the ValueError collapse
      as a deliberate v1 divergence in rust-bridges.md -- pick one, stop being
      accidental).
- [x] 0.4.4 `_ctypes_codegen.jac` trampoline (:235-237): stash the Python
      exception (`sys.exc_info()`) on the runtime object and chain/re-raise it
      after the FFI call returns, instead of bare `return 3`.

**0.5 Shared marshal layer**

- [x] 0.5.1 New `jac/jaclang/compiler/rust_bridge/_marshal.jac`: `enum SlotKind`
      (STR_PTR_LEN, BYTES_PTR_LEN, U64, BOOL_U8, F64, OUT_BUF, OUT_U64, OUT_ERR,
      WIDE_PTR_LEN) + `obj Slot { has name: str; has kind: SlotKind; }` +
      `def lower_params(fd: FnDesc) -> list[Slot]` and
      `def lower_return(fd: FnDesc) -> Slot`. Also move here: symbol-name
      constructors (`make_buf_sym(mod)` etc. -- currently format-string'd in
      `_ctypes_codegen.jac:75-97`, `_synth.jac:90-94`, and
      `calls.impl.jac:93-95`), `STATUS_OK/ERR/PANIC/CB_ERR` constants, and the
      magic `"message"` method-name constant.
- [x] 0.5.2 Port `_synth.jac` onto it: `_shim_decl`, `_method_body`, `_ctor_body`
      all consume `lower_params`/`lower_return`; delete the `_ctor_body` verbatim
      copy of `_method_body`'s marshaling.
      Verify: `test_generator_drift.jac` + na conformance byte-identical to
      pre-refactor output (golden-compare the rendered `.na.jac` for regex).
- [x] 0.5.3 Port `_ctypes_codegen.jac`: `_wire` and `_call` consume the same
      lowering. Verify: `test_loader.jac` suite + single-source conformance green.
      (Also fixed DRIFT-P1 opaque-ref param TypeError, DRIFT-R4 Option<scalar>
      silent non-None, DRIFT-P3 unbridgeable-tag honest skip.)
- [x] 0.5.4 Collapse the `rust.` namespace predicates onto
      `_finder.is_bridge_module`; dedupe `_gen_root` (`__init__.jac`) with
      `_finder._cache_root`. NB: only TWO real predicate sites existed (plan
      over-counted). The `imported.impl.jac` (type_system) site routes to the
      finder, but the `codeinfo.jac` (jac0core BOOTSTRAP) site MUST stay an inline
      mirror -- importing `_finder` from it creates a self-referential circular
      import (boundary_analysis_pass -> is_bundled_native_module -> _finder while
      _finder is mid-compile) that DEADLOCKS every fresh-process native compile.
      Kept in sync via comment; do not re-consolidate that one.
- [x] 0.5.5 na backend unification: make `_resolve_container_ast`
      (`types.impl.jac:577-684`) normalize AST→semantic type and delegate to the
      one `_lower_class_type` path (single place to add types later); thread an
      optional `expected_type` param through `_codegen_expr` →
      `_codegen_assignment` uses it, and extend to call-args and `return`
      positions (fixes `f(x={})` / `return {}` empty-container miscompiles).
      Verify: existing native container tests + new cases for the three literal
      positions.
- [x] 0.5.6 (finding 2026-07-11) na-loader honesty: `_synth.render()`
      SILENTLY drops any method returning an opaque wrapper of a
      **constructor-bearing** type ("na adopt-ctor signature clash" -- the wrapper
      can't carry both `init(v)` and the adopt-ctor `init(raw)` at the same
      arity). Surfaced by `jac-bridge-reentrant`: `Cell::alias(&self) -> Self`
      compiles + works through the CPython loader but vanishes on na; had to be
      re-spelled as a distinct ctor-less `CellAlias`. This is a silent-drop of a
      valid method (same honesty class as 0.3.1). Fix: either emit a recorded
      Skip-with-reason (minimum) or give the adopt-ctor a distinct arity/name so
      both survive. Owned by the synth/na-loader path.
      RESOLVED via the PREFERRED fix (parity by addition, user-chosen): na wrapper
      gains a distinct-name static adoption factory
      `static def _adopt(raw: int) -> T { a = T.__new__(T); a.__handle = raw;
      a.__closed = False; return a; }` (bypasses the Rust ctor, single drop). The
      `_method_body` ref gate loosened from `adoptable` to `opaque`, ref-returns
      emit `T._adopt(rh)` for ctor-bearing targets. Both loaders now expose e.g.
      `Cell::alias`. Guard: `test_render_ctor_return.jac` Test1 (survival) green.
      NATIVE-LOWERING RESIDUAL (now closed): the emitted `_adopt` shell rendered
      but did not nacompile -- NaIRGenPass could not lower `T.__new__(T)` (nor the
      external-local field writes on its result), so a ctor-bearing method-return
      demoted to Python-only at real compile time. NaIRGenPass now lowers
      `T.__new__(T)` to a bare zero-filled alloc (vtable + type-tag wired, no init
      call) and the shell's `adopted.field = ...` stores lower normally. Guards:
      unit `jac/tests/compiler/passes/native/test_native_obj_new_adopt.jac` (JIT,
      4 tests) + end-to-end reference crate `jac-bridge-adopt`
      (`Counter::snapshot(&self) -> Snapshot`, `Snapshot` ctor-bearing) driven
      through a real `.so` by `na/adopt_conformance.jac` (3 tests). Negative
      proof: reverting the fix regresses the conformance to `E5090 ... method
      'Counter.snapshot' ... demoting to Python-only`. So a ctor-bearing
      self-identity / adoptable type is no longer forced to be factory-minted to
      run on na.

**0.6 CI**

- [x] 0.6.1 `rust-bridges.yml`: replace the hand-enumerated `jac test <file>`
      steps with directory runs (`bridges/jac-bridge-loader/tests` and
      `tests/na`); add `jac-bridge-regex` to the na job's crate build list; add a
      step running `test_na_coverage_floor.jac`. Make gated tests report SKIP,
      not silent-pass (`skip_gate` → a printed `SKIP:` line at minimum).
- [x] 0.6.2 `rust-bridges-artifacts.yml`: install jaclang from the checkout
      (reuse the sibling workflow's setup-jac pattern), not PyPI.
- [x] 0.6.3 Adversarial suite (new `tests/na/adversarial_conformance.jac` or
      similar): non-bridge lambda untouched; two-crate allocators; identity
      replacer loop; reentrant method → clean error; use-after-close → clean
      error. This suite is the Phase 0 exit gate.

### Phase 1 -- Trait flattening + small lanes

**1.1 Flattening core (`bridges/jac-bridge-binder/src/`)**

- [ ] 1.1.1 `classify.rs`: `trait_disposition()` replacing the `:470` skip --
      NOISE set via paths-table canonical paths (Borrow, BorrowMut, Into, From,
      TryFrom, TryInto, Any, ToOwned, CloneToUninit, Same + `is_synthetic` +
      negative impls); local traits → concrete items + provided-defaults resolved
      from the in-index trait def; external/blanket traits → concrete/blanket
      items only, provided-defaults excluded from numerator AND denominator
      (document why: their signatures are unresolvable -- names only).
- [x] 1.1.2 Self-alias substitution: `self_aliases: &[&str]` (type name + blanket
      generic param, e.g. `D`) threaded through `classify_fn`,
      `classify_param_type`, `classify_return`, `classify_result_return`,
      `returns_self`, and the four rescue rules. Test on sha2's `new() -> D` and
      `finalize(self) -> Array<u8, OutputSize<D>>` shapes.
      DONE: the blanket `impl<D> Digest for D` materialized on each hasher has
      `blanket_impl.generic == "D"` and returns `-> D` where `Self` is meant. The
      per-impl alias set (type name + `blanket_impl` generic) is built in
      `classify_impl` and threaded down. `Digest::new() -> D` now classifies as a
      `-> Self` constructor on all 6 hashers; `finalize(self) -> Array<u8,
      OutputSize<D>>` stays an honest `Array` skip (the `D` inside `OutputSize<D>`
      is not mis-substituted, and the by-value `Self` RECEIVER - spelled literally
      as `Self`, not `D` - is still caught by the consuming-`self` guard, so nothing
      unsound is emitted). Guards: `src/tests/self_alias.rs` (3 unit tests).
      RIDER (surfaced by making the sha2 crate worth compiling): `trait_use_path`
      emitted `use sha2::DynDigest;`, but `DynDigest` is NOT re-exported at the
      sha2 root (only `Digest` is), so the generated crate never actually compiled.
      Fixed by routing EXTERNAL traits (defining crate ≠ bridged module) through the
      module's re-export of that crate - `sha2::digest::DynDigest` /
      `sha2::digest::Digest` (sha2 does `pub use digest;`); LOCAL traits (chrono's
      `Datelike`) keep the root path. Still no extra Cargo dep, still exact-version
      pinned. Proven by a new `#[ignore]`d `sha2_bridge_compiles_clean` roundtrip
      test (compiles the generated crate under `-D warnings`, checks the ctor
      shims) - CI already runs `-- --ignored`. sha2 corpus floor re-ratcheted 0→12
      (6 `new` ctors + 6 `output_size`) with rationale. Remaining sha2 surface
      (update/finalize) landed in 1.2.2 (the bytes lane + `&mut self` + consuming-
      `self` clone-out lifted the floor 12 -> 42); one-shot `digest` awaits a
      `FN_STATIC` lane (see 1.2.2 STATUS).
- [ ] 1.1.3 Per-type `seen_names` dedup, inherent-first then traits in
      deterministic order; losers → `Skip("name collision with <winner>")`.
- [ ] 1.1.4 `types.rs`: `via_trait: Option<String>` on `BridgeFn`.
- [ ] 1.1.5 `codegen.rs`: emit `use <trait_path>;` per via_trait; extend generated
      `Cargo.toml` deps with trait-defining crates (e.g. `digest` for sha2) --
      derive from the via_trait path's crate root; consuming-receiver arm:
      by-value `self` → `self.0.clone().method(...)` gated on a Clone impl, else
      skip-with-reason.
      Verify: roundtrip test compiles the generated sha2 crate under
      `-D warnings`.
- [ ] 1.1.6 Update determinism + corpus tests; re-ratchet
      `coverage-baseline.toml` with narrated entries (denominator policy change
      called out explicitly).

**1.2 Small lanes ∥**

- [ ] 1.2.1 `TAG_F64`: `jac-bridge-schema` constant + macro `ty_to_tag` +
      shim arms + `_blob.jac` + `_marshal.jac` F64 slot + na (f64 native) +
      ctypes (`c_double`) + `test_abi_drift.jac`. Conformance: an f64 echo fn in
      `jac-bridge-scalar`, both runtimes.
- [~] 1.2.2 `TAG_BYTES`: `(ptr, len)` param + JacBuf return; macro arms for
      `&[u8]` and `impl AsRef<[u8]>` params, `Vec<u8>` and digest-output
      (`Array<u8, _>` / `Output<Self>`) returns; na uses `__jac_bytes_from_raw` +
      explicit-len bytes params (never strlen); ctypes uses
      `(c_char_p, c_uint32)`. Conformance: sha2 `update`+`digest` against known
      SHA-256 vectors on BOTH runtimes -- this is the sha2 acceptance test.
      STATUS: wire + macro + CPython landed in the TAG_BYTES vertical (byte-
      identical, the `jac-bridge-scalar` fixture). The BINDER half is now done:
      `classify_param_type` reads `&[u8]` / `impl AsRef<[u8]>` as `ScalarType::Bytes`;
      `classify_return` reads `Vec<u8>` and `Array<u8, _>` / `GenericArray<u8, _>` as
      `BridgeReturn::Bytes` (intercepted before the `Vec<V>` list arm); the two
      receiver shapes the digest surface needs are lifted -- `&mut self` methods
      emit `pub fn f(&mut self, …)` (routed through the macro's reentrancy latch)
      and by-value `self` (`finalize`) is cloned out of the shared handle
      (`Digest::finalize(self.0.clone()).to_vec()`), Clone-gated in the classifier.
      Flattened-trait methods now emit UFCS (`Digest::update(&mut self.0, data)`) so
      the co-`use`d `Digest`/`DynDigest` don't make the call ambiguous (E0034). sha2
      floor re-ratcheted 12 -> 42 (new+update+finalize+finalize_reset+reset across 6
      hashers); the generated crate compiles clean under `-D warnings` with
      `update`/`finalize`/`finalize_reset` exported (`sha2_bridge_compiles_clean`).
      OPEN: (a) na SKIPS the whole lane on the two proven na gaps (bytes param
      struct-ptr vs `*const u8`; bytes method-return typed as bare i64 at the call
      site); (b) the one-shot associated `digest(data) -> Array` stays a skip -- a
      no-receiver fn is `FN_CTOR` in the macro (a `Self` return), so a static method
      returning bytes needs a distinct `FN_STATIC` lane. Hash-equivalence via
      new+update+finalize is unaffected; the CPython runtime SHA-256-vector
      conformance test (CI matrix) closes the acceptance, na half deferred.
- [x] 1.2.3 `-> String` return arm in `classify_return` (JacBuf machinery
      exists; no new tag).
      STATUS: DONE. `classify_return` now maps an owned `String` return to the
      existing `BridgeReturn::Str` lane (one arm, `rp.path == "String"`). Codegen
      already normalizes `Str` to an owned `-> String` via `.to_string()` (a clone
      on a `String` source, an allocation on `&str`), so the generated-source shape
      and the compile path are IDENTICAL to the long-proven `&str` lane (regex
      roundtrip's `OwnedMatch::as_str`) -- no new codegen, no new tag, no new compile
      risk. Corpus coverage is unchanged: the 5 fixtures' `String` returns are all
      Display's `to_string` (a NOISE trait, filtered) or live on `DateTime<Tz>`
      (a dropped generic). `string_return.rs` pins `DateTime<Utc>` to reach
      `to_rfc3339`/`to_rfc2822 -> String` and asserts the `Str` classification +
      `-> String`/`.to_string()` emit shape. Result<String,E>/Option<String> stay
      out of scope (no bare-String producer in the corpus needs them yet).
- [~] 1.2.4 Ref-lane generalization in the binder: emit `TAG_REF|idx` for
      cross-type returns and `TAG_OPT_BIT|REF` for `Option<BridgedType>` /
      `ParseResult<BridgedType>`; loaders already decode these shapes for Self --
      extend `_synth`/`_ctypes_codegen` decode to any type index (mostly lifting
      an artificial Self-only restriction). Conformance: chrono
      `NaiveDate::and_time -> NaiveDateTime` and `with_year -> Option<NaiveDate>`.
      STATUS: BINDER done. New `BridgeReturn::Ref(name)` (a fresh owned instance of
      another bridged type, `NaiveDateTime::date -> NaiveDate`) and `OptRef(name)`
      (`Option<Self>` / `Option<BridgedType>`, `with_year`/`with_month`/`succ_opt`).
      classify keeps a `ref_type_names` set (non-mono opaque types, built from
      `find_types` before method classification); codegen wraps the call in the
      target newtype (`NaiveDateTime(self.0.date())`, `....map(NaiveDate)`). LOADERS
      NEEDED NO CHANGE: both already pick the wrapper class by `tag_ref_index` and
      handle `Option`-of-ref None in-band; the residual Self-scoping is only the
      retain accounting for self-identity/shared aliasing returns, and a cross-type
      return here is fresh-owned (single drop via the ctor/`_adopt` path). MACRO was
      already general (`ret_tag` maps any bridged name to `Ref(idx)`). chrono floor
      61 -> 105 (past the 85 exit target); the ref-lane pattern compiles clean
      against real chrono under `-D warnings` (standalone check). NOTE: the plan's
      `and_time` example takes a bridged-type PARAM by value, a separate handle-arg
      lane, so it stays a skip; `and_hms`/`date`/`time` give the identical cross-type
      return shape without it. OPEN: (a) mono cross-type returns (`Date<Tz>`) need
      the instantiation check `returns_self` does, deferred; (b) `Result<Bridged, E>`
      returns not yet wired (only `Option`); (c) chrono has no whole-crate compile
      roundtrip -- an unrelated multi-`#[jac_error]` limitation rejects the module,
      and it newly bridges some deprecated methods (`and_hms`) that trip `-D warnings`
      (the binder does not filter `#[deprecated]` items -- separate hygiene item).
- [x] 1.2.5 Tuple-struct candidates in `classify_type` (single-field, bridgeable
      inner or opaque): unlocks uuid. Conformance: `Uuid::parse_str` +
      `is_nil` round-trip.
      STATUS: DONE. `classify_type` now admits a single-field tuple struct whose
      inner field is private (`Tuple([None])`, the newtype-with-opaque-inner shape)
      as an opaque handle, mirroring the Plain `has_stripped_fields` gate. uuid
      0 -> 13 bridged (past the ≥8 floor): `Uuid` gets a `from_slice` ctor + 7
      methods (`is_nil`/`is_max`/`get_version_num` + the `hyphenated`/`simple`/
      `urn`/`braced` format-handle conversions), and the format wrappers +
      `NonNilUuid` bridge with `into_uuid`/`get` ref-returns. Generated crate
      compiles clean under `-D warnings` (`uuid_bridge_compiles_clean` roundtrip).
      Two latent bugs the unlock surfaced were fixed alongside: (a) `inner_path`
      hard-coded the flat `crate::Type` -- a submodule type (`uuid::fmt::Simple`)
      needs its qualified path, and a PRIVATE-module type (`uuid::non_nil::NonNilUuid`)
      its crate-root re-export; `accessible_type_path` now resolves the shortest
      COMPILING path (named root re-export > root/glob-reexported > public submodule),
      never the raw `doc.paths` canonical path; (b) a `Ref`/`OptRef` return can name
      a type that classifies to nothing (`get_timestamp -> Option<Timestamp>`;
      `Timestamp`'s API is all closures/unsupported) and codegen drops such a
      dead-opaque type -- a new fixpoint `reconcile_ref_returns` demotes the dangling
      return to a skip. regex also gained +8 (its `SetMatches`/`CaptureLocations`
      tuple structs; `RegexSet::matches` now a ref-lane handle). NOTE: `parse_str`
      and the other extra `-> Self` assoc fns stay "additional constructor" skips --
      the ABI has ONE ctor per type; exposing the rest needs the deferred FN_STATIC
      lane (same gap as sha2's one-shot `digest`). The `is_nil` round-trip works via
      the winning ctor; the literal `parse_str`-as-ctor round-trip is FN_STATIC-gated.

**1.3 Exit gate**

- [ ] Corpus floors: chrono ≥ 85, sha2 ≥ 60 (incl. update/digest/finalize),
      uuid ≥ 8; determinism byte-identical; all flattened-or-skipped items
      visible in the coverage report.

### Phase 2 -- Wide lane

- [x] 2.1 `TAG_WIDE = 8`: schema + `_blob.jac` + `test_abi_drift.jac` (6/7 are
      `TAG_F64`/`TAG_BYTES`). Param
      wire = `(payload_ptr, payload_len: u32)`; return wire = JacBuf out-slot.
- [x] 2.2 `Wide<T>` newtype + macro arm. STATUS: DONE. `Tag::Wide` added to the
      macro (`is_wide_marker` recognizes `Wide<T>` in both param and return
      position). Param arm: crosses as `(ptr, len)`, decoded by `#rt::wide_decode`
      (`rmp_serde::from_slice`) inside the `catch_unwind` closure -- a malformed
      payload maps to a `String` via `?` → status 1 + error handle. Return arm:
      `#rt::wide_encode` (`rmp_serde::to_vec_named`) → `vec_to_jacbuf` out-slot.
      `Wide<T>` is a `#[serde(transparent)]` newtype emitted into the `#rt` module
      (gated on `has_wide`, like the async runtime) so wide-free bridges stay
      byte-identical and pull in no `serde`/`rmp_serde` dep; a `use super::#rt::Wide`
      is injected into the re-emitted module (mirrors the `JacCallback` import).
      Tests: `tests/wide.rs` (end-to-end round-trip through the shim with a
      NUL-containing string field + a scalar param wedged beside the wide one to
      pin per-value lane selection; plus the malformed-payload → status-1 path with
      the decode error message), `tests/ui/wide_missing_serde.rs` (trybuild: a
      `Wide<T>` whose `T: !Serialize` → spanned trait-bound error). Deps `rmp`,
      `rmp-serde`, `serde` land in generated crates via `emit_cargo_toml` (2.4);
      added as `jac-bridge` dev-deps here for the runtime test.
- [x] 2.3 Binder serde detection. STATUS: DONE. `classify.rs`
      `serde_disposition(item_id) -> SerdeInfo` (twin of `implements_error_trait`)
      walks a type's impl list once, unioning `Serialize`/`Deserialize` and
      noting whether ANY serde impl is `#[automatically_derived]`. `is_serde_trait_path`
      accepts BOTH the `serde::` and `serde_core::` roots via the precise `paths`
      summary (with a fully-qualified display-path fallback) -- verified against a
      serde-featured chrono fixture whose canonical root is `serde_core::ser::
      Serialize` (the >=1.0.220 core split; a `serde::`-only matcher finds NOTHING).
      `SerdeInfo { serialize, deserialize, automatically_derived }` surfaced on
      `BridgeType.serde` (default for synthesized wrappers; real disposition on
      opaque/error/mono types). `is_wide_serializable(ty, dir)` structural
      whitelist: msgpack scalars (128-bit ints excluded), `String`, `Vec`/`Option`/
      `Range`/`RangeInclusive` (recurse args), `HashMap`/`BTreeMap` (String key +
      wide value), `Duration`, tuples/slices/arrays; a LOCAL leaf does a real
      `serde_disposition` impl lookup, an unindexed external leaf is false. Overlay
      `[type."T"] wide = true|false` → `BridgeType.force_wide`, exclusive with
      `skip`/`monomorphize` (fails loud). `is_wide_*` are `#[allow(dead_code)]`
      until lane resolution (2.8) wires them into param/return classification.
      Tests: `classify::serde_lane_tests` (dual-root detection, manual-impl =>
      `!automatically_derived`, whitelist scalars/containers/leaf-lookup, +3),
      `tests::overlay_regex::type_wide_*` (force/deny + exclusivity, +4). Serde
      fixture provenance in `tests/fixtures/serde/README.md`; the `gen-fixtures.sh`
      feature column is 2.4.
- [x] 2.4 Feature plumbing. STATUS: DONE (2.4a/b/c). (a) `gen-fixtures.sh`
      `crate@version:features` column (NOT --all-features) routes featured
      fixtures to a feature-named subdir (`serde/`) the corpus glob skips; CRATES
      synced to on-disk versions; uuid serde fixture regenerated through the new
      path. (b) `[crate] features = [...]` overlay table (`CrateOverlay`,
      deny_unknown_fields, `Overlay::features()`); binder records but does not act
      on it. (c) `BridgeSpec.crate_features` (from overlay) → `emit_cargo_toml`
      pins the source-crate dep WITH features (bare `= "=x"` stays byte-identical
      when empty); binder `--features a,b` CLI flag is the channel for
      build-on-miss (rustdoc JSON has no overlay beside it); `run_build_pipeline`
      /`build_bridge` take a features list, enabled via `cargo add --features`
      (activates the optional dep so `cargo rustdoc -p crate` documents its impls;
      NOT re-passed to rustdoc -- `-p crate` resolves `--features` against the
      root package) and handed to the binder; `RegistryArtifact.features` records
      features as part of artifact identity. Tests: overlay parse/default/
      unknown-key/spec-unchanged (+4), emit_cargo_toml bare-vs-inline (+2).
      Follow-up: feature-aware LOCAL cache path + find needs import-site feature
      intent -- deferred (out of 2.4 scope).
- [ ] 2.5 na msgpack codec: shared runtime `.na.jac` module (decoder ~150 lines:
      lead-byte dispatch + fixed-literal `struct.unpack(">…")` reads → dict/list/
      str/int/float/bool/None; encoder for the same subset; bounded recursion
      depth; u64>i64::MAX documented). Import it from synthesized bridges.
- [ ] 2.6 ctypes msgpack codec (~120 lines, `struct.unpack_from`, zero deps) in
      `_ctypes_codegen.jac` or a sibling module.
- [ ] 2.7 Differential fuzz test: generate value trees, encode with rmp-serde
      (a tiny Rust test bin), decode with BOTH Jac decoders, assert identical
      Jac values; plus round-trip through the encoders.
- [ ] 2.8 Lane resolution in the binder: per-value rule (tag if fits, handle if
      opaque-bridged, wide otherwise) + the handle-wins canonical rule; assert in
      a unit test that a scalar param beside a Wide param stays TAG-lane.
- [ ] 2.9 Typed obj synthesis: only `automatically_derived && !has_stripped_fields`
      → Jac `obj` with rustdoc field names; else dict/str per actual wire shape.
      Pin per-crate round-trip fixtures (chrono NaiveDate == ISO string, uuid ==
      hyphenated string).
- [ ] 2.10 Sixth corpus fixture: a derived-serde data crate (e.g. `semver` or
      `geojson`), floor >50% with zero overlay. Re-ratchet baselines.
- [ ] 2.11 Perf gate in CI: scalar-signature codegen contains no wide-lane calls
      (generated-source inspection); one timed bulk case (10k Vec<f64>) with a
      generous ceiling to catch pathological regressions only.
- [ ] 2.12 Declare ABI v1 FROZEN: comment in `jac-bridge-schema` + doc note; any
      future need = payload-format evolution inside TAG_WIDE, never new tags.

### Phase 3 -- py-interop tier (parallel track; start any time after 0.6)

- [ ] 3.0 Spike (timebox 1 wk): 4 new forwarders in `jac/launcher/pyembed.zig`
      (`jpy_PyImport_ImportModule`, `jpy_PyObject_CallMethod`,
      `jpy_PyBytes_FromStringAndSize`, `jpy_PyBytes_AsStringAndSize`); na program
      boots `jac_engine_boot()`, imports orjson (pip-installed into the
      materialized rt site by hand), JSON round-trip + one polars
      `read_csv`/`shape`; trailer-append via the `_bundle_runtime` snippet +
      patchelf `$ORIGIN`; run on a pythonless machine; measure scalar-call
      latency (<2 µs target). GO/NO-GO gate for the rest of the phase.
- [ ] 3.1 `jac/launcher/pyinterop.zig`: high-level surface (~15 fns) --
      `jac_py_import/getattr/call/from_*/to_*/decref` using jac-bridge
      status-code + JacBuf conventions; args to `jac_py_call` as a msgpack
      payload (reuse the Phase-2 wire format; Python-side decode helper in the
      shim bootstrap). Keep the `jpy_` prefix discipline; all dlopen/dlsym stays
      in the shim.
- [ ] 3.2 `jaclang/runtimelib/.../python.na.jac`: `PyObj` with `__del__` decref;
      scalar/str/bytes conversions; lists/dicts as opaque PyObj + indexer
      helpers; GIL ensure/release per call; main-thread-only documented; make
      `install_signal_handlers` configurable in `InitOpts` (embed.zig
      `initInterpreter`).
- [ ] 3.3 `jac bundle --target binary --with-py-interop` (`project.impl.jac`):
      existing `_bundle_binary` flow + `pip install --only-binary=:all:
      --target stage/site <wheels>` + slim-payload filter (drop site/jaclang +
      pytest; keep libpython + zipped stdlib + wheels) + `_stage_pyembed_shim` +
      patchelf. FIX FIRST: the known exec-bit-drop in payload pack/materialize
      (wheels ship .so files).
- [ ] 3.4 `jac add py:<pkg>` + `[py-interop]` jac.toml stanza mirroring
      `[rust-bridges]`; host-platform-only in v1, documented.
- [ ] 3.5 Acceptance: an na binary doing a polars groupby, shipped to a machine
      with no Python; flagship-wheel smoke tests (orjson, polars, cryptography)
      in a CI job; docs section positioning rust: (performance) vs py: (variety).

### Phase 4 -- Productionization backlog (post-lanes, order by demand)

- [ ] Registry seeded from CI matrix (5 corpus crates + the serde fixture crate).
- [ ] Dogfood app: ≥2 rust bridges + py tier under `nacompile` + `jac bundle`.
- [ ] Mach-O `__DATA,__jac_bridge` reader in `_elf.jac` (port from
      jac-bridge-inspect's Rust) -- or gate darwin out of `_finder` until done.
- [ ] `corpus.rs` asserts rustdoc `format_version`; regen procedure documented in
      `gen-fixtures.sh`.
- [ ] Registry/CLI polish: urlopen timeout; missing sha256 → warn/reject; index
      fetched once per install run; `_bundle_binary` fails on missing bridges;
      `jac remove rust:` symmetry; nightly check in `toolchain_available()`;
      crate-name `^[A-Za-z0-9_-]+$` validation.
- [ ] Docs: fold ABI-v1 limits table into `rust-bridges.md`; fix the
      `#[jac::bridge]` vs `#[jac_bridge::bridge]` inconsistency; repoint
      TYPE-MODEL-V2 references (PLAN.md, IMPLEMENTATION.md, REMAINING.md) to this
      file; drop REMAINING.md from the PR or fold it in here.
- [ ] Windows na: reassess after the above.
