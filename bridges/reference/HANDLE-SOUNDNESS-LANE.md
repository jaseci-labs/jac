# Phase S -- Handle soundness lane (RC'd handles + ownership contract)

Status: TRACK A LANDED 2026-07-13. Track B BORROWED LANE LANDED 2026-07-14 -- the
`borrowed` (RC-pinned live interior view) ownership class is implemented and
verified end-to-end through the macro, ABI, and BOTH loaders, with a load-bearing
conformance test. Binder ownership classification (S.2) LANDED 2026-07-14 --
`Ownership` enum + `ret_ownership` field, the `[fn."T::m"] ownership = "…"` overlay
key, and codegen stamping `#[jac(shared|borrowed)]`, proven end-to-end by the
regex roundtrip compiling under `-D warnings`; borrowed *auto-detection* is
deliberately deferred to Phase 1.2.4 (see S.2.2). Track B COMPLETE 2026-07-14 --
the `shared`/self-identity loader wrappers (S.4.1/S.4.3) landed in both loaders
(inert until a Phase 1.2.4 producer emits such a return; the macro boxes every
return fresh today, so Arc-sharing is already sound under `owned` and no producer
exists yet -- the plumbing is here so it is sound the moment one does), pinned by
`test_shared_identity_retain.jac`; and the skip-with-reason contract (S.5.2/S.6.4)
landed as an overlay `reason` key that records a deliberately-refused method as a
VISIBLE skip carrying the author's rationale (fixing the prior silent `skip = true`
removal), pinned by the new binder overlay tests. Sequenced BEFORE Phase 1 (user decision 2026-07-13):
settle the handle ABI before Phase 1 lands more surface on it. Closes the
deferred aliasing double-free (`aliasing_conformance.jac` test 3, DEMONSTRATED
2026-07-11) and adds the ownership-contract metadata the "specialized bridge"
vision requires (owned / shared / borrowed).

### Progress snapshot (2026-07-14, borrowed lane)

DONE and verified end-to-end (release build + na probes + ctypes probes + macro
trybuild/blob tests all green):

- **Design lock (S.0.3):** the per-type `retain` symbol is `jac_<mod>_<T>_retain`
  and both loaders derive it from the frozen `_drop` suffix (`_retain_sym_for` /
  `_opaque_retains`) -- no separate naming-table entry needed.
- **Macro annotation (S.1.4, tag half):** `#[jac(owned|shared|borrowed)]` helper
  attribute on a bridge method → `Ownership` on `FnDef` → OR'd into the `Ref`
  return tag in the blob (owned = 0, byte-identical v1). Stripped before re-emit.
  Misplacement (non-handle return, borrowed without `&self`, unknown key) is a
  spanned compile error (two new trybuild UI tests). A guards.rs blob test pins
  that exactly the `#[jac(borrowed)]` method carries `TAG_BORROW_BIT` and the
  ctor's `-> Self` stays owned.
- **Loader borrowed wrapper (S.4.2 + S.4.4):** the na loader (`_synth.jac`) mints
  a borrowed view via a two-arg `init(raw, owner)` ctor that `retain`s the owner
  and stores its handle; `close()` calls the owner's drop (a decref under Track A)
  to release the RC-pin. Mirrored slot-for-slot in the ctypes loader
  (`_ctypes_codegen.jac`): `_call` retains the owner on a borrowed return and
  `close()` releases it. `Slot.is_shared`/`is_borrowed` added to `_marshal.jac`.
- **Fixture (new `jac-bridge-view` crate):** `Doc` (heap `i64`) + `Peek` (raw
  interior pointer); `Doc::peek` is `#[jac(borrowed)]`. The raw pointer makes the
  owner-retain LOAD-BEARING -- a de-retained build reads garbage, verified
  out-of-band.
- **Conformance (S.6.3):** `borrowed_conformance.jac` -- close the owner while a
  view is live (view still reads the mutated value; freed exactly once), view-first
  close (owner stays usable), and idempotent double-close.
- **Latent bugs fixed en route:** `pass;` is invalid Jac (parses as a bare name,
  runtime `NameError`) -- it sat un-exercised in `_synth.jac`/`_ctypes_codegen.jac`
  until the fixture's first `void`-returning method (`Doc::set`) hit it; and
  `_ret_ann` mis-annotated a `void` return as `dict[str,int]` because `TAG_VOID`
  (all bits set) false-matched `tag_is_map`. Both fixed with a `void` guard.

