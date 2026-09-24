import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.console { console }
import type from jaclang.project.apps { AppConfig }


def seal_copy_ignore(_dir: str, items: list[str]) -> list[str] {
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

def build_serve_manifest(entry_file: Path, proj_root: Path) -> (dict[str, any] | None) {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.project.config { get_config_for_path }
    import from jaclang.project.app_kinds { kind_has_server }
    import from jaclang.server.assembly { service_apps }
    try {
        config = get_config_for_path(proj_root);
        services: list[AppConfig] = [];
        if config is not None {
            selected = config.app_for_path(str(entry_file.resolve()));
            if selected is not None
                and kind_has_server(config.resolved_kind(selected)) {
                services = service_apps(config, selected);
            }
        }
        prepared = prepare_application(
            str(entry_file.resolve()),
            Jac.get_program(),
            str(proj_root.resolve()),
            services=[svc.entry_path(str(proj_root.resolve())) for svc in services]
        );
        result = dict(prepared.manifests[str(entry_file.resolve())]);
        result['module_manifests'] = {
            os.path.relpath(path, prepared.root).replace(os.sep, '/'): manifest
            for application in [prepared, *prepared.applications]
            for (path, manifest) in application.manifests.items()
        };
        return result;
    } except Exception as e {
        console.error(f"Seal aborted: application preparation failed: {e}");
        return None;
    }
}

def ensure_client_dist(config: any, entry_file: Path) -> (Path | None) {
    import from jaclang.client { get_bun }
    import from jaclang.client.targets.web_target { WebTarget }

    import from jaclang.project.client_paths { client_app_dir_for }
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

    client_meta: any = sm.get('client', {}) or {};
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

def vendor_packages(config: any, pkg_copy: Path) {
    import os;
    import from jaclang.packages.artifact { stage_source_tree }
    import from jaclang.packages.install { has_packages, sync }
    import from jaclang.project.package_scope { mounts_dir }
    if not has_packages(config) {
        return;
    }
    result = sync(config);
    proj_root = os.path.realpath(str(config.project_root));
    mounts_rel = mounts_dir(config.get_build_dir()).relative_to(
        Path(config.project_root)
    );
    runtime = {
        p.name
        for p in result.lock.packages
        if not p.dev
    };
    for (name, target) in sorted(result.targets.items()) {
        if name not in runtime or os.path.realpath(str(target)) == proj_root {
            continue;
        }
        (org, pkg) = name.split("/", 1);
        stage_source_tree(Path(target), pkg_copy / mounts_rel / org / pkg);
    }
    result.lock.write(pkg_copy / "jac.lock");
    console.print(
        f"  Sealing {len(result.lock.packages)} Jac package(s) into the image",
        style="muted"
    );
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
    import from jaclang.dist.sanitize { sanitize_shipped_tree }

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

    def copy_ignore(d: str, items: list[str]) -> list[str] {
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
        sanitize_shipped_tree(pkg_copy);
        vendor_packages(config, pkg_copy);

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
    result = download_wheels(specs, wd);
    if not result.ok {
        what = (
            f"no usable wheel for {', '.join(result.missing)}"
                if result.missing
                else "wheel download failed"
        );
        console.error(
            f"Fat-jab vendoring failed, {what}:\n  {result.detail}",
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


def build_jab(
    config: any,
    out_path: Path,
    app: str = "",
    fat: bool = False,
    bake_client: bool = True,
    require_entry: bool = False
) -> Path {
    import from jaclang.dist.archive { tar_gz_dir }
    import from jaclang.dist.jab { jab_app_meta }
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
        if require_entry and not (jab_app_meta(img).get("entry") or {}).get("path") {
            raise RuntimeError(
                f"No runnable entry for '{config.project.name}'; a runnable image "
                "needs an entry (main.jac at the package root, or [project] "
                "entry-point in jac.toml)."
            );
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
