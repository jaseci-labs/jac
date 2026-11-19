impl archwire_apps(root_dir: str) -> dict[str, DerivedApp] {
    import os;
    arch = os.path.join(root_dir, "archwire.jac");
    if not os.path.isfile(arch) {
        return {};
    }
    spec = wiring_for_path(arch);
    if spec is None or not spec.spaces {
        return {};
    }
    spaces = {s.name: s for s in spec.spaces};
    hosts = {s.name: s.host for s in spec.spaces};
    arrangements: dict[str, dict[str, list[str]]] = {};
    for app in spec.apps {
        arrangements.setdefault(app.name, {})[app.profile or "default"] = list(app.runs);
    }
    out: dict[str, DerivedApp] = {};
    for app in spec.apps {
        if app.profile {
            continue;
        }
        run_spaces = [spaces[n] for n in app.runs if n in spaces];
        serve_spaces = [spaces[n] for n in app.serves if n in spaces];
        browser = [s for s in run_spaces + serve_spaces if s.host == "browser"];
        hermes = [s for s in run_spaces if s.host == "hermes"];
        native = [s for s in run_spaces if s.host in ("native", "cpython", "node")];
        started = [s for s in native if s.entry_module];
        kind = "";
        entry_point = "";
        if serve_spaces and native {
            kind = "web-app";
            entry_point = _space_entry(browser[0] if browser else native[0]);
        } elif browser and not native {
            kind = "desktop";
            entry_point = _space_entry(browser[0]);
        } elif hermes {
            kind = "mobile";
            entry_point = _space_entry(hermes[0]);
        } elif started {
            kind = "cli";
            entry_point = started[0].entry_module;
        } elif native {
            kind = "service";
            entry_point = _space_entry(native[0]);
        }
        if not kind or not entry_point {
            continue;
        }
        pins: dict[str, str] = {};
        for s in run_spaces + serve_spaces {
            place = HOST_PLACEMENT.get(s.host, "");
            if not place {
                continue;
            }
            if s.entry_module {
                pins[s.entry_module] = place;
            }
            for p in s.patterns {
                pins[p.dotted + (".*" if p.is_glob else "")] = place;
            }
        }
        held = set(app.runs) | set(app.serves);
        out[app.name] = DerivedApp(
            name=app.name,
            kind=kind,
            entry_point=entry_point,
            pins=pins,
            runs=list(app.runs),
            serves=list(app.serves),
            remote=[s.name for s in spec.spaces if s.name not in held],
            arrangements=arrangements.get(app.name, {}),
            hosts=hosts
        );
    }
    return out;
}

impl _space_entry(space: SpaceRec) -> str {
    if space.entry_module {
        return space.entry_module;
    }
    for p in space.patterns {
        if not p.is_glob and p.dotted {
            return p.dotted;
        }
    }
    return "";
}
