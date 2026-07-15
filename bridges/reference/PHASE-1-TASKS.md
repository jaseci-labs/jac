# Phase 1 -- Trait flattening + small lanes (task list)

Scope-out verified against the tree (not just the plan). Exit gate at bottom.
See `FFI-LANES-PLAN.md` for the full lane strategy and `HANDLE-SOUNDNESS-LANE.md`
for the Phase S plumbing that 1.2.4 rides on.

## Step 0 -- Reconcile tag numbering (do first, ~10 min, unblocks 1.2.x)

- [ ] **0.1** Audit live consumed scalar tags: `BOOL=1, INT=2, UINT=3, STR=4, FN=5`
      (INT/UINT/MAP/LIST landed in M6.1/M6.2 *after* the plan was written).
- [ ] **0.2** Assign `TAG_F64 = 6`, `TAG_BYTES = 7` (next free). Plan's `TAG_WIDE = 6`
      is now stale -- record that `TAG_WIDE` must move to the next free slot for Phase 2.
- [ ] **0.3** Update `test_abi_drift.jac` in lockstep so the drift test tracks the new numbers.

## Track A -- Trait flattening (sha2 is the driver)  [critical path: 1.1.1 → 1.1.2 → 1.1.5]

- [ ] **1.1.1** `trait_disposition` in `classify.rs` (~120 lines, replaces the wholesale
      `if impl_block.trait_.is_some() { continue }` at `classify.rs:478`).
      NOISE set + local vs external/blanket classification + **denominator policy**.
      ⚠ External/blanket provided-defaults are unresolvable (names only) -- they must leave
      **both** numerator and denominator, or Iterator's ~80 defaults corrupt the coverage %.
      *Blocks 1.1.3–1.1.6.*
- [ ] **1.1.2** self-alias substitution: thread `self_aliases: &[&str]` through the 4 rescue rules.
      ⚠ blanket-generic mis-substitution (sha2 `D` / `OutputSize<D>`) -- needs a hash-equivalence test.
      *Blocks 1.2.2 acceptance.*
- [ ] **1.1.3** per-type `seen_names` first-wins dedup (18 cross-trait collisions in sha2 alone).
- [ ] **1.1.4** add `via_trait: Option<String>` to `BridgeFn` (`types.rs`). *Blocks 1.1.5.*
- [ ] **1.1.5** codegen: emit `use <trait_path>;` + **add trait-crate dep to generated Cargo.toml**
      (`digest`, not just `sha2`, derived from the `via_trait` path root) + consuming-`self`
      clone-out gated on Clone-impl detection. Caught by the `-D warnings` roundtrip. *Exit-gate work.*
- [ ] **1.1.6** re-ratchet `coverage-baseline.toml` (two-sided ratchet) + determinism check.

## Track B -- Small lanes (∥ with Track A)

- [ ] **1.2.1** `TAG_F64` full vertical: schema → macro → `_blob.jac` → `_marshal.jac` → na →
      ctypes → drift test. (native na, straightforward -- warm-up vertical.)
- [ ] **1.2.2** `TAG_BYTES` `(ptr, len)` full vertical. ⚠ **NEVER strlen** -- msgpack/binary
      carries NULs (see memory `NA len strlen binary guard`). This is the sha2 acceptance carrier
      **and** the Phase-2 wide-lane carrier -- get it right once. *sha2 gate.*
- [ ] **1.2.3** `-> String` return arm in `classify.rs` (JacBuf already exists).
- [ ] **1.2.5** tuple-struct candidates in `classify_type` -- the entire uuid fix (+8). *uuid gate.*

## Track C -- Ref-lane generalization (do LAST; most de-risked by Phase S)

- [ ] **1.2.4** Generalize the Self-only ref lane to any type index.
  - [ ] Add `BridgeReturn::Ref(TypeName)` variant (`types.rs:278` -- none exists today;
        `classify_return` currently drops `-> NaiveDateTime` / `-> Option<NaiveDate>` to
        `Err(UnsupportedType)` / `LifetimeBorrow`).
  - [ ] Wire `ret_ownership` at the point the receiver-bound ref is first emitted
        (default `Owned` is correct for fresh cross-type objects like `and_time`).
  - [ ] Handle `Option<BridgedType>` and `Result<BridgedType>` (reuse existing
        `TAG_REF_BIT` / `TAG_OPT_BIT` decode -- this is "lift Self restriction to any type index,"
        not a new wire shape).
  - [ ] Loader side already adopts (Phase S: `T.__new__(T)` + external field writes +
        `_adopt(raw)` shell render/nacompile -- `jac-bridge-adopt`). Confirm both loaders, no new work expected.
  - *chrono gate.*

## Exit gate (hard numbers)

- chrono ≥ **85** bridged
- sha2 ≥ **60** usable incl. `update` / `digest` / `finalize`, proven by
  **hash-equivalence conformance on na**
- uuid ≥ **8**
- determinism: byte-identical cross-process
- every flattened method **or its skip** visible in the coverage report

## Local dev reminders

