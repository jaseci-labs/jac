"""Implementation of the build command.

Compiles a whole Jac project into a single .jab artifact: a JIR container
(FLAG_PROGRAM) holding every reachable user module's bytecode, MTIR, and
interop, plus a manifest and dependency graph.
"""

import os;
import sys;
import from jaclang.cli.console { console }

"""Build a .jab whole-program artifact from a Jac project."""
impl build(
    filename: str = "",
    profile: str = "release",
    out: str = "",
    target: str = "all",
    no_typecheck: bool = False,
    check_only: bool = False
) -> int {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compiler { JacCompiler }

    # Resolve the entry file: CLI arg > jac.toml entry_point.
    if not filename {
        config = get_config();
        if config is not None {
            filename = config.project.entry_point;
        }
    }
    if not filename {
        console.error("Error: No entry file specified and no entry-point in jac.toml.");
        console.error("  Specify an entry file: jac build app.jac");
        console.error("  Or set [project] entry_point in jac.toml");
        return 1;
    }

    # Discover config from the file's directory (handles absolute paths).
    _discover_config_from_file(filename);

    entry_path = Path(filename).resolve();
    if not entry_path.exists() {
        console.error(f"Error: Entry file '{filename}' not found.");
        console.error(f"  Resolved path: {entry_path}");
        return 1;
    }

    # Type-check is on by default for release, gated off by --no-typecheck.
    type_check = not no_typecheck;

    program = JacProgram();
    compiler = JacCompiler();

    # Whole-program build: BFS the server import closure, optionally run the
    # full type-check schedule, gate on blocking errors. Returns None on
    # failure (build() already printed the gate summary to stderr).
    if check_only {
        console.print(f"[jac build] Type-checking {filename} (whole-program)...");
    } else {
        console.print(
            f"[jac build] Building {filename} "
            f"(profile={profile}, target={target})..."
        );
    }

    try {
        root_mod = compiler.build(
            file_path=str(entry_path), target_program=program, type_check=type_check
        );
    } except Exception as e {
        import from jaclang.jac0core.helpers { dump_traceback }
        console.error(f"[jac build] Build failed: {e}");
        console.error(dump_traceback(e));
        return 1;
    }

    if root_mod is None {
        # build() prints its own blocking-error summary; surface any extras.
        if program.errors_had {
            for err in program.errors_had {
                console.error(f"  {err.pretty_print()}");
            }
        }
        console.error("[jac build] Build failed: whole-program type-check gate.");
        return 1;
    }

    # --check-only: gate passed, emit nothing.
    if check_only {
        console.print("[jac build] Type-check PASSED");
        return 0;
    }

    # Collect user modules from the program hub (filter out jaclang.* internals).
    jaclang_root = str(Path(sys.modules["jaclang"].__file__).parent.resolve());
    hub = program.mod.hub;
    user_modules: dict[str, object] = {};
    for (mod_path, mod_node) in hub.items() {
        if mod_path.startswith(jaclang_root) {
            continue;
        }
        user_modules[mod_path] = mod_node;
    }

    # Build the importer -> [targets] dep graph (absolute paths) by walking
    # each module's own uni.Import nodes. Resolving from the AST (rather than
    # program._dependents) keeps the edge set in sync with the modules actually
    # in the closure, and is robust to dependency-tracking timing.
    abs_dep_graph = _build_dep_graph(user_modules);

    # Topological order via DFS post-order: dependencies before dependents.
    ordered_paths: list[str] = [];
    visited: set[str] = set();

    def _topo_visit(path: str) -> None {
        if path in visited {
            return;
        }
        visited.add(path);
        for dep in abs_dep_graph.get(path, []) {
            _topo_visit(dep);
        }
        if path in user_modules {
            ordered_paths.append(path);
        }
    }

    for mod_path in list(user_modules.keys()) {
        _topo_visit(mod_path);
    }

    # Convert the dep graph to rel_paths so it travels with the relocatable .jab.
    base_dir = str(entry_path.parent);
    dep_graph: dict[str, list[str]] = {};
    for (importer, targets) in abs_dep_graph.items() {
        dep_graph[_rel_path(importer, base_dir)] = [
            _rel_path(t, base_dir) for t in targets
        ];
    }

    # Assemble per-module sections for the whole-program JIR.
    modules = _collect_module_sections(ordered_paths, user_modules, str(entry_path));

    # Determine output path.
    if out {
        out_path = Path(out);
    } else {
        config = get_config();
        if config is not None {
            build_dir = Path(config.get_build_dir());
        } else {
            build_dir = entry_path.parent / ".jac";
        }
        stem = entry_path.stem;
        if stem.endswith(".na") {
            stem = stem[:-3];
        }
        out_path = build_dir / "build" / profile / (stem + ".jab");
    }

    out_path.parent.mkdir(parents=True, exist_ok=True);

    # Build the manifest.
    entry_rel = _rel_path(str(entry_path), str(entry_path.parent));
    manifest: dict[str, object] = {
        "format": 1,
        "profile": profile,
        "entry": entry_rel,
        "py_tag": list(sys.version_info[:2]),
        "targets": [target]
    };

    # Serialize as a FLAG_PROGRAM JIR and write to disk.
    import from jaclang.jac0core.jir { write_program_jir }
    jab_data = write_program_jir(modules, manifest, dep_graph);
    with open(str(out_path), "wb") as f {
        f.write(jab_data);
    }

    console.print(f"[jac build] Done -> {out_path} ({len(modules)} module(s))");
    return 0;
}


