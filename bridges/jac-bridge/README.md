# jac-bridge (proc-macro)

`#[jac_bridge::bridge(module = "…")]` generates the C-ABI shims and the D2
metadata blob from an annotated Rust `impl` block. See the crate docs for the ABI
conventions; this README records the Phase-0 handle-soundness guards and how the
generated handle layout diverges from the frozen M0 reference vectors.

## Handle layout (0.2.2) -- divergence from the hand-written M0 crates

Macro-generated bridges wrap every opaque handle in

```rust
#[repr(C)]
pub struct JacHandle<T> {
    pub busy: AtomicBool, // reentrancy latch
    pub value: T,
}
```

A handle crossing the boundary is `Box::into_raw(Box::new(JacHandle::new(val)))`,
not `Box::into_raw(Box::new(val))`. The hand-written M0 reference vectors
(`jac-bridge-regex`, and the frozen `jac-bridge-owning*` / `jac-bridge-reentrant`
sources) mint a bare `Box<T>`. This is safe because the loader treats a handle as
an opaque `u64` and each crate mints, dereferences, and drops its own handles -- the
layout never crosses between a macro crate and an M0 crate -- but it means the raw
handle integer from a macro bridge points at a `JacHandle<T>`, not a `T`. The M0
crates are frozen reference vectors and are intentionally **not** updated to match.

## Guards emitted by the macro

- **0.2.2 reentrancy guard** -- each `&mut self` shim try-locks the handle's `busy`
  latch (`BusyGuard::try_acquire`) before forming the exclusive borrow. A busy
  handle returns status 1 with `"object already in use (reentrant call)"`. The
  latch releases on drop, including on unwind. `&self`-only shims skip the latch.
  `busy` and `value` are accessed through disjoint raw-pointer field projections
  so the shared latch borrow and the exclusive value borrow never alias.

- **0.2.1 null-handle guard** -- method shims and the `error_message` / `panic_message`
  shims return status 1 with `"null handle (use after close?)"` on a raw handle of
  0 instead of dereferencing null (defense-in-depth for the aliasing use-after-close
  path the synthesized Jac wrapper cannot catch).

- **0.2.3 boundary-size guard** -- `string_to_jacbuf` / `vec_to_jacbuf` assert
  `len <= u32::MAX && cap <= u32::MAX`; a >4 GiB buffer panics into the status-2
  path rather than truncating the length and later freeing the wrong extent.

- **0.2.4 attribute validation** -- an unknown key in `#[bridge(...)]` is a spanned
  compile error (`expected 'module'`), not a silent fallback to the default module
  name.

- **0.2.5 panic message** -- the shared `catch_unwind` wrapper downcasts the panic
  payload (`&str` / `String`) so the Jac-side exception carries the real message.

- **0.2.6 strict callback UTF-8** -- the callback return path validates bytes with
  `str::from_utf8` (matching the param-side discipline) instead of
  `from_utf8_lossy`; invalid UTF-8 becomes a callback error.

## TAG_FN (0.1.2, for Track A)

A `JacCallback`-typed param is tagged `schema::TAG_FN` in the emitted param descs
(`Tag::Callback => TAG_FN`). This is universal -- driven by the param type in
`ty_to_tag`, not gated to any particular crate/vertical. Asserted on the raw blob
bytes by `tests/guards.rs::callback_param_carries_tag_fn`.

## Tests

- `tests/guards.rs` -- runtime acceptance for 0.2.2 / 0.2.1 / 0.1.2.
- `tests/compile_fail.rs` + `tests/ui/*.rs` -- trybuild rejection cases (incl.
  `unknown_attr_key` for 0.2.4).

Run with `cargo test -p jac-bridge`.
