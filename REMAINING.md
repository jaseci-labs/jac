# Rust bridges - remaining work

Living checklist for what is **not done** after the M2–M6 branch (na-first product
policy - see IMPLEMENTATION.md / PLAN.md). Updated 2026-07.

**Ship bar:** `nacompile` / `jac bundle`. CPython (`jac run`) is secondary.

---

## Before merge (housekeeping)

- [ ] Push 6 unpushed commits on `rust-ffi`
- [ ] Land uncommitted binder / synth / docs / test changes (~1.5k LOC)
- [ ] Add `docs/docs/reference/language/rust-bridges.md` to the PR (currently untracked)
- [ ] Refresh stale comments in demo crates (`jac-bridge-map`, `jac-bridge-list` still say na skips dict/list)
- [ ] PR description already updated; keep in sync if scope shifts

---

## M6 - close the milestone

| Item | Status | Notes |
|------|--------|-------|
| M6.1 na closures (`{call, ctx}`) | ✅ Done | |
| M6.2 integers + `HashMap→dict` / `Vec→list` returns | ✅ Done | flat `V ∈ {bool, int, str}` only |
| M6.3 `async fn` as blocking | ✅ Done | module-owned Tokio runtime + block_on shim (`jac-bridge-async`); CI: workspace binder tests + `test_async.jac` loader + `async_conformance.jac` na vertical |
| `Option<String>` on na | ❌ Open | `_synth.jac` skips pure `Option<str>` returns; CPython works |
| Callback `retain`/`release` | ⏸ Deferred | only when Rust **stores** a callback past the call |

---

## Production v1 (na) - ~1–2 months after merge

### Packaging & distribution

- [ ] Populate registry with real artifacts (not just regex); extend CI matrix crates as binder allows
- [ ] Document **experimental** ABI v1 limits in user-facing docs (partially in `rust-bridges.md`)
- [ ] One real app dogfood (not only conformance tests) on `nacompile` + `jac bundle`

### Binder / crates

- [ ] **2–4 seed crates with overlays** (chrono `monomorphize`, base64, …) - prove not regex-only
- [ ] **Use-site instantiation manifests** - na compiler emits concrete generic instantiations seen at call sites; local-build binder consumes them (today: hand `monomorphize` overlays only)
- [ ] ABI stability / semver policy for `abi_version` and blob format

### na platform gaps

- [ ] **Windows na** - immature; prioritize if Windows native ship matters (ctypes is not the path)
- [ ] **Static-musl binaries** - bridges require dynamic link today; document or implement staticlib path (D1.1 v2)
- [ ] Local dev ergonomics - LLVM shim (`zig build jacllvm`) is heavy; document or automate

---

## ABI v1 ceiling (honest skips until v2)

These are **not** “finish M6” items - they need TYPE-MODEL-V2 or accepted v1 limits:

| Gap | Example |
|-----|---------|
| Floats | `f32` / `f64` - macro rejects |
| Bytes | `Vec<u8>`, `&[u8]` |
| Collection **params** | pass `Vec` / `HashMap` **into** Rust |
| Nested containers | `list[list]`, `dict[str, list]` |
| Nullable scalars | `Option<bool>`, `Option<int>` |
| General callbacks | only `str→str` replacer; `replacen` still skipped |
| na callback detection | `_lambda_arg_is_callback` keys off lambda + i64 slot + `make_buf` sink, not callee `TAG_FN` (ABI v1 heuristic) |
| Tuples | non-empty |
| Struct / enum by value | opaque handles only |
| Unpinned generics | `Date<Tz>` dropped without overlay |
| Trait-object APIs | uuid 0/6, sha2 0/0 |

Reference: `bridges/reference/TYPE-MODEL-V2-PLAN.md`

---

## TYPE-MODEL-V2 (broad interop) - ~3–6 months

Clean cutover; delete v1 tag bitfield. Phases 0–7 in TYPE-MODEL-V2-PLAN.md:

0. Foundation - `jac-bridge-typemodel`, postcard metadata, shared `_marshal.jac`, re-encode existing shapes
1. Floats
2. Bytes
3. Nullable scalars / general `Option` / `Result`
4. Nested containers + collection params
5. Tuples
6. Record / Variant by value
7. Real callback signatures (`Func` / `FnSig`)

---

## Explicitly not doing

- **cl / wasm** third consumer (dropped 2026-07-03)
- **Dual-runtime parity** as a product requirement (CPython catches up when cheap)
- **Hand-authored per-crate bridges** (principle zero - binder + overlays only)

---

## Coverage floors today (binder corpus)

| Crate | Bridged | Total | Comment |
|-------|---------|-------|---------|
| regex | 31 | 84 | north-star; ~37% |
| chrono | 33 | 181 | needs overlays for `Date<Tz>` / `DateTime<Tz>` |
| base64 | 1 | 11 | |
| uuid | 0 | 6 | structural |
| sha2 | 0 | 0 | `Digest` trait aliases |

Ratchet floors in `bridges/jac-bridge-binder/tests/corpus/coverage-baseline.toml` as rules land.

---

## Suggested order

1. Merge branch (housekeeping)
2. Ship **experimental** - regex + registry + native-only docs
3. Seed crates + overlays + use-site monomorphization
4. na polish (`Option<String>`, Windows na if needed)
5. TYPE-MODEL-V2 Phase 0 when v1 ceiling blocks real users
