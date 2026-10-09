import jaclang.compiler.frontend.unitree as uni;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.frontend.constant { SymbolType, Tokens as Tok }
import from jaclang.cli.console { console }
import from jaclang.server_entry { emit_server_entry }
import from jaclang.bun_entry { EndpointMeta }


def _is_pub(access: any) -> bool {
    return access is not None and access.tag.name == Tok.KW_PUB;
}


def _inline_extra_deps(out_dir: Path, chunks: list[str], seen_jac: dict[str, bool]) {
    import re;
    bundled_sources = (
        'server_runtime.js',
        'bun_schema.js',
        'bun_store.js',
        'jac_runtime.js'
    );
    extras = [
        p
        for p in sorted(out_dir.iterdir())
        if p.suffix == '.js'
            and p.name not in bundled_sources
            and p.name != 'server.mjs'
    ];
    local = {p.name for p in extras};
    for path in extras {
        kept: list[str] = [];
        for ln in path.read_text(encoding='utf-8').splitlines() {
            mt = re.search(r'^import\s+[^;]*?[\"\']\./([^\"\']+\.js)[\"\']', ln);
            if mt and mt.group(1) in local {
                continue;
            }
            kept.append(ln);
        }
        text = '\n'.join(kept);

        def _jac_repl(m: any) -> str {
            if seen_jac['seen'] {
                return '';
            }
            seen_jac['seen'] = True;
            return m.group(0);
        }
        text = re.sub(r'const _jac = \{.*?\n\};', _jac_repl, text, flags=re.DOTALL);
        chunks.append(text);
        seen_jac['seen'] = True;
    }
}


