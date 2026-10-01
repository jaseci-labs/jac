import from jaclang.packages.semver { Version }

glob NONE: int = 0,
     PATCH: int = 1,
     MINOR: int = 2,
     MAJOR: int = 3,
     LEVEL_NAMES: dict[int, str] = {0: "none", 1: "patch", 2: "minor", 3: "major"},
     SCHEMA_KINDS: tuple[str, ...] = ("node", "edge");

obj ApiChange {
    has path: str,
        level: int,
        reason: str,
        schema: bool = False;

    def describe -> str {
        tag = " [persistence schema]" if self.schema else "";
        return f"{LEVEL_NAMES[self.level]}: {self.path}: {self.reason}{tag}";
    }
}

def _positional(sig: dict[str, any]) -> list[str] {
    return [
        p["name"]
        for p in sig.get("params", [])
        if p.get("kind") in ("positional", "normal")
    ];
}

def diff_signature(
    path: str, old: dict[str, any], new: dict[str, any]
) -> list[ApiChange] {
    out: list[ApiChange] = [];
    old_params = {p["name"]: p for p in old.get("params", [])};
    new_params = {p["name"]: p for p in new.get("params", [])};
    for (name, p) in old_params.items() {
        if name not in new_params {
            out.append(
                ApiChange(path=path, level=MAJOR, reason=f"parameter '{name}' removed")
            );
            continue;
        }
        q = new_params[name];
        if q.get("kind") != p.get("kind") {
            out.append(
                ApiChange(
                    path=path,
                    level=MAJOR,
                    reason=f"parameter '{name}' changed from {p.get('kind')} to {q.get(
                        'kind'
                    )}"
                )
            );
        }
        if q.get("type") != p.get("type") {
            out.append(
                ApiChange(
                    path=path,
                    level=MAJOR,
                    reason=f"parameter '{name}' type {p.get('type')} -> {q.get('type')}"
                )
            );
        }
        if p.get("default") and not q.get("default") {
            out.append(
                ApiChange(
                    path=path,
                    level=MAJOR,
                    reason=f"parameter '{name}' lost its default"
                )
            );
        } elif q.get("default") and not p.get("default") {
            out.append(
                ApiChange(
                    path=path,
                    level=MINOR,
                    reason=f"parameter '{name}' gained a default"
                )
            );
        }
    }
    for (name, q) in new_params.items() {
        if name in old_params {
            continue;
        }
        optional = q.get("default") or q.get("kind") in ("varargs", "kwargs");
        out.append(
            ApiChange(
                path=path,
                level=MINOR if optional else MAJOR,
                reason=(
                    f"optional parameter '{name}' added"
                        if optional
                        else f"required parameter '{name}' added"
                )
            )
        );
    }
    old_pos = [
        n
        for n in _positional(old)
        if n in new_params
    ];
    new_pos = [
        n
        for n in _positional(new)
        if n in old_params
    ];
    if old_pos != new_pos {
        out.append(
            ApiChange(path=path, level=MAJOR, reason="positional parameters reordered")
        );
    }
    if old.get("returns") != new.get("returns") {
        out.append(
            ApiChange(
                path=path,
                level=MAJOR,
                reason=f"return type {old.get('returns')} -> {new.get('returns')}"
            )
        );
    }
    return out;
}

def _diff_members(
    path: str, kind: str, old: dict[str, any], new: dict[str, any]
) -> list[ApiChange] {
    out: list[ApiChange] = [];
    schema = kind in SCHEMA_KINDS;
    for (name, m) in old.items() {
        mpath = f"{path}.{name}";
        if name not in new {
            is_field = m.get("kind") == "field";
            out.append(
                ApiChange(
                    path=mpath,
                    level=MAJOR,
                    reason=f"{m.get('kind')} removed",
                    schema=schema and is_field
                )
            );
            continue;
        }
        n = new[name];
        if n.get("kind") != m.get("kind") {
            out.append(
                ApiChange(
                    path=mpath,
                    level=MAJOR,
                    reason=f"{m.get('kind')} became a {n.get('kind')}",
                    schema=schema
                )
            );
            continue;
        }
        if m.get("kind") == "field" {
            if n.get("type") != m.get("type") {
                out.append(
                    ApiChange(
                        path=mpath,
                        level=MAJOR,
                        reason=f"field type {m.get('type')} -> {n.get('type')}",
                        schema=schema
                    )
                );
            }
            if m.get("default") and not n.get("default") {
                out.append(
                    ApiChange(path=mpath, level=MAJOR, reason="field lost its default")
                );
            }
        } elif m.get("kind") == "method" {
            out.extend(diff_signature(mpath, m, n));
        }
    }
    for (name, n) in new.items() {
        if name in old {
            continue;
        }
        mpath = f"{path}.{name}";
        if n.get("kind") == "field" and not n.get("default") {
            out.append(
                ApiChange(
                    path=mpath,
                    level=MAJOR,
                    reason="required field added (existing constructions break)",
                    schema=schema
                )
            );
        } else {
            out.append(
                ApiChange(
                    path=mpath,
                    level=MINOR,
                    reason=f"{n.get('kind')} added",
                    schema=schema and n.get("kind") == "field"
                )
            );
        }
    }
    return out;
}

