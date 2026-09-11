"""Semantic queries share scheduled, detached compiler products."""

import from jaclang.compiler.pipeline.keys { SERVING }
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.pipeline.products { require_product }
import from jaclang.compiler.pipeline.contracts { CompilationProduct }
import from jaclang.compiler.api { native_dependency_facts }
import from jaclang.compiler.ir.enums { CodeContext }


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


test "application closure keeps client assets out of Jac compilation" {
    import from jaclang.compiler.api { compile_application }
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / 'jac.toml').write_text('[project]\nname="assets"\nkind="web-app"\n');
        style = base / 'site.css';
        style.write_text('body { color: red; }');
        path = base / 'main.jac';
        path.write_text('import "./site.css";\ndef:pub app -> any { return <div />; }');
        program = JacProgram();
        compile_application(
            program, str(path), CompileOptions(project_root=tmp, app_kind='web-app')
        );
        assert not program.errors_had , [str(e) for e in program.errors_had];
        assert program.find_module(str(style)) is None;
    }
}

test "application closure preserves diagnostics from rejected graphs" {
    import from jaclang.compiler.api { compile_application }
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def value -> int { return "bad"; }');
        program = JacProgram();
        compile_application(
            program,
            str(path),
            CompileOptions(no_cgen=True, default_codespace='server', project_root=tmp)
        );
        assert any(error.code?.code == 'E1002' for error in program.errors_had);
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
        facts = program.analysis.result(str(path), SERVING);
        assert facts.func_access['ping'] is False;
        assert facts.func_access['secret'] is True;
        count = program.analysis.pass_runs['ServingFactsPass'];
        assert require_product(program, module, CompilationProduct.SERVING);
        assert program.analysis.pass_runs['ServingFactsPass'] == count;
    }
}


test "serving metadata exposes members only for from imports" {
    import from jaclang.build.manifests { _manifest }
    import from jaclang.compiler.api { compile_application }
    import from jaclang.compiler.session.options { CompileOptions }
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
    import from jaclang.compiler.api { native_path_eligible }
    import from jaclang.compiler.session.context { cache_scope, active_program }
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


test "an uncacheable interface records an unavailable artifact without repeating analysis" {
    import from jaclang.compiler.pipeline.keys { INTERFACE }
    import from jaclang.compiler.pipeline.products { invalidate_product }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def value -> int { return 1; }');
        program = JacProgram();
        module = program.compile(str(path), no_cgen=True);
        assert not program.errors_had;
        module.codespace_inferred = True;
        invalidate_product(program, module, CompilationProduct.INTERFACE);
        assert require_product(program, module, CompilationProduct.INTERFACE);
        result = program.analysis.lookup(module.loc.mod_path, INTERFACE);
        assert result is not None;
        assert result.data is None;
        assert result.unavailable_reason;
        runs = dict(program.analysis.pass_runs);
        assert require_product(program, module, CompilationProduct.INTERFACE);
        assert program.analysis.pass_runs == runs;
        assert not program.errors_had;
    }
}


test "cached import edges retain distinct roles for the same provider" {
    import from jaclang.compiler.analysis.binding.facts { ImportEdge }
    import from jaclang.compiler.session.cache.artifact_codec {
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
    rows = registry.dep_rows(module);
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

test "a scheduled type query resolves a symbol before whole-module checking" {
    import from jaclang.compiler.api { query_type }
    import from jaclang.compiler.ir.types.nodes { FunctionType }
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'query.jac';
        path.write_text('def answer -> int { return 42; }');
        program = JacProgram();
        module = program.compile(
            str(path),
            options=CompileOptions(
                symtab_ir_only=True,
                no_cgen=True,
                force_target_program=True,
                default_codespace='server'
            )
        );
        symbol = module.names_in_scope.get('answer');
        assert symbol is not None;
        assert isinstance(query_type(program, symbol), FunctionType);
        assert not program.errors_had;
        assert program.analysis.mutations.mask == 0;
    }
}

test "pipe type queries preserve syntax parents and lexical children" {
    import from jaclang.compiler.api { query_type }
    import from jaclang.compiler.ir.schema { BinaryExpr, Token }
    import from jaclang.compiler.ir.enums { Tokens as Tok }
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'pipes.jac';
        path.write_text(
            'def add(a: int, b: int) -> int { return a + b; } '
            'glob forward = (1, 2) |> add, backward = add <| (3, 4);'
        );
        program = JacProgram();
        module = program.compile(
            str(path),
            options=CompileOptions(
                symtab_ir_only=True,
                no_cgen=True,
                force_target_program=True,
                default_codespace='server'
            )
        );
        pipes = [
            part
            for part in module.get_all_sub_nodes(BinaryExpr)
            if isinstance(part.op, Token)
                and part.op.name in (Tok.PIPE_FWD, Tok.PIPE_BKWD)
        ];
        assert len(pipes) == 2;
        for pipe in pipes {
            children = list(pipe.kid);
            parents = [child.parent for child in children];
            assert str(query_type(program, pipe)) == 'int';
            assert pipe.kid == children;
            assert [child.parent for child in children] == parents;
            assert pipe.left.parent is pipe;
            assert pipe.right.parent is pipe;
        }
        assert not program.errors_had;
        assert program.analysis.mutations.mask == 0;
    }
}

