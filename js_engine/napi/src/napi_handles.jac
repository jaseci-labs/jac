"""NapiHandleSlot and NapiHandleScope — handle scope tracking.

napi_value (void* on C side, int64 on Jac side) == JSValue directly.
Handle scopes are tracked by depth (no per-slot GC root tracking).

Bun reference:
  bun/src/bun.js/bindings/NapiHandleScope.h (NapiHandleScope struct).
"""

import from napi.src.napi_env { NapiEnv }

obj:pub NapiHandleSlot {
    """A single handle slot — holds one JSValue."""
    has val: int = 0;  # JSValue (int64 tagged union)
}

obj:pub NapiHandleScope {
    """One level of the handle-scope stack."""
    has prev_depth: int = 0,
        escapable: bool = False,
        escaped: bool = False;
}

# ── Scope stub operations ──────────────────────────────────────────────────────

"""Push a new handle scope onto the env's scope stack."""
def:pub napi_push_scope(env: NapiEnv, escapable: bool) -> NapiHandleScope {
    scope: NapiHandleScope = NapiHandleScope(
        prev_depth=env.scope_depth, escapable=escapable, escaped=False
    );
    env.scope_depth = env.scope_depth + 1;
    return scope;
}

"""Pop a handle scope from the env's scope stack."""
def:pub napi_pop_scope(env: NapiEnv, scope: NapiHandleScope) {
    env.scope_depth = scope.prev_depth;
}

"""Allocate a new handle slot for a JSValue.
napi_value == JSValue (no slot object needed)."""
def:pub napi_new_handle(env: NapiEnv, jsval: int) -> int {
    # napi_value == JSValue — no slot object needed.
    return jsval;
}

"""Read the JSValue from a napi_value handle (identity: the handle IS the JSValue)."""
def:pub napi_slot_value(handle: int) -> int {
    return handle;
}

# ── Scope dispatch handlers ───────────────────────────────────────────────────────────
# Called by the jump table in napi_dispatch.na.jac for ops 1–5.

import from "lib/libnapi_shim.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;
}

glob _SCOPE_DEPTH: int = 0;  # simple monotonic depth counter

"""napi_open_handle_scope: argv[0]=env, argv[1]=napi_handle_scope* out."""
def:pub _h_open_scope(argv: int) -> int {
    scope_out: int = _napi_argv_i64(argv, 1);
    _SCOPE_DEPTH = _SCOPE_DEPTH + 1;
    _napi_write_i64(scope_out, _SCOPE_DEPTH);  # non-NULL sentinel
    return 0;  # NAPI_OK
}

"""napi_close_handle_scope: argv[0]=env, argv[1]=scope (opaque sentinel)."""
def:pub _h_close_scope(argv: int) -> int {
    if _SCOPE_DEPTH > 0 {
        _SCOPE_DEPTH = _SCOPE_DEPTH - 1;
    }
    return 0;
}

"""napi_open_escapable_handle_scope: same as open but marks as escapable."""
def:pub _h_open_esc_scope(argv: int) -> int {
    scope_out: int = _napi_argv_i64(argv, 1);
    _SCOPE_DEPTH = _SCOPE_DEPTH + 1;
    # OR in a high bit to distinguish escapable scopes from regular ones.
    _napi_write_i64(scope_out, 0x40000000 | _SCOPE_DEPTH);
    return 0;
}

"""napi_close_escapable_handle_scope."""
def:pub _h_close_esc_scope(argv: int) -> int {
    if _SCOPE_DEPTH > 0 {
        _SCOPE_DEPTH = _SCOPE_DEPTH - 1;
    }
    return 0;
}

"""napi_escape_handle: argv[0]=env, argv[1]=scope, argv[2]=escapee, argv[3]=result*.
Identity: copy the escapee napi_value straight to *result."""
def:pub _h_escape_handle(argv: int) -> int {
    escapee: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    _napi_write_i64(result_ptr, escapee);
    return 0;
}

"""Scope sub-dispatcher — routes ops 1–5 to the handler above."""
def:pub _dispatch_scope(op: int, argv: int) -> int {
    if op == 1 {
        return _h_open_scope(argv);
    } elif op == 2 {
        return _h_close_scope(argv);
    } elif op == 3 {
        return _h_open_esc_scope(argv);
    } elif op == 4 {
        return _h_close_esc_scope(argv);
    } elif op == 5 {
        return _h_escape_handle(argv);
    }
    return 0;
}
