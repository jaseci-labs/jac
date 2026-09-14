"""Reading app declarations never walks or parses the source workspace."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import os;
import from jaclang.project.workspace { workspace_for_path }
import from jaclang.compiler.driver.compilation_context { SourceStore }
import from jaclang.compiler.driver.program { JacProgram }

test "unrelated broken source is not discovery input" {
    with TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text('[apps.a]\nkind="service"\nentry-point="a"\n');
        (base / 'a.jac').write_text('def:pub hello -> str { return "ok"; }\n');
        (base / 'unrelated.jac').write_text('this is not valid Jac !!!');
        with patch.object(
            os, 'walk', side_effect=AssertionError('source scan during declarations')
        ) {
            spec = workspace_for_path(str(base / 'a.jac'));
            assert spec is not None;
            assert list(spec.apps) == ['a'];
            assert spec.app_for_path(str(base / 'unrelated.jac')) is None;
        }
    }
}

test "source reads isolate mutable syntax without retaining parser trees" {
    import gc;
    import weakref;
    store = SourceStore();
    program = JacProgram();
    (first, failed) = store.parse(
        'glob value = 1;\n', '/tmp/context-source.jac', program, []
    );
    assert not failed;
    (second, failed) = store.parse(
        'glob value = 1;\n', '/tmp/context-source.jac', program, []
    );
    assert not failed;
    assert first is not second and first.body[0] is not second.body[0];
    first_ref = weakref.ref(first);
    second_ref = weakref.ref(second);
    del first;
    del second;
    gc.collect();
    assert first_ref() is None and second_ref() is None;
    (edited, failed) = store.parse(
        'glob value = 2;\n', '/tmp/context-source.jac', program, []
    );
    assert not failed and edited.source.code == 'glob value = 2;\n';
}

test "source overlays include unsaved and newly created annexes" {
    with TemporaryDirectory() as td {
        base = Path(td) / 'sample.jac';
        annex = Path(td) / 'sample.impl.jac';
        base.write_text('def answer -> int;\n');
        store = SourceStore();
        source = 'impl answer -> int { return 42; }\n';
        assert store.set_overrides({str(annex): source}) == {str(annex)};
        assert store.annexes(str(base)) == [(source, str(annex))];
        before = store.fingerprint(str(base));
        store.set_overrides({str(annex): source.replace('42', '43')});
        assert store.fingerprint(str(base)) != before;
        assert not annex.exists();
        assert store.set_overrides({}) == {str(annex)};
        assert store.annexes(str(base)) == [];
    }
}

test "dependency reads use an empty overlay and never persist it as disk content" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    with TemporaryDirectory() as td {
        library = Path(td) / 'lib.jac';
        consumer = Path(td) / 'app.jac';
        library.write_text('obj Foo { has x: int; }\n');
        consumer.write_text('import from .lib { Foo }\nwith entry { f = Foo(x=1); }\n');
        program = JacProgram();
        program.source_store.set_overrides({str(library): ''});
        dependency = program.load_dependency_module(str(library));
        assert dependency.source.code == '' , 'the empty editor buffer must override disk';
        program.source_store.set_overrides({str(library): 'obj Foo { has y: str; }\n'});
        program.invalidate_module(str(library));
        program.compile(str(consumer), options=CompileOptions(no_cgen=True));
        assert program.errors_had , 'the consumer must see the unsaved field change';
        assert library.read_text() == 'obj Foo { has x: int; }\n';
        clean = JacProgram();
        clean.compile(str(consumer), options=CompileOptions(no_cgen=True));
        assert not clean.errors_had , [str(e) for e in clean.errors_had];
    }
}

test "captured disk sources remain stable and detect concurrent writes" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        path.write_text('glob value = 1;\n');
        store = SourceStore();
        with store.capture() as inputs {
            before = store.read(str(path));
            assert inputs.is_current(store);
            path.write_text('glob value = 2;\n');
            assert store.read(str(path)) == before;
            assert not inputs.is_current(store);
            with store.capture() as nested {
                assert nested is inputs;
            }
            assert store.snapshot is inputs;
        }
        assert store.snapshot is None;
        with store.capture() as fresh {
            assert store.read(str(path)) == 'glob value = 2;\n';
            assert fresh.is_current(store);
        }
    }
}

test "captured annex membership and configuration are revision inputs" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        annex = Path(directory) / 'main.impl.jac';
        config = Path(directory) / 'jac.toml';
        path.write_text('def answer -> int;\n');
        store = SourceStore();
        with store.capture() as inputs {
            store.record_module(str(path));
            assert store.annexes(str(path)) == [];
            annex.write_text('impl answer -> int { return 42; }\n');
            assert store.annexes(str(path)) == [];
            assert not inputs.is_current(store);
        }
        with store.capture() as configured {
            store.record_module(str(path));
            assert len(store.annexes(str(path))) == 1;
            assert configured.is_current(store);
            config.write_text('[project]\nname="changed"\n');
            assert not configured.is_current(store);
        }
    }
}

test "an editor override is frozen and capture ends after failure" {
    store = SourceStore();
    path = '/tmp/unsaved-source-snapshot.jac';
    store.set_overrides({path: 'before'});
    try {
        with store.capture() as inputs {
            store.set_overrides({path: 'after'});
            assert store.read(path) == 'before';
            assert not inputs.is_current(store);
            raise RuntimeError('abandoned compilation');
        }
    } except RuntimeError {}
    assert store.snapshot is None and store.read(path) == 'after';
}