Two-loop parity note: the na path is the ship bar; the ctypes path is validated by
a direct `build_module` probe (both read `9` after the owner closes).

### Progress snapshot (2026-07-13)

DONE and verified end-to-end (release build + na probes green):

- S.1 Track A -- `JacHandle<T>.rc: AtomicUsize`, per-type `retain` shim,
  decref-and-free-at-zero drop shim, Send note. Backward compatible (rc init 1 →
  every existing single-owner handle still frees exactly once). Workspace builds,
  `jac-bridge` guards + trybuild UI tests pass.
- S.0.2 / S.3.1 / S.3.2 -- `TAG_SHARED_BIT` (0x0800_0000) + `TAG_BORROW_BIT`
  (0x0400_0000) in the Rust schema and the Jac `_blob.jac` mirror; `tag_ref_index`
  now strips the ownership bits and `tag_is_shared`/`tag_is_borrowed` predicates
  added; `test_abi_drift.jac` extended to pin both constants.
- S.5.1 -- reentrant reference crate rewritten from the `usize`-smuggled double-own
  to a genuinely shared `Arc<Mutex<i64>>` inner (`alias` clones the `Arc`).
- S.6.1 -- test 3 flipped from asserting a crash to asserting a clean
  `["5","survived"]`.
- S.6.2 -- new test 4: shared alias outlives its closed originator (mutates to 11)
  and double-close is idempotent.
- S.7.1 / S.7.2 -- risk register row flipped to RESOLVED; `rust-bridges.md`
  documents the owned/shared/borrowed contract + skip-with-reason for unsound
  aliasing / mutable interior views.

REMAINING (Track B -- binder-coupled, needs a design decision + corpus verification):

