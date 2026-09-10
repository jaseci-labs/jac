"""Semantic queries share scheduled, detached compiler products."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pipeline {
    require_product,
    CompilationProduct,
    native_dependency_facts
}
import from jaclang.compiler.frontend.constant { CodeContext }


test "native eligibility reuses syntax and observes content changes with identical stat" {
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def value -> int { return 1; }\n');
        program = JacProgram();
        first = native_dependency_facts(program, str(path));
        assert not first.reason;
        parses = program.source_store.parses;
        assert native_dependency_facts(program, str(path)) is first;
        assert program.source_store.parses == parses;
        stamp = path.stat();
        path.write_text('def value -> int { return 2; }\n');
        os.utime(path, ns=(stamp.st_atime_ns, stamp.st_mtime_ns));
        second = native_dependency_facts(program, str(path));
        assert second is not first;
        assert program.source_store.parses == parses + 1;
    }
}


test "native speculative parse errors do not contaminate compilation diagnostics" {
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'bad.jac';
        path.write_text('def broken {');
        program = JacProgram();
        assert native_dependency_facts(program, str(path)).reason == 'parse error';
        assert not program.errors_had;
    }
}


test "import facts include plain imports and drive reverse dependencies" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        (base / 'helper.jac').write_text('def value -> int { return 1; }');
        path.write_text('import helper;\nwith entry { print(helper.value()); }');
        program = JacProgram();
        module = program.compile(str(path), no_cgen=True);
        assert not program.errors_had , [str(e) for e in program.errors_had];
        assert require_product(program, module, CompilationProduct.IMPORTS);
        assert any(
            edge.target == str(base / 'helper.jac')
            for edge in program.deps.imports[str(path)]
        );
        assert str(path) in program.transitive_dependents(str(base / 'helper.jac'));
    }
}


test "serving access is a reusable scheduled product" {
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text(
            'def:pub ping -> int { return 1; }\ndef secret -> int { return 2; }'
        );
        program = JacProgram();
        module = program.compile(str(path), no_cgen=True);
        assert not program.errors_had , [str(e) for e in program.errors_had];
        assert require_product(program, module, CompilationProduct.SERVING);
        facts = program.analysis.serving_facts[str(path)];
        assert facts.func_access['ping'] is False;
        assert facts.func_access['secret'] is True;
        count = program.analysis.pass_runs['ServingFactsPass'];
        assert require_product(program, module, CompilationProduct.SERVING);
        assert program.analysis.pass_runs['ServingFactsPass'] == count;
    }
}


test "serving metadata exposes members only for from imports" {
    import from jaclang.compiler.driver.application { _manifest }
    import from jaclang.compiler.driver.pipeline { compile_application }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        (base / 'helper.jac').write_text('def:pub value -> int { return 1; }');
        options = CompileOptions(
            no_cgen=True, default_codespace='server', project_root=tmp
        );
        for (source, exposed) in [
            ('import helper;\ndef:pub ping -> int { return helper.value(); }', False),
            (
                'import from helper { value }\ndef:pub ping -> int { return value(); }',
                True
            )
        ] {
            path.write_text(source);
            program = JacProgram();
            module = compile_application(program, str(path), options);
            assert not program.errors_had , [str(e) for e in program.errors_had];
            manifest = _manifest(program, str(path), tmp, module);
            assert 'ping' in manifest['func_access'];
            assert ('value' in manifest['func_access']) == exposed , manifest;
        }
    }
}


test "native path queries share compilation syntax and restore nested contexts" {
    import from jaclang.compiler.driver.pipeline { native_path_eligible }
    import from jaclang.compiler.driver.compilation_context {
        cache_scope,
        active_program
    }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def value -> int { return 1; }');
        program = JacProgram();
        previous = active_program();
        with cache_scope('', program.options, program) {
            assert native_path_eligible(str(path));
            parses = program.source_store.parses;
            assert parses > 0;
            with cache_scope('nested') {
                assert active_program() is program;
                assert native_path_eligible(str(path));
            }
            assert program.source_store.parses == parses;
        }
        assert active_program() is previous;
    }
}


test "an uncacheable interface does not become a successful product" {
    import from jaclang.compiler.driver.pipeline { invalidate_product }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def value -> int { return 1; }');
        program = JacProgram();
        module = program.compile(str(path), no_cgen=True);
        assert not program.errors_had;
        module.codespace_inferred = True;
        invalidate_product(program, module, CompilationProduct.INTERFACE);
        assert not require_product(program, module, CompilationProduct.INTERFACE);
        assert not require_product(program, module, CompilationProduct.INTERFACE);
        assert not program.errors_had;
    }
}


test "cached import edges retain distinct roles for the same provider" {
    import from jaclang.compiler.driver.semantic_facts { ImportEdge }
    import from jaclang.compiler.driver.jir {
        deps_section,
        read_dep_rows,
        write_precompiled_jir,
        SEC_DEPS
    }
    program = JacProgram();
    module = '/project/main.jac';
    provider = '/project/helper.jac';
    program.deps.imports[module] = [
        ImportEdge(provider, True, False, CodeContext.SERVER, True, False),
        ImportEdge(provider, True, False, CodeContext.CLIENT, False, True),
        ImportEdge(provider, True, True, CodeContext.NATIVE, False, True)
    ];
    registry = program.iface_registry();
    registry.direct_deps[module] = {provider: 'digest'};
    rows = registry.dep_rows(module, None);
    cached = write_precompiled_jir(None, extra_sections={SEC_DEPS: deps_section(rows)});
    restored = JacProgram();
    restored.deps.restore_imports(module, read_dep_rows(cached));
    edges = restored.deps.imports[module];
    assert len(edges) == 3;
    assert not any(edge.top_level and edge.from_import for edge in edges);
    assert any(
        edge.context == CodeContext.NATIVE and edge.is_comptime for edge in edges
    );
    assert any(
        edge.context == CodeContext.CLIENT and edge.from_import for edge in edges
    );
    assert all(edge.jac for edge in edges);
    assert module in restored.transitive_dependents(provider);
}