"""Build importer -> [target] edges (absolute paths) for the closure.

Walks each module's uni.Import nodes. Only edges between modules that are
both in the closure are recorded; .py / jaclang.* imports are dropped. The
caller converts to rel_paths for the relocatable .jab.
"""
def _build_dep_graph(user_modules: dict[str, object]) -> dict[str, list[str]] {
    import jaclang.jac0core.unitree as uni;
    import from pathlib { Path }

    dep_graph: dict[str, list[str]] = {};
    for (mod_path, mod_node) in user_modules.items() {
        edges: list[str] = [];
        for imp in mod_node.get_all_sub_nodes(uni.Import) {
            paths: list[object] = [];
            if imp.from_loc is not None {
                paths.append(imp.from_loc);
            } else {
                for item in imp.items {
                    if isinstance(item, uni.ModulePath) {
                        paths.append(item);
                    }
                }
            }
            for mp in paths {
                try {
                    dep_path = str(Path(mp.resolve_relative_path()).resolve());
                } except Exception {
                    continue;
                }
                if dep_path in user_modules and dep_path not in edges {
                    edges.append(dep_path);
                }
            }
        }
        if edges {
            dep_graph[mod_path] = edges;
        }
    }
    return dep_graph;
}


"""Collect (rel_path, content_hash, sections) for each module in topo order.

sections holds SEC_BYTECODE, and SEC_MTIR / SEC_INTEROP when available.
"""
def _collect_module_sections(
    ordered_paths: list[str], user_modules: dict[str, object], entry_path: str
) -> list[tuple[str, int, dict[int, bytes]]] {
    import zlib;
    import pickle;
    import json;
    import from pathlib { Path }
    import from jaclang.jac0core.jir { SEC_BYTECODE, SEC_MTIR, SEC_INTEROP }

    base_dir = str(Path(entry_path).parent);
    modules: list[tuple[str, int, dict[int, bytes]]] = [];

    for mod_path in ordered_paths {
        mod_node = user_modules[mod_path];
        gen = mod_node?.gen;
        sections: dict[int, bytes] = {};

        if gen is not None {
            bytecode = gen?.py_bytecode;
            if bytecode is not None {
                sections[SEC_BYTECODE] = bytecode;
            }
            mtir = gen?.jac_mach;
            if mtir is not None {
                try {
                    sections[SEC_MTIR] = pickle.dumps(mtir, pickle.HIGHEST_PROTOCOL);
                } except Exception {
                    pass;
                }
            }
            interop = gen?.interop;
            if interop is not None {
                try {
                    sections[SEC_INTEROP] = json.dumps(interop).encode("utf-8");
                } except Exception {
                    pass;
                }
            }
        }

        rel = _rel_path(mod_path, base_dir);
        content_hash = zlib.crc32(rel.encode("utf-8")) & 0xFFFFFFFF;
        modules.append((rel, content_hash, sections));
    }

    return modules;
}


"""Discover jac.toml from the entry file's directory.

Ensures that when building from any working directory, the jac.toml in the
project root is found and used for configuration.
"""
def _discover_config_from_file(filename: str) -> None {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { add_venv_to_path }

    file_path = Path(filename).resolve();
    file_dir = file_path.parent;

    # Preserve any active profile from previously loaded config.
    existing_config = get_config();
    active_profile = existing_config.active_profile if existing_config else None;

    try {
        config = get_config(start_path=file_dir, force_discover=True);
    } except (OSError, KeyError, ValueError) as e {
        console.print(
            f"Warning: Failed to discover config from {file_dir}: {e}", style="warning"
        );
        return;
    }

    if config is not None {
        if active_profile {
            config.apply_profile_overlay(active_profile);
        }
        add_venv_to_path(config);
    }
}


"""Compute a relative path from base_dir to full_path.

Falls back to the absolute path string if os.path.relpath raises (e.g. across
drives on Windows).
"""
def _rel_path(full_path: str, base_dir: str) -> str {
    try {
        return os.path.relpath(full_path, base_dir);
    } except ValueError {
        return full_path;
    }
}
