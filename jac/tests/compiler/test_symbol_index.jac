"""Symbol products retain locations and input revisions, never compiler trees."""
import gc;
import weakref;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context { SourceStore, cache_scope }
import from jaclang.compiler.tools.symbol_index { SymbolIndex, IndexShard }
import from jaclang.project.config { config_scope }
import from jaclang.compiler.driver.jir {
    SEC_DEBUG_SRC,
    get_module_cache_path,
    read_section_bytes,
    write_module_cache
}

def _collect(program: JacProgram, index: SymbolIndex, path: Path) -> IndexShard {
    with program.source_store.capture() as inputs, config_scope(path.parent) {
        module = program.compile(
            file_path=str(path),
            options=CompileOptions(
                no_cgen=True, need_full_ast=True, force_target_program=True
            )
        );
        assert not program.errors_had , str(program.errors_had);
        owner = program.module_owner(module);
        assert owner is not None;
        shard = index.collect(module, owner.context_key, inputs.manifest());
        index.install(shard);
        return shard;
    }
}

test "cross module references survive releasing every compiler tree" {
    with TemporaryDirectory() as directory {
        library = Path(directory) / 'lib.jac';
        consumer = Path(directory) / 'main.jac';
        library.write_text('def answer -> int { return 42; }\n');
        consumer.write_text(
            'import from .lib { answer }\ndef run -> int { return answer(); }\n'
        );
        program = JacProgram.for_analysis();
        index = SymbolIndex();
        lib_shard = _collect(program, index, library);
        _collect(program, index, consumer);
        module = program.find_module(str(consumer));
        assert module is not None;
        reference = weakref.ref(module);
        del module;
        key = next(
            key
            for (key, info) in lib_shard.definitions.items()
            if info.name == 'answer'
        );
        before = index.references_for(key, program.source_store);
        assert {ref.file for ref in before} == {str(library), str(consumer)};
        assert any(ref.role == 'def' for ref in before);
        assert all(ref.end_col > ref.col for ref in before);
        program.release_compile_closure();
        gc.collect();
        assert reference() is None , 'the symbol index retained a compiler module';
        assert [
            ref.to_dict() for ref in index.references_for(key, program.source_store)
        ]
            == [ref.to_dict() for ref in before];
        assert index.lookup('answer', program.source_store)[0].file == str(library);
    }
}

test "persistent symbol sections preserve other products and reject changed inputs" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        path.write_text('def answer -> int { return 42; }\n');
        program = JacProgram.for_analysis();
        index = SymbolIndex();
        shard = _collect(program, index, path);
        with cache_scope(shard.context) {
            write_module_cache(str(path), None, {SEC_DEBUG_SRC: b'existing product'});
        }
        assert index.persist(shard);
        with cache_scope(shard.context) {
            assert read_section_bytes(
                get_module_cache_path(str(path)).read_bytes(), SEC_DEBUG_SRC
            )
                == b'existing product';
        }
        restored = SymbolIndex();
        assert restored.load(str(path), shard.context, SourceStore());
        assert restored.lookup('answer', SourceStore());
        assert not SymbolIndex().load(
            str(path), shard.context + '-different', SourceStore()
        );
        path.write_text('def answer -> int { return 43; }\n');
        assert not SymbolIndex().load(str(path), shard.context, SourceStore());
        assert not restored.lookup('answer', SourceStore());
        program.source_store.set_overrides(
            {str(path): 'def answer -> int { return 44; }\n'}
        );
        program.invalidate_module(str(path));
        unsaved = _collect(program, index, path);
        assert index.lookup('answer', program.source_store);
        assert not index.persist(unsaved) , 'unsaved text was written to the disk cache';
        program.release_compile_closure();
    }
}

test "creating an annex invalidates an otherwise unchanged symbol shard" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        path.write_text('def answer -> int { return 42; }\n');
        program = JacProgram.for_analysis();
        index = SymbolIndex();
        shard = _collect(program, index, path);
        assert shard.inputs.is_current(program.source_store);
        (Path(directory) / 'main.test.jac').write_text(
            'test check { assert answer() == 42; }\n'
        );
        assert not shard.inputs.is_current(program.source_store);
        assert not index.lookup('answer', program.source_store);
        program.release_compile_closure();
    }
}