- S.0.3 -- add the `retain` symbol name to the naming table in `_marshal.jac`
  (the retain shims exist in Rust; the loaders don't call them yet).
- S.1.4 (shared/borrowed return arms) -- the `#[bridge]` macro must learn a
  per-method ownership annotation the binder emits (the plan assumes binder
  metadata reaches the macro; the concrete annotation SYNTAX is unspecified and
  is the open design decision).
- S.2 -- DONE 2026-07-14 (this list is the older 2026-07-13 snapshot; see the
  2026-07-14 progress snapshot and the S.2 section for the landed detail). Binder
  `Ownership` enum + `ret_ownership` field, `classify_return` default-Owned,
  `[fn."T::m"] ownership` overlay key, codegen stamps `#[jac(shared|borrowed)]`.
  `coverage-baseline.toml` byte-identical before/after; borrowed auto-detection
  gated conservatively = deferred to Phase 1.2.4.
- S.4.1 / S.4.3 -- loader `shared`/self-identity wrappers + self/identity
  retain (borrowed S.4.2/S.4.4 landed), mirrored in `_synth.jac`/`_ctypes_codegen.jac`.
- S.5.2 / S.6.4 -- separate unsound-crate fixture + binder skip-visibility test.
- S.6.3 -- borrowed-view RC-pin test.

Note on why test 3 flips without Track B: the rewritten fixture uses a Rust-level
`Arc` (so `alias` is `owned` at the ABI -- a fresh box over an Arc-cloned inner),
which is sufficient to make the double-free go away. Track A's handle-box RC is a
complementary, orthogonal fix for the identity/`Self`-return and copied-handle
classes; the shared/borrowed ABI bits are reserved for the binder-generated
identity/interior-view returns Track B will emit.

## The load-bearing finding (read first)

The reentrant reference crate's aliasing hazard is **Rust-level unsoundness, not a
handle-ABI gap**. `Cell` and `CellAlias` are two distinct Rust types, each boxed in
its own `JacHandle<T>`, that both own the SAME `Box<i64>` smuggled through a
`usize` (`jac-bridge-reentrant/src/lib.rs:52-64,140-160`). The double-free happens
in the inner `i64`'s `Drop`, which is invisible to any handle-table bookkeeping:

- **RC'ing the `JacHandle` box does not help** -- the two wrappers hold two different
  boxes, so their refcounts are independent.
- **A generation/epoch check does not help** -- closing the `Cell`'s slot cannot bump
  the `CellAlias`'s slot generation; they are different slots.

Therefore this lane does TWO complementary things and is honest about which defends
what:

- **Track A -- RC'd handles.** Fixes the class where two wrappers share ONE handle
  box: identity/`Self` returns, a user copying a handle integer, and an
  *honestly*-shared alias (same inner object, one RC). `close()` becomes "drop my
  reference"; the inner object is freed only at rc==0.
- **Track B -- ownership contract.** Classifies every handle return as `owned` /
  `shared` / `borrowed`, so borrowed views retain (RC-pin) their owner and shared views refcount.
  For a crate whose API is unsound at the Rust level (the current `Cell::alias`),
  the correct disposition is **skip-with-reason**, not a fake defense. The reentrant
  fixture is rewritten (S.5) to an honestly-shareable shape so RC can make it sound
  and test 3 can flip.

ABI stays **append-only** over frozen v1 (new high-bit return tags + a new per-type
`retain` symbol); no `ABI_VERSION` bump required.

---

## S.0 -- Design lock (do first, no code)

- [ ] S.0.1 Define the three ownership classes and their loader-side contract:
  - `owned` (default, = today's behavior): wrapper owns the object; `close()` drops
    it; safe to `close()` exactly once.
  - `shared`: wrapper holds one reference on an RC'd inner; adopting/aliasing
    `retain`s; `close()` decrefs; inner freed at rc==0; double-close is idempotent.
  - `borrowed` (**DECIDED 2026-07-13 -- live, RC-pinned view**): a non-owning LIVE
    view into an owner's interior. Minting a view `retain`s the owner handle
    (rc+1); the view reads through a live pointer into the owner's stable
    allocation (stable because the owner's box can't be freed while rc>0). The
    owner physically cannot reach rc==0 while any view is live, so the view is
    ALWAYS valid -- no `__valid` flag, no owner-walk-on-close, no invalidation
    graph. Dropping the view `release`s the owner (rc-1); reads observe live owner
    state, zero-copy. Reuses the SAME `rc`/`retain` primitive as `shared`
    (S.0.3/S.1.2) -- borrowed is nearly free once Track A lands.
    - **Why NOT snapshot (eager copy) -- rejected on evidence.** serde_json `Value`
      is a non-`Copy` recursive enum: `get(&self)->Option<&Value>`, `pointer`,
      `as_object->Option<&Map>`, `as_array->Option<&Vec>` -- snapshot deep-clones the
      subtree on every access. ndarray's whole API is zero-copy views (`view`,
      `slice`, `row`, `as_slice->Option<&[A]>`) -- snapshot defeats the crate's
      purpose. So snapshot is a non-starter as a production foundation, not merely
      a "simpler v1". The original S.0.1 framing (lazy-invalidation graph vs
      snapshot) was a false dichotomy; RC-pinning is both simpler than the graph
      and sounder than snapshot.
    - **`&mut Field` interior views are NOT bridged** (serde_json `get_mut`,
      ndarray `view_mut`/`as_slice_mut`): they alias the owner handle's exclusive
      borrow → Rust UB. Disposition is **skip-with-reason** (or a future
      RefCell-style runtime latch), never snapshot (a copy can't be mutated
      through). The `&mut Self` builder chain (regex) is a different shape -- an
      identity/shared return (S.4.3), not an interior view, and IS bridged.
- [x] S.0.2 Encoding decision (recommend append-only high bits, NOT an `ABI_VERSION`
  bump): `TAG_SHARED_BIT = 0x0800_0000`, `TAG_BORROW_BIT = 0x0400_0000` OR'd into a
  `Ref` return tag. Default (neither bit) = `owned`. Verify no collision with the
  existing high bits (REF `0x8000`, OPT `0x4000`, MAP `0x2000`, LIST `0x1000` <<16).
- [x] S.0.3 New per-type runtime symbol name: `jac_<module>_<Type>_retain(handle)`.
  Both loaders derive it from the drop-sym's frozen `_drop` suffix
  (`_retain_sym_for` in `_synth.jac`, the `_retain` swap in `_ctypes_codegen.jac`),
  so no separate naming-table constructor is needed.

---

## S.1 -- Rust runtime: RC the handle box (`bridges/jac-bridge/src/lib.rs`)

- [x] S.1.1 `JacHandle<T>` (lib.rs:673-683): add `rc: AtomicUsize` (init 1) beside
  the existing `busy: AtomicBool`. `#[repr(C)]` field order is ABI -- append `rc`
  after `value` is unsafe for existing blobs, but the handle struct never crosses
  the wire as bytes (only its pointer does), so field order is internal; still,
  keep `busy` first to preserve the `&(*p).busy` offset math the shims rely on
  (lib.rs:1134). Put `rc` last.
- [x] S.1.2 New retain shim per opaque type -- mirror the drop-shim loop
  (lib.rs:874-889): `jac_<mod>_<T>_retain(handle: u64)` → if `handle != 0`,
  `(*(handle as *const JacHandle<T>)).rc.fetch_add(1, Relaxed)`.
- [x] S.1.3 Rewrite the drop shim (lib.rs:882-887) from unconditional
  `Box::from_raw(...)` drop to decref-and-free-at-zero:
  `if rc.fetch_sub(1, Release) == 1 { fence(Acquire); drop(Box::from_raw(...)); }`.
  This is the whole RC fix; verify the identity/`Self`-return double-release class
  (Phase 0 0.1.3(a)) is now redundant at this layer.
- [x] S.1.4 Ownership annotation + tag emission. The macro learns a per-method
  `#[jac(owned|shared|borrowed)]` helper attribute (`parse_ownership`), carries it
  on `FnDef`, and ORs `TAG_SHARED_BIT`/`TAG_BORROW_BIT` into the `Ref` return tag
  in `build_blob`. Owned stays byte-identical (no bit). The **shim body** is
  deliberately UNCHANGED (still `Box::into_raw(JacHandle::new(val))`): the RC-pin
  is performed loader-side (S.4.2) by retaining the owner on adopt, which is
  simpler and sound because the view value carries its own interior pointer. A
  future macro-synthesized zero-copy arm (returning a pointer into the owner's
  allocation directly) can build on the same `retain` primitive but is not needed
  for the read-only interior-view case landed here.
- [x] S.1.5 Update the `Send` assertion note (lib.rs:856-867): `AtomicUsize` is
  `Send + Sync`, so `JacHandle<T>: Send iff T: Send` still holds; document the added
  field in the comment.

## S.2 -- Binder: ownership classification (`bridges/jac-bridge-binder/src/`)

- [x] S.2.1 `types.rs`: `enum Ownership { Owned, Shared, Borrowed }` (`#[default]
  Owned`); `ret_ownership: Ownership` on `BridgeFn`. All ~13 construction sites
  (real classify + synthesized owning-wrapper readers + test helpers) default to
  `Owned` -- owning wrappers own their data, so `Owned` is correct for every one.
- [x] S.2.2 **Overlay-driven force + default `Owned` -- DONE. Auto-detection of
  `borrowed` from a receiver lifetime is DEFERRED to Phase 1.2.4 (rationale below).**
  `classify_return` defaults every handle return to `Owned` (correct for honest
  crates: `NaiveDate::and_time -> NaiveDateTime` is a FRESH object; every M4
  owning-wrapper return owns its buffer). A new `[fn."T::m"] ownership =
  "owned"|"shared"|"borrowed"` overlay key (`FnOverlay.ownership`, `deny_unknown_fields`
  so a typo fails loud) forces the class where rustdoc cannot prove it; it is
  exclusive with `skip` (no return to classify) and `treat_as` (return shape
  decided at classify time), validated in `apply_overlay`. Documented in the
  `Ownership` doc-comment that Rust-level-unsound double-owns are NOT inferred --
  they are the crate author's bug, handled by skip-with-reason + the overlay.
  - **Why auto-detection is deferred, not implemented now:** a borrowed return is
    one whose lifetime is bound to `&self` (`&self -> &Field`). Today EVERY such
    return is a `SkipReason::LifetimeBorrow` skip -- no bridged handle return
    carries a receiver lifetime until Phase 1.2.4's ref-lane generalization
    (cross-type / `Option<T>` handle returns) makes them bridgeable. Adding the
    detection now would be dead, untestable code firing on nothing in the corpus
    (and risking a baseline move). The plan's own sequencing note already says
    "Phase 1's ref-lane generalization (1.2.4) inherits the ownership tag for
    free -- do S before 1.2.4": S provides the plumbing (enum + field + overlay +
    codegen), 1.2.4 provides the producer and wires `ret_ownership = Borrowed` at
    the point a receiver-bound ref first becomes a bridged handle return.
