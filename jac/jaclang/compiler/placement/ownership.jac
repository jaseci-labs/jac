import os;
import hashlib;
import json;
import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
import from jaclang.compiler.frontend.parser { parse }
import jaclang.compiler.frontend.unitree as uni;
import type from jaclang.compiler.placement.workspace { WorkspaceSpec }

glob _graphs: dict[str, tuple] = {},
     _imports: dict[str, tuple] = {};


def consumer_graph(ws: WorkspaceSpec) -> tuple[dict[str, set[str]], str] {
    if not ws.explicit or len(ws.serving_apps()) < 2 {
        return ({}, "");
    }
    files: dict[str, tuple] = {};
    for (directory, dirs, names) in os.walk(ws.project_root) {
        dirs[:] = sorted(
            d
            for d in dirs
            if not d.startswith('.') and d not in ("node_modules", "__pycache__")
        );
        for name in sorted(names) {
            if not name.endswith('.jac') {
                continue;
            }
            path = os.path.realpath(os.path.join(directory, name));
            try {
                st = os.stat(path);
                files[path] = (st.st_mtime_ns, st.st_size);
            } except OSError {
                continue;
            }
        }
    }
    stamp = (ws.digest, tuple(sorted(files.items())));
    cached = _graphs.get(ws.toml_path);
    if cached is not None and cached[0] == stamp {
        return (cached[1], cached[2]);
    }
    structure = tuple(sorted(files));
    edges: dict[str, set[str]] = {};
    for (path, file_stamp) in files.items() {
        old = _imports.get(path);

        key = (ws.digest, structure, file_stamp);
        if old is not None and old[0] == key {
            edges[path] = set(old[1]);
            continue;
        }
        deps: set[str] = set();
        (mod, had_errors) = parse(read_file_with_encoding(path), path);
        if not had_errors {
            for imp in mod.get_all_sub_nodes(uni.Import) {
                if imp.is_typed
                    or imp.is_comptime
                    or imp.has_string_path
                    or imp.has_clib_decls {
                    continue;
                }
                targets: list[str] = [];
                if imp.from_loc is not None {
                    targets.append(imp.from_loc.resolve_relative_path());
                    for item in imp.items if targets[0] not in files else [] {
                        if isinstance(item, uni.ModuleItem)
                            and isinstance(item.name, uni.Name) {
                            targets.append(
                                imp.from_loc.resolve_relative_path(item.name.value)
                            );
                        }
                    }
                } else {
                    for item in imp.items {
                        if isinstance(item, uni.ModulePath) {
                            targets.append(item.resolve_relative_path());
                        }
                    }
                }
                for target in targets {
                    real = os.path.realpath(target);
                    if real in files {
                        deps.add(real);
                    }
                }
            }
        }
        edges[path] = set(deps);
        _imports[path] = (key, deps);
    }

    import from jaclang.compiler.driver.bccache { discover_annex_files }
    for path in files {
        for suffix in ('.impl.jac', '.test.jac') {
            edges[path].update(
                os.path.realpath(p)
                for p in discover_annex_files(path, suffix)
                if os.path.realpath(p) in files
            );
        }
    }
    consumers: dict[str, set[str]] = {};
    for app in ws.serving_apps() {
        pending = [
            p
            for p in files
            if app.contains(p)
        ];
        seen: set[str] = set();
        while pending {
            path = pending.pop();
            if path in seen {
                continue;
            }
            seen.add(path);
            claimed = ws.app_for_path(path);
            if claimed is not None and claimed.name != app.name {
                continue;
            }

            owners = [
                a.name
                for a in ws.apps.values()
                if a.claims_module(ws.module_dot_path(path))
            ];
            if owners and app.name not in owners {
                continue;
            }
            consumers.setdefault(path, set()).add(app.name);
            pending.extend(edges.get(path, set()) - seen);
        }
    }
    digest = hashlib.sha256(
        json.dumps(
            {p: sorted(names) for (p, names) in sorted(consumers.items())},
            sort_keys=True
        ).encode()
    ).hexdigest()[:16];
    _graphs[ws.toml_path] = (stamp, consumers, digest);
    return (consumers, digest);
}
