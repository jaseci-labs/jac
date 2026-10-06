"""Server-side use of natively-pinned module members.

`JcirGenPass.exit_import` used to drop every import whose target is a
natively pinned user module (`Import.native_only_drop`), which left the
importing server tier with no binding at all: constructing one of the
target's obj archetypes died with `NameError` at execution.

Main now keeps an import whose bound names the Python side actually names
(#9593, `stamp_native_import_facts` + `python_side_name_refs`), so the
server image binds `MirrorPoint` and `mirror_double` through the ordinary
Jac import machinery instead of a mirror splice. The splice
(`pyb_mirror_member`) remains for imports nothing on the Python side
references. These tests pin the binding contract either way: the names
resolve and answer across the codespace.
"""

import contextlib;
import io;
import os;
import sys;
import tempfile;
import types;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.py.codegen_shim { generated_python }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     CLIENT = "na_mirror_client.jac",
     TARGET = "na_mirror_target.jac";

def _compiled_client -> tuple[JacProgram, uni.Module] {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, CLIENT),
        options=CompileOptions(no_ir_cache=True)
    );
    return (prog, mod, );
}

def _target_module_source -> str {
    """The target's server-tier Python image.

    Compiled from a scratch directory so the fixture project's
    `na_mirror_target = native` pin does not apply: the exec below stands in
    for the materialized server image a real deployment provides.
    """;
    prog = JacProgram();
    with tempfile.TemporaryDirectory() as tmp {
        target_path = os.path.join(tmp, "na_mirror_target.jac");
        with open(os.path.join(FIXTURES, TARGET)) as src_fh {
            source = src_fh.read();
        }
        with open(target_path, "w") as dst_fh {
            dst_fh.write(source);
        }
        mod = prog.compile(
            file_path=target_path,
            options=CompileOptions(no_ir_cache=True)
        );
        errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not prog.errors_had , f"target compilation errors: {errors}";
        return generated_python(mod.gen);
    }
}

def _install_target_module -> None {
    target_globals: dict[any, any] = {};
    exec(_target_module_source(), target_globals);
    target_mod = types.ModuleType("na_mirror_target");
    target_mod.__dict__.update(target_globals);
    sys.modules["na_mirror_target"] = target_mod;
}


test "mirror fixture compiles clean" {
    (prog, mod) = _compiled_client();
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
}


test "pinned-native import stays bound in the server image" {
    (prog, mod) = _compiled_client();
    py_src = generated_python(mod.gen);
    assert "from na_mirror_target import" in py_src , (
        "the server image dropped the import of a natively-pinned module; "
        "constructing its obj would NameError again. The import the Python "
        "side names must survive into the image"
    );
    assert "MirrorPoint" in py_src;
    assert "mirror_double" in py_src;
    target_imports = [
        imp for imp in mod.get_all_sub_nodes(uni.Import)
        if imp.from_loc is not None
        and imp.from_loc.dot_path_str == "na_mirror_target"
    ];
    assert len(target_imports) == 1 , "client imports na_mirror_target once";
    assert not target_imports[0].native_only_drop , (
        "the python-named import of a pinned-native module was stamped "
        "native_only_drop, so the emitter omitted it and every use of "
        "MirrorPoint or mirror_double raised NameError"
    );
}


test "mirrored obj constructs and answers across the codespace" {
    (prog, mod) = _compiled_client();
    assert not prog.errors_had;
    py_code = compile(
        generated_python(mod.gen), os.path.join(FIXTURES, CLIENT), "exec"
    );
    _install_target_module();
    buf = io.StringIO();
    try {
        with contextlib.redirect_stdout(buf) {
            exec(py_code, {});
        }
    } finally {
        sys.modules.pop("na_mirror_target", None);
    }
    output = buf.getvalue().strip();
    assert output == "7 42" , (
        f"cross-codespace construction produced '{output}', expected '7 42'"
    );
}
