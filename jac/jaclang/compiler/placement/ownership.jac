import os;
import hashlib;
import json;
import from pathlib { Path }
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
import from jaclang.compiler.frontend.parser { parse }
import jaclang.compiler.frontend.unitree as uni;
import type from jaclang.compiler.placement.workspace { WorkspaceSpec }

glob _graphs: dict[str, tuple] = {},
     _imports: dict[str, tuple] = {},
     _snapshots: ContextVar = ContextVar("workspace_snapshots", `default=None);


@contextmanager
def workspace_snapshot -> Iterator[None] {
    if _snapshots.get() is not None {
        yield None;
        return;
    }
    token = _snapshots.set({});
    try {
        yield None;
    } finally {
        _snapshots.reset(token);
    }
}


def seed_workspace_snapshot(project_root: str, files: dict) -> None {
    snapshots = _snapshots.get();
    if snapshots is None {
        raise RuntimeError("Workspace inventory requires an active snapshot.");
    }
    snapshots[('files', os.path.realpath(project_root))] = files;
}


def consumer_graph(ws: WorkspaceSpec) -> tuple[dict[str, set[str]], str] {
    if not ws.explicit or len(ws.serving_apps()) < 2 {
        return ({}, "");
    }
    snapshots = _snapshots.get();
    snapshot_key = (ws.toml_path, ws.digest);
    if snapshots is not None and snapshot_key in snapshots {
        return snapshots[snapshot_key];
    }
    result = _reconcile_graph(ws);
    if snapshots is not None {
        snapshots[snapshot_key] = result;
    }
    return result;
}


def _reconcile_graph(ws: WorkspaceSpec) -> tuple[dict[str, set[str]], str] {
    files: dict[str, tuple] = {};
    snapshots = _snapshots.get();
    inventory = snapshots.get(('files', os.path.realpath(ws.project_root)))
        if snapshots is not None else None;
    if inventory is not None {
        files = {p: st for (p, st) in inventory.items() if p.endswith('.jac')};
    }
    for (directory, dirs, names) in os.walk(ws.project_root) if inventory is None else [] {
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
    import from jaclang.compiler.driver.jir { compiler_generation }
    toolchain = compiler_generation();
    disk_path = Path(ws.project_root) / '.jac' / 'cache' / 'ownership.json';
    disk: dict = {};
    try {
        candidate = json.loads(disk_path.read_text(encoding='utf-8'));
        if candidate.get('format') == 1
            and candidate.get('workspace') == ws.digest
            and candidate.get('toolchain') == toolchain
            and isinstance(candidate.get('files'), dict)
            and isinstance(candidate.get('imports'), dict)
            and isinstance(candidate.get('consumers'), dict)
            and isinstance(candidate.get('digest'), str) {
            disk = candidate;
        }
    } except (OSError, ValueError, TypeError, AttributeError) {}
    file_record = {p: list(st) for (p, st) in files.items()};
    if disk.get('files') == file_record {
        consumers = {p: set(names) for (p, names) in disk['consumers'].items()};
        _graphs[ws.toml_path] = (stamp, consumers, disk['digest']);
        return (consumers, disk['digest']);
    }
    structure = tuple(sorted(files));
    same_structure = set(disk.get('files', {})) == set(files);
    edges: dict[str, set[str]] = {};
    for (path, file_stamp) in files.items() {
        old = _imports.get(path);

        key = (ws.digest, structure, file_stamp);
        if old is not None and old[0] == key {
            edges[path] = set(old[1]);
            continue;
        }
        if same_structure and disk['files'].get(path) == list(file_stamp)
            and path in disk.get('imports', {}) {
            deps = set(disk['imports'][path]);
            edges[path] = deps;
            _imports[path] = (key, deps);
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

    import_edges = {p: sorted(deps) for (p, deps) in edges.items()};
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
    try {
        disk_path.parent.mkdir(parents=True, exist_ok=True);
        import tempfile;
        with tempfile.NamedTemporaryFile(
            mode='w', dir=str(disk_path.parent), delete=False, encoding='utf-8'
        ) as tmp {
            json.dump({
                'format': 1, 'workspace': ws.digest, 'toolchain': toolchain,
                'files': file_record, 'imports': import_edges,
                'consumers': {p: sorted(names) for (p, names) in consumers.items()},
                'digest': digest
            }, tmp);
            tmp_path = tmp.name;
        }
        os.replace(tmp_path, str(disk_path));
    } except OSError {}

    return (consumers, digest);
}
