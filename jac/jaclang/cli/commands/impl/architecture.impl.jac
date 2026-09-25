import json;
import os;
import from enum { StrEnum }

enum ArchAction(StrEnum) { INIT = "init", SYNC = "sync", GRAPH = "graph" }

glob WIRE_LINE_WIDTH: int = 88;

obj WireRow {
    has provider: str,
        form: str,
        alias: str = "",
        items: list[tuple[str, str]] = [],
        consumers: list[str] = [];

    def key -> tuple[str, str, str, tuple[tuple[str, str], ...]] {
        return (self.provider, self.form, self.alias, tuple(self.items));
    }

    def text(scope: str) -> str {
        left = self.provider;
        if scope and left.startswith(scope + ".") {
            left = left[len(scope) + 1:];
        }
        words = [
            w
            for w in self.form.split(" ")
            if w in ("comptime", "include", "type")
        ];
        head = (" ".join(words) + " " if words else "") + left;
        right = " | ".join(self.consumers);
        if "from" in self.form {
            payload = ", ".join(
                [
                    name + (" as " + alias if alias else "")
                    for (name, alias) in self.items
                ]
            );
            return f"{head} --> {right} {{ {payload} }}";
        }
        alias = " as " + self.alias if self.alias else "";
        return f"{head}{alias} --> {right};";
    }
}

def _parse_action(action: str) -> (ArchAction | None) {
    try {
        return ArchAction(action);
    } except ValueError {
        return None;
    }
}

def _project_root -> (str | None) {
    cfg = get_config();
    if cfg is None or cfg.project_root is None {
        console.error(
            "no jac.toml found; run `jac arch` inside a project",
            hint="arch.jac lives beside jac.toml",
        );
        return None;
    }
    return str(cfg.project_root);
}

def _empty_spec(root_dir: str) -> WiringSpec {
    return WiringSpec(
        root_dir=root_dir, path=os.path.join(root_dir, ARCH_FILE_NAME), source=""
    );
}

def _module_files(spec: WiringSpec) -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    for name in spec.project_modules() {
        path = spec.module_file(name);
        if path is not None and path.endswith(".jac") {
            out.append((name, path));
        }
    }
    return out;
}

def _parse_imports(path: str) -> list[tuple[Import, (list[str] | None)]] {
    try {
        (mod, _err) = parse_woven(read_file_with_encoding(path), path, None, []);
    } except Exception {
        return [];
    }
    out: list[tuple[Import, (list[str] | None)]] = [];
    for imp in mod.get_all_sub_nodes(typ=Import) {
        out.append((imp, [] if imp.parent is mod else scope_path_of(imp)));
    }
    return out;
}

