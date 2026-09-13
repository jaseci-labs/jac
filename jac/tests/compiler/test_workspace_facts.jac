"""Entry declarations are boundaries; ordinary imports inherit compilation context."""
import from jaclang.compiler.session.context { program_cache_identity }
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.session.context {
    bind_options,
    context_program,
    cache_scope
}
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.workspace {
    app_for_path,
    workspace_for_path,
    app_fact_digest
}

glob CONFIG: str = '[project]\nname="contexts"\ndefault-app="web"\n[apps.web]\nkind="web-app"\nentry-point="web"\n[apps.api]\nkind="service"\nentry-point="api"\n';

def workspace(base: Path) {
    (base / 'jac.toml').write_text(CONFIG);
    (base / 'web.jac').write_text('def page -> int { return 1; }\n');
    (base / 'api.jac').write_text('def:pub count -> int { return 2; }\n');
    (base / 'shared.jac').write_text('node Item { has label: str = ""; }\n');
}

test "only declared entries have a filesystem app identity" {
    with TemporaryDirectory() as td {
        base = Path(td);
        workspace(base);
        web = app_for_path(str(base / 'web.jac'));
        api = app_for_path(str(base / 'api.jac'));
        assert web is not None and web.name == 'web';
        assert api is not None and api.name == 'api';
        assert app_for_path(str(base / 'shared.jac')) is None;
        assert web.effective_route() == '/api/web';
        assert api.effective_route() == '/api/api';
        assert app_fact_digest(web) != app_fact_digest(api);
    }
}

test "workspace probes scale with modules within a compilation request" {
    import from unittest.mock { patch }
    import from jaclang.compiler.session.context { compilation_scope, context_app }
    with TemporaryDirectory() as td {
        base = Path(td);
        workspace(base);
        path = str(base / 'shared.jac');
        options = CompileOptions(project_root=td, target_app='web');
        with compilation_scope('web', options) {
            with patch('os.lstat', wraps=os.lstat) as probe {
                app = context_app(path);
                assert app is not None and app.name == 'web';
                first = probe.call_count;
                for i in range(40) {
                    assert context_app(path) is app;
                }
                assert probe.call_count == first , (
                    f'repeated module facts made {probe.call_count
                        - first} extra filesystem probes'
                );
            }
            with compilation_scope(
                'api', CompileOptions(project_root=td, target_app='api')
            ) {
                other = context_app(path);
                assert other is not None and other.name == 'api';
            }
            assert context_app(path) is app;
        }
        toml = base / 'jac.toml';
        stamp = os.path.getmtime(toml) + 2.0;
        toml.write_text(CONFIG.replace('web-app', 'desktop'));
        os.utime(toml, (stamp, stamp));
        with compilation_scope('web', options) {
            refreshed = context_app(path);
            assert refreshed is not None and refreshed.kind == 'desktop' , (
                f'workspace edit was not observed: {refreshed}'
            );
        }
    }
}

test "application identity scopes observe workspace edits between requests" {
    import from jaclang.compiler.session.context { context_app }
    with TemporaryDirectory() as td {
        base = Path(td);
        workspace(base);
        path = str(base / 'shared.jac');
        options = CompileOptions(project_root=td, target_app='web');
        with cache_scope('web', options) {
            first = context_app(path);
            assert first is not None and first.kind == 'web-app';
            toml = base / 'jac.toml';
            stamp = os.path.getmtime(toml) + 2.0;
            toml.write_text(CONFIG.replace('web-app', 'desktop'));
            os.utime(toml, (stamp, stamp));
            refreshed = context_app(path);
            assert refreshed is not None and refreshed.kind == 'desktop' , (
                'an application identity scope must not retain old workspace facts'
            );
        }
    }
}