- [x] S.2.3 `codegen.rs`: **stamps `#[jac(shared)]`/`#[jac(borrowed)]` on the
  non-`Owned` method** (empty for `Owned` → byte-identical pre-Phase-S output).
  The macro (S.1.4, landed) consumes the attribute and ORs
  `TAG_SHARED_BIT`/`TAG_BORROW_BIT` into the `Ref` return tag, and already emits
  the per-type `retain` shim unconditionally (Track A), so the binder does not
  emit tags/retain-symbols directly -- the layering is binder-emits-attr →
  macro-emits-tag+retain. The borrowed loader wrapper (retain-owner-on-mint,
  release-on-close) is S.4.2, already landed. **Verified under `-D warnings`:**
  `roundtrip.rs` forces `[fn."Regex::find"] ownership = "borrowed"` on the real
  regex fixture and the generated cdylib compiles warning-clean through the macro,
  with the attribute pinned immediately above `pub fn find`.

## S.3 -- Schema mirror (`bridges/jac-bridge-schema/src/lib.rs` + loader)

- [x] S.3.1 Add `TAG_SHARED_BIT` / `TAG_BORROW_BIT` constants with doc comments in
  the append-only-evolution style of the existing bits (schema/src/lib.rs:38-53).
- [x] S.3.2 Mirror both in `jac/jaclang/compiler/rust_bridge/_blob.jac`; extend
  `bridges/jac-bridge-loader/tests/test_abi_drift.jac` to assert the new constants
  match across the Rust source and the Jac parser.

