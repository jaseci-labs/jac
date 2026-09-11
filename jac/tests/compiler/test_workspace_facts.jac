"""Entry declarations are boundaries; ordinary imports inherit compilation context."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context {
    bind_options,
    context_program,
    cache_scope
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.placement.workspace {
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
    import from jaclang.compiler.driver.jir { get_module_cache_path }
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
            with cache_scope(selected.context_key) {
                slots.append(get_module_cache_path(str(base / 'shared.jac')));
            }
        }
        assert slots[0] != slots[1];
    }
}

test "placement reuses an untyped dependency tree across app contexts" {
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
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
        assert not api.analysis.analyses_run.provides(first, AnalysisFact.TYPE_OF);
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

test "application traversal checks imported bodies on cold and warm requests" {
    import from jaclang.compiler.driver.pipeline { compile_application }
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