def _string_bundle_bun_artifact(out_dir: Path, module_name: str) -> str {
    chunks: list[str] = [f'// Bundled Bun sv service artifact for {module_name!r}'];
    bundled_sources = (
        'server_runtime.js',
        'bun_schema.js',
        'bun_store.js',
        'jac_runtime.js',
        f'{module_name}.js'
    );

    def _rewrite_entry_line(line: str) -> str {
        for src in bundled_sources {
            if f'from "./{src}"' not in line {
                continue;
            }
            if not line.startswith('import ') or '{' not in line or '}' not in line {
                raise RuntimeError(
                    f'String bundler cannot rewrite import line for '
                        + f'\'{src}\': {line!r}. Bun.build output shape changed; '
                        + 'fix or remove _string_bundle_bun_artifact.'
                );
            }
            spec = line[len('import {'):line.rindex('}')].strip();
            aliases: list[str] = [];
            for pair in spec.split(',') {
                parts = [p.strip() for p in pair.split(' as ')];
                if len(parts) == 2 {
                    aliases.append(f'const {parts[1]} = {parts[0]};');
                }
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

    seen_jac: dict[str, bool] = {'seen': False};
    jac_rt_path = out_dir / 'jac_runtime.js';
    if jac_rt_path.exists() {
        kept_jac: list[str] = [];
        for ln in jac_rt_path.read_text(encoding='utf-8').splitlines() {
            if not _keep_line(ln) {
                continue;
            }
            kept_jac.append(ln);
            if 'const _jac' in ln {
                seen_jac['seen'] = True;
            }
        }
        chunks.append('\n'.join(kept_jac));
    }
    runtime_path = out_dir / 'server_runtime.js';
    if runtime_path.exists() {
        runtime_text = runtime_path.read_text(encoding='utf-8');
        kept_rt: list[str] = [];
        for ln in runtime_text.splitlines() {
            if not _keep_line(ln) {
                continue;
            }
            kept_rt.append(ln);
            if 'const _jac' in ln {
                seen_jac['seen'] = True;
            }
        }
        chunks.append('\n'.join(kept_rt));
    }
    schema_path = out_dir / 'bun_schema.js';
    if schema_path.exists() {
        chunks.append(schema_path.read_text(encoding='utf-8'));
    }
    bun_store_path = out_dir / 'bun_store.js';
    if bun_store_path.exists() {
        chunks.append(bun_store_path.read_text(encoding='utf-8'));
    }
    _inline_extra_deps(out_dir, chunks, seen_jac);
    module_js = out_dir / f'{module_name}.js';
    if module_js.exists() {
        chunks.append(module_js.read_text(encoding='utf-8'));
    }
    entry_lines: list[str] = [
        _rewrite_entry_line(ln)
        for ln in (out_dir / 'server.mjs').read_text(encoding='utf-8').splitlines()
    ];
    chunks.append('\n'.join(entry_lines));
    bundle = '\n'.join(chunks) + '\n';
    if 'const _jac' not in bundle and '_jac.' in bundle {
        import from jaclang.compiler.backends.es.jac_runtime_js { build_jac_runtime_js }
        bundle = f'const _jac = {build_jac_runtime_js()};\n' + bundle;
    }
    return bundle;
}


def _bundle_bun_artifact(out_dir: Path, module_name: str, artifact: Path) -> None {
    import subprocess;
    server_entry = out_dir / 'server.mjs';
    bun_bin = shutil.which('bun');
    if bun_bin {
        rt_path = out_dir / 'server_runtime.js';
        rt_original: (str | None) = None;
        try {
            rt_text = rt_path.read_text(encoding='utf-8');
            if '__jacInitBunStore' in rt_text
                and 'from "./bun_store.js"' not in rt_text {
                rt_original = rt_text;
                rt_path.write_text(
                    'import { __jacCommitGraph, __jacEnsureRoot, __jacInitBunStore, '
                        + '__jacInstallOspPersistHooks, __jacServerSpawnWalker } '
                        + 'from "./bun_store.js";\n'
                        + rt_text,
                    encoding='utf-8'
                );
            }
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
                built = artifact.parent / 'server.js';
                if not built.exists() {
                    built = Path(f"{artifact.parent / artifact.stem}.js");
                }
                if built.exists() {
                    built.replace(artifact);
                    return;
                }
            }
            if rt_original is not None {
                rt_path.write_text(rt_original, encoding='utf-8');
            }
            console.print(
                f"  Bun.build failed for '{module_name}'; using string bundler"
                    + (f": {result.stderr.strip()}" if result.stderr.strip() else ''),
                style='warning'
            );
        } except Exception as e {
            if rt_original is not None {
                rt_path.write_text(rt_original, encoding='utf-8');
            }
            console.print(f'  Bun.build unavailable ({e}); using string bundler');
        }
    }
    artifact.write_text(
        _string_bundle_bun_artifact(out_dir, module_name), encoding='utf-8'
    );
}


def _cl_stdlib_specifiers(js_code: str) -> list[str] {
    import re;
    found: list[str] = [];
    seen: set[str] = set();
    for m in re.finditer(r"from\s+['\"]([^'\"]+)['\"]", js_code) {
        spec = m.group(1);
        if spec not in seen {
            seen.add(spec);
            found.append(spec);
        }
    }
    for m in re.finditer(r"import\s+['\"]([^'\"]+)['\"]", js_code) {
        spec = m.group(1);
        if spec not in seen {
            seen.add(spec);
            found.append(spec);
        }
    }
    return [
        s
        for s in found
        if not s.startswith('.') and not s.startswith('/')
    ];
}


def _cl_stdlib_ref(dotted: str) -> tuple[(str, str)] | None {
    import os;
    import from jaclang.compiler.frontend.codeinfo { cl_stdlib_root }
    stdlib_root = cl_stdlib_root();
    if not stdlib_root or not dotted {
        return None;
    }
    rel = dotted.replace('.', os.sep);
    plain = os.path.join(stdlib_root, rel + '.jac');
    if os.path.isfile(plain) {
        return (rel, plain);
    }
    pkg_init = os.path.join(stdlib_root, rel, '__init__.jac');
    if os.path.isfile(pkg_init) {
        return (os.path.join(rel, '__init__'), pkg_init);
    }
    return None;
}


def _rewrite_bare_specifiers(
    js_code: str, resolved: dict[str, str], depth: int
) -> str {
    if not resolved {
        return js_code;
    }
    import re;
    prefix = ('../' * depth) or './';

    def _sub(m: any) -> str {
        spec = m.group(2);
        src = resolved.get(spec);
        if src is None {
            return m.group(0);
        }
        rel = f'{prefix}{src}.js';
        if m.group(1).startswith('from') {
            return f'from "{rel}"';
        }
        base = spec.split('/')[-1];
        return f'import * as {base} from "{rel}"';
    }
    return re.sub(r'(from\s+[\"\']|import\s+[\"\'])([^\"\']+)([\"\'])', _sub, js_code);
}


def _dep_export_names(dep_js: str) -> list[str] {
    import re;
    exported: set[str] = set();
    for m in re.finditer(r'export\s*\{([^}]*)\}', dep_js) {
        for part in m.group(1).split(',') {
            exported.add(part.strip());
        }
    }
    names: list[str] = [];
    seen: set[str] = set();
    for m in re.finditer(
        r'^(?:async\s+)?(?:function|class|const|let|var)\s+([A-Za-z_$][\w$]*)',
        dep_js,
        re.MULTILINE
    ) {
        name = m.group(1);
        if (name not in seen and not name.startswith('_') and name not in exported) {
            seen.add(name);
            names.append(name);
        }
    }
    return names;
}


def _emit_cl_stdlib_deps(js_code: str, prog: any, options: any, out_dir: Path) -> str {
    import from jaclang.compiler.driver.pass_driver { run_pass }
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    resolved: dict[str, str] = {};
    pending: list[tuple[str, int]] = [(s, 0) for s in _cl_stdlib_specifiers(js_code)];
    while pending {
        (spec, depth) = pending.pop();
        if spec in resolved {
            continue;
        }
        ref = _cl_stdlib_ref(spec.replace('/', '.'));
        if ref is None {
            continue;
        }
        (src_name, dep_path) = ref;
        resolved[spec] = src_name;
        target = out_dir / f"{src_name}.js";
        if target.exists() {
            continue;
        }
        dep_mod = prog.compile(file_path=str(dep_path), options=options);
        dep_js = dep_mod.gen.js
            if dep_mod is not None and dep_mod.gen is not None
            else '';
        if dep_mod is not None and not dep_js.strip() {
            run_pass(EsastGenPass, dep_mod, prog);
            dep_js = dep_mod.gen.js or '';
        }
        if not dep_js.strip() {
            continue;
        }
        target.parent.mkdir(parents=True, exist_ok=True);
        child_depth = src_name.count('/') + 1;
        next_specs = _cl_stdlib_specifiers(dep_js);
        dep_js = _rewrite_bare_specifiers(dep_js, resolved, child_depth);
        exports = _dep_export_names(dep_js);
        if exports {
            dep_js += f"\nexport {{{', '.join(exports)}}};\n";
        }
        target.write_text(dep_js, encoding='utf-8');
        for nxt in next_specs {
            if nxt not in resolved {
                pending.append((nxt, child_depth));
            }
        }
    }
    return _rewrite_bare_specifiers(js_code, resolved, 0);
}


def _extract_endpoints(
    ir: any, module_name: str
) -> (tuple[list[EndpointMeta], list[EndpointMeta]]) {
    walkers: list[EndpointMeta] = [];
    functions: list[EndpointMeta] = [];
    for item in ir.body {
        if isinstance(item, uni.Archetype)
            and item.sym_category == SymbolType.WALKER_ARCH {
            walkers.append(
                EndpointMeta(
                    name=str(item.name.sym_name),
                    module=module_name,
                    `pub=_is_pub(item.access)
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
                    `pub=_is_pub(item.access),
                    params=fn_params
                )
            );
        }
    }
    return (walkers, functions);
}


def build_bun_service_artifact(
    module_name: str, base_path: str, project_name: str = ''
) -> Path {
    import from jaclang.compiler.driver.program { JacProgram }
    base_dir = Path(base_path);
    module_file = base_dir / f"{module_name}.jac";
    if not module_file.exists() {
        raise RuntimeError(
            f"Bun service '{module_name}': file not found at {module_file}"
        );
    }
    prog = JacProgram();
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    ir = prog.compile(
        file_path=str(module_file), options=CompileOptions(force_codespace='client')
    );
    if prog.errors_had {
        errs = '\n'.join(str(e) for e in prog.errors_had);
        raise RuntimeError(f"Failed to compile {module_file}:\n{errs}");
    }
    import from jaclang.compiler.driver.pass_driver { run_pass }
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    js_code = ir.gen.js if ir is not None and ir.gen is not None else '';
    if ir is not None and not js_code.strip() {
        run_pass(EsastGenPass, ir, prog);
        js_code = ir.gen.js or '';
    }
    if not js_code.strip() {
        raise RuntimeError(f"Bun service '{module_name}' produced no JS output");
    }

    (walkers, functions) = _extract_endpoints(ir, module_name);

    out_dir = base_dir / '.jac' / 'server' / module_name;
    if out_dir.exists() {
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);
    js_code = _emit_cl_stdlib_deps(
        js_code, prog, CompileOptions(force_codespace='client'), out_dir
    );
    endpoint_names = [w.name for w in walkers] + [f.name for f in functions];
    if endpoint_names and 'export' not in js_code {
        js_code = js_code.rstrip() + f"\nexport {{{', '.join(endpoint_names)}}};\n";
    }
    pname = project_name or module_name;
    import from jaclang.server.session { promotions_for }

    rc = emit_server_entry(
        out_dir,
        pname,
        [{'rel': f"{module_name}.jac", 'js': js_code}],
        [
            w
            for w in walkers
            if w.`pub
        ],
        [
            f
            for f in functions
            if f.`pub
        ],
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
