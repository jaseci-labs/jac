"""
js_engine version constants.

Single source of truth for all version strings exposed via:
  process.version          → JS_ENGINE_VERSION_V      (e.g. "v0.1.0")
  process.versions.js_engine → JS_ENGINE_VERSION         (e.g. "0.1.0")
  process.versions.node    → NODE_COMPAT_VERSION      (Node.js API compat target)
  process.versions.uv      → UV_VERSION               (libuv — must match system)
  process.versions.openssl → OPENSSL_VERSION          (OpenSSL — must match system)

This file is the only place the version is defined.
Do NOT put V8, modules, napi, ares, brotli — those are
Node.js/V8 internals that have no equivalent in js_engine.
nghttp2 and llhttp ARE included because js_engine ships those libraries.
"""

# ── js_engine own version ──────────────────────────────────────────────────────
glob:pub JS_ENGINE_VERSION: str = "0.1.0",
     JS_ENGINE_VERSION_V: str = "v0.1.0",
     NODE_COMPAT_VERSION: str = "22.12.0",
     UV_VERSION: str = "1.48.0",
     OPENSSL_VERSION: str = "3.0.13",
     ZLIB_VERSION: str = "1.3",
     PCRE2_VERSION: str = "10.45",
     LLHTTP_VERSION: str = "9.4.1",
     NGHTTP2_VERSION: str = "1.59.0";
# ── Node.js API compatibility target (NOT js_engine's version) ────────────────
# The subset of the Node.js 22 API surface that js_engine targets.
# User code that checks process.versions.node will see this value.

# ── Actual runtime library versions (must match what is linked) ──────────────
# libuv  — pkg-config libuv
# OpenSSL — pkg-config openssl
# zlib   — pkg-config zlib
# PCRE2  — pkg-config libpcre2-8
# llhttp  — HTTP/1.1 parser (Phase A)
# nghttp2 — HTTP/2 (Phase D/E)