## S.4 -- Loaders: ownership-aware wrappers (`_synth.jac`, `_ctypes_codegen.jac`)

- [x] S.4.1 `_synth.jac` (landed 2026-07-14): a `shared` (TAG_SHARED_BIT) method
  return calls `jac_<mod>_<T>_retain(rh)` UNCONDITIONALLY on adopt so each wrapper
  is an independent RC owner; `close()` calls the drop-sym (now a decref). The
  retain shim is declared in the import block via `_retain_targets` (shared +
  self-identity targets, merged with the borrowed owners). Mirrored in
  `_ctypes_codegen._call` (S.4.4). Emission pinned by
  `test_shared_identity_retain.jac`. INERT until a producer emits a shared return
  (the macro boxes every return fresh today; Arc-sharing is already sound under
  `owned`, so forcing `shared` on a fresh box would leak -- there is deliberately
  no producer until Phase 1.2.4).
- [x] S.4.2 `borrowed` wrapper (RC-pinned live view, per S.0.1): the wrapper holds
  a RETAINED ref to its owner handle (the `&self` receiver, marked by the binder).
  The adopt/init path calls `jac_<mod>_<T>_retain(owner_raw)`. `close()` calls the
  owner's drop-sym -- which under Track A is now a DECREF, so it never frees the
  viewed field, only releases the owner retain. NO `__valid` field, NO per-method
  validity guard, NO owner-walks-its-borrows graph: validity is guaranteed by
  rc>0 (the owner cannot reach 0 while a view is live). The owner's own `close()`
  is the same decref, so closing the owner first simply defers the actual free to
  the last view's release.
