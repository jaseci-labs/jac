"""Implementation of jac-shadcn lockfile helpers."""

import tomlkit;
import from pathlib { Path }

glob LOCKFILE_NAME: str = "jac-shadcn.lock";
glob LOCKFILE_VERSION: int = 1;


"""Extract `npm_deps` list from a lockfile entry, tolerating tomlkit's
typed wrappers and missing fields."""
def _entry_npm_deps(record: any) -> list {
    if record is None {
        return [];
    }
    deps = record["npm_deps"] if "npm_deps" in record else [];
    return list(deps);
}


"""Get a single field from a lockfile entry. Returns None if missing."""
def _entry_field(record: any, key: str) -> any {
    if record is None {
        return None;
    }
    return record[key] if key in record else None;
}

impl lockfile_path(project_root: Path) -> Path {
    return Path(str(project_root)) / LOCKFILE_NAME;
}

impl load_lockfile(project_root: Path) -> dict {
    path = lockfile_path(project_root);
    if not path.exists() {
        return {};
    }
    with open(path, "r") as f {
        data = tomlkit.parse(f.read());
    }
    # Normalize so callers don't need to guard against missing top-level keys.
    if "components" not in data {
        data["components"] = tomlkit.table();
    }
    return data;
}

impl save_lockfile(project_root: Path, data: dict) -> None {
    path = lockfile_path(project_root);
    if "version" not in data {
        data["version"] = LOCKFILE_VERSION;
    }
    if "components" not in data {
        data["components"] = tomlkit.table();
    }
    with open(path, "w") as f {
        f.write(tomlkit.dumps(data));
    }
}

impl record_install(
    project_root: Path, name: str, version: str, npm_deps: list
) -> None {
    data = load_lockfile(project_root);
    if "components" not in data {
        data["components"] = tomlkit.table();
    }
    entry = tomlkit.table();
    entry["version"] = version;
    entry["npm_deps"] = sorted(list(npm_deps));
    data["components"][name] = entry;
    save_lockfile(project_root, data);
}

impl record_remove(project_root: Path, name: str) -> None {
    data = load_lockfile(project_root);
    components = data.get("components");
    if components is None or name not in components {
        return;
    }
    del components[name];
    save_lockfile(project_root, data);
}

impl compute_orphan_deps(project_root: Path, removed_names: list) -> list {
    data = load_lockfile(project_root);
    components = data.get("components", {});

    # Union of npm deps held by entries that are NOT being removed.
    keep_set: set = set();
    for (name, raw_entry) in components.items() {
        if name in removed_names {
            continue;
        }
        deps = _entry_npm_deps(raw_entry);
        for dep in deps {
            keep_set.add(str(dep));
        }
    }

    # npm deps owned by the removed entries that nothing else claims.
    orphans: set = set();
    for name in removed_names {
        raw_entry = components.get(name);
        if raw_entry is None {
            continue;
        }
        deps = _entry_npm_deps(raw_entry);
        for dep in deps {
            dep_str = str(dep);
            if dep_str not in keep_set {
                orphans.add(dep_str);
            }
        }
    }
    return sorted(list(orphans));
}

impl installed_version(project_root: Path, name: str) -> str | None {
    data = load_lockfile(project_root);
    components = data.get("components", {});
    raw_entry = components.get(name);
    if raw_entry is None {
        return None;
    }
    ver = _entry_field(raw_entry, "version");
    return str(ver) if ver is not None else None;
}
