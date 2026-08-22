import from pathlib { Path }
import os;
import json;
import from jaclang.cli.console { console }
import from jaclang.runtimelib.bun_entry { EndpointMeta, build_bun_server_entry_script }


def emit_server_entry(
    out_dir: Path,
    project_name: str,
    compiled_modules: list,
    walkers: list[EndpointMeta],
    functions: list[EndpointMeta],
    promotions: dict[str, list[str]] | None = None
) -> int {
    out_dir.mkdir(parents=True, exist_ok=True);
    module_imports: list[str] = [];
    handler_imports: list[str] = [];

    for w in walkers {
        if not w.`pub {
            continue;
        }
        wn = w.name;
        mod = w.module.replace('.', '/');
        module_imports.append(f'import {{ {wn} as _W_{wn} }} from "./{mod}.js";');
        handler_imports.append(
            'async function _spawn_'
                + wn
                + '(fields) { return execWalker(_W_'
                + wn
                + ', fields); }'
        );
    }
    for f in functions {
        if not f.`pub {
            continue;
        }
        fn = f.name;
        mod = f.module.replace('.', '/');
        module_imports.append(f'import {{ {fn} as _F_{fn} }} from "./{mod}.js";');
    }

    import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compiler { run_pass }
    import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
    runtime_src = Path(resolve_client_runtime_cl_path('bun'));
    # server_runtime.jac is a JS-interop module: it deliberately uses JS
    # idioms (Reflect.apply, dot-dict access, `match` attribute names) that
    # the Jac checker rejects. Compile with type_check=False EXPLICITLY so
    # this boundary is visible and intentional, not an accident of defaults.
    # Drift is caught by the bun e2e suites, which execute the artifact
    # through real Bun.build (mislowered or invalid JS fails the build).
    import from jaclang.jac0core.compile_options { CompileOptions }
    prog = JacProgram();
    rt_mod = prog.compile(
        str(runtime_src), options=CompileOptions(type_check=False)
    );
    if rt_mod is not None {
        run_pass(EsastGenPass, rt_mod, prog);
    }
    if prog.errors_had or not rt_mod?.gen?.js {
        console.error('  server: failed to compile server_runtime.jac');
        return 1;
    }
    runtime_js = rt_mod.gen.js;
    (out_dir / 'server_runtime.js').write_text(runtime_js, encoding='utf-8');
    import jaclang.runtimelib as _rt_pkg;
    bun_store_src = Path(os.path.dirname(_rt_pkg.__file__)) / 'bun_store.js';
    if bun_store_src.exists() {
        (out_dir / 'bun_store.js').write_text(
            bun_store_src.read_text(encoding='utf-8'), encoding='utf-8'
        );
        import from jaclang.runtimelib.store { SCHEMA_SQL }
        schema_js = (
            '// GENERATED from jaclang.runtimelib.store.SCHEMA_SQL — do not edit.\n'
            + 'export const SCHEMA_SQL = '
            + repr([str(stmt) for stmt in SCHEMA_SQL])
            + ';\n'
        );
        # Baked at build time from [database.indexes] via promotions_for() so
        # BunStore computes the same schema fingerprint as PgStore.
        schema_js += 'export const PROMOTIONS = ' + json.dumps(
            promotions or {}, sort_keys=True
        ) + ';\n';
        (out_dir / 'bun_schema.js').write_text(schema_js, encoding='utf-8');
    }
    for unit in compiled_modules {
        if not unit.get('js') {
            continue;
        }
        rel = str(unit['rel']).replace('.jac', '.js');
        dest = out_dir / rel;
        dest.parent.mkdir(parents=True, exist_ok=True);
        dest.write_text(str(unit['js']), encoding='utf-8');
    }

    entry_script = build_bun_server_entry_script(
        project_name, walkers, functions, module_imports, handler_imports
    );
    (out_dir / 'server.mjs').write_text(entry_script, encoding='utf-8');
    return 0;
}
