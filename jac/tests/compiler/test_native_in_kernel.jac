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

"""Options of a default run: native placement, but not ahead of time."""
def run_options -> CompileOptions {
    return CompileOptions(
        default_codespace="native", skip_native_engine=True, no_ir_cache=True
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

"""A bundled native module (`math`, `json`, `os`) belongs to the compiler
package, and a session is handed package modules as interfaces. The generator
needs the tree: a call is lowered from the callee's declaration. So a session
compiles these modules from source, whatever the options, and a default run
lowers the same IR the host does. Held as an interface, `floor` here bound to
libm's `floor` and returned a float."""
test "a default run lowers a bundled native import the way the host does" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'rounding.jac').write_text(
            'import math;\nimport from math { floor, sqrt }\n\n'
                + 'with entry {\n    print(floor(2.5), sqrt(16.0), math.floor(7.5));\n}\n'
        );
        entry_file = str(base / 'rounding.jac');
        program = JacProgram();
        module = program.compile(entry_file, options=run_options());
        assert not program.errors_had , [str(e) for e in program.errors_had];
        expected = unit_products(module, program);
        assert expected.native_ir , "the host generated no IR for the fixture";
        with patch.dict(os.environ, SWITCHES) {
            session = kernel_snapshot(
                active_host(),
                JacProgram(),
                entry_file,
                run_options(),
                emit_closure=True
            );
            outcome = run_kernel_compile(session.text(), entry_file, None, session);
        }
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.errors , [str(e) for e in outcome.analysis.errors];
        emitted = outcome.unit(entry_file);
        assert emitted is not None , [u.path for u in outcome.units];
        assert emitted.native_ir == expected.native_ir , (
            "the kernel session's IR differs from the host generator's"
        );
        assert "__jac_mono_floor" in emitted.native_ir , (
            "floor was not lowered from the bundled module's own definition"
        );
    }
}

"""The host can still fail after the kernel has lowered a module: the IR may
not link, because a dependency turned out not to be a native unit. Where
placement only inferred native, that is a demotion like any other. The host
holds the verdict and asks the kernel again, and the second session compiles
the module for the server."""
test "a module the host cannot link is demoted and compiled again for the server" {
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
        with patch.dict(os.environ, SWITCHES) {
            with patch.object(
                JacCompiler, "_load_native_from_cache", side_effect=refusal
            ) as link {
                code = builder.get_bytecode(
                    full_target=entry_file, target_program=program
                );
            }
        }
        assert link.call_count == 1 , (
            "the module came back native after its verdict was held"
        );
        assert code is not None , "the demoted module has no server code";
        verdict = program.native_units().verdict_for(entry_file);
        assert verdict is not None and verdict.demoted , verdict;
        assert verdict.code == "E5020" , verdict.code;
        assert "helper.jac is not a native unit" in verdict.detail , verdict.detail;
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
        with patch.dict(os.environ, SWITCHES) {
            with patch.object(
                JacCompiler, "_load_native_from_cache", side_effect=refusal
            ) {
                try {
                    builder.kernel_native_entry(
                        entry_file,
                        program,
                        CompileOptions(
                            default_codespace="native", force_codespace="native"
                        )
                    );
                } except LinkPlanError {
                    raised = True;
                }
            }
        }
        assert raised , "a forced native module was demoted instead of failing";
    }
}

"""`jac run` of a native program asks the kernel first: the program is compiled
by one kernel session, the host adopts the record and runs the entry natively,
and a second run starts from the cache with no compile at all."""
test "jac run executes a native program from a kernel session, then from the cache" {
    import subprocess;
    import from tests.support { jac_command }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'fib.jac').write_text(FIB);
        env: dict[str, str] = dict(os.environ);
        env.update(SWITCHES);
        env["JAC_KERNEL_TIMING"] = "1";
        first = subprocess.run(
            jac_command("run", "fib.jac"),
            cwd=str(base),
            capture_output=True,
            text=True,
            env=env
        );
        assert first.returncode == 0 , first.stderr[-2000:];
        assert "fib 6765" in first.stdout , first.stdout + first.stderr[-1500:];
        assert "kernel compile" in first.stderr , first.stderr[-1500:];
        assert "Preparing application" not in first.stderr , (
            "a native entry fell back to the Python lane:\n" + first.stderr[-1500:]
        );
        again = subprocess.run(
            jac_command("run", "fib.jac"),
            cwd=str(base),
            capture_output=True,
            text=True,
            env=env
        );
        assert again.returncode == 0 , again.stderr[-2000:];
        assert "fib 6765" in again.stdout;
        assert "kernel compile" not in again.stderr , again.stderr[-1500:];
    }
}