- [x] S.4.3 Self/identity returns (landed 2026-07-14): a method whose return type
  is the receiver's OWN type emits a runtime guard `if rh == self.__handle {
  <retain>(rh); }` before adopt, so a return that hands back the receiver's own box
  becomes an independent RC owner instead of a naked second owner. A fresh-box
  return (the common case) skips the retain, so existing fixtures stay
  byte-identical (the guard never fires today). Mirrored in `_ctypes_codegen._call`
  as `elif self_h is not None and h == self_h { own_retain(h); }`.
- [x] S.4.4 Mirror in `_ctypes_codegen.jac` -- the borrowed, shared, AND
  self-identity paths are all mirrored in `_call` (`_opaque_retains` wiring for
  every opaque type; `tag_is_shared`/`h == self_h` guards next to the borrowed
  owner-retain block).

## S.5 -- Rewrite the reentrant fixture to an honestly-shareable shape

`bridges/jac-bridge-reentrant/src/lib.rs`

- [x] S.5.1 Replace the `usize`-smuggled double-own with genuine shared ownership:
  `Cell` holds the inner counter behind an RC'd, `Send` cell (e.g.
  `Arc<Mutex<i64>>` or an RC'd `JacHandle` shared by both wrappers). `alias` returns
  a `shared` handle over the SAME inner -- so RC (S.1) makes closing either wrapper
  safe, and test 3 flips to a clean result.
- [x] S.5.2 Landed 2026-07-14 as the overlay **`reason`** capability rather than a
  synthetic corpus crate (user decision): the binder cannot auto-detect Rust-level
  unsoundness, so the refusal is author-driven via `[fn."T::m"] skip = true,
  reason = "…"`. The prior `skip = true` REMOVED the method silently (a
  coverage-honesty gap); it now records a VISIBLE `SkipReason::OverlaySkip(reason)`
  and the reason surfaces verbatim in `report()`. `reason` requires `skip` and is
  exclusive with `treat_as`. A full synthetic rustdoc-JSON crate was rejected as
  heavyweight ceremony -- the overlay-skip mechanism and its coverage-visibility
  were already proven against the regex fixture; the new capability is the missing
  author-supplied rationale the docs' "skipped with a reason" promise required.

## S.6 -- Flip / extend conformance (`aliasing_conformance.jac`)

- [x] S.6.1 Test 3 (lines 132-157): flip from `assert crashed` to expecting a clean,
  caught Jac exception / correct value, per the comment at 128-130. Requires
  S.1+S.4+S.5.
- [x] S.6.2 New test: `shared` alias survives independent `close()` of the
  originator (RC keeps inner alive); double-close is idempotent; both `__del__`s run
  without abort.
- [x] S.6.3 New test: a `borrowed` view RC-PINS its owner -- closing the owner
  while a view is live does NOT free it (owner `close()` is just a decref); the
  view stays valid and readable until the view itself is closed; the underlying
  object is freed exactly once when rc hits 0. Landed as
  `borrowed_conformance.jac` against the new `jac-bridge-view` fixture, with the
  retain proven load-bearing (de-retained build reads garbage). (The old "view
  raises after owner closes" spec is unreachable under RC-pinning -- the owner
  can't close past a live view.)
- [x] S.6.4 Landed 2026-07-14: skip-visibility tests in the binder suite
  (`src/tests/overlay_regex.rs`): `skip_with_reason_is_recorded_and_visible_in_the_report`
  (skip + reason -> visible `OverlaySkip(Some(reason))` in `spec.skips` and the
  reason verbatim in `report()`), `skip_without_reason_still_records_a_visible_skip`
  (the honesty fix -- a reasonless skip is still recorded), and the two validation
  guards (`reason` requires `skip`; `reason` is exclusive with `treat_as`).

## S.7 -- Docs + risk register

- [x] S.7.1 `FFI-LANES-PLAN.md` risk register: update the DEMONSTRATED aliasing row
  and Part IV -- aliasing moves from "deferred, undefended" to "owned/shared/borrowed
  contract; unsound crates skipped". Note test 3 flipped.
- [x] S.7.2 `docs/.../rust-bridges.md`: document the ownership contract (owned =
  default transfers ownership; shared = RC; borrowed = live interior view that retains (RC-pins) its owner; mutable `&Field` interior aliases are skip-with-reason), the
  overlay keys, and the explicit statement that Rust-level-unsound aliasing APIs are
  skipped, not defended.

---

## Sequencing note

S.0 → S.1/S.3 (Rust + schema) → S.2 (binder) → S.4 (loaders) → S.5 (fixture) →
S.6 (tests) → S.7 (docs). S.5 can start in parallel with S.1 (it only needs the
retain-symbol name from S.0.3). After this lane, Phase 1's ref-lane generalization
(1.2.4, cross-type / `Option<T>` handle returns) inherits the ownership tag for
free -- do S before 1.2.4.

## Local dev reminders (from the plan)

- na tests: `JAC_LLVM_SHIM=<worktree>/jac/zig-out/lib/libjacllvm.so` +
  `PYTHONPATH=<worktree>/jac`; single-process `jaclang run` probes, not `jac test`
  (OOMs on xdist).
- A `.impl.jac`-only edit does not bust the bytecode cache -- touch the decl.
- Nothing in jac0core may import the compiler's `rust_bridge` package (bootstrap
  cycle).