test "a normal import inherits its app and an entry import changes context" {
    with TemporaryDirectory() as td {
        base = Path(td);
        workspace(base);
        program = JacProgram();
        web_options = bind_options(
            str(base / 'web.jac'), program, CompileOptions(no_cgen=True)
        );
        web = context_program(program, web_options);
        shared_options = bind_options(
            str(base / 'shared.jac'), web, CompileOptions(no_cgen=True)
        );
        assert shared_options.target_app == 'web';
        assert context_program(web, shared_options) is web;
        api_options = bind_options(
            str(base / 'api.jac'), web, CompileOptions(no_cgen=True)
        );
        api = context_program(web, api_options);
        assert api is not web and api.options.target_app == 'api';
        assert bind_options(str(base / 'api.jac'), web, web.options).ui == '';
        assert api.source_store is web.source_store;
        assert bind_options(str(base / 'shared.jac'), api, CompileOptions()).target_app
            == 'api';
        assert context_program(api, web_options) is web;
    }
}

test "context identity resolves implicit defaults without merging distinct targets" {
    import copy;
    import from unittest.mock { patch }
    import jaclang.compiler.session.target_options as targets;
    import from jaclang.compiler.session.context { context_identity }
    implicit = CompileOptions(aot_mode=True, entry_point='/tmp/context-entry.jac');
    explicit = copy.copy(implicit);
    explicit.default_codespace = 'native';
    with patch.object(targets, 'effective_default_codespace', return_value='native') {
        assert context_identity(implicit) == context_identity(explicit);
        program = JacProgram();
        selected = context_program(program, implicit);
        assert context_program(program, explicit) is selected;
        for name in (
            'default_codespace',
            'force_codespace',
            'target_app',
            'entry_point'
        ) {
            distinct = copy.copy(explicit);
            setattr(distinct, name, 'client');
            assert context_program(program, distinct) is not selected;
        }
    }
    with patch.object(targets, 'effective_default_codespace', return_value='server') {
        assert context_identity(implicit) != context_identity(explicit);
    }
    assert implicit.default_codespace == '';
}

test "native imports reuse the context selected by the effective project default" {
    import from unittest.mock { patch }
    import jaclang.compiler.session.target_options as targets;
    import from jaclang.compiler.backends.common.artifact_store { artifact_for }
    with TemporaryDirectory() as td {
        entry_path = Path(td) / 'entry.jac';
        helper = Path(td) / 'helper.jac';
        entry_path.write_text(
            'import from helper { increment }\n'
            'def answer(value: int) -> int { return increment(value); }\n'
        );
        helper.write_text('def increment(value: int) -> int { return value + 1; }\n');
        program = JacProgram();
        compiler = program._get_compiler();
        with patch.object(
            targets, 'effective_default_codespace', return_value='native'
        ), patch.object(compiler, 'parse_str', wraps=compiler.parse_str) as parse {
            module = program.compile(
                str(entry_path),
                options=CompileOptions(
                    aot_mode=True, force_target_program=True, no_ir_cache=True
                )
            );
            assert not program.errors_had , [str(e) for e in program.errors_had];
            assert artifact_for(module).llvm_ir is not None;
            assert len(program.contexts) == 1;
            assert sum(call.args[1] == str(helper) for call in parse.call_args_list)
                == 1;
        }
    }
}

test "shared syntax produces distinct app facts in either request order" {
    for names in [('web', 'api'), ('api', 'web')] {
        with TemporaryDirectory() as td {
            base = Path(td);
            workspace(base);
            program = JacProgram();
            modules = [];
            for name in names {
                options = bind_options(
                    str(base / (name + '.jac')), program, CompileOptions(no_cgen=True)
                );
                selected = context_program(program, options);
                modules.append(
                    selected.compile(str(base / 'shared.jac'), options=options)
                );
            }
            assert not program.errors_had , '\n'.join(
                str(e) for e in program.errors_had
            );
            assert modules[0] is not modules[1];
            assert modules[0].app == names[0];
            assert modules[1].app == names[1];
            assert program.source_store.hits > 0;
        }
    }
}

