impl ImportWiringPass.run_walk with Module entry {
    mod = here;
    path = mod.loc.mod_path;
    if is_arch_file(path) {
        self._check_arch_module(mod);
        return;
    }
    for stmt in mod.body {
        if isinstance(stmt, ImplImport) {
            self.ctx.emit(E2088, node_override=stmt);
        }
    }
    spec = wiring_for_path(path);
    if spec is None {
        return;
    }
    self._check_module(mod, spec);
}

impl ImportWiringPass._rule_names(rules: list[ImportRule]) -> str {
    return ", ".join([f"rule '{r.name.value}'" for r in rules]);
}

impl ImportWiringPass._check_arch_module(mod: Module) -> None {
    path = mod.loc.mod_path;
    spec = wiring_for_path(path);
    is_root = spec is not None
        and os.path.realpath(spec.path) == os.path.realpath(path);
    blocks: list[ImplImport] = [];
    for stmt in mod.body {
        if isinstance(stmt, ImplImport) {
            blocks.append(stmt);
        } elif not isinstance(stmt, (String, EmptyToken)) {
            self.ctx.emit(
                E2089,
                node_override=stmt,
                kind=pascal_to_snake(type(stmt).__name__).replace("_", " ")
            );
        }
    }
    if not is_root or spec is None {
        return;
    }
    seen_scopes: set[int] = set();
    rule_names: dict[str, ImportRule] = {};
    for block in blocks {
        self._check_scope(spec, block, seen_scopes);
        for stmt in block.body {
            if isinstance(stmt, ImportRule) {
                if stmt.name.value in rule_names {
                    self.ctx.emit(E2092, node_override=stmt.name, name=stmt.name.value);
                } else {
                    rule_names[stmt.name.value] = stmt;
                }
                self._check_rule_liveness(spec, stmt);
            } elif isinstance(stmt, ImportWire) {
                self._check_wire(spec, stmt);
            }
        }
    }
}

impl ImportWiringPass._check_scope(
    spec: WiringSpec, block: ImplImport, seen: set[int]
) -> None {
    if id(block) in seen {
        return;
    }
    seen.add(id(block));
    sc = block.scope;
    if sc is None {
        return;
    }
    name = block.scope_prefix;
    if spec.module_file(name) is None and not spec.is_package_dir(name) {
        self.ctx.emit(E1140, node_override=sc, scope=name);
    }
}

impl ImportWiringPass._check_wire(spec: WiringSpec, wire: ImportWire) -> None {
    provider = wire.provider_path;
    provider_ok = spec.module_file(provider) is not None;
    if not provider_ok {
        self.ctx.emit(E1141, node_override=wire.provider, module=provider);
    }
    names: (list[tuple[str, UniNode]] | None) = None;
    if not wire.is_module_form {
        names = [(item.name.value, item) for item in wire.items];
    }
    for consumer_node in wire.consumers {
        consumer = consumer_node.dot_path_str;
        cfile = spec.module_file(consumer);
        if cfile is None {
            detail = (
                "a package needs an __init__ module to receive imports"
                    if spec.is_package_dir(consumer)
                    else "no such module under the project root"
            );
            self.ctx.emit(
                E1142, node_override=consumer_node, module=consumer, detail=detail
            );
            continue;
        }
        if not cfile.endswith(".jac") {
            self.ctx.emit(
                E1142,
                node_override=consumer_node,
                module=consumer,
                detail="only Jac modules receive generated imports"
            );
            continue;
        }
        if consumer == provider {
            self.ctx.emit(E1143, node_override=consumer_node, module=consumer);
            continue;
        }
        if provider_ok {
            self._check_edge(spec, provider, consumer, names, consumer_node);
        }
    }
}

impl ImportWiringPass._check_rule_liveness(spec: WiringSpec, rule: ImportRule) -> None {
    modules = spec.project_modules();
    top_level = {m.split(".")[0] for m in modules};
    prefix = rule.block.scope_prefix;
    for p in rule.sources {
        if p.is_any {
            continue;
        }
        full = ModulePattern.join_scope(prefix, p.dotted);
        if full and full.split(".")[0] not in top_level {
            continue;
        }
        if not any([p.matches(m, prefix) for m in modules]) {
            self.ctx.emit(
                W2083,
                node_override=p,
                name=rule.name.value,
                what=f"source pattern '{WiringSpec.pattern_text(p)}'"
            );
        }
    }
    for t in rule.targets {
        if t.is_any {
            continue;
        }
        if not any([t.matches(m) for m in modules]) {
            self.ctx.emit(
                W2083,
                node_override=t,
                name=rule.name.value,
                what=f"target pattern '{WiringSpec.pattern_text(t)}'"
            );
        }
    }
}

