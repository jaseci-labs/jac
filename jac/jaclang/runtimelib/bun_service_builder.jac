import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.constant { SymbolType }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.server_entry { emit_server_entry }
import from jaclang.runtimelib.bun_entry { EndpointMeta }


def _string_bundle_bun_artifact(out_dir: Path, module_name: str) -> str {
    chunks: list[str] = [f'// Bundled Bun sv service artifact for {module_name!r}'];
    bundled_sources = (
        'server_runtime.js',
        'bun_schema.js',
        'bun_store.js',
        f'{module_name}.js'
    );

    def _rewrite_entry_line(line: str) -> (str | None) {
        for src in bundled_sources {
            if f'from "./{src}"' not in line {
                continue;
            }
            if ' as ' not in line or not line.startswith('import ') {
                return None;
            }
            spec = line[len('import {'):line.rindex('}')].strip();
            aliases: list[str] = [];
            for pair in spec.split(',') {
                (orig, alias) = [p.strip() for p in pair.split(' as ')];
                aliases.append(f'const {alias} = {orig};');
            }
            return ' '.join(aliases);
        }
        return line;
    }

    def _keep_line(line: str) -> bool {
        for src in bundled_sources {
            if f'from "./{src}"' in line {
                return False;
            }
        }
        return True;
    }

    runtime_path = out_dir / 'server_runtime.js';
    if runtime_path.exists() {
        runtime_text = runtime_path.read_text(encoding='utf-8');
        chunks.append(
            '\n'.join(
                [ln for ln in runtime_text.splitlines() if _keep_line(ln)]
            )
        );
    }
    schema_path = out_dir / 'bun_schema.js';
    if schema_path.exists() {
        chunks.append(schema_path.read_text(encoding='utf-8'));
    }
    bun_store_path = out_dir / 'bun_store.js';
    if bun_store_path.exists() {
        chunks.append(bun_store_path.read_text(encoding='utf-8'));
    }
    module_js = out_dir / f'{module_name}.js';
    if module_js.exists() {
        chunks.append(module_js.read_text(encoding='utf-8'));
    }
    entry_lines: list[str] = [];
    for line in (out_dir / 'server.mjs').read_text(encoding='utf-8').splitlines() {
        rewritten = _rewrite_entry_line(line);
        if rewritten is not None {
            entry_lines.append(rewritten);
        }
    }
    chunks.append('\n'.join(entry_lines));
    bundle = '\n'.join(chunks) + '\n';
    if 'const _jac' not in bundle and '_jac.' in bundle {
        import from jaclang.compiler.passes.ecmascript.jac_runtime_js {
            build_jac_runtime_js
        }
        bundle = f'const _jac = {build_jac_runtime_js()};\n' + bundle;
    }
    return bundle;
}


def _bundle_bun_artifact(out_dir: Path, module_name: str, artifact: Path) -> None {
    import shutil;
    import subprocess;
    server_entry = out_dir / 'server.mjs';
    bun_bin = shutil.which('bun');
    if bun_bin {
        try {
            result = subprocess.run(
                [
                    bun_bin,
                    'build',
                    str(server_entry),
                    '--outdir',
                    str(artifact.parent),
                    '--outfile',
                    artifact.stem,
                    '--target=bun',
                    '--format=esm'
                ],
                capture_output=True,
                text=True,
                timeout=120
            );
            if result.returncode == 0 {
                # bun names the bundle after the entry file (server.js),
                # regardless of --outfile — locate and rename it.
                built = artifact.parent / 'server.js';
                if not built.exists() {
                    built = Path(f"{artifact.parent / artifact.stem}.js");
                }
                if built.exists() {
                    built.replace(artifact);
                    return;
                }
            }
            console.print(
                f"  Bun.build failed for '{module_name}'; using string bundler"
                    + (f": {result.stderr.strip()}" if result.stderr.strip() else ''),
                style='warning'
            );
        } except Exception as e {
            console.print(f'  Bun.build unavailable ({e}); using string bundler');
        }
    }
    artifact.write_text(_string_bundle_bun_artifact(out_dir, module_name), encoding='utf-8');
}