test "contextual artifacts cannot overwrite another app cache slot" {
    import from jaclang.compiler.session.cache.artifact_codec { get_module_cache_path }
    with TemporaryDirectory() as td {
        base = Path(td);
        workspace(base);
        program = JacProgram();
        slots = [];
        for name in ['web', 'api'] {
            options = bind_options(
                str(base / (name + '.jac')), program, CompileOptions()
            );
            selected = context_program(program, options);
            with cache_scope(program_cache_identity(selected), selected.options) {
                slots.append(get_module_cache_path(str(base / 'shared.jac')));
            }
        }
        assert slots[0] != slots[1];
    }
}

test "placement reuses an untyped dependency tree across app contexts" {
    import from unittest.mock { patch }
    import from jaclang.compiler.pipeline.contracts { AnalysisFact }
    with TemporaryDirectory() as td {
        base = Path(td);
        workspace(base);
        program = JacProgram();
        web = context_program(
            program,
            bind_options(str(base / 'web.jac'), program, CompileOptions(no_cgen=True))
        );
        path = str(base / 'api.jac');
        first = web.load_dependency_module(path, need_tree=True);
        api = context_program(web, bind_options(path, web, web.options));
        assert api is not web;
        assert not api.analysis.provides(first, AnalysisFact.TYPE_OF);
        with patch.object(
            web,
            'compile',
            side_effect=AssertionError('placement rebuilt a symbol tree')
        ) {
            for need_tree in [True, False, True] {
                assert web.load_dependency_module(path, need_tree=need_tree) is first;
            }
        }
    }
}

test "implicit projects still identify their entry" {
    with TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text('[project]\nname="hello"\nkind="cli"\n');
        (base / 'main.jac').write_text('with entry { print(1); }\n');
        spec = workspace_for_path(str(base / 'main.jac'));
        assert spec is not None and not spec.explicit;
        app = app_for_path(str(base / 'main.jac'));
        assert app is not None and app.implicit and app.name == 'hello';
        assert app_for_path(str(base / 'helper.jac')) is None;
    }
}

test "repeated dependency imports reuse their prepared contextual facts" {
    import from jaclang.compiler.pipeline.keys { PLACEMENT_SUMMARY }
    with TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text(
            '[project]\nname="cached"\n[placement]\ndefault="server"\n'
        );
        path = str(base / 'helper.jac');
        Path(path).write_text('def answer -> int { return 42; }\n');
        options = CompileOptions(no_cgen=True, iface_ok=True, project_root=td);
        cold = JacProgram();
        cold = context_program(cold, bind_options(path, cold, options));
        assert cold.iface_registry().ensure(path) is not None;
        assert not cold.errors_had;
        warm = JacProgram();
        warm = context_program(warm, bind_options(path, warm, options));
        module = warm.load_dependency_module(path);
        context = warm.module_context(module);
        assert module.stub_only;
        summary = context.analysis.lookup(path, PLACEMENT_SUMMARY);
        assert summary is not None;
        runs = dict(context.analysis.pass_runs);
        assert context.load_dependency_module(path) is module;
        assert context.analysis.pass_runs == runs;
        assert context.analysis.lookup(path, PLACEMENT_SUMMARY) is summary;
    }
}

test "application traversal checks imported bodies on cold and warm requests" {
    import from jaclang.compiler.api { compile_application }
    with TemporaryDirectory() as td {
        base = Path(td);
        entry_path = str(base / 'main.jac');
        helper_path = str(base / 'helper.jac');
        (base / 'main.jac').write_text(
            'import from helper { count }\ndef run -> int { return count(); }\n'
        );
        (base / 'helper.jac').write_text('def count -> int { return 1; }\n');
        options = CompileOptions(no_cgen=True, iface_ok=True, project_root=td);
        cold = JacProgram();
        compile_application(cold, entry_path, options);
        assert not cold.errors_had;
        assert cold.source_store.parses == 2;
        (base / 'helper.jac').write_text('def count -> int { return "bad"; }\n');
        for iteration in range(2) {
            checked = JacProgram();
            compile_application(checked, entry_path, options);
            assert any(
                alert.loc.mod_path == helper_path
                    and alert.code is not None
                    and alert.code.code == 'E1002' for alert in checked.errors_had
            ) , f'imported body escaped checking on request {iteration}';
        }
    }
}
