"""Server-side mirrors for native-placed module members.

`JcirGenPass.exit_import` dropped every import whose target is a natively
pinned user module (`Import.native_only_drop`). The drop is right about
ownership -- the native lane owns the module -- but it left the importing
server tier with no binding at all, so constructing one of the target's obj
archetypes died with `NameError` at execution.

The emitter now splices `interop_bridge.pyb_mirror_member` calls instead: each
imported name loads the target's server tier through the ordinary Jac import
machinery and binds the member.
"""

import contextlib;
import io;
import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.py.codegen_shim { generated_python }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     CLIENT = "na_mirror_client.jac";

def _compiled_client -> tuple[JacProgram, uni.Module] {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, CLIENT),
        options=CompileOptions(no_ir_cache=True)
    );
    return (prog, mod, );
}


test "mirror fixture compiles clean" {
    (prog, mod) = _compiled_client();
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
}


test "pinned-native import lowers to mirror splices" {
    (prog, mod) = _compiled_client();
    py_src = generated_python(mod.gen);
    assert "pyb_mirror_member" in py_src , (
        "the dropped cross-codespace import emitted no mirror splice; server "
        "code constructing a native-placed obj will NameError again"
    );
    assert "MirrorPoint" in py_src;
    assert "mirror_double" in py_src;
    assert "from na_mirror_target import" not in py_src , (
        "the emitter issued a plain Python import for a natively-pinned "
        "module; that re-introduces the ownership violation the drop fixed"
    );
}


test "mirrored obj constructs and answers across the codespace" {
    (prog, mod) = _compiled_client();
    assert not prog.errors_had;
    py_code = compile(
        generated_python(mod.gen), os.path.join(FIXTURES, CLIENT), "exec"
    );
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        exec(py_code, {});
    }
    output = buf.getvalue().strip();
    assert output == "7 42" , (
        f"cross-codespace construction produced '{output}', expected '7 42'"
    );
}