def build_bun_service_artifact(
    module_name: str, base_path: str, project_name: str = ''
) -> Path {
    import from jaclang.jac0core.program { JacProgram }
    base_dir = Path(base_path);
    module_file = base_dir / f"{module_name}.jac";
    if not module_file.exists() {
        raise RuntimeError(
            f"Bun service '{module_name}': file not found at {module_file}"
        );
    }
    prog = JacProgram();
    import from jaclang.jac0core.compile_options { CompileOptions }
    ir = prog.compile(
        file_path=str(module_file),
        options=CompileOptions(force_codespace='client', type_check=False)
    );
    if prog.errors_had {
        errs = '\n'.join(str(e) for e in prog.errors_had);
        raise RuntimeError(f"Failed to compile {module_file}:\n{errs}");
    }
    import from jaclang.jac0core.compiler { run_pass }
    import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
    js_code = ir.gen.js if ir is not None and ir.gen is not None else '';
    if ir is not None and not js_code.strip() {
        run_pass(EsastGenPass, ir, prog);
        js_code = ir.gen.js or '';
    }
    if not js_code.strip() {
        raise RuntimeError(f"Bun service '{module_name}' produced no JS output");
    }

    walkers: list[EndpointMeta] = [];
    functions: list[EndpointMeta] = [];
    import from jaclang.jac0core.constant { Tokens as Tok }
    for item in ir.body {
        if isinstance(item, uni.Archetype)
            and item.sym_category == SymbolType.WALKER_ARCH {
            walkers.append(
                EndpointMeta(
                    name=str(item.name.sym_name),
                    module=module_name,
                    `pub=item.access is not None and item.access.tag.name == Tok.KW_PUB
                )
            );
        } elif isinstance(item, uni.Ability) and item.name_ref is not None {
            fn_name = str(item.name_ref.sym_name);
            if fn_name.startswith('_') {
                continue;
            }
            fn_params: list[str] = [];
            if isinstance(item.signature, uni.FuncSignature) {
                for pvar in item.signature.get_parameters() {
                    if pvar.name is not None {
                        fn_params.append(str(pvar.name.sym_name));
                    }
                }
            }
            functions.append(
                EndpointMeta(
                    name=fn_name,
                    module=module_name,
                    `pub=item.access is not None and item.access.tag.name == Tok.KW_PUB,
                    params=fn_params
                )
            );
        }
    }

    out_dir = base_dir / '.jac' / 'server' / module_name;
    if out_dir.exists() {
        import shutil;
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);
    endpoint_names = [w.name for w in walkers] + [f.name for f in functions];
    if endpoint_names and 'export' not in js_code {
        js_code = js_code.rstrip() + f"\nexport {{{', '.join(endpoint_names)}}};\n";
    }
    pname = project_name or module_name;
    import from jaclang.runtimelib.session { promotions_for }
    # Single enforcement point for endpoint visibility: only `pub` endpoints
    # become network surface (routes, listings, handlers). Full lists are
    # still exported from the module so non-pub symbols remain importable
    # internally. Mirrors the cpython host, where non-pub endpoints default
    # to auth-required and the bun host has no auth layer yet.
    rc = emit_server_entry(
        out_dir,
        pname,
        [{'rel': f"{module_name}.jac", 'js': js_code}],
        [w for w in walkers if w.`pub],
        [f for f in functions if f.`pub],
        promotions=promotions_for(base_path)
    );
    if rc != 0 {
        raise RuntimeError(f"Failed to emit Bun server entry for '{module_name}'");
    }
    artifact = base_dir / '.jac' / 'server' / f"{module_name}.mjs";
    _bundle_bun_artifact(out_dir, module_name, artifact);
    import from jaclang.jac0core.sv_service_host {
        bun_artifact_stamp_path,
        bun_service_inputs_digest
    }
    bun_artifact_stamp_path(module_name, str(base_dir)).write_text(
        bun_service_inputs_digest(module_name, str(base_dir)), encoding='utf-8'
    );
    console.print(f"  ✔ Bun service artifact: {artifact}", style='success');
    return artifact;
}
