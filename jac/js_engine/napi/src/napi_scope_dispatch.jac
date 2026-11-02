"""Scope-op sub-dispatcher for NAPI handle scopes.

Op assignments (matches napi_dispatch.na.jac):
  1 = NAPI_OP_OPEN_HANDLE_SCOPE
  2 = NAPI_OP_CLOSE_HANDLE_SCOPE
  3 = NAPI_OP_OPEN_ESCAPABLE_HANDLE_SCOPE
  4 = NAPI_OP_CLOSE_ESCAPABLE_HANDLE_SCOPE
  5 = NAPI_OP_ESCAPE_HANDLE
"""

import from "libjs_native.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;
}

import from napi.src.napi_ops {
    NAPI_OP_OPEN_HANDLE_SCOPE,
    NAPI_OP_CLOSE_HANDLE_SCOPE,
    NAPI_OP_OPEN_ESCAPABLE_HANDLE_SCOPE,
    NAPI_OP_CLOSE_ESCAPABLE_HANDLE_SCOPE,
    NAPI_OP_ESCAPE_HANDLE,
    NAPI_OK
}

glob _SCOPE_DEPTH: int = 0;

"""napi_open_handle_scope: argv[0]=env, argv[1]=napi_handle_scope* out."""
def:pub _h_open_scope(argv: int) -> int {
    scope_out: int = _napi_argv_i64(argv, 1);
    _SCOPE_DEPTH = _SCOPE_DEPTH + 1;
    _napi_write_i64(scope_out, _SCOPE_DEPTH);  # non-NULL sentinel
    return NAPI_OK;
}

"""napi_close_handle_scope: argv[0]=env, argv[1]=scope (opaque sentinel)."""
def:pub _h_close_scope(argv: int) -> int {
    if _SCOPE_DEPTH > 0 {
        _SCOPE_DEPTH = _SCOPE_DEPTH - 1;
    }
    return NAPI_OK;
}

"""napi_open_escapable_handle_scope: same as open but marks as escapable."""
def:pub _h_open_esc_scope(argv: int) -> int {
    scope_out: int = _napi_argv_i64(argv, 1);
    _SCOPE_DEPTH = _SCOPE_DEPTH + 1;
    # OR in a high bit to distinguish escapable scopes from regular ones.
    _napi_write_i64(scope_out, 0x40000000 | _SCOPE_DEPTH);
    return NAPI_OK;
}

"""napi_close_escapable_handle_scope."""
def:pub _h_close_esc_scope(argv: int) -> int {
    if _SCOPE_DEPTH > 0 {
        _SCOPE_DEPTH = _SCOPE_DEPTH - 1;
    }
    return NAPI_OK;
}

"""napi_escape_handle: argv[0]=env, argv[1]=scope, argv[2]=escapee, argv[3]=result*.
Identity: copy the escapee napi_value straight to *result."""
def:pub _h_escape_handle(argv: int) -> int {
    escapee: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    _napi_write_i64(result_ptr, escapee);
    return NAPI_OK;
}

"""Scope sub-dispatcher — routes ops 1–5 to the handlers above."""
def:pub _dispatch_scope(op: int, argv: int) -> int {
    if op == NAPI_OP_OPEN_HANDLE_SCOPE {
        return _h_open_scope(argv);
    } elif op == NAPI_OP_CLOSE_HANDLE_SCOPE {
        return _h_close_scope(argv);
    } elif op == NAPI_OP_OPEN_ESCAPABLE_HANDLE_SCOPE {
        return _h_open_esc_scope(argv);
    } elif op == NAPI_OP_CLOSE_ESCAPABLE_HANDLE_SCOPE {
        return _h_close_esc_scope(argv);
    } elif op == NAPI_OP_ESCAPE_HANDLE {
        return _h_escape_handle(argv);
    }
    return NAPI_OK;
}
