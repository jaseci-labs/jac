"""Reading app declarations never walks or parses the source workspace."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import os;
import from jaclang.compiler.session.workspace { workspace_for_path }
import from jaclang.compiler.session.sources { SourceCache, SourceStore }
import from jaclang.compiler.session.session { JacProgram }

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

test "programs reuse frozen source revisions without sharing mutable syntax" {
    cache = SourceCache();
    left = SourceStore(shared=cache);
    right = SourceStore(shared=cache);
    first_program = JacProgram();
    second_program = JacProgram();
    code = 'glob value = 1;\n';
    (first, failed) = left.parse(code, '/tmp/shared-source.jac', first_program, []);
    assert not failed;
    with patch(
        'jaclang.compiler.frontend.parser.frontend.parse_woven',
        side_effect=AssertionError('a frozen revision must not be parsed again')
    ) {
        (second, failed) = right.parse(
            code, '/tmp/shared-source.jac', second_program, []
        );
    }
    assert not failed and left.parses == 1 and right.parses == 0;
    assert right.hits == 1;
    assert first.body[0] is not second.body[0];
    assert first.mutation_permit is first_program.analysis.mutations;
    assert second.mutation_permit is second_program.analysis.mutations;
    right.parse('glob value = 2;\n', '/tmp/shared-source.jac', second_program, []);
    assert right.parses == 1;
    right.parse(
        code,
        '/tmp/shared-source.jac',
        second_program,
        [('glob annex_value = 3;\n', '/tmp/shared-source.impl.jac')]
    );
    assert right.parses == 2;
}

test "shared syntax cache evicts by node budget and preserves live stores" {
    cache = SourceCache();
    store = SourceStore(shared=cache);
    first = store.unit('glob a = 1;', '/tmp/source-a.jac', []);
    second = store.unit('glob b = 2;', '/tmp/source-b.jac', []);
    cache.limit = first.node_count + second.node_count;
    cache.clear();
    cache.put(first.revision, first);
    cache.put(second.revision, second);
    assert cache.get(first.revision) is first;
    third = SourceStore().unit('glob c = 3;', '/tmp/source-c.jac', []);
    cache.put(third.revision, third);
    assert cache.get(second.revision) is None;
    assert cache.get(first.revision) is first;
    assert cache.nodes <= cache.limit;
    assert store.units[second.revision] is second;
    cache.clear();
    assert not cache.units and cache.nodes == 0;
}

test "cached parse diagnostics belong to the receiving program" {
    cache = SourceCache();
    first = JacProgram();
    second = JacProgram();
    code = 'def broken( {';
    SourceStore(shared=cache).parse(code, '/tmp/broken-cache.jac', first, []);
    SourceStore(shared=cache).parse(code, '/tmp/broken-cache.jac', second, []);
    assert first.errors_had and second.errors_had;
    assert first.errors_had[0] is not second.errors_had[0];
    original = second.errors_had[0].msg;
    first.errors_had[0].msg = 'changed by first program';
    assert second.errors_had[0].msg == original;
}

test "host symbol imports use fresh graphs and retain their program context" {
    import from jaclang.compiler.session.compiler { JacCompiler }
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as td {
        source = Path(td) / 'api.jac';
        source.write_text('def answer -> int { return 42; }\n');
        compiler = JacCompiler();
        compiler.selfhost._jaclang_root = td;
        first = JacProgram();
        second = JacProgram();
        first._compiler = compiler;
        second._compiler = compiler;
        options = CompileOptions(
            no_cgen=True, symtab_ir_only=True, force_target_program=True
        );
        left = first.compile(str(source), options=options);
        right_options = options.for_symbols();
        right_options.force_target_program = True;
        right = second.compile(str(source), options=right_options);
        assert not first.errors_had and not second.errors_had;
        assert left is not right and left.body[0] is not right.body[0];
        assert left.mutation_permit is first.analysis.mutations;
        assert right.mutation_permit is second.analysis.mutations;
        assert 'answer' in left.names_in_scope and 'answer' in right.names_in_scope;
        assert compiler.selfhost.program.find_module(str(source)) is None;
        assert first.source_store.parses == 0 and second.source_store.parses == 0;
        assert compiler.selfhost.can_prepare_symbols(str(source), first);
        first.options.force_codespace = 'client';
        assert not compiler.selfhost.can_prepare_symbols(str(source), first);
        first.options.force_codespace = '';
        first.options.aot_mode = True;
        assert not compiler.selfhost.can_prepare_symbols(str(source), first);
    }
}
