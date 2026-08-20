import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.constant { SymbolType, CodeContext }
import from jaclang.jac0core.placement { module_has_root_access }
import from jaclang.cli.console { console }
import from jaclang.cli.commands.eject_targets.server_entry { emit_server_entry }


def _bundle_bun_artifact(out_dir: Path, module_name: str) -> str {
    chunks: list[str] = [
        f'// Bundled Bun sv service artifact for {module_name!r}'
    ];
    runtime_path = out_dir / 'server_runtime.js';
    if runtime_path.exists() {
        chunks.append(runtime_path.read_text(encoding='utf-8'));
    }
    module_js = out_dir / f'{module_name}.js';
    if module_js.exists() {
        chunks.append(module_js.read_text(encoding='utf-8'));
    }
    skip_markers = (
        'from "./server_runtime.js"',
        f'from "./{module_name}.js"'
    );
    entry_lines: list[str] = [];
    should_skip: bool = False;
    for line in (out_dir / 'server.mjs').read_text(encoding='utf-8').splitlines() {
        should_skip = False;
        for marker in skip_markers {
            if marker in line {
                should_skip = True;
                break;
            }
        }
        if not should_skip {
            entry_lines.append(line);
        }
    }
    chunks.append('\n'.join(entry_lines));
    return '\n'.join(chunks) + '\n';
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
    ir = prog.compile(file_path=str(module_file));
    if prog.errors_had {
        errs = '\n'.join(str(e) for e in prog.errors_had);
        raise RuntimeError(f"Failed to compile {module_file}:\n{errs}");
    }
    if module_has_root_access(ir) {
        raise RuntimeError(
            f"Bun hosting is opt-in and stateless: '{module_name}' touches "
                + "root/graph persistence (module_has_root_access). Use CPython "
                + "sv or wait for P2 PERSIST on bun."
        );
    }
    js_code = ir.gen.js or '';
    if not js_code.strip() {
        raise RuntimeError(f"Bun service '{module_name}' produced no JS output");
    }

    walkers: list = [];
    functions: list = [];
    for item in ir.body {
        if item?.code_context == CodeContext.CLIENT {
            continue;
        }
        if isinstance(item, uni.Archetype) and item.sym_category == SymbolType.WALKER_ARCH {
            walkers.append(
                {
                    'name': str(item.name.sym_name),
                    'module': module_name,
                    'pub': item.access is not None and 'pub' in str(item.access)
                }
            );
        } elif isinstance(item, uni.Ability) and item.name_ref is not None {
            fn_name = str(item.name_ref.sym_name);
            if fn_name.startswith('_') {
                continue;
            }
            functions.append(
                {
                    'name': fn_name,
                    'module': module_name,
                    'pub': item.access is not None and 'pub' in str(item.access)
                }
            );
        }
    }

    out_dir = base_dir / '.jac' / 'server' / module_name;
    if out_dir.exists() {
        import shutil;
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);
    pname = project_name or module_name;
    rc = emit_server_entry(
        out_dir,
        pname,
        [{'rel': f"{module_name}.jac", 'js': js_code}],
        walkers,
        functions
    );
    if rc != 0 {
        raise RuntimeError(f"Failed to emit Bun server entry for '{module_name}'");
    }
    artifact = base_dir / '.jac' / 'server' / f"{module_name}.mjs";
    artifact.write_text(_bundle_bun_artifact(out_dir, module_name), encoding='utf-8');
    console.print(f"  ✔ Bun service artifact: {artifact}", style='success');
    return artifact;
}
