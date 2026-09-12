# Python source/AST -> PyCode through Jac validation, codegen and assembly.

import from jaclang.runtime.python.objects { PyObj, py_error, is_error }
import from jaclang.compiler.frontend.python.parser {
    parse_eval_expr,
    parse_file,
    parse_interactive
}
import from jaclang.compiler.frontend.python.ast_nodes {
    expr,
    mod,
    Expr,
    Expression,
    Module,
    Interactive
}
import from jaclang.compiler.frontend.python.compiler_preprocess { preprocess_node }
import from jaclang.compiler.frontend.python.compiler_validate {
    validate_eval_expr,
    validate_module_body,
    check_ast_warnings,
    future_features
}
import from jaclang.compiler.frontend.python.compiler_symtable { build_module_symtable }
import from jaclang.compiler.frontend.python.compiler_diagnostics {
    compiler_diag_to_pyobj
}
import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
    compile_eval,
    compile_exec
}
# Statement-dispatch siblings: imported for their load-time registration into
# the compiler_dispatch leaf (see compiler_dispatch.jac); without these edges
# a compile of any compound statement would call an unwired handler slot.
import from jaclang.compiler.backends.py.jacpython.compiler_defs { visit_function_def }
import from jaclang.compiler.backends.py.jacpython.compiler_exc { visit_try }
import from jaclang.compiler.backends.py.jacpython.compiler_loops { visit_if }
import from jaclang.compiler.backends.py.jacpython.compiler_match { visit_match }
import from jaclang.compiler.backends.py.jacpython.flowgraph { verify_cfg }
import from jaclang.compiler.backends.py.jacpython.assembler { assemble }
import from jaclang.compiler.backends.py.jacpython.compiler_annotations {
    stringify_future_annotations
}
import from jaclang.compiler.backends.py.jacpython.compiler_context {
    current_compile_flags,
    add_future_flags,
    enter_compile_context,
    exit_compile_context,
    ensure_compile_registries_wired,
}

def compile_source(
    source: str, filename: str, mode: str, optimize: int, flags: int = 0
) -> PyObj {
    if optimize not in (0, 1, 2) {
        return py_error("ValueError", "compile(): invalid optimize value");
    }
    reg = ensure_compile_registries_wired();
    if is_error(reg) {
        return reg;
    }
    enter_compile_context(optimize, flags);
    try {
        if mode == "eval" {
            result = compile_eval_path(source, filename, mode);
        } elif mode == "single" {
            tree = parse_interactive(source, filename, current_compile_flags());
            if tree is None {
                result = py_error("SyntaxError", "invalid syntax");
            } else {
                result = compile_exec_ast(
                    Module(body=tree.body, type_ignores=[]), filename, True
                );
            }
        } else {
            result = compile_exec_path(source, filename, mode);
        }
    } finally {
        exit_compile_context();
    }
    return result;
}

def compile_ast(
    tree: mod, filename: str, mode: str, optimize: int = 0, flags: int = 0
) -> PyObj {
    if optimize not in (0, 1, 2) {
        return py_error("ValueError", "compile(): invalid optimize value");
    }
    reg = ensure_compile_registries_wired();
    if is_error(reg) {
        return reg;
    }
    enter_compile_context(optimize, flags);
    try {
        if mode == "eval" and isinstance(tree, Expression) {
            result = compile_eval_ast(tree.body, filename);
        } elif mode == "exec" and isinstance(tree, Module) {
            result = compile_exec_ast(tree, filename);
        } elif mode == "single" and isinstance(tree, Interactive) {
            result = compile_exec_ast(
                Module(body=tree.body, type_ignores=[]), filename, True
            );
        } else {
            result = py_error("TypeError", "AST root does not match compilation mode");
        }
    } finally {
        exit_compile_context();
    }
    return result;
}

def prepare_ast_output(
    tree: mod, filename: str, optimize: int, flags: int
) -> mod | PyObj {
    if isinstance(tree, (Module, Interactive)) {
        (features, result) = future_features(tree.body, False);
        if result.diag is not None {
            return compiler_diag_to_pyobj(result.diag);
        }
        flags |= features;
    }
    return preprocess_node(tree, optimize, flags, bool(flags & 0x8000));
}

def compile_eval_path(source: str, filename: str, mode: str) -> PyObj {
    if mode != "eval" {
        return py_error(
            "NotImplementedError",
            "compile_source: mode '" + mode + "' not yet supported (Phase C)"
        );
    }
    e = parse_eval_expr(source, filename, current_compile_flags());
    if e is None {
        return py_error(
            "SyntaxError", "compile_source: failed to parse eval expression"
        );
    }
    return compile_eval_ast(e, filename);
}

def compile_eval_ast(e: expr, filename: str) -> PyObj {
    vr = validate_eval_expr(e, bool(current_compile_flags() & 0x2000));
    if vr.diag is not None {
        return compiler_diag_to_pyobj(vr.diag);
    }
    import from jaclang.compiler.backends.py.jacpython.compiler_context {
        current_optimization_level
    }
    e = preprocess_node(e, current_optimization_level(), current_compile_flags(), True);
    check_ast_warnings(e, filename);
    sr = build_module_symtable(
        [
            Expr(
                value=e,
                lineno=e.lineno,
                col_offset=e.col_offset,
                end_lineno=e.end_lineno,
                end_col_offset=e.end_col_offset
            )
        ]
    );
    if sr.diag is not None {
        return compiler_diag_to_pyobj(sr.diag);
    }
    u = compile_eval(e, filename, "<module>", 1, sr.top);
    if u.diag is not None {
        return compiler_diag_to_pyobj(u.diag);
    }
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        return compiler_diag_to_pyobj(cfg.diag);
    }
    return assemble(cfg);
}

# exec-mode native front end (PLAN.md P0.12 band 2: straight-line modules).
# parse_file -> validate -> symtable -> compile_exec -> verify_cfg -> assemble.
def compile_exec_path(source: str, filename: str, mode: str) -> PyObj {
    if mode != "exec" {
        return py_error(
            "NotImplementedError",
            "compile_source: mode '" + mode + "' not yet supported"
        );
    }
    m = parse_file(source, filename, current_compile_flags());
    if m is None {
        return py_error("SyntaxError", "compile_source: failed to parse exec module");
    }
    return compile_exec_ast(m, filename);
}

def compile_exec_ast(m: Module, filename: str, interactive: bool = False) -> PyObj {
    (features, future_result) = future_features(m.body);
    if future_result.diag is not None {
        return compiler_diag_to_pyobj(future_result.diag);
    }
    add_future_flags(features);
    vr = validate_module_body(m.body, bool(current_compile_flags() & 0x2000));
    if vr.diag is not None {
        return compiler_diag_to_pyobj(vr.diag);
    }
    import from jaclang.compiler.backends.py.jacpython.compiler_context {
        current_optimization_level
    }
    preprocess_node(m, current_optimization_level(), current_compile_flags(), True);
    check_ast_warnings(m, filename);
    sr = build_module_symtable(m.body);
    if sr.diag is not None {
        return compiler_diag_to_pyobj(sr.diag);
    }
    # Scope analysis still validates annotation expressions and their binding
    # forms before the future flag turns those expressions into strings.
    if current_compile_flags() & 0x1000000 {
        stringify_future_annotations(m, filename);
    }
    u = compile_exec(m.body, filename, "<module>", 1, sr.top, interactive);
    if u.diag is not None {
        return compiler_diag_to_pyobj(u.diag);
    }
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        return compiler_diag_to_pyobj(cfg.diag);
    }
    return assemble(cfg);
}