impl ImportWiringPass._check_edge(
    spec: WiringSpec,
    provider: str,
    consumer: str,
    names: (list[tuple[str, UniNode]] | None),
    at: UniNode
) -> None {
    constrained = spec.rules_for_provider(provider);
    if not constrained {
        if spec.is_project_module(provider) and spec.is_sealed(provider) {
            self.ctx.emit(
                E2090,
                node_override=at,
                provider=provider,
                consumer=consumer,
                rules="no rule",
                help_text=(
                    f"'{provider}' is sealed: arch.jac names it, or [arch] closed in"
                    " jac.toml covers it, so it flows only where an edge rule admits,"
                    " and no rule names it as a provider yet. Add one, for example"
                    f" `edge {ImportWiringPass._rule_name_for(provider)}:"
                    f" {ImportWiringPass._package_pattern(provider)} -->"
                    f" {ImportWiringPass._package_pattern(consumer)};`, or run"
                    " `jac arch sync` to derive one from the current imports."
                )
            );
        }
        return;
    }
    admitting = spec.rules_admitting(provider, consumer);
    if not admitting {
        self.ctx.emit(
            E2090,
            node_override=at,
            provider=provider,
            consumer=consumer,
            rules=ImportWiringPass._rule_names(constrained)
        );
        return;
    }
    allowed = WiringSpec.admitted_names(admitting);
    if allowed is None {
        return;
    }
    rules_text = ImportWiringPass._rule_names(
        [
            r
            for r in admitting
            if not r.is_open
        ]
    );
    if names is None {
        self.ctx.emit(
            E2091,
            node_override=at,
            name="*",
            provider=provider,
            consumer=consumer,
            rules=rules_text
        );
        return;
    }
    for (name, name_node) in names {
        if name not in allowed {
            self.ctx.emit(
                E2091,
                node_override=name_node,
                name=name,
                provider=provider,
                consumer=consumer,
                rules=rules_text
            );
        }
    }
}

impl ImportWiringPass._check_module(mod: Module, spec: WiringSpec) -> None {
    consumer = spec.module_name(mod.loc.mod_path);
    if consumer is None {
        return;
    }
    sealed = spec.is_sealed(consumer);
    if sealed and spec.parse_failed {
        self.ctx.emit(E2093, node_override=mod, consumer=consumer);
    }
    provided = spec.consumer_bindings(consumer) if sealed else {};
    for imp in ModuleFacts.iter_module_imports(mod) {
        self._check_import(spec, imp, consumer, provided, sealed);
    }
    for imp in ModuleFacts.iter_nested_imports(mod) {
        self._check_import(spec, imp, consumer, provided, False, nested=sealed);
    }
}

impl ImportWiringPass._package_pattern(module: str) -> str {
    return module.rsplit(".", 1)[0] + ".*" if "." in module else module;
}

impl ImportWiringPass._rule_name_for(module: str) -> str {
    head = module.split(".")[0];
    return "".join([part.capitalize() for part in head.split("_")]) + "Flows";
}

impl ImportWiringPass._check_import(
    spec: WiringSpec,
    imp: Import,
    consumer: str,
    provided: dict[tuple[str, str, str, str], ImportWire],
    enforce: bool,
    nested: bool = False
) -> None {
    src = imp.loc.mod_path;
    if src == spec.path or src.endswith(".test.jac") {
        return;
    }
    from_loc = imp.from_loc;
    if from_loc is not None {
        project_provider = spec.import_provider(from_loc);
        provider = project_provider
            if project_provider is not None
            else from_loc.dot_path_str;
        form = import_form(imp.is_absorb, imp.is_typed, imp.is_comptime, True);
        names: list[tuple[str, UniNode]] = [];
        for item in imp.items {
            if not isinstance(item, ModuleItem) {
                continue;
            }
            alias = item.alias.value if item.alias is not None else "";
            names.append((item.name.value, item));
            if nested and project_provider is not None {
                self.ctx.emit(
                    E2094,
                    node_override=item,
                    module=project_provider,
                    consumer=consumer
                );
            }
            if enforce and project_provider is not None {
                key = (project_provider, form, item.name.value, alias);
                if key not in provided {
                    binding = WireBinding(
                        provider=project_provider,
                        form=form,
                        name=item.name.value,
                        alias=alias
                    );
                    self.ctx.emit(
                        E1144,
                        node_override=item,
                        module=project_provider,
                        consumer=consumer,
                        wire=binding.wire_text(consumer)
                    );
                }
            }
        }
        self._check_edge(spec, provider, consumer, names, imp);
        return;
    }
    form = import_form(imp.is_absorb, imp.is_typed, imp.is_comptime, False);
    for item in imp.items {
        if not isinstance(item, ModulePath) {
            continue;
        }
        project_provider = spec.import_provider(item);
        provider = project_provider
            if project_provider is not None
            else item.dot_path_str;
        alias = item.alias.value if item.alias is not None else "";
        if nested and project_provider is not None {
            self.ctx.emit(
                E2094, node_override=item, module=project_provider, consumer=consumer
            );
        }
        if enforce and project_provider is not None {
            key = (project_provider, form, "", alias);
            if key not in provided {
                binding = WireBinding(
                    provider=project_provider, form=form, alias=alias
                );
                self.ctx.emit(
                    E1144,
                    node_override=item,
                    module=project_provider,
                    consumer=consumer,
                    wire=binding.wire_text(consumer)
                );
            }
        }
        self._check_edge(spec, provider, consumer, None, item);
    }
}
