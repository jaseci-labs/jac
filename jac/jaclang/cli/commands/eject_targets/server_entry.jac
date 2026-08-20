import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.bun_entry { build_bun_server_entry_script }

def emit_server_entry(
    out_dir: Path,
    project_name: str,
    compiled_modules: list,
    walkers: list,
    functions: list
) -> int {
    out_dir.mkdir(parents=True, exist_ok=True);
    module_imports: list[str] = [];
    handler_imports: list[str] = [];

    for w in walkers {
        wn = str(w['name']);
        mod = str(w['module']).replace('.', '/');
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
        fn = str(f['name']);
        mod = str(f['module']).replace('.', '/');
        module_imports.append(f'import {{ {fn} as _F_{fn} }} from "./{mod}.js";');
    }

    import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
    runtime_src = Path(resolve_client_runtime_cl_path('bun'));
    runtime_js_path = runtime_src.with_suffix('.js');
    runtime_js = '';
    if runtime_js_path.exists() {
        runtime_js = runtime_js_path.read_text(encoding='utf-8');
    } elif runtime_src.suffix == '.js' {
        if not runtime_src.exists() {
            console.error(f'  server: missing runtime source {runtime_src}');
            return 1;
        }
        runtime_js = runtime_src.read_text(encoding='utf-8');
    } else {
        import from jaclang.jac0core.program { JacProgram }
        import from jaclang.jac0core.compiler { run_pass }
        import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
        prog = JacProgram();
        rt_mod = prog.compile(str(runtime_src));
        if rt_mod and rt_mod.gen and not rt_mod.gen.js {
            run_pass(EsastGenPass, rt_mod, prog);
        }
        if prog.errors_had or not rt_mod?.gen?.js {
            console.error('  server: failed to compile server_runtime.jac');
            return 1;
        }
        runtime_js = rt_mod.gen.js;
    }
    (out_dir / 'server_runtime.js').write_text(runtime_js, encoding='utf-8');
    handler_imports.insert(
        0, 'import { execWalker, startBunServer } from "./server_runtime.js";'
    );

    for unit in compiled_modules {
        if not unit.get('js') {
            continue;
        }
        rel = str(unit['rel']).replace('.jac', '.js');
        dest = out_dir / rel;
        dest.parent.mkdir(parents=True, exist_ok=True);
        dest.write_text(str(unit['js']), encoding='utf-8');
    }

    entry = build_bun_server_entry_script(
        project_name,
        walkers,
        functions,
        module_imports,
        handler_imports
    );
    (out_dir / 'server.mjs').write_text(entry, encoding='utf-8');
    return 0;
}
