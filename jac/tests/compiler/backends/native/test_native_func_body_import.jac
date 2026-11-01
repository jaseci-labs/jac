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
import from tests.support {
    TESTS_DIR,
    adopt_native_units,
    compile_mir,
    compile_native,
    compile_native_refused,
    compile_native_unit,
    diagnostics_text,
    error_codes,
    native_address,
    native_force_opts,
    write_case
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
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
# module-level one is, but its owning function absorbs it (epic #8201): the
# decision step demotes the function to its Python implementation instead of
# lowering the import to a silent no-op statement -- and when native is
# required, the refusal is a structured E5092.
test "an unsupported body-scoped import demotes its function, callers stay loud" {
    source = "def use() -> int {\n"
        "    import collections;\n"
        "    d = collections.OrderedDict();\n"
        "    return len(d);\n"
        "}\n";
    fx = compile_mir(write_case(source, "_func_body_bad_import.jac"));
    assert fx.is_demoted("use") , (
        f"the function with the Python-only import must be demoted: {fx.demoted()}"
    );

    result = compile_native_refused(
        write_case(
            source + "with entry { print(use()); }\n",
            "_func_body_bad_import_caller.jac"
        ),
        "",
        CompileOptions(force_codespace="native", native_required=True)
    );
    assert "E5092" in error_codes(result) , (
        f"expected E5092 for the native caller of the demoted function, got:\n"
        f"{diagnostics_text(result)}"
    );
}

# Widening guard. Seeing body-scoped imports must not widen what gets REGISTERED:
# module-level imports keep the set they always had, and nested imports are
# harvested only from elements placed in the native context. Without the second
# half, an import nested in a server-placed element pulls its module -- and any
# C library that module declares -- onto the native link line, so the artifact
# fails to link anywhere that library is absent.
test "nested imports are harvested only from native-context elements" {
    import from jaclang.compiler.frontend.module_facts { ModuleFacts }
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    prog = JacProgram();
    # No forced codespace: the solver places this module's elements on the
    # server, so its body-scoped import is server-context.
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "clib_ctx_gated_lib.jac"),
        options=CompileOptions(no_cgen=True)
    );
    _stmts: list[any] = list(ModuleFacts.iter_context_stmts(ir));
    placements = [stmt.code_context for stmt in _stmts];
    assert CodeContext.NATIVE not in placements , (
        f"fixture no longer exercises server placement: {placements}"
    );
    assert len(ModuleFacts.iter_nested_imports(ir)) == 1 , (
        "fixture should carry exactly one body-scoped import"
    );
    assert ModuleFacts.iter_nested_imports(ir, CodeContext.NATIVE) == [] , (
        "a body-scoped import under a server-placed element must not be "
        "harvested for native registration"
    );
}

# The paired positive: when the enclosing element IS native, the body-scoped
# import resolves its module and that module's declared C library does reach the
# link set -- which is the transitive half of N8c actually working.
test "a native-context body-scoped import contributes its module's clib" {
    opts = native_force_opts();
    opts.skip_native_engine = True;
    fx = compile_native_unit(
        os.path.join(FIXTURES, "clib_ctx_gated_entry.jac"), "", opts, ["mir"]
    );
    prog = JacProgram();
    prog.options = opts;
    adopt_native_units(prog, fx.result, opts);
    # The link set is the plan's: the imported module is its own unit and its
    # declared C library rides on that unit's interface.
    import from jaclang.compiler.backends.native.link_plan { build_link_plan }
    plan = build_link_plan(prog, [fx.path], opts);
    assert any("libctxgated" in p for p in plan.clib_paths()) , (
        f"transitive body-scoped import did not contribute its clib: "
        f"{plan.clib_paths()}"
    );
}
