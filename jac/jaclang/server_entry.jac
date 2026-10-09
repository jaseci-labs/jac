import from pathlib { Path }
import os;
import json;
import from jaclang.cli.console { console }
import from jaclang.bun_entry { EndpointMeta, build_bun_server_entry_script }


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
        fn = f.name;
        mod = f.module.replace('.', '/');
        module_imports.append(f'import {{ {fn} as _F_{fn} }} from "./{mod}.js";');
    }

    import from jaclang.client.runtime_source { resolve_client_runtime_cl_path }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.pass_driver { run_pass }
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    runtime_src = Path(resolve_client_runtime_cl_path('bun'));

    prog = JacProgram();
    rt_mod = prog.compile(str(runtime_src));
    if rt_mod is not None {
        run_pass(EsastGenPass, rt_mod, prog);
    }
    runtime_js = rt_mod?.gen?.js if rt_mod is not None else '';
    if not (runtime_js or '').strip() {
        console.error('  server: failed to lower server_runtime.jac');
        return 1;
    }

    import from jaclang.bun_service_builder { _dep_export_names }
    runtime_exports = _dep_export_names(runtime_js);
    if runtime_exports {
        runtime_js += f"\nexport {{{', '.join(runtime_exports)}}};\n";
    }
    (out_dir / 'server_runtime.js').write_text(runtime_js, encoding='utf-8');

    import from jaclang.compiler.backends.es.jac_runtime_js { build_jac_runtime_js }
    (out_dir / 'jac_runtime.js').write_text(
        f'const _jac = {build_jac_runtime_js()};\nexport {{ _jac }};\n',
        encoding='utf-8'
    );
    import jaclang as _jaclang_pkg;
    bun_store_src = Path(os.path.dirname(_jaclang_pkg.__file__)) / 'bun_store.js';
    if bun_store_src.exists() {
        (out_dir / 'bun_store.js').write_text(
            bun_store_src.read_text(encoding='utf-8'), encoding='utf-8'
        );
        import from jaclang.data.store { SCHEMA_SQL, SCHEMA_VERSION }
        schema_js = (
            '// GENERATED from jaclang.data.store.SCHEMA_SQL — do not edit.\n'
            + 'export const SCHEMA_SQL = '
            + repr([str(stmt) for stmt in SCHEMA_SQL])
            + ';\n'
            + f'export const SCHEMA_VERSION = {int(SCHEMA_VERSION)};\n'
        );

        schema_js += 'export const PROMOTIONS = '
            + json.dumps(promotions or {}, sort_keys=True)
            + ';\n';
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