def _diff_symbol(
    path: str, old: dict[str, any], new: dict[str, any]
) -> list[ApiChange] {
    if old.get("kind") != new.get("kind") {
        return [
            ApiChange(
                path=path,
                level=MAJOR,
                reason=f"{old.get('kind')} became a {new.get('kind')}",
                schema=old.get("kind") in SCHEMA_KINDS
                    or new.get("kind") in SCHEMA_KINDS
            )
        ];
    }
    kind = old.get("kind", "");
    if kind == "function" {
        return diff_signature(path, old, new);
    }
    if kind in ("global", "type") {
        if old.get("type") != new.get("type") {
            return [
                ApiChange(
                    path=path,
                    level=MAJOR,
                    reason=f"type {old.get('type')} -> {new.get('type')}"
                )
            ];
        }
        return [];
    }
    out: list[ApiChange] = [];
    if old.get("bases") != new.get("bases") {
        out.append(
            ApiChange(
                path=path,
                level=MAJOR,
                reason=f"bases {old.get('bases')} -> {new.get('bases')}"
            )
        );
    }
    out.extend(
        _diff_members(path, kind, old.get("members", {}), new.get("members", {}))
    );
    return out;
}

def diff_surfaces(old: dict[str, any], new: dict[str, any]) -> list[ApiChange] {
    out: list[ApiChange] = [];
    old_mods: dict[str, any] = old.get("modules", {});
    new_mods: dict[str, any] = new.get("modules", {});
    for (module, symbols) in sorted(old_mods.items()) {
        if module not in new_mods {
            out.append(
                ApiChange(path=module, level=MAJOR, reason="exported module removed")
            );
            continue;
        }
        fresh = new_mods[module];
        for (name, sym) in sorted(symbols.items()) {
            path = f"{module}.{name}";
            if name not in fresh {
                out.append(
                    ApiChange(
                        path=path,
                        level=MAJOR,
                        reason=f"{sym.get('kind')} removed",
                        schema=sym.get("kind") in SCHEMA_KINDS
                    )
                );
                continue;
            }
            out.extend(_diff_symbol(path, sym, fresh[name]));
        }
        for (name, sym) in sorted(fresh.items()) {
            if name not in symbols {
                out.append(
                    ApiChange(
                        path=f"{module}.{name}",
                        level=MINOR,
                        reason=f"{sym.get('kind')} added"
                    )
                );
            }
        }
    }
    for module in sorted(new_mods) {
        if module not in old_mods {
            out.append(
                ApiChange(path=module, level=MINOR, reason="exported module added")
            );
        }
    }
    return out;
}

def required_level(changes: list[ApiChange]) -> int {
    level = PATCH;
    for change in changes {
        level = max(level, change.level);
    }
    return level;
}

def bump_level(old: Version, new: Version) -> int {
    if new <= old {
        return NONE;
    }
    if old.major == 0 and new.major == 0 {
        if old.minor == 0 and new.minor == 0 {
            return MAJOR;
        }
        if new.minor != old.minor {
            return MAJOR;
        }
        return MINOR;
    }
    if new.major != old.major {
        return MAJOR;
    }
    if new.minor != old.minor {
        return MINOR;
    }
    return PATCH;
}

def check_bump(old: Version, new: Version, changes: list[ApiChange]) -> str {
    actual = bump_level(old, new);
    if actual == NONE {
        return f"version {new} must be greater than the previous release {old}";
    }
    needed = required_level(changes);
    if actual < needed {
        return (
            f"{old} -> {new} is a {LEVEL_NAMES[actual]} bump, but the exported API "
            f"changes need a {LEVEL_NAMES[needed]} bump"
        );
    }
    return "";
}

def minimum_next(old: Version, changes: list[ApiChange]) -> Version {
    needed = required_level(changes);
    if old.major == 0 {
        if needed == MAJOR {
            return old.bump_minor() if old.minor > 0 else old.bump_patch();
        }
        return old.bump_patch();
    }
    if needed == MAJOR {
        return old.bump_major();
    }
    if needed == MINOR {
        return old.bump_minor();
    }
    return old.bump_patch();
}
