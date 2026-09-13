import type from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.cache.catalog_codec { encode_catalog }
import json;
import from pathlib { Path }
import from jaclang.compiler.session.cache.store { atomic_write }
import os;
import sys;
import time;
import from jaclang.compiler.session.cache.catalog_paths {
    ENV_BUILDING,
    catalog_key,
    jac_internal_stub_dir,
    jaclang_pkg_dir,
    typeshed_stdlib_dir
}
import from jaclang.compiler.api { prepare_catalog }
import from jaclang.compiler.analysis.interfaces.facts { CatalogRequest }
import jaclang.compiler.session.cache.catalog_reader;

glob PRELUDE_ORDER: tuple[str, ...] = (
         "builtins",
         "typing",
         "types",
         "enum",
         "jac_builtins",
         "dom_types",
         "na_builtins",
         "js_globals",
         "builtin_overrides",
         "typing_ambient"
     );

def parse_versions(stdlib_dir: str) -> dict[str, tuple[int, int]] {
    out: dict[str, tuple[int, int]] = {};
    path = os.path.join(stdlib_dir, "VERSIONS");
    if not os.path.isfile(path) {
        return out;
    }
    with open(path, "r", encoding="utf-8") as f {
        for raw in f {
            line = raw.split("#", 1)[0].strip();
            if not line or ":" not in line {
                continue;
            }
            (name, spec) = line.split(":", 1);
            spec = spec.strip();
            (lo_s, hi_s) = spec.split("-", 1) if "-" in spec else (spec, "");
            lo = _minor_of(lo_s);
            hi = _minor_of(hi_s) if hi_s else 999;
            out[name.strip()] = (lo, hi);
        }
    }
    return out;
}

def _minor_of(text: str) -> int {
    parts = text.strip().split(".");
    if len(parts) < 2 {
        return 0;
    }
    try {
        return int(parts[1]);
    } except ValueError {
        return 0;
    }
}

def version_ok(dotted: str, versions: dict[str, tuple[int, int]], minor: int) -> bool {
    parts = dotted.split(".");
    for n in range(len(parts), 0, -1) {
        prefix = ".".join(parts[:n]);
        spec = versions.get(prefix);
        if spec is not None {
            return spec[0] <= minor <= spec[1];
        }
    }
    return True;
}

def typeshed_module_files(stdlib_dir: str, minor: int) -> list[tuple[str, str]] {
    versions = parse_versions(stdlib_dir);
    out: list[tuple[str, str]] = [];
    for (walk_dir, dirs, files) in os.walk(stdlib_dir) {
        dirs[:] = sorted(
            d
            for d in dirs
            if not d.startswith(".") and d != "@tests"
        );
        for name in sorted(files) {
            if not name.endswith(".pyi") {
                continue;
            }
            full = os.path.join(walk_dir, name);
            rel = os.path.relpath(full, stdlib_dir).replace(os.sep, "/");
            dotted = rel[:-4].replace("/", ".");
            if dotted.endswith(".__init__") {
                dotted = dotted[:-9];
            }
            if not version_ok(dotted, versions, minor) {
                continue;
            }
            out.append((dotted, full));
        }
    }
    return out;
}

def jac_internal_stub_files(pkg_dir: str) -> list[tuple[str, str]] {
    stub_dir = jac_internal_stub_dir(pkg_dir);
    out: list[tuple[str, str]] = [];
    if not os.path.isdir(stub_dir) {
        return out;
    }
    for name in sorted(os.listdir(stub_dir)) {
        if name.endswith(".pyi") {
            out.append((name[:-4], os.path.join(stub_dir, name)));
        }
    }
    return out;
}

