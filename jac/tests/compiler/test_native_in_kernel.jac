"""A kernel session generates native code.

A module placed in the native codespace is lowered to LLVM IR inside the
kernel session, which returns the IR text, the native interface and the
layout in the module's unit record. The host turns that record into machine
code, cache sections and an engine without analysing the module or holding
its tree. These cases run the kernel's code under Python, so they need no
kernel library; what they pin is the hand-off: the record must carry what
the host's own generator produces, and the host must be able to run it."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.unit_products { UnitProducts, unit_products }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_OK,
    CompileReport,
    run_kernel_compile
}
import from jaclang.project.kernel_snapshot { kernel_snapshot }

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
     ),
     SWITCHES: dict[str, str] = {"JAC_KERNEL_COMPILE": "inprocess"};

def native_options -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        default_codespace="native",
        skip_native_engine=True,
        no_ir_cache=True
    );
}

"""What the host's own generator produces for `entry_file`, as a unit record."""
def host_native(entry_file: str) -> UnitProducts {
    program = JacProgram();
    module = program.compile(entry_file, options=native_options());
    assert not program.errors_had , [str(e) for e in program.errors_had];
    return unit_products(module, program);
}

"""Compile `entry_file` in a kernel session run under Python, native generation on."""
def kernel_native(entry_file: str) -> CompileReport {
    with patch.dict(os.environ, SWITCHES) {
        session = kernel_snapshot(
            active_host(), JacProgram(), entry_file, native_options(), emit_closure=True
        );
        return run_kernel_compile(session.text(), entry_file, None, session);
    }
}

test "a kernel session returns a native module's IR, interface and layout" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'fib.jac').write_text(FIB);
        entry_file = str(base / 'fib.jac');
        expected = host_native(entry_file);
        assert expected.native_ir , "the host generated no IR for the fixture";
        outcome = kernel_native(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.errors , [str(e) for e in outcome.analysis.errors];
        emitted = outcome.unit(entry_file);
        assert emitted is not None , [u.path for u in outcome.units];
        assert emitted.native_ir == expected.native_ir , (
            "the kernel session's IR differs from the host generator's"
        );
        assert emitted.native_iface == expected.native_iface;
        assert emitted.native_layout == expected.native_layout;
        assert emitted.native_deps == expected.native_deps;
        assert emitted.jcir == expected.jcir;
        assert emitted.interop == expected.interop;
    }
}

test "a session with native generation off leaves a native module to the host" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'fib.jac').write_text(FIB);
        entry_file = str(base / 'fib.jac');
        session = kernel_snapshot(
            active_host(), JacProgram(), entry_file, native_options(), emit_closure=True
        );
        session.seed.native_codegen = False;
        outcome = run_kernel_compile(session.text(), entry_file, None, session);
        assert outcome.unit(entry_file) is None , "a deferred native module emitted a unit";
        entry_report = outcome.analysis.module(entry_file);
        assert entry_report is not None and entry_report.native;
    }
}

test "a native dependency is lowered in the session and emitted as its own unit" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'shapes.jac').write_text(SHAPES);
        (base / 'main.jac').write_text(USES_SHAPES);
        entry_file = str(base / 'main.jac');
        dep_file = str(base / 'shapes.jac');
        expected = host_native(entry_file);
        outcome = kernel_native(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.errors , [str(e) for e in outcome.analysis.errors];
        emitted = outcome.unit(entry_file);
        assert emitted is not None and emitted.native_ir == expected.native_ir;
        assert dep_file in [os.path.realpath(d) for d in emitted.native_deps];
        lowered = outcome.unit(dep_file);
        assert lowered is not None , [u.path for u in outcome.units];
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
        with patch.dict(os.environ, SWITCHES) {
            (in_kernel, engine) = builder.kernel_native_entry(
                entry_file, program, CompileOptions(default_codespace="native")
            );
        }
        assert in_kernel;
        assert not program.errors_had , [str(e) for e in program.errors_had];
        assert engine is not None , "the adopted unit produced no engine";
        assert engine.get_function_address("jac_entry") != 0;
        assert program.find_module(entry_file) is None , (
            "the host holds a tree for a module the kernel compiled"
        );
        registry = program.native_units();
        for unit_path in (entry_file, str(base / 'shapes.jac')) {
            held = registry.entries.get(os.path.realpath(unit_path));
            assert held is not None and held.bitcode , f"no machine code for {unit_path}";
        }
    }
}

"""Placement is optimistic: a module pinned or inferred native that cannot be
lowered is demoted and compiled again on the server. In a kernel session that
retry happens inside the session, and the host learns of it from the unit's
placement record and the session's notes, not by compiling the module."""
test "a module that cannot be lowered is demoted inside the session" {
    import json;
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(
            CONFIG + '\n[placement.pins]\nmodels = "native"\n'
        );
        (base / 'models.jac').write_text(
            'def double(x: int) -> int {\n    return x * 2;\n}\n\n'
                + 'with entry {\n    print(len([root-->]));\n}\n'
        );
        entry_file = str(base / 'models.jac');
        with patch.dict(os.environ, SWITCHES) {
            session = kernel_snapshot(
                active_host(),
                JacProgram(),
                entry_file,
                CompileOptions(skip_native_engine=True, no_ir_cache=True),
                emit_closure=True
            );
            outcome = run_kernel_compile(session.text(), entry_file, None, session);
        }
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.errors , [str(e) for e in outcome.analysis.errors];
        emitted = outcome.unit(entry_file);
        assert emitted is not None , [u.path for u in outcome.units];
        assert emitted.jcir , "the demoted module has no server code";
        assert not emitted.native_ir , "a demoted module still carries native IR";
        summary = json.loads(emitted.placement);
        assert summary.get("native_verdict_code") == "E5092" , summary;
        notes = [
            row[2]
            for row in outcome.analysis.events
            if row and row[0] == "note"
        ];
        assert any("did not lower" in note for note in notes) , outcome.analysis.events;
    }
}
