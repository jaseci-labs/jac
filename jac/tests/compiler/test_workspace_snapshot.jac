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

test "source revisions parse once and return isolated syntax" {
    store = SourceStore();
    program = JacProgram();
    (first, failed) = store.parse(
        'glob value = 1;\n', '/tmp/context-source.jac', program, []
    );
    assert not failed;
    (second, failed) = store.parse(
        'glob value = 1;\n', '/tmp/context-source.jac', program, []
    );
    assert not failed and store.parses == 1 and store.hits == 1;
    assert first is not second and first.body[0] is not second.body[0];
    store.parse('glob value = 2;\n', '/tmp/context-source.jac', program, []);
    assert store.parses == 2 and len(store.units) == 1;
}

test "syntax retention respects both entry and node budgets" {
    store = SourceStore(max_units=2);
    program = JacProgram();
    source = 'glob value = 1;\n';
    store.parse(source, '/tmp/recent-a.jac', program, []);
    store.parse(source, '/tmp/recent-b.jac', program, []);
    store.parse(source, '/tmp/recent-a.jac', program, []);
    store.parse(source, '/tmp/recent-c.jac', program, []);
    assert set(store.revisions) == {'/tmp/recent-a.jac', '/tmp/recent-c.jac'};
    assert store.evictions == 1 and store.hits == 1;
    store.max_nodes = 1;
    store.parse(source + '# large\n', '/tmp/recent-a.jac', program, []);
    assert '/tmp/recent-a.jac' not in store.revisions;
    store.forget('/tmp/recent-c.jac');
    assert not store.units and store.cached_nodes == 0;
    store.clear();
    assert not store.revisions;
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