def _rss_mb -> int {
    import resource;
    usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss;
    return int(usage // (1024 * 1024))
        if sys.platform == "darwin"
        else int(usage // 1024);
}

def build_catalog(
    out_path: str,
    only: (list[str] | None) = None,
    pkg_dir: (str | None) = None,
    quiet: bool = False
) -> dict[str, object] {
    started = time.monotonic();
    import from jaclang.compiler.session.session { JacProgram }
    prog = JacProgram();
    import from jaclang.compiler.session.compiler { JacCompiler }
    import from jaclang.compiler.bootstrap.selfhost { SelfHostCache }

    prog._compiler = JacCompiler(
        stub_catalog_disabled=True, _selfhost=SelfHostCache(_program=prog)
    );
    previous_building = os.environ.get(ENV_BUILDING);
    os.environ[ENV_BUILDING] = "1";
    try {
        return _build_catalog_inner(prog, out_path, only, pkg_dir, quiet, started);
    } finally {
        if previous_building is None {
            os.environ.pop(ENV_BUILDING, None);
        } else {
            os.environ[ENV_BUILDING] = previous_building;
        }
        prog.release_compile_closure(retain_stubs=False);
    }
}

def _build_catalog_inner(
    prog: JacProgram,
    out_path: str,
    only: (list[str] | None),
    pkg_dir: (str | None),
    quiet: bool,
    started: float
) -> dict[str, object] {
    pkg = pkg_dir or jaclang_pkg_dir();
    wanted = set(only) if only is not None else None;
    files = jac_internal_stub_files(pkg)
        + typeshed_module_files(typeshed_stdlib_dir(pkg), sys.version_info.minor);
    selected = [
        (name, path)
        for (name, path) in files
        if wanted is None or name in wanted
    ];
    product = prepare_catalog(
        prog, CatalogRequest(pkg, catalog_key(pkg), selected, quiet)
    );
    data = encode_catalog(product.prepared);
    atomic_write(Path(out_path), data);
    manifest: dict[str, object] = {};
    manifest.update(product.statistics.as_dict());
    manifest["bytes"] = len(data);
    manifest["key"] = catalog_key(pkg);
    manifest["load_failures"] = product.load_failures;
    manifest["seconds"] = round(time.monotonic() - started, 2);
    manifest["python"] = f"{sys.version_info.major}.{sys.version_info.minor}";
    try {
        with open(out_path + ".json", "w", encoding="utf-8") as f {
            json.dump(manifest, f, indent=2, sort_keys=True);
        }
    } except OSError {}
    if not quiet {
        sys.stderr.write(
            f"stubcat: {manifest['modules']} modules, {manifest['symbols']} symbols, "
            f"{manifest['types']} types, {manifest['bytes']} bytes, "
            f"{manifest['failures']} evaluation failures in {manifest['seconds']}s\n"
        );
        sys.stderr.flush();
    }
    return manifest;
}

def main(argv: list[str]) -> int {
    out: (str | None) = None;
    only: (list[str] | None) = None;
    pkg_dir: (str | None) = None;
    for arg in argv {
        if arg.startswith("--only=") {
            only = [
                s
                for s in arg[len("--only="):].split(",")
                if s
            ];
        } elif arg.startswith("--pkg-dir=") {
            pkg_dir = arg[len("--pkg-dir="):];
        } elif arg.startswith("--") {
            sys.stderr.write(f"stubcat: unknown flag {arg}\n");
            return 2;
        } else {
            out = arg;
        }
    }
    if out is None {
        sys.stderr.write("usage: stubcat <out.bin> [--only=a,b] [--pkg-dir=DIR]\n");
        return 2;
    }
    try {
        manifest = build_catalog(out, only=only, pkg_dir=pkg_dir, quiet=False);
    } except Exception as e {
        sys.stderr.write(f"stubcat: build failed: {type(e).__name__}: {e}\n");
        return 1;
    }
    load_failures = manifest["load_failures"];
    if isinstance(load_failures, list) and load_failures {
        sys.stderr.write(f"stubcat: {len(load_failures)} modules failed to load\n");
    }
    return 0;
}
