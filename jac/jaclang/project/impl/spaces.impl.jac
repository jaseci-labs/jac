impl archwire_apps(root_dir: str) -> dict[str, DerivedApp] {
    arch = os.path.join(root_dir, "archwire.jac");
    if not os.path.isfile(arch) {
        return {};
    }
    source = "";
    with open(arch, encoding="utf-8") as fh {
        source = fh.read();
    }
    (spaces, apps) = _declarations(source);
    out: dict[str, DerivedApp] = {};
    for (name, runs, serves) in apps {
        derived = _derive(
            name,
            [
                spaces[n]
                for n in runs
                if n in spaces
            ],
            [
                spaces[n]
                for n in serves
                if n in spaces
            ]
        );
        if derived is not None {
            out[name] = derived;
        }
    }
    return out;
}

impl _braced(text: str, open_at: int) -> tuple[str, int] {
    depth = 0;
    for i in range(open_at, len(text)) {
        if text[i] == "{" {
            depth += 1;
        } elif text[i] == "}" {
            depth -= 1;
            if depth == 0 {
                return (text[open_at + 1:i], i + 1);
            }
        }
    }
    return (text[open_at + 1:], len(text));
}

impl _declarations(
    source: str
) -> tuple[dict[str, Space], list[tuple[str, list[str], list[str]]]] {
    spaces: dict[str, Space] = {};
    apps: list[tuple[str, list[str], list[str]]] = [];
    for block in re.finditer(r"\bgraph\s+spaces(?:\s+(\w+))?\s*\{", source) {
        (body, _) = _braced(source, block.end() - 1);
        at = 0;
        while (
            decl
            := re.compile(r"\b(space|app)\s+(\w+)\s*(?::\s*(\w+))?\s*\{").search(
                body, at
            )
        )
            is not None {
            (inner, at) = _braced(body, decl.end() - 1);
            items = [
                part.strip()
                for part in inner.split(";")
                if part.strip()
            ];
            if decl.group(1) == "space" {
                start_module = "";
                patterns: list[str] = [];
                for item in items {
                    words = item.split();
                    if words[0] == "entry" and len(words) == 2 {
                        start_module = words[1];
                    } elif words[0] not in ("store", "auth") {
                        patterns.extend(
                            [
                                p.strip()
                                for p in item.split("|")
                                if p.strip()
                            ]
                        );
                    }
                }
                spaces[decl.group(2)] = Space(
                    name=decl.group(2),
                    host=decl.group(3) or "",
                    entry_module=start_module,
                    patterns=patterns
                );
            } elif block.group(1) is None {
                runs: list[str] = [];
                serves: list[str] = [];
                for item in items {
                    (word, _, rest) = item.partition(" ");
                    names = [
                        n.strip()
                        for n in rest.split(",")
                        if n.strip()
                    ];
                    if word == "run" {
                        runs.extend(names);
                    } elif word == "serve" {
                        serves.extend(names);
                    }
                }
                apps.append((decl.group(2), runs, serves));
            }
        }
    }
    return (spaces, apps);
}

impl _derive(name: str, runs: list[Space], serves: list[Space]) -> DerivedApp | None {
    browser = [
        s
        for s in runs + serves
        if s.host == "browser"
    ];
    hermes = [
        s
        for s in runs
        if s.host == "hermes"
    ];
    native = [
        s
        for s in runs
        if s.host in ("native", "cpython", "node")
    ];
    started = [
        s
        for s in native
        if s.entry_module
    ];
    kind = "";
    entry_point = "";
    if serves and native {
        kind = "web-app";
        entry_point = _entry_of(browser[0] if browser else native[0]);
    } elif browser and not native {
        kind = "desktop";
        entry_point = _entry_of(browser[0]);
    } elif hermes {
        kind = "mobile";
        entry_point = _entry_of(hermes[0]);
    } elif started {
        kind = "cli";
        entry_point = started[0].entry_module;
    } elif native {
        kind = "service";
        entry_point = _entry_of(native[0]);
    }
    if not kind or not entry_point {
        return None;
    }
    pins: dict[str, str] = {};
    for s in runs + serves {
        place = HOST_PLACEMENT.get(s.host, "");
        if not place {
            continue;
        }
        if s.entry_module {
            pins[s.entry_module] = place;
        }
        for pattern in s.patterns {
            pins[pattern] = place;
        }
    }
    return DerivedApp(name=name, kind=kind, entry_point=entry_point, pins=pins);
}

impl _entry_of(space: Space) -> str {
    if space.entry_module {
        return space.entry_module;
    }
    for pattern in space.patterns {
        if not pattern.endswith(".*") {
            return pattern;
        }
    }
    return "";
}
