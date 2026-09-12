"""A broken file in the compiler's own sources is never degraded around.

Every schedule builder in `compiler.pipeline.schedule` degrades on `ImportError` so the
compiler can bootstrap itself and so an install missing an optional backend
still compiles. Both of those are *absence*. When #8215 dropped a comma from
`esast_gen_pass.jac`'s import list the file was present and simply would not
parse, and `get_py_code_gen` degraded around it anyway: every compile silently
lost the ES and native backends with no diagnostic naming the file, and finding
it took a bisect (#8218).

These tests pin the two halves of the distinction:

1. A .jac source that fails to compile raises `JacSourceCompileError` -- an
   `ImportError` that carries the offending file -- so a caller can tell
   breakage from absence.
2. `get_py_code_gen` re-raises that as `CompilerSourceError`, naming file and
   diagnostics, when the file is the compiler's own; it still returns the
   bytecode-only fallback for a genuinely absent backend and for a broken
   module that belongs to user code.
"""

import importlib;
import os;
import sys;
import tempfile;
import types;
import jaclang.compiler.ir.schema as uni;
import jaclang.compiler.session.compiler as compiler_mod;
import from jaclang.meta_importer { JacSourceCompileError }
import from jaclang.compiler.bootstrap.source_failures { CompilerSourceError }
import from jaclang.compiler.pipeline.schedule { get_py_code_gen }
import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.runtime.runtime { JacRuntime as Jac }

# The #8215 defect shape: an import list whose separator went missing.
glob BROKEN_SRC = (
         'import from math {\n'
         '    ceil,\n'
         '    floor\n'
         '    sqrt\n'
         '}\n'
         '\n'
         'def value -> int {\n'
         '    return 1;\n'
         '}\n'
     ),
     ES_BACKEND = 'jaclang.compiler.backends.es';

glob COMPILER_SRC = os.path.join(
         os.path.dirname(os.path.dirname(compiler_mod.__file__)),
         'backends',
         'es',
         'esast_gen_pass.jac'
     ),
     USER_SRC = os.path.join(tempfile.gettempdir(), 'not_the_compiler.jac');

def _broken_backend(source_path: str) -> ImportError {
    return JacSourceCompileError(
        f"{source_path} failed to compile:\n" "error[E0005]: Unexpected token 'E5099'",
        source_path
    );
}

def _absent_backend -> ImportError {
    return ModuleNotFoundError("The ES backend is absent");
}

"""Fail the backend import at the scheduler's module-loading boundary."""
def _codegen_with(failure: ImportError) -> list[PassIdentity] {
    import from unittest.mock { patch }
    original = importlib.import_module;
    def load(name: str, package: str | None = None) -> types.ModuleType {
        if name == ES_BACKEND {
            raise failure;
        }
        return original(name, package);
    }
    with patch.object(importlib, "import_module", side_effect=load) {
        return get_py_code_gen(native=False);
    }
}

test "a .jac source that fails to compile names the file and the parse error" {
    tmp = tempfile.mkdtemp(prefix="jac_loud_src_");
    broken = os.path.join(tmp, "broken_seam_fixture.jac");
    with open(broken, "w") as f {
        f.write(BROKEN_SRC);
    }
    prog = Jac.get_program();
    prior = list(prog.errors_had);
    sys.path.insert(0, tmp);
    err: (ImportError | None) = None;
    try {
        importlib.import_module("broken_seam_fixture");
    } except ImportError as e {
        err = e;
    } finally {
        sys.path.remove(tmp);
        sys.modules.pop("broken_seam_fixture", None);
        prog.errors_had.clear();
        prog.errors_had.extend(prior);
    }
    assert err is not None , "a module that cannot parse must not import cleanly";
    assert isinstance(err, JacSourceCompileError) , f"got {type(
        err
    ).__name__}, not a marked compile failure";
    assert os.path.realpath(err.jac_source_path) == os.path.realpath(broken);
    assert broken in str(err);
    assert "failed to compile" in str(err);
    assert "error[" in str(err) , f"no diagnostic in: {err}";
}


test "a compile error in a shared impl/ annex is reported as the module's own" {
    # #8982 item 2: the error lived in `impl/config.impl.jac`, the importer
    # scoped diagnostics by the `config.` prefix, and the shared annex folder
    # matched nothing, so the failure surfaced as a bare "No bytecode found".
    tmp = tempfile.mkdtemp(prefix="jac_loud_annex_");
    os.mkdir(os.path.join(tmp, "impl"));
    base = os.path.join(tmp, "annex_owner_fixture.jac");
    with open(base, "w") as f {
        f.write("obj Owner {\n    def greet -> str;\n}\n");
    }
    with open(os.path.join(tmp, "impl", "annex_owner_fixture.impl.jac"), "w") as f {
        f.write('impl Owner.greet -> str {\n    root = "hi";\n    return root;\n}\n');
    }
    prog = Jac.get_program();
    prior = list(prog.errors_had);
    sys.path.insert(0, tmp);
    err: (ImportError | None) = None;
    try {
        importlib.import_module("annex_owner_fixture");
    } except ImportError as e {
        err = e;
    } finally {
        sys.path.remove(tmp);
        sys.modules.pop("annex_owner_fixture", None);
        prog.errors_had.clear();
        prog.errors_had.extend(prior);
    }
    assert isinstance(err, JacSourceCompileError) , f"got {err!r}";
    assert "failed to compile" in str(err) , f"annex error was dropped: {err}";
    assert "error[" in str(err) , f"no diagnostic in: {err}";
    assert "annex_owner_fixture.impl.jac" in str(err) , (
        f"the diagnostic does not name the annex it came from: {err}"
    );
}

test "a broken compiler source fails loudly instead of dropping backends" {
    err: (CompilerSourceError | None) = None;
    try {
        _codegen_with(_broken_backend(COMPILER_SRC));
    } except CompilerSourceError as e {
        err = e;
    }
    assert err is not None , "a broken compiler source must not degrade to a short schedule";
    assert COMPILER_SRC in str(err);
    assert "Unexpected token" in str(err) , f"the parse error must survive into the report: {err}";
}

test "an absent backend still degrades to the bytecode-only fallback" {
    sched = _codegen_with(_absent_backend());
    assert [p.value for p in sched]
        == ["NativeImportFactsPass", "JcirGenPass", "JcirBytecodeGenPass"];
}

test "a broken module outside the compiler tree still degrades" {
    sched = _codegen_with(_broken_backend(USER_SRC));
    assert [p.value for p in sched]
        == ["NativeImportFactsPass", "JcirGenPass", "JcirBytecodeGenPass"];
}
