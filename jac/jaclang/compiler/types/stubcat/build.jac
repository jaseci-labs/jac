import from jaclang.jac0core.cache_paths { atomic_write }
import json;
import os;
import sys;
import time;
import from jaclang.compiler.types.stubcat.locate {
    ENV_BUILDING,
    catalog_key,
    jac_internal_stub_dir,
    jaclang_pkg_dir,
    typeshed_stdlib_dir
}
import from jaclang.compiler.types.stubcat.writer { CatalogWriter }
import jaclang.compiler.types.stubcat.reader;

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
) -> dict[str, any] {
    started = time.monotonic();
    previous_building = os.environ.get(ENV_BUILDING);
    previous_evict = os.environ.get("JAC_NO_UNIT_EVICT");
    os.environ[ENV_BUILDING] = "1";
    os.environ["JAC_NO_UNIT_EVICT"] = "1";
    try {
        return _build_catalog_inner(out_path, only, pkg_dir, quiet, started);
    } finally {
        if previous_building is None {
            os.environ.pop(ENV_BUILDING, None);
        } else {
            os.environ[ENV_BUILDING] = previous_building;
        }
        if previous_evict is None {
            os.environ.pop("JAC_NO_UNIT_EVICT", None);
        } else {
            os.environ["JAC_NO_UNIT_EVICT"] = previous_evict;
        }
    }
}

def _build_catalog_inner(
    out_path: str,
    only: (list[str] | None),
    pkg_dir: (str | None),
    quiet: bool,
    started: float
) -> dict[str, any] {
    pkg = pkg_dir or jaclang_pkg_dir();
    import from jaclang.compiler.driver.program { JacProgram }
    prog = JacProgram();
    compiler = prog._get_compiler();
    compiler.stub_catalog_disabled = True;
    ev = prog.get_type_evaluator();
    writer = CatalogWriter(evaluator=ev, pkg_dir=pkg);

    wanted: (set[str] | None) = set(only) if only is not None else None;
    def take(dotted: str) -> bool {
        return wanted is None or dotted in wanted;
    }

    prelude: list[tuple[str, any]] = [
        ("builtins", ev.builtins_module),
        ("typing", ev.typing_module),
        ("types", ev.types_module),
        ("enum", ev.enum_module),
        ("jac_builtins", ev.jac_builtins_module),
        ("dom_types", ev.dom_types_module),
        ("na_builtins", ev.na_builtins_module),
        ("js_globals", ev.js_globals_module)
    ];
    for (dotted, mod) in prelude {
        if mod is not None {
            writer.add_module(mod, dotted);
        }
    }

    files = jac_internal_stub_files(pkg)
        + typeshed_module_files(typeshed_stdlib_dir(pkg), sys.version_info.minor);
    load_failures: list[str] = [];
    loaded = 0;
    for (dotted, path) in files {
        if not take(dotted) {
            continue;
        }
        if not quiet and loaded % 25 == 0 {
            sys.stderr.write(
                f"stubcat: loading {dotted} ({loaded} done, rss={_rss_mb()} MB)\n"
            );
            sys.stderr.flush();
        }
        loaded += 1;
        try {
            mod = prog.load_dependency_module(path);
        } except Exception as e {
            load_failures.append(f"{dotted}: {type(e).__name__}: {e}");
            continue;
        }
        writer.add_module(mod, dotted);
    }
    if not quiet {
        sys.stderr.write(
            f"stubcat: {len(writer.modules)} modules loaded, forcing types...\n"
        );
        sys.stderr.flush();
    }
    writer.force_all();
    data = writer.emit(catalog_key(pkg), ev.ambient_typing_names_by_module);
    atomic_write(out_path, data);
    manifest = writer.manifest();
    manifest["bytes"] = len(data);
    manifest["key"] = catalog_key(pkg);
    manifest["load_failures"] = load_failures;
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
    if manifest["load_failures"] {
        sys.stderr.write(
            f"stubcat: {len(manifest['load_failures'])} modules failed to load\n"
        );
    }
    return 0;
}