def _collect_rows(spec: WiringSpec, modules: list[tuple[str, str]]) -> list[WireRow] {
    rows: dict[tuple[str, str, str, tuple[tuple[str, str], ...]], list[WireRow]] = {};
    owner_of: dict[str, str] = {};
    for (module, path) in modules {
        payloads: dict[tuple[str, str, str], list[tuple[str, str]]] = {};
        module_rows: list[tuple[str, WireRow]] = [];
        provided_by_scope: dict[str, dict[tuple[str, str, str, str], ImportWire]] = {};
        sources = [path, *discover_annex_files(path, ".impl.jac")];
        for src in sources {
            for (imp, scope) in _parse_imports(src) {
                if scope is None {
                    continue;
                }
                consumer = ".".join([module, *scope]);
                if consumer not in provided_by_scope {
                    provided_by_scope[consumer] = spec.consumer_bindings(module, scope);
                }
                provided = provided_by_scope[consumer];
                from_loc = imp.from_loc;
                if from_loc is not None {
                    provider = spec.import_provider(from_loc);
                    if provider is None or provider == module {
                        continue;
                    }
                    form = WiringSpec.import_form(
                        imp.is_absorb, imp.is_typed, imp.is_comptime, True
                    );
                    bucket = payloads.setdefault((provider, form, consumer), []);
                    for item in imp.items {
                        if not isinstance(item, ModuleItem) {
                            continue;
                        }
                        alias = item.alias.value if item.alias is not None else "";
                        if (provider, form, item.name.value, alias) in provided {
                            continue;
                        }
                        item_entry = (item.name.value, alias);
                        if item_entry not in bucket {
                            bucket.append(item_entry);
                        }
                    }
                    continue;
                }
                form = WiringSpec.import_form(
                    imp.is_absorb, imp.is_typed, imp.is_comptime, False
                );
                for item in imp.items {
                    if not isinstance(item, ModulePath) {
                        continue;
                    }
                    provider = spec.import_provider(item);
                    if provider is None or provider == module {
                        continue;
                    }
                    alias = item.alias.value if item.alias is not None else "";
                    if (provider, form, "", alias) in provided {
                        continue;
                    }
                    module_rows.append(
                        (consumer, WireRow(provider=provider, form=form, alias=alias))
                    );
                }
            }
        }
        for ((provider, form, consumer), items) in payloads.items() {
            if items {
                module_rows.append(
                    (
                        consumer,
                        WireRow(provider=provider, form=form, items=sorted(items))
                    )
                );
            }
        }
        for (consumer, row) in module_rows {
            candidates = rows.setdefault(row.key(), []);
            target: (WireRow | None) = None;
            for cand in candidates {
                if consumer in cand.consumers {
                    target = cand;
                    break;
                }
                if not any([owner_of[c] == module for c in cand.consumers]) {
                    target = cand;
                    break;
                }
            }
            if target is None {
                target = WireRow(
                    provider=row.provider,
                    form=row.form,
                    alias=row.alias,
                    items=row.items
                );
                candidates.append(target);
            }
            if consumer not in target.consumers {
                target.consumers.append(consumer);
                owner_of[consumer] = module;
            }
        }
    }
    out: list[WireRow] = [];
    for group in rows.values() {
        for row in group {
            if (
                len(row.consumers) == 1
                or len(row.text(_scope_of(row.provider))) + 4 <= WIRE_LINE_WIDTH
            ) {
                out.append(row);
                continue;
            }
            for consumer in sorted(row.consumers) {
                out.append(
                    WireRow(
                        provider=row.provider,
                        form=row.form,
                        alias=row.alias,
                        items=row.items,
                        consumers=[consumer]
                    )
                );
            }
        }
    }
    return sorted(
        out,
        key=lambda (r: WireRow) { (
            r.provider,
            r.consumers[0] if r.consumers else "",
            r.form
        ); }
    );
}

def _scope_of(provider: str) -> str {
    return provider.rsplit(".", 1)[0] if "." in provider else "";
}

def _merge_into(spec: WiringSpec, rows: list[WireRow]) -> str {
    lines = spec.source.split("\n");
    insertions: list[tuple[int, list[str]]] = [];
    appended: list[str] = [];
    groups: dict[str, list[WireRow]] = {};
    for row in rows {
        groups.setdefault(_scope_of(row.provider), []).append(row);
    }
    for scope in sorted(groups.keys()) {
        block: (GraphImport | None) = None;
        for candidate in spec.blocks {
            if candidate.scope_prefix == scope {
                block = candidate;
            }
        }
        texts = ["    " + row.text(scope) for row in groups[scope]];
        if block is None {
            head = "graph import" + (" " + scope if scope else " ") + "{";
            appended.append("\n".join([head, *texts, "}"]));
        } else {
            insertions.append((block.loc.last_line - 1, texts));
        }
    }
    for (line_idx, texts) in sorted(insertions, reverse=True) {
        lines[line_idx:line_idx] = texts;
    }
    text = "\n".join(lines).rstrip("\n");
    if appended {
        text = (text + "\n\n" if text else "") + "\n\n".join(appended);
    }
    return text + "\n";
}

def _render_blocks(rows: list[WireRow]) -> str {
    groups: dict[str, list[WireRow]] = {};
    for row in rows {
        groups.setdefault(_scope_of(row.provider), []).append(row);
    }
    blocks: list[str] = [];
    for scope in sorted(groups.keys()) {
        head = "graph import" + (" " + scope if scope else "") + " {";
        lines = [head, *["    " + row.text(scope) for row in groups[scope]], "}"];
        blocks.append("\n".join(lines));
    }
    return "\n\n".join(blocks) + "\n";
}

def _format_source(text: str, path: str) -> str {
    prog = JacProgram.jac_str_formatter(text, path);
    if prog.errors_had or prog.mod.main is None {
        return text;
    }
    return prog.mod.main.gen.jac;
}

