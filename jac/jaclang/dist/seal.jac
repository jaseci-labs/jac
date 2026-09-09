import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.console { console }


def seal_copy_ignore(_dir: str, items: list) -> list {
    drop = [
        "__pycache__",
        "node_modules",
        ".jac",
        "_precompiled",
        ".git",
        ".venv",
        "venv",
        "dist",
        "build",
        ".mypy_cache",
        ".pytest_cache"
    ];
    return [
        it
        for it in items
        if it in drop or it.endswith("-seal-stage")
    ];
}

def run_precompiler(src_dir: str, flags: list[str]) -> int {
    import sys;
    import subprocess;

    code = (
        "import _jac_finder as _jf; _jf.apply_dev_source_override(); _jf.install(); "
        "import sys; sys.argv = ['jac', 'precompile', "
        + repr(src_dir)
        + "] + "
        + repr(list(flags))
        + "; from jaclang.cli.cli_boot import start_cli; start_cli()"
    );
    return subprocess.call([sys.executable, "-c", code]);
}

def resolve_entry_file(config: any, app: str = "") -> (Path | None) {
    import from jaclang.dist.precompile_bytecode { bundle_app }

    proj_root = config.project_root;
    chosen = bundle_app(config, app);
    if chosen is None or proj_root is None {
        return None;
    }
    p = Path(chosen.entry_path(str(proj_root)));
    if p.is_file() {
        return p;
    }
    p2 = Path(str(p) + ".jac");
    if p2.is_file() {
        return p2;
    }
    console.print(
        f"  ⚠ app '{chosen.name}' entry-point '{p}' not found; "
        "sealing without serve payloads",
        style="warning"
    );
    return None;
}

def build_serve_manifest(entry_file: Path, proj_root: Path) -> (dict | None) {
    import os;
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    import from jaclang.compiler.driver.schedules { get_boundary_analysis_sched }
    import from jaclang.client.client_bundle { _ensure_js_generated }
    import from jaclang.dist.precompile_bytecode {
        find_jac_files,
        _nested_project_dirs
    }

    nested = _nested_project_dirs(str(proj_root));
    targets = [
        p
        for p in find_jac_files(str(proj_root))
        if not any(p.startswith(n) for n in nested)
    ];
    entry_key = str(entry_file.resolve());
    if entry_key not in targets {
        targets.insert(0, entry_key);
    }

    for jac_path in targets {
        prev_errors = len(Jac.get_program().errors_had);
        try {
            Jac.get_program().compile(jac_path);
        } except Exception as e {
            console.error(f"Seal aborted: '{jac_path}' failed to compile: {e}");
            return None;
        }
        if len(Jac.get_program().errors_had) > prev_errors {
            errs = "\n".join(
                str(e) for e in Jac.get_program().errors_had[prev_errors:]
            );
            console.error(f"Seal aborted: '{jac_path}' failed to compile:\n{errs}");
            return None;
        }
    }

    client: dict = {};
    mod = Jac.get_program().find_module(entry_key);
    if mod and mod.gen.client_manifest {
        if not mod.gen.client_manifest.exports {
            _ensure_js_generated(mod, Jac.program);
        }
        m = mod.gen.client_manifest;
        client = {
            'exports': list(m.exports),
            'globals': list(m.globals),
            'params': m.params,
            'globals_values': m.globals_values,
            'has_client': m.has_client
        };
    }

    proj_prefix = str(proj_root.resolve()) + os.sep;

    def in_project(hmod: any) -> bool {
        mp = hmod?.loc?.mod_path;
        return bool(mp) and os.path.abspath(str(mp)).startswith(proj_prefix);
    }

    for hub in Jac.get_program()._search_hubs() {
        for hmod in hub.values() {
            if not in_project(hmod) {
                continue;
            }
            man0 = hmod.gen.interop_manifest if (hmod and hmod.gen) else None;
            if man0 and not (man0.walker_access or man0.func_access) {
                try {
                    Jac.get_program().run_schedule(hmod, get_boundary_analysis_sched());
                } except Exception {}
            }
        }
    }

    func_access: dict[str, bool] = {};
    walker_access: dict[str, bool] = {};
    endpoint_effects: dict[str, any] = {};
    cross: list[dict] = [];
    seen: set = set();
    for hub in Jac.get_program()._search_hubs() {
        for hmod in hub.values() {
            if not in_project(hmod) {
                continue;
            }
            man = hmod.gen.interop_manifest if (hmod and hmod.gen) else None;
            if not man {
                continue;
            }
            for (n, a) in man.func_access.items() {
                if n not in func_access {
                    func_access[n] = a;
                }
            }
            for (n, a) in man.walker_access.items() {
                if n not in walker_access {
                    walker_access[n] = a;
                }
            }
            for (ekey, eeff) in man.endpoint_effects.items() {
                endpoint_effects[ekey] = eeff;
            }
            for binding in man.server_exports_to_client {
                ast_node = binding?.ast_node;
                src_path = (
                    ast_node.loc.mod_path if (ast_node and ast_node?.loc) else None
                );
                if not src_path or (binding.name, binding.kind) in seen {
                    continue;
                }
                try {
                    rel = os.path.relpath(src_path, str(proj_root));
                } except ValueError {
                    continue;
                }
                if rel.startswith('..') {
                    continue;
                }
                table = walker_access if binding.kind == 'walker' else func_access;
                auth = table.get(binding.name, None);
                if auth is None {
                    is_pub = (
                        ast_node is not None
                        and ast_node?.access is not None
                        and ast_node.access.tag.name == Tok.KW_PUB
                    );
                    auth = not is_pub;
                }
                seen.add((binding.name, binding.kind));
                cross.append(
                    {
                        'name': binding.name,
                        'kind': binding.kind,
                        'src': rel.replace(os.sep, '/'),
                        'auth': bool(auth)
                    }
                );
            }
        }
    }
    return {
        'client': client,
        'func_access': func_access,
        'walker_access': walker_access,
        'endpoint_effects': endpoint_effects,
        'cross_bindings': cross
    };
}

