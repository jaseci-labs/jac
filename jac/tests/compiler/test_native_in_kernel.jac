"""The kernel generates native code.

A module placed in the native codespace is lowered to LLVM IR inside the
kernel, which returns the IR text, the native interface and the layout in the
module's unit record. The host turns that record into machine code, cache
sections and an engine without analysing the module or holding its tree."""
import ctypes;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support {
    compile_native,
    diagnostics_text,
    get_func,
    kernel_compile_file
}

glob CONFIG: str = '[project]\nname="kernel-native"\n',
     FIB: str = (
         'def fib(n: int) -> int {\n'
         '    if n < 2 {\n        return n;\n    }\n'
         '    return fib(n - 1) + fib(n - 2);\n}\n\n'
         'with entry {\n    print("fib", fib(20));\n}\n'
     ),
     SHAPES: str = (
         'def square(x: int) -> int {\n    return x * x;\n}\n\n'
         'obj Point {\n    has x: int = 0, y: int = 0;\n\n'
         '    def norm2 -> int {\n        return square(self.x) + square(self.y);\n    }\n}\n'
     ),
     USES_SHAPES: str = (
         'import from shapes { square, Point }\n\n'
         'with entry {\n    p = Point(x=3, y=4);\n'
         '    print("sq", square(7), "norm2", p.norm2());\n}\n'
     );

def native_options -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        default_codespace="native",
        skip_native_engine=True,
        no_ir_cache=True
    );
}

test "a kernel compile returns a native module's IR, interface and layout" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'fib.jac').write_text(FIB);
        entry_file = str(base / 'fib.jac');
        result = kernel_compile_file(entry_file, native_options());
        assert result.ok() , diagnostics_text(result);
        emitted = result.unit(entry_file);
        assert emitted is not None , [u.path for u in result.units];
        assert emitted.native_ir , "the kernel generated no IR for the fixture";
        assert emitted.native_iface , "the unit carries no native interface";
        assert emitted.native_layout , "the unit carries no native layout";
        (eng, _fx) = compile_native('fib.jac', str(base));
        assert get_func(eng, "fib", ctypes.c_int64, ctypes.c_int64)(20) == 6765;
    }
}

test "a native dependency is lowered in the same compile and emitted as its own unit" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'shapes.jac').write_text(SHAPES);
        (base / 'main.jac').write_text(USES_SHAPES);
        entry_file = str(base / 'main.jac');
        dep_file = str(base / 'shapes.jac');
        result = kernel_compile_file(entry_file, native_options());
        assert result.ok() , diagnostics_text(result);
        emitted = result.unit(entry_file);
        assert emitted is not None and emitted.native_ir;
        assert dep_file in [os.path.realpath(d) for d in emitted.native_deps];
        lowered = result.unit(dep_file);
        assert lowered is not None , [u.path for u in result.units];
        assert lowered.native_ir , "the dependency's unit carries no IR";
        assert lowered.native_iface , "the dependency's unit carries no interface";
    }
}

test "the host runs a native module from its kernel record without analysing it" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'shapes.jac').write_text(SHAPES);
        (base / 'main.jac').write_text(USES_SHAPES);
        entry_file = str(base / 'main.jac');
        program = JacProgram();
        builder = program._get_compiler();
        engine = builder.kernel_native_entry(
            entry_file, program, CompileOptions(default_codespace="native")
        );
        assert not program.errors_had , [str(e) for e in program.errors_had];
        assert engine is not None , "the adopted unit produced no engine";
        assert engine.get_function_address("jac_entry") != 0;
        registry = program.native_units();
        for unit_path in (entry_file, str(base / 'shapes.jac')) {
            held = registry.entries.get(os.path.realpath(unit_path));
            assert held is not None and held.bitcode , f"no machine code for {unit_path}";
        }
    }
}

"""A module pinned native whose code the backend cannot lower keeps its server
code: the decision step refuses the functions it cannot represent, records
them in the unit's demoted set, and the module compiles cleanly."""
test "a pinned native module with a construct the backend refuses keeps its server code" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(
            CONFIG + '\n[placement.pins]\nmodels = "native"\n'
        );
        (base / 'models.jac').write_text(
            'def double(x: int) -> int {\n    return x * 2;\n}\n\n'
                + 'with entry {\n    s = {1, "a"};\n    print(double(2), len(s));\n}\n'
        );
        entry_file = str(base / 'models.jac');
        result = kernel_compile_file(
            entry_file,
            CompileOptions(skip_native_engine=True, no_ir_cache=True),
            ["bytecode", "mir"]
        );
        assert result.ok() , diagnostics_text(result);
        emitted = result.unit(entry_file);
        assert emitted is not None , [u.path for u in result.units];
        assert emitted.code is not None , "the module has no server code";
        assert emitted.demoted , "the refused construct left no demotion on record";
        assert all(d.reason for d in emitted.demoted) , [d.symbol for d in emitted.demoted];
    }
}