test "runtime bytecode extends an analyzed graph without discarding its bindings" {
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def value -> int { return 42; }');
        program = JacProgram();
        module = program.compile(
            str(path), options=CompileOptions(no_cgen=True, default_codespace='server')
        );
        assert not program.errors_had;
        parses = program.source_store.parses;
        code = program._get_compiler().get_bytecode(str(path), program);
        assert code is not None;
        context = program.module_context(module);
        assert module not in context.analysis.invalid_graphs;
        assert context.find_module(str(path)) is module;
        assert program.source_store.parses == parses;
    }
}


test "route metadata skips valid modules without client output" {
    import from jaclang.compiler.api { route_exports }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / 'jac.toml').write_text('[project]\nname="routes"\nkind="web-app"\n');
        for source in [
            '',
            'def helper -> int { return 1; }',
            'obj Data { has value: int; }'
        ] {
            path = base / 'helper.jac';
            path.write_text(source);
            program = JacProgram();
            assert route_exports(program, str(path)) == (None, None);
            assert not program.errors_had;
        }
        page = base / 'page.jac';
        page.write_text('def:pub View -> JsxPage { return <div>Home</div>; }');
        assert route_exports(JacProgram(), str(page)) == ('View', None);
    }
}


test "route metadata rejects compilation errors on repeated requests" {
    import from jaclang.compiler.api { route_exports }
    import from jaclang.compiler.pipeline.contracts { ProductUnavailable }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / 'jac.toml').write_text('[project]\nname="routes"\nkind="web-app"\n');
        path = base / 'page.jac';
        for source in [
            'def View -> JsxPage { return <div UNCLOSED; }',
            'def helper -> int { return "bad"; }'
        ] {
            path.write_text(source);
            program = JacProgram();
            for attempt in range(2) {
                rejected = False;
                try {
                    route_exports(program, str(path));
                } except ProductUnavailable {
                    rejected = True;
                }
                assert rejected;
                assert program.errors_had;
            }
        }
    }
}


test "recoverable syntax retains editor types but cannot publish artifacts" {
    import from jaclang.compiler.pipeline.contracts { AnalysisFact }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'broken.jac';
        path.write_text('def View -> JsxPage { return <div UNCLOSED; }');
        program = JacProgram();
        module = program.compile(str(path), no_cgen=True);
        context = program.module_context(module);
        assert module.parse_failed;
        assert context.analysis.provides(module, AnalysisFact.TYPE_OF);
        for product in [
            CompilationProduct.CLIENT,
            CompilationProduct.INTERFACE,
            CompilationProduct.NATIVE_IR,
            CompilationProduct.EXECUTABLE,
            CompilationProduct.SERVING
        ] {
            assert not require_product(context, module, product);
        }
        assert context.analysis.provides(module, AnalysisFact.TYPE_OF);
        assert context.find_module(str(path)) is module;
    }
}


test "route failures use diagnostics from the selected application context" {
    import from jaclang.compiler.api { route_exports }
    import from jaclang.compiler.pipeline.contracts { ProductUnavailable }
    import from jaclang.compiler.session.context { program_for }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        for (name, kind) in [('cli', 'cli'), ('web', 'web-app')] {
            project = base / name;
            project.mkdir();
            (project / 'jac.toml').write_text(
                f'[project]\nname="{name}"\nkind="{kind}"\n'
            );
        }
        initial = base / 'cli' / 'main.jac';
        initial.write_text('def helper -> int { return 1; }');
        path = base / 'web' / 'page.jac';
        path.write_text('def helper -> int { return "bad"; }');
        program = JacProgram();
        program.compile(str(initial), no_cgen=True);
        selected = program_for(str(path), program);
        assert selected is not program;
        rejected = False;
        try {
            route_exports(program, str(path));
        } except ProductUnavailable {
            rejected = True;
        }
        assert rejected;
        assert selected.errors_had;
    }
}