def _write_arch(arch_path: str, text: str) {
    formatted = _format_source(text, arch_path);
    tmp = arch_path + ".tmp";
    with open(tmp, "w") as f {
        f.write(formatted);
    }
    os.replace(tmp, arch_path);
}

def _strip_modules(paths: list[str]) -> int {
    changed = 0;
    for path in paths {
        annexes = [
            *discover_annex_files(path, ".impl.jac"),
            *discover_annex_files(path, ".test.jac")
        ];
        for target in [path, *annexes] {
            prog = JacProgram.jac_file_formatter(target, auto_lint=True);
            format_failed = any(
                [e.code is not None and e.code.code == "E5051" for e in prog.errors_had]
            );
            stripped = any(
                [
                    w.code is not None and w.code.code == "W3053"
                    for w in prog.warnings_had
                ]
            );
            if format_failed or not stripped or prog.mod.main is None {
                continue;
            }
            formatted = prog.mod.main.gen.jac;
            if formatted and formatted != prog.mod.main.source.code {
                with open(target, "w") as f {
                    f.write(formatted);
                }
                changed += 1;
            }
        }
    }
    return changed;
}

def _arch_target(directory: str) -> (str | None) {
    if directory {
        return os.path.abspath(directory);
    }
    return _project_root();
}

def _arch_files(root_dir: str) -> list[str] {
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(root_dir) {
        dirnames[:] = sorted(
            [
                d
                for d in dirnames
                if not d.startswith(".")
                    and d not in ("node_modules", "__pycache__")
                    and not os.path.isfile(os.path.join(dirpath, d, "jac.toml"))
            ]
        );
        if ARCH_FILE_NAME in filenames {
            found.append(os.path.join(dirpath, ARCH_FILE_NAME));
        }
    }
    return drop_git_ignored(found, cwd=root_dir);
}

def _arch_init(force: bool, strip: bool, directory: str) -> int {
    root_dir = _arch_target(directory);
    if root_dir is None {
        return 1;
    }
    arch_path = os.path.join(root_dir, ARCH_FILE_NAME);
    if os.path.exists(arch_path) and not force {
        console.error(
            f"{arch_path} already exists",
            hint="use `jac arch sync` to extend it, or --force to rewrite it"
        );
        return 1;
    }
    spec = _empty_spec(root_dir);
    modules = _module_files(spec);
    rows = _collect_rows(spec, modules);
    _write_arch(arch_path, _render_blocks(rows) if rows else "");
    console.success(
        f"wrote {ARCH_FILE_NAME}: {len(rows)} wires sealing {len(modules)} modules"
    );
    if strip {
        changed = _strip_modules([path for (_name, path) in modules]);
        console.print(f"stripped wired imports from {changed} files");
    }
    return 0;
}

def _row_bindings(row: WireRow) -> list[tuple[str, str, str, str]] {
    if "from" in row.form {
        return [(row.provider, row.form, name, alias) for (name, alias) in row.items];
    }
    return [(row.provider, row.form, "", row.alias)];
}

def _arch_sync(strip: bool, directory: str) -> int {
    root_dir = _arch_target(directory);
    if root_dir is None {
        return 1;
    }
    targets = [os.path.join(root_dir, ARCH_FILE_NAME)]
        if directory
        else _arch_files(root_dir);
    if not targets {
        console.error(
            f"no {ARCH_FILE_NAME} under {root_dir}", hint="run `jac arch init` first"
        );
        return 1;
    }
    status = 0;
    for arch_path in targets {
        status = max(status, _sync_one(arch_path, strip));
    }
    return status;
}

def _sync_one(arch_path: str, strip: bool) -> int {
    spec = wiring_for_path(arch_path) if os.path.isfile(arch_path) else None;
    if spec is None {
        console.error(f"{arch_path} does not exist", hint="run `jac arch init` first");
        return 1;
    }
    if spec.parse_failed {
        console.error(f"{arch_path} has syntax errors; fix them before syncing");
        return 1;
    }
    modules = _module_files(spec);
    rows = _collect_rows(spec, modules);
    if rows {
        _write_arch(arch_path, _merge_into(spec, rows));
        console.success(f"added {len(rows)} wires to {arch_path}");
    } else {
        console.print(f"{arch_path} already declares every import of its modules");
    }
    if strip {
        changed = _strip_modules([path for (_name, path) in modules]);
        console.print(f"stripped wired imports from {changed} files");
    }
    return 0;
}

