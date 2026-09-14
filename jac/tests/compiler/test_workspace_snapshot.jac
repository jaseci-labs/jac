"""Reading app declarations never walks or parses the source workspace."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import os;
import from jaclang.compiler.placement.workspace { workspace_for_path }
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

test "native snapshots release with their source store and isolate mutable trees" {
    import from jaclang.compiler.native_compiler { NativeSyntax, ensure_loaded }
    import from unittest { SkipTest }
    if ensure_loaded() is None {
        raise SkipTest("native frontend disabled");
    }
    store = SourceStore();
    program = JacProgram();
    source = '# unicode: café\nglob value = 1;\n';
    (first, failed) = store.parse(source, '/tmp/owned-source.jac', program, []);
    assert not failed;
    snapshot = next(iter(store.units.values())).syntax;
    assert isinstance(snapshot, NativeSyntax);
    assert len(first.source.comments) == 1;
    first.source.comments.clear();
    (second, failed) = store.parse(source, '/tmp/owned-source.jac', program, []);
    assert not failed and second.source.code == source;
    assert len(second.source.comments) == 1;
    assert first.body[0] is not second.body[0];
    store.clear();
    assert not store.units and not store.revisions;
    assert second.source.code == source and len(second.body) == 1;
    try {
        snapshot.materialize();
        assert False , "clearing the store left its native region alive";
    } except RuntimeError {}
    snapshot.close();
}

test "replacing a source revision closes its previous native snapshot" {
    import from jaclang.compiler.native_compiler { NativeSyntax, ensure_loaded }
    import from unittest { SkipTest }
    if ensure_loaded() is None {
        raise SkipTest("native frontend disabled");
    }
    store = SourceStore();
    program = JacProgram();
    (old_tree, _) = store.parse(
        'glob value = 1;\n', '/tmp/revised-source.jac', program, []
    );
    old_snapshot = next(iter(store.units.values())).syntax;
    assert isinstance(old_snapshot, NativeSyntax);
    store.parse('glob value = 2;\n', '/tmp/revised-source.jac', program, []);
    assert len(store.units) == 1 and old_tree.source.code == 'glob value = 1;\n';
    try {
        old_snapshot.materialize();
        assert False , "replacing a source revision retained its old native region";
    } except RuntimeError {}
    store.clear();
}

test "source snapshots preserve diagnostics with either frontend" {
    import jaclang.compiler.native_compiler as native;
    for disabled in [False, True] {
        store = SourceStore();
        contexts = [JacProgram(), JacProgram()];
        with patch.object(
            native,
            'ensure_loaded',
            return_value=None if disabled else native.ensure_loaded()
        ) {
            for program in contexts {
                (_, failed) = store.parse(
                    'glob broken = ;\n', '/tmp/broken-source.jac', program, []
                );
                assert failed and program.errors_had;
            }
        }
        assert store.parses == 1 and store.hits == 1;
        assert [error.pretty_print() for error in contexts[0].errors_had]
            == [error.pretty_print() for error in contexts[1].errors_had];
        store.clear();
    }
}
