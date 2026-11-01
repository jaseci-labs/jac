impl module_files(spec: WiringSpec) -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    for name in spec.project_modules() {
        path = spec.module_file(name);
        if path is not None and path.endswith(".jac") {
            out.append((name, path));
        }
    }
    return out;
}

impl parsed_imports(
    host: ProjectHost, path: str
) -> list[tuple[Import, (list[str] | None)]] {
    (mod, had_error) = parse_woven(host.read_source(path), path, None, []);
    if had_error {
        raise KernelError(
            f"{path} does not parse; fix it before running `jac arch`"
        );
    }
    out: list[tuple[Import, (list[str] | None)]] = [];
    for imp in mod.get_all_sub_nodes(typ=Import) {
        out.append((imp, [] if imp.parent is mod else scope_path_of(imp)));
    }
    return out;
}

impl collect_facts(
    host: ProjectHost, spec: WiringSpec, modules: list[tuple[str, str]]
) -> list[tuple[str, WireBinding]] {
    facts: list[tuple[str, WireBinding]] = [];
    seen: set[tuple[str, tuple[str, str, str, str]]] = set();
    for (module, path) in modules {
        for src in [path, *host.annex_files(path, ".impl.jac")] {
            for (imp, scope) in parsed_imports(host, src) {
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

impl unused_facts(
    host: ProjectHost, spec: WiringSpec, modules: list[tuple[str, str]]
) -> set[tuple[str, tuple[str, str, str, str]]] {
    unused: set[tuple[str, tuple[str, str, str, str]]] = set();
    for (module, path) in modules {
        if not spec.is_covered(module) {
            continue;
        }
        mod = host.woven_module(path, None);
        if mod is None {
            raise KernelError(
                f"{path} does not parse; fix it before pruning its wires"
            );
        }
        for found in unused_wire_bindings(mod) {
            unused.add((found.consumer, found.binding.key()));
        }
    }
    return unused;
}

impl feeds(spec: WiringSpec, consumer: str, module: str) -> bool {
    split = spec.split_consumer(consumer);
    return (split[0] if split is not None else consumer) == module;
}

impl node_id(name: str) -> str {
    return name.replace(".", "_").replace("-", "_");
}

impl render_mermaid(spec: WiringSpec) -> str {
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
    for (pkg, members) in sorted(packages.items()) {
        lines.append(f"    subgraph {pkg}");
        for name in members {
            lines.append(f"        {node_id(name)}[{name}]");
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
                f"    {node_id(wire.provider)} -->|{label}| {node_id(consumer)}"
            );
        }
    }
    return "\n".join(lines) + "\n";
}

impl render_json(spec: WiringSpec) -> str {
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

impl laid_out(plan: ArchPlan, text: str) -> ArchPlan {
    program = JacCompiler.jac_str_formatter(text, plan.arch_path);
    if program.errors_had or program.mod.main is None {
        plan.refusal = f"refusing to write {plan.arch_path}: the rendered wiring does not parse";
        plan.hint = str(program.errors_had[0]) if program.errors_had else "";
        return plan;
    }
    plan.text = program.mod.main.gen.jac;
    return plan;
}

impl init_plan(host: ProjectHost, arch_path: str) -> ArchPlan {
    root_dir = os.path.dirname(arch_path);
    plan = ArchPlan(arch_path=arch_path);
    spec = WiringSpec(root_dir=root_dir, path=arch_path);
    modules = module_files(spec);
    plan.modules = [path for (_name, path) in modules];
    parent_arch = arch_file_for(os.path.dirname(os.path.realpath(root_dir)));
    parent = wiring_for_path(parent_arch) if parent_arch is not None else None;
    if parent is not None {
        fed = [
            path
            for (_name, path) in modules
            if parent.is_covered(parent.module_name(path) or "")
        ];
        if fed {
            plan.refusal = f"{len(fed)} modules under {root_dir} take their imports from "
                + f"{parent.path}; a new {ARCH_FILE_NAME} here would cut them off";
            plan.hint = "write those imports back into the modules first, or extend "
                + f"{parent.path} with `jac arch sync`";
            return plan;
        }
    }
    facts = collect_facts(host, spec, modules);
    rules = propose_rules(spec, facts, []);
    plan.added = len(facts);
    plan.rules = len(rules);
    plan.rules_added = len(rules);
    return laid_out(plan, render_wiring(spec, facts, rules));
}

impl sync_plan(host: ProjectHost, arch_path: str, prune: bool) -> ArchPlan {
    plan = ArchPlan(arch_path=arch_path);
    spec = wiring_for_path(arch_path) if os.path.isfile(arch_path) else None;
    if spec is None {
        plan.refusal = f"{arch_path} does not exist";
        plan.hint = "run `jac arch init` first";
        return plan;
    }
    if spec.parse_failed {
        plan.refusal = f"{arch_path} has syntax errors; fix them before syncing";
        return plan;
    }
    modules = module_files(spec);
    plan.modules = [path for (_name, path) in modules];
    added = collect_facts(host, spec, modules);
    dropped = unused_facts(host, spec, modules) if prune else set();
    facts = [
        (consumer, binding)
        for (consumer, binding) in wiring_facts(spec.wires) + added
        if (consumer, binding.key()) not in dropped
    ];
    rules = propose_rules(spec, facts, spec.rules);
    before = {rule_text(r) for r in spec.rules};
    plan.added = len(added);
    plan.dropped = len(dropped);
    plan.rules = len(rules);
    plan.rules_added = len(
        [
            r
            for r in rules
            if rule_text(r) not in before
        ]
    );
    plan.fed = [
        path
        for (name, path) in modules
        if any([feeds(spec, c, name) for (c, _key) in dropped])
    ];
    return laid_out(plan, render_wiring(spec, facts, rules));
}

impl graph_plan(arch_path: str, graph_format: str) -> ArchPlan {
    plan = ArchPlan(arch_path=arch_path);
    spec = wiring_for_path(arch_path);
    if spec is None {
        plan.refusal = f"{arch_path} does not exist";
        plan.hint = "run `jac arch init` first";
        return plan;
    }
    plan.text = render_json(spec) if graph_format == "json" else render_mermaid(spec);
    return plan;
}