def ensure_client_dist(config: any, entry_file: Path) -> (Path | None) {
    import from jaclang.client { get_bun }
    import from jaclang.client.targets.web_target { WebTarget }

    import from jaclang.client.targets.registry { client_app_dir_for }
    dist = client_app_dir_for(config, str(entry_file)) / 'dist';
    bun = None;
    try {
        bun = get_bun();
    } except Exception {
        bun = None;
    }
    if bun {
        console.print("  Building client bundle (web)", style="muted");
        try {
            WebTarget().build(entry_file, Path(config.project_root));
        } except Exception as e {
            console.error(f"Client build failed: {e}");
            return None;
        }
        return dist if dist.is_dir() else None;
    }
    if dist.is_dir() and any(dist.`glob('client.*.js')) {
        console.print(
            "  ⚠ bun unavailable; baking the existing client dist as-is",
            style="warning"
        );
        return dist;
    }
    console.error(
        "This app has client code but no client bundle could be built or "
        f"found ({dist}).",
        hint="Install bun (jac will fetch it on demand) or prebuild the client."
    );
    return None;
}

def bake_native_payloads(config: any, pkg_copy: Path, app: str = "") -> bool {
    import os;
    import from jaclang.jac0core.ext_registry { base_stem }
    import from jaclang.compiler.placement.placement_solver { native_default_path_ok }
    import from jaclang.server.sealed_serve { NATIVE_DIR_REL }

    entry_file = resolve_entry_file(config, app);
    if entry_file is None or not native_default_path_ok(str(entry_file)) {
        return True;
    }
    try {
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        triple = str(llvm.get_default_triple());
    } except Exception as e {
        console.error(f"Cannot resolve the native target triple: {e}");
        return False;
    }
    stem = base_stem(entry_file.name);
    out_dir = pkg_copy / NATIVE_DIR_REL / triple;
    out_dir.mkdir(parents=True, exist_ok=True);
    console.print(f"  Compiling native binary for {triple}", style="muted");
    import from jaclang.cli.commands.native_build { native_build }
    rc = native_build(filename=str(entry_file), output=str(out_dir / stem));
    if rc != 0 {
        console.error("Native compilation failed; seal aborted.");
        return False;
    }
    return True;
}

def bake_serve_payloads(
    config: any, pkg_copy: Path, app: str = "", bake_client: bool = True
) -> bool {
    import json;
    import shutil;
    import from jaclang.server.sealed_serve { SERVE_MANIFEST_REL, CLIENT_DIST_REL }

    entry_file = resolve_entry_file(config, app);
    if entry_file is None {
        return True;
    }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    Jac.set_full_target_path(str(entry_file));
    sm = build_serve_manifest(entry_file, Path(config.project_root));
    if sm is None {
        return False;
    }
    dest_manifest = pkg_copy / SERVE_MANIFEST_REL;
    dest_manifest.parent.mkdir(parents=True, exist_ok=True);
    dest_manifest.write_text(
        json.dumps(sm, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );

    client_meta = sm.get('client', {}) or {};
    if not bake_client
        or not (client_meta.get('has_client') or client_meta.get('exports')) {
        return True;
    }
    dist_src = ensure_client_dist(config, entry_file);
    if dist_src is None {
        return False;
    }
    dest_dist = pkg_copy / CLIENT_DIST_REL;
    if dest_dist.exists() {
        shutil.rmtree(dest_dist);
    }
    shutil.copytree(dist_src, dest_dist);
    n_files = sum(
        1
        for p in dest_dist.rglob('*')
        if p.is_file()
    );
    console.print(f"  ✔ Baked client dist ({n_files} files)", style="success");
    return True;
}

def make_sealed_image(
    config: any,
    parent: Path,
    name: str,
    out_dir: (Path | None) = None,
    app: str = "",
    bake_client: bool = True
) -> (Path | None) {
    import shutil;
    import tempfile;
    import from jaclang.jac0core { ext_registry }

    proj_root = config.project_root;
    if proj_root is None {
        console.error("No project root to seal.");
        return None;
    }

    out_names: set = set();
    if out_dir is not None {
        try {
            rel0 = Path(out_dir).resolve().relative_to(Path(proj_root).resolve());
            out_names.add(rel0.parts[0]);
        } except ValueError {}
    }

    def copy_ignore(d: str, items: list) -> list {
        skipped = seal_copy_ignore(d, items);
        if out_names and Path(d).resolve() == Path(proj_root).resolve() {
            skipped = list(
                set(skipped)
                    | {
                        it
                        for it in items
                        if it in out_names
                    }
            );
        }
        return skipped;
    }

    stage = Path(tempfile.mkdtemp(prefix=f"{name}-seal-"));
    try {
        pkg_copy = stage / name;
        shutil.copytree(proj_root, pkg_copy, ignore=copy_ignore);

        has_init = any((pkg_copy / f).exists() for f in ext_registry.INIT_FILES);
        if not has_init and not (pkg_copy / "__init__.py").exists() {
            (pkg_copy / "__init__.jac").write_text("");
        }

        if not bake_serve_payloads(config, pkg_copy, app, bake_client=bake_client) {
            return None;
        }
        if not bake_native_payloads(config, pkg_copy, app) {
            return None;
        }

        rc = run_precompiler(
            str(stage), ["--seal"] + ([f"--app={app}"] if app else [])
        );
        if rc != 0 {
            console.error("Seal failed.");
            return None;
        }

        parent.mkdir(parents=True, exist_ok=True);
        dest = parent / name;
        if dest.exists() {
            shutil.rmtree(dest);
        }
        shutil.move(str(pkg_copy), str(dest));
        return dest;
    } finally {
        shutil.rmtree(stage, ignore_errors=True);
    }
}

def vendor_jab_deps(config: any, img: Path) -> bool {
    import from jaclang.project.providers { resolve_plan, get_python_provider }
    import from jaclang.jac0core.sealed { python_tag }
    import from jaclang.dist.jab_vendor {
        wheels_dir,
        download_wheels,
        write_vendor_manifest
    }

    plan = resolve_plan(config, include_dev=False);
    py_prov = get_python_provider();
    py_deps = [
        d
        for d in plan.for_ecosystem("python")
        if d.source == "pypi"
    ];
    skipped = [
        d.name
        for d in plan.for_ecosystem("python")
        if d.source != "pypi"
    ];
    if skipped {
        console.print(
            f"  ⚠ not vendoring non-pypi dep(s): {', '.join(sorted(skipped))} "
            "(installed normally at run time)",
            style="warning"
        );
    }
    specs = py_prov.specs_for(py_deps);
    if not specs {
        console.print(
            "  ✔ Fat jab: no third-party Python deps to vendor", style="success"
        );
        write_vendor_manifest(img, specs, python_tag=python_tag());
        return True;
    }

    console.print(
        f"  Vendoring {len(specs)} Python dependency closure as wheels", style="muted"
    );
    wd = wheels_dir(img);
    (ok, err) = download_wheels(specs, wd);
    if not ok {
        console.error(
            f"Fat-jab vendoring failed while downloading wheels:\n  {err}",
            hint=(
                "A dep may lack a wheel for this platform. Build without --fat, "
                "or pre-provide the wheels via PIP_FIND_LINKS."
            )
        );
        return False;
    }
    write_vendor_manifest(img, specs, python_tag=python_tag());

    wheels = sorted(wd.`glob("*.whl"));
    total = sum([w.stat().st_size for w in wheels]);
    console.print(
        f"  ✔ Vendored {len(wheels)} wheel(s) ({total:,} bytes); "
        "materializes offline, no PyPI",
        style="success"
    );
    return True;
}