def _node_id(name: str) -> str {
    return name.replace(".", "_").replace("-", "_");
}

def _render_mermaid(spec: WiringSpec) -> str {
    lines: list[str] = ["graph LR"];
    for rule in spec.rules {
        srcs = " | ".join([WiringSpec.pattern_text(p) for p in rule.sources]);
        tgts = " | ".join([WiringSpec.pattern_text(p) for p in rule.targets]);
        names = ""
            if rule.is_open
            else " { " + ", ".join(sorted(rule.item_names)) + " }";
        lines.append(f"    %% edge {rule.name.value}: {srcs} --> {tgts}{names}");
    }
    modules: set[str] = set();
    for wire in spec.wires {
        modules.add(wire.provider_path);
        modules.update(wire.consumer_paths);
    }
    packages: dict[str, list[str]] = {};
    for name in sorted(modules) {
        packages.setdefault(name.split(".")[0], []).append(name);
    }
    for (pkg, names) in sorted(packages.items()) {
        lines.append(f"    subgraph {pkg}");
        for name in names {
            lines.append(f"        {_node_id(name)}[{name}]");
        }
        lines.append("    end");
    }
    for wire in spec.wires {
        label = (
            "module"
                if wire.is_module_form
                else ", ".join([item.name.value for item in wire.items])
        );
        for consumer in wire.consumer_paths {
            lines.append(
                f"    {_node_id(wire.provider_path)} -->|{label}| {_node_id(consumer)}"
            );
        }
    }
    return "\n".join(lines) + "\n";
}

def _render_json(spec: WiringSpec) -> str {
    wires = [
        {
            "provider": wire.provider_path,
            "consumers": list(wire.consumer_paths),
            "form": WiringSpec.import_form(
                wire.is_absorb, wire.is_typed, wire.is_comptime, not wire.is_module_form
            ),
            "names": (
                None
                    if wire.is_module_form
                    else [
                        {
                            "name": item.name.value,
                            "alias": item.alias.value
                                if item.alias is not None
                                else None
                        } for item in wire.items
                    ]
            )
        } for wire in spec.wires
    ];
    rules = [
        {
            "name": rule.name.value,
            "scope": rule.block.scope_prefix,
            "sources": [WiringSpec.pattern_text(p) for p in rule.sources],
            "targets": [WiringSpec.pattern_text(p) for p in rule.targets],
            "names": None if rule.is_open else sorted(rule.item_names)
        } for rule in spec.rules
    ];
    return json.dumps({"wires": wires, "rules": rules}, indent=2) + "\n";
}

def _arch_graph(fmt: str, output: str, directory: str) -> int {
    root_dir = _arch_target(directory);
    if root_dir is None {
        return 1;
    }
    arch_path = os.path.join(root_dir, ARCH_FILE_NAME);
    spec = wiring_for_path(arch_path);
    if spec is None {
        console.error(f"{arch_path} does not exist", hint="run `jac arch init` first");
        return 1;
    }
    text = _render_json(spec) if fmt == "json" else _render_mermaid(spec);
    if output {
        with open(output, "w") as f {
            f.write(text);
        }
        console.success(f"wrote {output}");
        return 0;
    }
    console.print(text, end="");
    return 0;
}

impl arch(
    action: str = "graph",
    scope: str = "",
    strip: bool = False,
    force: bool = False,
    format: str = "mermaid",
    output: str = ""
) -> int {
    verb = _parse_action(action);
    if verb is None {
        console.error(f"unknown action: {action} (expected init, sync or graph)");
        return 2;
    }
    if scope and not os.path.isdir(scope) {
        console.error(
            f"'{scope}' is not a directory; `jac arch` takes the directory an arch.jac governs"
        );
        return 2;
    }
    if verb == ArchAction.INIT {
        return _arch_init(force, strip, scope);
    }
    if verb == ArchAction.SYNC {
        return _arch_sync(strip, scope);
    }
    return _arch_graph(format, output, scope);
}
