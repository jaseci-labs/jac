"""Dependent editor records survive body edits only with a stable compiled contract."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.tools.symbol_index { IndexShard, SymbolIndex }
import from jaclang.compiler.tools.workspace_index { WorkspaceIndexer }
import from jaclang.project.config { config_scope }

test "a body edit refreshes compact consumers while a signature edit invalidates them" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        library = base / 'lib.jac';
        consumer = base / 'main.jac';
        library.write_text('def answer -> int { return 42; }\n');
        consumer.write_text(
            'import from .lib { answer }\ndef run -> int { return answer(); }\n'
        );
        program = JacProgram.for_analysis();
        index = SymbolIndex();
        indexer = WorkspaceIndexer(program, index);
        def collect(path: Path) -> IndexShard {
            with program.source_store.capture() as inputs, config_scope(base) {
                module = program.compile(
                    file_path=str(path),
                    options=CompileOptions(
                        no_cgen=True, need_full_ast=True, force_target_program=True,
                        entry_point=str(consumer)
                    )
                );
                assert not program.errors_had , str(program.errors_had);
                shard = indexer.collect(module, inputs.manifest());
                assert shard is not None;
                return shard;
            }
        }
        try {
            before = collect(library);
            retained = collect(consumer);
            assert before.interface is not None;
            assert str(library) in retained.inputs.files;
            program.invalidate_module(str(library));
            program.invalidate_module(str(consumer));
            library.write_text('def answer -> int { return 43; }\n');
            assert not retained.inputs.is_current(program.source_store);
            after = collect(library);
            assert after.interface == before.interface;
            assert retained.inputs.is_current(program.source_store);
            assert program.find_module(str(consumer)) is None;
            program.invalidate_module(str(library));
            library.write_text('def answer -> str { return "changed"; }\n');
            changed = collect(library);
            assert changed.interface != after.interface;
            assert not retained.inputs.is_current(program.source_store);
        } finally {
            program.release_compile_closure();
        }
    }
}
