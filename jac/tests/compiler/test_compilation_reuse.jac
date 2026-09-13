"""Products extend a live source revision and preserve its compilation context."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compilation_context { program_for }
import from jaclang.compiler.driver.compiler { JacCompiler }
import from jaclang.compiler.driver.selfhost { SelfHostCache }
import from jaclang.compiler.driver.progstate { ModuleHub }
import from jaclang.compiler.frontend.unitree { ProgramModule }
import jaclang.compiler.types.stubcat.modiface;
import jaclang.compiler.types.stubcat.reader;
import jaclang.compiler.types.stubcat.writer;
import jaclang.compiler.types.type_evaluator;

test "interface then bytecode reuses one source tree for ordinary and compiler units" {
    for internal in (False, True) {
        with TemporaryDirectory() as directory {
            source = Path(directory) / "example.jac";
            source.write_text("def answer() -> int { return 42; }\n");
            path = str(source);
            program = JacProgram();
            if internal {
                program._compiler = JacCompiler(
                    _selfhost=SelfHostCache(_program=program, _jaclang_root=directory)
                );
            } else {
                program = program_for(path, program);
            }
            registry = program.iface_registry();
            iface = registry.ensure(path);
            assert iface is not None;
            analyzed = program.find_module(path);
            assert analyzed is not None and not analyzed.stub_only;
            assert program.analysis.parse_runs.get(path, 0) == 1;
            bytecode = program.get_bytecode(path);
            assert bytecode is not None;
            assert program.analysis.parse_runs.get(path, 0) == 1 , (
                "requesting executable code rebuilt the existing frontend"
            );
            assert program.analysis.tree_hits.get(path, 0) >= 1;
            assert analyzed.gen.py_bytecode;
            namespace: dict[str, any] = {"__name__": "reuse_example"};
            exec(bytecode, namespace);
            assert namespace["answer"]() == 42;
            program.release_compile_closure(retain_stubs=False);
        }
    }
}

test "live revisions detect restored timestamps and annex membership changes" {
    with TemporaryDirectory() as directory {
        source = Path(directory) / "example.jac";
        source.write_text("def answer() -> int { return 42; }\n");
        path = str(source);
        hub = ModuleHub(ProgramModule());
        hub.stamp(path);
        assert hub.is_fresh(path);
        original = source.stat();
        source.write_text("def answer() -> int { return 43; }\n");
        os.utime(path, ns=(original.st_atime_ns, original.st_mtime_ns));
        assert not hub.is_fresh(path);
        hub.stamp(path);
        annex = Path(directory) / "example.impl.jac";
        annex.write_text("impl answer { return 44; }\n");
        os.utime(str(annex), ns=(original.st_atime_ns, original.st_mtime_ns));
        assert not hub.is_fresh(path);
        hub.stamp(path);
        assert hub.is_fresh(path);
        annex.unlink();
        assert not hub.is_fresh(path);
        hub.stamp(path);
        source.unlink();
        assert not hub.is_fresh(path);
    }
}

test "requesting executable options keeps the producer identity" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    options = CompileOptions(
        no_cgen=True,
        symtab_ir_only=True,
        iface_ok=True,
        target_app="desktop",
        app_kind="client",
        opt_level=3,
        native_target="aarch64-unknown-linux-gnu",
        skip_native_engine=True
    );
    executable = options.for_executable();
    assert executable.codegen_identity() == options.codegen_identity();
    assert executable.analysis_identity() == options.analysis_identity();
    assert executable.skip_native_engine;
    assert not executable.symtab_ir_only and not executable.no_cgen;
    assert not executable.iface_ok;
    assert options.symtab_ir_only and options.no_cgen;
}