"""A bundled native module (`math`) belongs to the compiler package. A call is
lowered from the callee's declaration, so the kernel compiles these modules
from source: held as an interface, `floor` bound to libm's `floor` and
returned a float."""
test "a bundled native import is lowered from its own definition" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'rounding.jac').write_text(
            'import math;\nimport from math { floor, sqrt }\n\n'
                + 'def floored(x: float) -> int {\n    return floor(x);\n}\n\n'
                + 'def rooted(x: float) -> float {\n    return sqrt(x);\n}\n\n'
                + 'def floored_again(x: float) -> int {\n    return math.floor(x);\n}\n'
        );
        (eng, _fx) = compile_native('rounding.jac', str(base));
        assert get_func(eng, "floored", ctypes.c_int64, ctypes.c_double)(2.5) == 2;
        assert get_func(eng, "floored", ctypes.c_int64, ctypes.c_double)(-2.5) == -3;
        assert get_func(eng, "floored_again", ctypes.c_int64, ctypes.c_double)(7.5) == 7;
        assert get_func(eng, "rooted", ctypes.c_double, ctypes.c_double)(16.0) == 4.0;
    }
}

"""The host can still fail after the kernel has lowered a module: the IR may
not link. Placement was settled before the module was lowered, so a link
failure is a compiler defect. It surfaces as one; nothing compiles the module
again for the server."""
test "a module the host cannot link is an error, not a second compile" {
    import from jaclang.compiler.backends.native.link_plan { LinkPlanError }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'fib.jac').write_text(FIB);
        entry_file = str(base / 'fib.jac');
        program = JacProgram();
        builder = program._get_compiler();
        refusal = LinkPlanError("helper.jac is not a native unit");
        raised = False;
        with patch.object(
            JacCompiler, "_load_native_from_cache", side_effect=refusal
        ) as link {
            try {
                builder.get_bytecode(full_target=entry_file, target_program=program);
            } except LinkPlanError {
                raised = True;
            }
        }
        assert raised , "a link failure was absorbed instead of surfacing";
        assert link.call_count == 1 , "the module was compiled again after it failed to link";
    }
}

test "a link failure stays an error when native was asked for outright" {
    import from jaclang.compiler.backends.native.link_plan { LinkPlanError }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'fib.jac').write_text(FIB);
        entry_file = str(base / 'fib.jac');
        program = JacProgram();
        builder = program._get_compiler();
        refusal = LinkPlanError("helper.jac is not a native unit");
        raised = False;
        with patch.object(
            JacCompiler, "_load_native_from_cache", side_effect=refusal
        ) {
            try {
                builder.kernel_native_entry(
                    entry_file,
                    program,
                    CompileOptions(default_codespace="native", force_codespace="native")
                );
            } except LinkPlanError {
                raised = True;
            }
        }
        assert raised , "a forced native module was demoted instead of failing";
    }
}

"""`jac run` of a native program compiles it through the kernel, adopts the
unit and runs the entry natively; a second run starts from the cache and
compiles nothing."""
test "jac run executes a native program from a kernel compile, then from the cache" {
    import subprocess;
    import from tests.support { jac_command }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'fib.jac').write_text(FIB);
        first = subprocess.run(
            jac_command("run", "fib.jac"), cwd=str(base), capture_output=True, text=True
        );
        assert first.returncode == 0 , first.stderr[-2000:];
        assert "fib 6765" in first.stdout , first.stdout + first.stderr[-1500:];
        assert "Preparing application" not in first.stderr , (
            "a native entry went through the Python lane:\n" + first.stderr[-1500:]
        );
        cached = sorted((base / '.jac' / 'cache').rglob('fib.*.jir'));
        assert cached , "the first run cached no unit";
        stamps = [p.stat().st_mtime_ns for p in cached];
        again = subprocess.run(
            jac_command("run", "fib.jac"), cwd=str(base), capture_output=True, text=True
        );
        assert again.returncode == 0 , again.stderr[-2000:];
        assert "fib 6765" in again.stdout;
        assert [p.stat().st_mtime_ns for p in cached] == stamps , (
            "the second run compiled the program again"
        );
    }
}
