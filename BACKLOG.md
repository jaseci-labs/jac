# CEF Desktop — Backlog & Optimizations

Post-release improvements deferred from PLAN.md. Shipping with `libpython` is
acceptable for the initial release.

---

## J2 — CEF vtables in Jac clib structs 🔧 READY

**Goal:** Delete `cef_shim.c` (~628 lines of C); express CEF vtables as Jac clib
structs.

**Blockers resolved (upstream main):**
- #6574 — `Callable = 0` defaults in clib struct fields ✅
- #6575 — C→Jac callback trampolines for fn-ptr fields ✅
- #6576 — Allocate clib vtable structs without RC header (flat C layout) ✅

**Next step:** Rebase onto main, rewrite vtables in `cef.na.jac`, delete C shim.

---

## J3 — Replace embedded Python loopback with Jac `na`

**Goal:** Remove `libpython` from desktop hosts. Port `oauth_broker` to `na`
using libc socket I/O. Eliminates ~30-50MB from the binary.

**Approach:** Write a minimal HTTP server in Jac `na` using raw libc sockets.
OAuth broker routes (`/__jac/oauth/start`, `/__jac/oauth/callback`) are the
minimum requirement — static serving can stay if Phase 6 lands.

---

## J4 — `sv` walkers in-process

**Goal:** Wire `sv import` to an embedded interpreter per `DESKTOP_ARCH.md`.
Depends on J3 (or a Jac runtime embed path that doesn't require libpython).

---

## J5 — Build tooling

**Goal:** Ship prebuilt `libwebview.so` per platform. Keep `fetch_libcef.sh`
(CEF is always a binary download). `gcc` only needed for one-time shim builds
until J2 eliminates them.

---

## Phase 6 — CEF Scheme Handler

**Goal:** Replace loopback TCP server for static asset serving with
`cef_register_scheme_handler_factory`, serving `jac://app/` directly from the
CEF process.

**Notes:**
- Eliminates stable port complexity and Python TCP server for static files
- OAuth broker loopback stays (needs real HTTP for system browser redirect per
  RFC 8252)
- Requires implementing `cef_resource_handler_t` — another vtable struct
- If this lands, J3 scope shrinks to OAuth-only HTTP

---

## Phase 5 Cleanup

Minor items that don't block release:
- Remove debug `cef_dist_137/` backup
- Re-extract locales from the 119 tarball (currently empty but works)
- Verify `window.__JAC_DESKTOP__` and `window.__JAC_BROKER__` are set in the JS runtime