def tar_gz_dir(top: Path) -> bytes {
    import io;
    import gzip;
    import tarfile;
    import os;

    def normalize(ti: any) -> any {
        ti.mtime = 0;
        ti.uid = 0;
        ti.gid = 0;
        ti.uname = "";
        ti.gname = "";
        return ti;
    }

    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w") as tf {
        for (dirpath, dirnames, filenames) in os.walk(str(top)) {
            dirnames.sort();
            for fn in sorted(filenames) {
                full = Path(str(dirpath)) / str(fn);
                tf.add(str(full), arcname=str(full.relative_to(top)), filter=normalize);
            }
        }
    }
    return gzip.compress(buf.getvalue(), 6, mtime=0);
}


def build_jab(
    config: any,
    out_path: Path,
    app: str = "",
    fat: bool = False,
    bake_client: bool = True
) -> Path {
    out_path = Path(out_path);
    out_path.parent.mkdir(parents=True, exist_ok=True);
    work = Path(tempfile.mkdtemp(prefix="jab-", dir=str(out_path.parent)));
    try {
        img = make_sealed_image(
            config,
            work,
            config.project.name,
            out_dir=out_path.parent,
            app=app,
            bake_client=bake_client
        );
        if img is None {
            raise RuntimeError(f"sealing {config.project.name} failed");
        }
        if fat and not vendor_jab_deps(config, img) {
            raise RuntimeError(
                f"vendoring {config.project.name}'s dependencies failed"
            );
        }
        out_path.write_bytes(tar_gz_dir(img));
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
    return out_path;
}
