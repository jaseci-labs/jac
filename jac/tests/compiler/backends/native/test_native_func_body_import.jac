"""Function-body `import from` statements must lower on the native backend.

Roadmap item N8c of jaseci-labs/jac#7967: module-level imports lower, but an
import written inside a function body raised "Native lowering failed for
statement 'Import'" and then a cascade of "Native lowering failed for ..." for
every name the import bound. The body-scoped spelling is the house idiom for
lazy and conditional imports, so it must lower rather than merely fail
politely.

Results are compared against the sv/bytecode run of the same fixture.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support { TESTS_DIR, compile_native, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Import the fixture on the sv/bytecode pathway and hand back its module."""
def sv_module(stem: str) -> any {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(stem, None);
        return importlib.import_module(stem);
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
    }
}

test "function-body imports lower and agree with sv" {
    (eng, _) = compile_native("func_body_import.jac");
    sv = sv_module("func_body_import");
    cases = [
        "floor_half",
        "ceil_third",
        "conditional_import",
        "sibling_import",
        "sibling_type_import",
        "method_import"
    ];
    for name in cases {
        addr = native_address(eng, name);
        assert addr != 0 , f"'{name}' not found in the JIT engine";
        na_fn = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
        sv_fn = getattr(sv, name);
        for arg in [0, 9, 17] {
            assert na_fn(arg) == sv_fn(arg) , (
                f"{name}({arg}): native {na_fn(arg)} != sv {sv_fn(arg)}"
            );
        }
    }
}

# Supporting the body-scoped spelling must not smuggle unsupported modules in:
# a Python-only import written in a body is the same capability violation a
# module-level one is, but its owning function absorbs it as a granular seam
# (epic #8201): the function demotes to its Python implementation with the
# stdlib help text on the demotion diagnostic, instead of lowering to a
# silent no-op statement -- and a native caller of the demoted function is a
# structured E5092, never a silent bind to its abort stub.
test "an unsupported body-scoped import demotes its function, callers stay loud" {
    import contextlib;
    import io;
    prog = JacProgram();
    buf = io.StringIO();
    _prev = os.environ.get("JAC_NA_DEBUG");
    os.environ["JAC_NA_DEBUG"] = "1";
    try {
        with contextlib.redirect_stderr(buf) {
            ir = prog.compile(
                file_path=os.path.join(FIXTURES, "_func_body_bad_import.jac"),
                use_str="def use() -> int {\n"
                "    import collections;\n"
                "    d = collections.OrderedDict();\n"
                "    return len(d);\n"
                "}\n",
                options=native_force_opts()
            );
        }
    } finally {
        if _prev is None {
            del os.environ["JAC_NA_DEBUG"];
        } else {
            os.environ["JAC_NA_DEBUG"] = _prev;
        }
    }
    log = buf.getvalue();
    assert not prog.errors_had , f"a function-owned import violation must demote, got: {[
        str(e) for e in prog.errors_had
    ]}";
    assert ir.gen.native_layout is not None;
    assert "use" not in ir.gen.native_layout.functions , (
        "the function with the Python-only import must leave the native layout"
    );
    assert "NA_DEBUG demote use" in log , f"no demotion recorded for use in:\n{log}";
    assert "Native compilation supports these stdlib imports" in log , (
        f"the demotion diagnostic should carry the stdlib help:\n{log}"
    );

    caller = JacProgram();
    caller.compile(
        file_path=os.path.join(FIXTURES, "_func_body_bad_import_caller.jac"),
        use_str="def use() -> int {\n"
        "    import collections;\n"
        "    d = collections.OrderedDict();\n"
        "    return len(d);\n"
        "}\n"
        "with entry { print(use()); }\n",
        options=native_force_opts()
    );
    caller_codes = [
        alrt.code.code
        for alrt in caller.errors_had
        if alrt.code is not None
    ];
    assert "E5092" in caller_codes , f"expected E5092 for the native caller of the demoted function, got: {[
        str(e) for e in caller.errors_had
    ]}";
}

# Widening guard. Seeing body-scoped imports must not widen what gets REGISTERED:
# module-level imports keep the set they always had, and nested imports are
# harvested only from elements placed in the native context. Without the second
# half, an import nested in a server-placed element pulls its module -- and any
# C library that module declares -- onto the native link line, so the artifact
# fails to link anywhere that library is absent.
test "nested imports are harvested only from native-context elements" {
    import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    prog = JacProgram();
    # No forced codespace: the solver places this module's elements on the
    # server, so its body-scoped import is server-context.
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "clib_ctx_gated_lib.jac"),
        options=CompileOptions(no_cgen=True)
    );
    _stmts: list = list(ModuleCodegenPass.iter_context_stmts(ir));
    placements = [stmt.code_context for stmt in _stmts];
    assert CodeContext.NATIVE not in placements , (
        f"fixture no longer exercises server placement: {placements}"
    );
    assert len(ModuleCodegenPass.iter_nested_imports(ir)) == 1 , (
        "fixture should carry exactly one body-scoped import"
    );
    assert ModuleCodegenPass.iter_nested_imports(ir, CodeContext.NATIVE) == [] , (
        "a body-scoped import under a server-placed element must not be "
        "harvested for native registration"
    );
}

# The paired positive: when the enclosing element IS native, the body-scoped
# import resolves its module and that module's declared C library does reach the
# link set -- which is the transitive half of N8c actually working.
test "a native-context body-scoped import contributes its module's clib" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "clib_ctx_gated_entry.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {[str(e) for e in prog.errors_had]}";
    assert any("libctxgated" in p for p in ir.gen._clib_paths) , (
        f"transitive body-scoped import did not contribute its clib: "
        f"{ir.gen._clib_paths}"
    );
}