- na tests: `JAC_LLVM_SHIM=<worktree>/jac/zig-out/lib/libjacllvm.so` + `PYTHONPATH=<worktree>/jac`.
- Use single-process `jaclang run` probes -- **not `jac test`** (OOMs on xdist, standing memory).
- `.impl.jac`-only edits don't bust the bytecode cache -- touch the decl or clear `~/.cache/jac`.

## Design decisions (resolved)

### D1 -- Coverage denominator = crate's *resolvable semantic API* (global NOISE policy)

Chosen 2026-07-14. The coverage % must stay **meaningful, stable, and ratchetable** --
it is the binder's north-star and the exit gate (`chrono ≥ 85`) is measured against it.

Denominator mechanics (`coverage.rs:31`): `total = bridged + skips.len() + dropped.len()`.
Every `skips.push` is +1 denominator / +0 numerator; a `continue` is invisible to both.
So the policy is literally "for which trait methods do I push a Skip."

**Three-way disposition per trait impl (replaces the wholesale `continue` at `classify.rs:478`):**

| Class | Action | Numerator | Denominator |
| --- | --- | --- | --- |
| **NOISE** (Debug, Display, Clone, Copy, From/Into, TryFrom/TryInto, PartialEq/Eq, Ord/PartialOrd, Hash, Default, Drop, Send/Sync, Serialize/Deserialize, AsRef/AsMut, Borrow, Deref/DerefMut, Index, operators, Iterator/IntoIterator) | `continue` (as today) | -- | -- |
| **Semantic + method resolvable** (a real `Function` exists -- in `impl_block.items` **or** in a resolvable trait-def, e.g. `Datelike`, `Timelike`, `Digest`) | classify as an inherent method | if bridged | always |
| **Provided-default, trait-def unresolvable** (std `Iterator`'s ~80 blanket defaults -- name-only via `provided_trait_methods`) | skip enumeration entirely; **never push a Skip** | -- | -- |

- **Discriminator = resolvability of a `Function` in the rustdoc index**, NOT "is it in
  `impl_block.items`." sha2's `digest`/`finalize` are provided defaults on the `digest`
  crate's trait; `digest` is a direct dep so its rustdoc IS indexed → pull the `Function`
  from the **trait-definition item**. This is why 1.1.2 self-alias substitution is a hard
  prerequisite for 1.2.2 (the trait-def sig is in terms of `Self`/`Self::OutputSize`).
- **NOISE set is ONE central, versioned policy list** -- never per-crate overlay tuning
  (that would make the metric non-comparable across crates and the ratchet gameable).
- **Add `inherited_excluded: usize` to `Coverage`** -- counts the excluded unresolvable
  defaults, printed as "+N inherited defaults not considered", **excluded from `total()`/
  `pct()`**. Keeps the exclusion auditable without corrupting the ratio (the honesty
  guarantee, mirroring Phase S soundness).

### D2 -- `BridgeReturn::Ref { ty: String, opt: bool }` (1.2.4)

Engineering-determined, not a judgment call -- recorded so the rationale isn't relitigated.

- **Carry the origin type NAME, not a `types` index** -- `sort_types` runs at
  `classify.rs:84` *after* classification, so any captured index is a latent bug. Use the
  **origin** name (rustdoc names `Date`, not mono `DateUtc`; see `classify.rs:725`).
  Consistent with existing `OptWrapper(String)`/`Wrapper(String)` late-resolution.
- **No new wire shape.** Fallibility stays on `BridgeFn::throws`; nullability = `opt` →
  reuses `TAG_OPT_BIT`; handle-ness = `TAG_REF_BIT`. `Result<Option<T>,E>` = throws +
  `Ref{opt:true}`. All three axes compose.
- **Owned cross-type only.** `ret_ownership = Owned` (byte-identical, Phase S). A
  `-> &OtherType` borrow carries a lifetime → stays a `LifetimeBorrow` skip; borrowed
  cross-type is a later, harder lane.
- **Enabling plumbing:** thread a `known: HashMap<origin_name → identity>` into `Ctx`
  right after `find_types()` (`classify.rs:44`) -- it completes before any `classify_impl`,
  so the full set is available. `returns_self` only knows the current `bt`; this is what
  lets `classify_return` recognize *other* bridged types.
- **Refactor `classify_result_return` (`classify.rs:750`) to recurse** the `Ok` type
  through `classify_return` (today it hardcodes `returns_self → OwnSelfResult`); then
  `Result<OtherType,E>` and `Option<OtherType>` fall out for free.
- **Loader lift likely near-zero:** the adopt target is statically known at codegen from
  `Ref{ty}`, so codegen emits `TargetWrapper._adopt(raw)` instead of `Self._adopt(raw)`;
  the wire carries no type identity. Confirm against `codegen.rs`, but Phase S's `_adopt`
  shell is the whole runtime.

## Sequencing

1. Step 0 (tag reconciliation).
2. Track A + Track B in parallel (∥ confirmed by the plan's marker).
3. Track C (1.2.4) last -- chrono ≥ 85 depends on it landing together with 1.1.
