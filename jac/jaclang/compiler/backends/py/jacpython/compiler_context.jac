# Per-compilation context stack (PLAN.md Phase 3 / #4).
#
# Holds compilation-scoped mutable state (pending_break_finishes, active flag)
# so failed or nested compiles cannot leak process-global residue. Stack slots
# use list holders for shared state; registry validation runs once before
# the first product compile.

import from jaclang.runtime.python.objects { py_error, PyObj, py_none }
import from contextvars { ContextVar }
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    pending_break_finish,
    basicblock,
    loop_frame,
}
import from jaclang.compiler.backends.py.jacpython.compiler_dispatch { stmt_handlers }

obj compile_context {
    has pending_break_finishes: list[pending_break_finish] = [],
        optimize: int = 0,
        flags: int = 0;
}

glob _compile_contexts: any = ContextVar(
         "jacpython_compile_contexts", `default=()
     ),
     _registries_validated: list[bool] = [False];

def product_compile_active -> bool {
    return bool(_compile_contexts.get());
}

def enter_compile_context(optimize: int = 0, flags: int = 0) {
    _compile_contexts.set(
        _compile_contexts.get() + (compile_context(optimize=optimize, flags=flags), )
    );
}

def current_optimization_level -> int {
    stack = _compile_contexts.get();
    return stack[-1].optimize if stack else 0;
}

def exit_compile_context {
    stack = _compile_contexts.get();
    if stack {
        _compile_contexts.set(stack[:-1]);
    }
}

def current_pending_break_finishes -> list[pending_break_finish] {
    stack = _compile_contexts.get();
    if not stack {
        return [];
    }
    return (stack[-1] as compile_context).pending_break_finishes;
}

def push_pending_break_finish(frame: loop_frame, join: basicblock, allow_nop: bool) {
    current_pending_break_finishes().append(
        pending_break_finish(frame=frame, join=join, allow_nop=allow_nop)
    );
}

def append_pending_break_finish(job: pending_break_finish) {
    current_pending_break_finishes().append(job);
}

def ensure_compile_registries_wired -> PyObj {
    if _registries_validated[0] {
        return py_none();
    }
    required_handlers = [
        "visit_if",
        "visit_while",
        "visit_for",
        "visit_async_for",
        "visit_function_def",
        "visit_async_function_def",
        "visit_class_def",
        "visit_type_alias",
        "visit_import",
        "visit_import_from",
        "visit_cleanup_stmts",
        "clear_exception_name",
        "visit_try",
        "visit_try_star",
        "visit_raise_stmt",
        "visit_with",
        "visit_async_with",
        "visit_match",
        "deferred_comp_handlers",

    ];
    hi = 0;
    while hi < len(required_handlers) {
        key = required_handlers[hi];
        if not (key in stmt_handlers) {
            return py_error(
                "RuntimeError", "compiler: stmt_handlers missing '" + key + "'"
            );
        }
        slot = stmt_handlers[key];
        if slot is None {
            return py_error(
                "RuntimeError", "compiler: stmt_handlers '" + key + "' is unwired"
            );
        }
        hi = hi + 1;
    }
    _registries_validated[0] = True;
    return py_none();
}

# Future flags belong to a compilation and are inherited by all nested code.
def current_compile_flags -> int {
    stack = _compile_contexts.get();
    return stack[-1].flags if stack else 0;
}

def add_future_flags(flags: int) {
    stack = _compile_contexts.get();
    if stack {
        stack[-1].flags |= flags;
    }
}
