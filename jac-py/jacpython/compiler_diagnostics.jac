# Compiler-owned diagnostics (INTEGRATION_PLAN Phase 2).
#
# Internal compiler phases record structured diagnostics here. product_compile.jac
# converts them to user-visible PyError objects at the outer seam; compiler
# internals must not use runtime py_error as control flow.

import from objects { PyObj, py_error }

obj compiler_diagnostic {}

obj parse_diagnostic(compiler_diagnostic) {
    has kind: str,
        message: str,
        filename: str,
        lineno: int = -1,
        col_offset: int = -1;
}

obj validation_diagnostic(compiler_diagnostic) {
    has kind: str,
        message: str,
        lineno: int = -1,
        col_offset: int = -1;
}

obj symbol_diagnostic(compiler_diagnostic) {
    has kind: str,
        message: str,
        lineno: int = -1,
        col_offset: int = -1;
}

obj lowering_diagnostic(compiler_diagnostic) {
    has kind: str,
        message: str,
        lineno: int = -1,
        col_offset: int = -1;
}

obj internal_compiler_diagnostic(compiler_diagnostic) {
    has kind: str,
        message: str;
}

# Product seam: compiler_diagnostic -> PyError PyObj.
def compiler_diag_to_pyobj(d: compiler_diagnostic) -> PyObj {
    if isinstance(d, parse_diagnostic) {
        p = d as parse_diagnostic;
        return py_error(p.kind, p.message);
    }
    if isinstance(d, validation_diagnostic) {
        v = d as validation_diagnostic;
        return py_error(v.kind, v.message);
    }
    if isinstance(d, symbol_diagnostic) {
        s = d as symbol_diagnostic;
        return py_error(s.kind, s.message);
    }
    if isinstance(d, lowering_diagnostic) {
        l = d as lowering_diagnostic;
        return py_error(l.kind, l.message);
    }
    if isinstance(d, internal_compiler_diagnostic) {
        i = d as internal_compiler_diagnostic;
        return py_error(i.kind, i.message);
    }
    return py_error("SystemError", "unknown compiler diagnostic");
}

# Test helpers: extract kind/message without casting through any.
def compiler_diag_kind(d: compiler_diagnostic) -> str {
    if isinstance(d, parse_diagnostic) {
        return (d as parse_diagnostic).kind;
    }
    if isinstance(d, validation_diagnostic) {
        return (d as validation_diagnostic).kind;
    }
    if isinstance(d, symbol_diagnostic) {
        return (d as symbol_diagnostic).kind;
    }
    if isinstance(d, lowering_diagnostic) {
        return (d as lowering_diagnostic).kind;
    }
    if isinstance(d, internal_compiler_diagnostic) {
        return (d as internal_compiler_diagnostic).kind;
    }
    return "";
}

def compiler_diag_message(d: compiler_diagnostic) -> str {
    if isinstance(d, parse_diagnostic) {
        return (d as parse_diagnostic).message;
    }
    if isinstance(d, validation_diagnostic) {
        return (d as validation_diagnostic).message;
    }
    if isinstance(d, symbol_diagnostic) {
        return (d as symbol_diagnostic).message;
    }
    if isinstance(d, lowering_diagnostic) {
        return (d as lowering_diagnostic).message;
    }
    if isinstance(d, internal_compiler_diagnostic) {
        return (d as internal_compiler_diagnostic).message;
    }
    return "";
}
