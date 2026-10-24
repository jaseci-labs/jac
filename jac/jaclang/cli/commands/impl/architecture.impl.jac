import json;
import os;
import from enum { StrEnum }

enum ArchAction(StrEnum) { INIT = "init", SYNC = "sync", GRAPH = "graph" }

def _parse_action(action: str) -> (ArchAction | None);

def _project_root -> (str | None);

def _empty_spec(root_dir: str) -> WiringSpec;

def _module_files(spec: WiringSpec) -> list[tuple[str, str]];

def _parse_imports(path: str) -> list[tuple[Import, (list[str] | None)]];

def _collect_facts(
    spec: WiringSpec, modules: list[tuple[str, str]]
) -> list[tuple[str, WireBinding]];

def _unused_facts(
    spec: WiringSpec, modules: list[tuple[str, str]]
) -> set[tuple[str, tuple[str, str, str, str]]];

def _feeds(spec: WiringSpec, consumer: str, module: str) -> bool;

def _write_arch(arch_path: str, text: str) -> bool;

def _strip_modules(paths: list[str]) -> int;

def _arch_target(directory: str) -> (str | None);

def _arch_files(root_dir: str) -> list[str];

def _arch_init(force: bool, strip: bool, directory: str) -> int;

def _arch_sync(strip: bool, directory: str, prune: bool = False) -> int;

def _sync_one(arch_path: str, strip: bool, prune: bool) -> int;

def _node_id(name: str) -> str;

def _render_mermaid(spec: WiringSpec) -> str;

def _render_json(spec: WiringSpec) -> str;

def _arch_graph(fmt: str, output: str, directory: str) -> int;

impl arch(
    action: str = "graph",
    scope: str = "",
    strip: bool = False,
    prune: bool = False,
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
            f"'{scope}' is not a directory; `jac arch` takes the directory an archwire.jac governs"
        );
        return 2;
    }
    if verb == ArchAction.INIT {
        return _arch_init(force, strip, scope);
    }
    if verb == ArchAction.SYNC {
        return _arch_sync(strip, scope, prune);
    }
    return _arch_graph(format, output, scope);
}

impl _parse_action(action: str) -> (ArchAction | None) {
    try {
        return ArchAction(action);
    } except ValueError {
        return None;
    }
}

impl _project_root -> (str | None) {
    cfg = get_config();
    if cfg is None or cfg.project_root is None {
        console.error(
            "no jac.toml found; run `jac arch` inside a project",
            hint="archwire.jac lives beside jac.toml",
        );
        return None;
    }
    return str(cfg.project_root);
}

impl _empty_spec(root_dir: str) -> WiringSpec {
    return WiringSpec(root_dir=root_dir, path=os.path.join(root_dir, ARCH_FILE_NAME));
}

impl _module_files(spec: WiringSpec) -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    for name in spec.project_modules() {
        path = spec.module_file(name);
        if path is not None and path.endswith(".jac") {
            out.append((name, path));
        }
    }
    return out;
}

impl _parse_imports(path: str) -> list[tuple[Import, (list[str] | None)]] {
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

impl _collect_facts(
    spec: WiringSpec, modules: list[tuple[str, str]]
) -> list[tuple[str, WireBinding]] {
    facts: list[tuple[str, WireBinding]] = [];
    seen: set[tuple[str, tuple[str, str, str, str]]] = set();
    for (module, path) in modules {
        for src in [path, *discover_annex_files(path, ".impl.jac")] {
            for (imp, scope) in _parse_imports(src) {
                if scope is None {
                    continue;
                }
                consumer = ".".join([module, *scope]);
                provided = spec.consumer_bindings(module, scope);
                injected = not is_positional_import(imp);
                for (binding, _item) in spec.import_bindings(imp) {
                    binding.injected = injected;
                    key = (consumer, binding.key());
                    if binding.provider == module
                        or binding.key() in provided
                        or key in seen {
                        continue;
                    }
                    seen.add(key);
                    facts.append((consumer, binding));
                }
            }
        }
    }
    return facts;
}

impl _unused_facts(
    spec: WiringSpec, modules: list[tuple[str, str]]
) -> set[tuple[str, tuple[str, str, str, str]]] {
    unused: set[tuple[str, tuple[str, str, str, str]]] = set();
    host = active_host();
    for (module, path) in modules {
        mod = host.woven_module(path, None) if spec.is_covered(module) else None;
        if mod is None {
            continue;
        }
        for found in unused_wire_bindings(mod) {
            unused.add((found.consumer, found.binding.key()));
        }
    }
    return unused;
}

impl _feeds(spec: WiringSpec, consumer: str, module: str) -> bool {
    split = spec.split_consumer(consumer);
    return (split[0] if split is not None else consumer) == module;
}

impl _write_arch(arch_path: str, text: str) -> bool {
    import tempfile;
    prog = JacProgram.jac_str_formatter(text, arch_path);
    if prog.errors_had or prog.mod.main is None {
        console.error(
            f"refusing to write {arch_path}: the rendered wiring does not parse",
            hint=str(prog.errors_had[0]) if prog.errors_had else None
        );
        return False;
    }
    formatted = prog.mod.main.gen.jac;
    (fd, tmp) = tempfile.mkstemp(
        dir=os.path.dirname(arch_path) or ".", prefix=".arch.", suffix=".tmp"
    );
    try {
        with os.fdopen(fd, "w") as f {
            f.write(formatted);
        }
        os.replace(tmp, arch_path);
    } except BaseException as err {
        if os.path.exists(tmp) {
            os.unlink(tmp);
        }
        raise err;
    }
    return True;
}

impl _strip_modules(paths: list[str]) -> int {
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
                    w.code is not None and w.code.code in ("W3053", "W3054")
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

impl _arch_target(directory: str) -> (str | None) {
    if directory {
        return os.path.abspath(directory);
    }
    return _project_root();
}

impl _arch_files(root_dir: str) -> list[str] {
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

impl _arch_init(force: bool, strip: bool, directory: str) -> int {
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
    parent_arch = arch_file_for(os.path.dirname(os.path.realpath(root_dir)));
    parent = wiring_for_path(parent_arch) if parent_arch is not None else None;
    if parent is not None {
        fed = [
            path
            for (_name, path) in modules
            if parent.is_covered(parent.module_name(path) or "")
        ];
        if fed {
            console.error(
                f"{len(fed)} modules under {root_dir} take their imports from "
                f"{parent.path}; a new {ARCH_FILE_NAME} here would cut them off",
                hint="write those imports back into the modules first, or extend "
                f"{parent.path} with `jac arch sync`"
            );
            return 1;
        }
    }
    facts = _collect_facts(spec, modules);
    rules = propose_rules(spec, facts, []);
    if not _write_arch(arch_path, render_wiring(spec, facts, rules)) {
        return 1;
    }
    console.success(
        f"wrote {ARCH_FILE_NAME}: {len(facts)} wired names and {len(
            rules
        )} rules sealing {len(modules)} modules"
    );
    if strip {
        changed = _strip_modules([path for (_name, path) in modules]);
        console.print(f"stripped wired imports from {changed} files");
    }
    return 0;
}

impl _arch_sync(strip: bool, directory: str, prune: bool = False) -> int {
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
        status = max(status, _sync_one(arch_path, strip, prune));
    }
    return status;
}

impl _sync_one(arch_path: str, strip: bool, prune: bool) -> int {
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
    added = _collect_facts(spec, modules);
    dropped = _unused_facts(spec, modules) if prune else set();
    facts = [
        (consumer, binding)
        for (consumer, binding) in wiring_facts(spec.wires) + added
        if (consumer, binding.key()) not in dropped
    ];
    rules = propose_rules(spec, facts, spec.rules);
    before = {rule_text(r) for r in spec.rules};
    admitted = len(
        [
            r
            for r in rules
            if rule_text(r) not in before
        ]
    );
    if not _write_arch(arch_path, render_wiring(spec, facts, rules)) {
        return 1;
    }
    console.success(
        f"{arch_path}: added {len(added)} wired names, removed {len(dropped)} unused,"
        f" {admitted} rules added or widened"
    );
    pruned = [
        path
        for (name, path) in modules
        if any([_feeds(spec, c, name) for (c, _key) in dropped])
    ];
    if strip or pruned {
        changed = _strip_modules(
            [path for (_name, path) in modules] if strip else pruned
        );
        console.print(f"stripped wired and dead imports from {changed} files");
    }
    return 0;
}

impl _node_id(name: str) -> str {
    return name.replace(".", "_").replace("-", "_");
}

impl _render_mermaid(spec: WiringSpec) -> str {
    lines: list[str] = ["graph LR"];
    for rule in spec.rules {
        srcs = " | ".join([p.text for p in rule.sources]);
        tgts = " | ".join([p.text for p in rule.targets]);
        names = ""
            if rule.is_open
            else " { " + ", ".join(sorted(rule.item_names)) + " }";
        lines.append(f"    %% edge {rule.name}: {srcs} --> {tgts}{names}");
    }
    modules: set[str] = set();
    for wire in spec.wires {
        modules.add(wire.provider);
        modules.update(wire.consumers);
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
                else ", ".join([name for (name, _alias) in wire.items])
        );
        for consumer in wire.consumers {
            lines.append(
                f"    {_node_id(wire.provider)} -->|{label}| {_node_id(consumer)}"
            );
        }
    }
    return "\n".join(lines) + "\n";
}

impl _render_json(spec: WiringSpec) -> str {
    wires = [
        {
            "provider": wire.provider,
            "consumers": list(wire.consumers),
            "form": import_form(
                wire.is_absorb, wire.is_typed, wire.is_comptime, not wire.is_module_form
            ),
            "names": (
                None
                    if wire.is_module_form
                    else [
                        {"name": name, "alias": alias or None}
                        for (name, alias) in wire.items
                    ]
            )
        } for wire in spec.wires
    ];
    rules = [
        {
            "name": rule.name,
            "sources": [p.text for p in rule.sources],
            "targets": [p.text for p in rule.targets],
            "names": None if rule.is_open else sorted(rule.item_names)
        } for rule in spec.rules
    ];
    return json.dumps({"wires": wires, "rules": rules}, indent=2) + "\n";
}

impl _arch_graph(fmt: str, output: str, directory: str) -> int {
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
