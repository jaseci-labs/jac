impl ImportWiringPass.run_walk with Module entry {
    mod = here;
    path = mod.loc.mod_path;
    if is_arch_file(path) {
        self._check_arch_module(mod);
        return;
    }
    for stmt in mod.body {
        if isinstance(stmt, GraphImport) {
            self.ctx.emit(E2088, node_override=stmt);
        }
    }
    spec = wiring_for_path(path);
    if spec is None {
        return;
    }
    self._check_module(mod, spec);
}

impl ImportWiringPass._rule_names(rules: list[RuleRec]) -> str {
    return ", ".join([f"rule '{r.name}'" for r in rules]);
}

impl ImportWiringPass._check_arch_module(mod: Module) -> None {
    path = mod.loc.mod_path;
    spec = wiring_for_path(path);
    is_root = spec is not None
        and os.path.realpath(spec.path) == os.path.realpath(path);
    blocks: list[GraphImport] = [];
    for stmt in mod.body {
        if isinstance(stmt, GraphImport) {
            blocks.append(stmt);
        } elif isinstance(stmt, String) {
            self.ctx.emit(E2089, node_override=stmt, kind="docstring");
        } elif not isinstance(stmt, EmptyToken) {
            self.ctx.emit(
                E2089,
                node_override=stmt,
                kind=pascal_to_snake(type(stmt).__name__).replace("_", " ")
            );
        }
    }
    if mod.doc is not None {
        self.ctx.emit(E2089, node_override=mod.doc, kind="docstring");
    }
    for comment in mod.source.comments {
        self.ctx.emit(E2089, node_override=comment, kind="comment");
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
                self._check_rule_patterns(spec, stmt);
            } elif isinstance(stmt, ImportWire) {
                self._check_wire(spec, stmt);
            }
        }
    }
}

impl ImportWiringPass._check_scope(
    spec: WiringSpec, block: GraphImport, seen: set[int]
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
        self.ctx.emit(
            E2097, node_override=sc, name=name, what="this graph import block"
        );
    }
}

impl ImportWiringPass._check_wire(spec: WiringSpec, wire: ImportWire) -> None {
    provider = wire.provider_path;
    provider_ok = spec.module_file(provider) is not None;
    if not provider_ok {
        self.ctx.emit(E1141, node_override=wire.provider, module=provider);
    }
    for target in wire.targets {
        self._check_target(spec, provider, provider_ok, target);
    }
}

impl ImportWiringPass._check_target(
    spec: WiringSpec, provider: str, provider_ok: bool, target: WireTarget
) -> None {
    names: (list[tuple[str, UniNode]] | None) = None;
    if not target.is_module_form {
        names = [(item.name.value, item) for item in target.items];
    }
    seen_modules: set[str] = set();
    for (consumer_node, path) in zip(target.consumers, target.consumer_paths) {
        split = spec.split_consumer(path);
        consumer = split[0] if split is not None else path;
        if split is not None and consumer in seen_modules {
            self.ctx.emit(
                E1142,
                node_override=consumer_node,
                module=path,
                detail=f"this wire already names '{consumer}'; a wire lands in each"
                " module once, so give the other scope its own wire"
            );
            continue;
        }
        seen_modules.add(consumer);
        cfile = spec.module_file(consumer);
        if cfile is None {
            if spec.is_package_dir(consumer) {
                self.ctx.emit(
                    E1142,
                    node_override=consumer_node,
                    module=consumer,
                    detail="a package needs an __init__ module to receive imports"
                );
            } else {
                self.ctx.emit(
                    E2097,
                    node_override=consumer_node,
                    name=consumer,
                    what="this wire's import into it"
                );
            }
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
            self._check_edge(spec, provider, consumer, names, consumer_node, True);
        }
    }
}

impl ImportWiringPass._check_rule_patterns(spec: WiringSpec, rule: ImportRule) -> None {
    modules = spec.project_modules();
    top_level = {m.split(".")[0] for m in modules};
    record = rule_record(rule);
    for (side, patterns, nodes) in [
        ("source", record.sources, rule.sources),
        ("target", record.targets, rule.targets)
    ] {
        for (pattern, node) in zip(patterns, nodes) {
            if pattern.is_glob and not pattern.dotted {
                self.ctx.emit(E2100, node_override=node, name=record.name, side=side);
                continue;
            }
            if side == "source"
                and (
                    pattern.is_string
                    or (
                        pattern.dotted and pattern.dotted.split(".")[0] not in top_level
                    )
                ) {
                continue;
            }
            if not any([pattern.matches(m) for m in modules]) {
                self.ctx.emit(
                    E2098,
                    node_override=node,
                    name=record.name,
                    what=f"{side} pattern '{pattern.text}'"
                );
            }
        }
    }
}

impl ImportWiringPass._check_edge(
    spec: WiringSpec,
    provider: str,
    consumer: str,
    names: (list[tuple[str, UniNode]] | None),
    at: UniNode,
    local: bool
) -> None {
    constrained = spec.rules_governing(provider, consumer, local);
    if not constrained {
        if spec.needs_rule(provider, consumer, local) {
            source = spec.top_package(provider);
            target = spec.top_package(consumer);
            self.ctx.emit(
                E2099,
                node_override=at,
                provider=provider,
                consumer=consumer,
                source=source,
                target=target,
                rule=rule_text(spec.edge_rule(source, [target]))
            );
        }
        return;
    }
    admitting = spec.rules_admitting(provider, consumer, local);
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
    if spec.parse_failed {
        self.ctx.emit(E2093, node_override=mod, consumer=consumer);
    }
    declared: set[tuple[str, tuple[str, str, str, str]]] = set();
    for imp in ModuleFacts.iter_module_imports(mod) {
        self._check_import(spec, imp, consumer, [], declared);
    }
    for imp in ModuleFacts.iter_nested_imports(mod) {
        self._check_import(spec, imp, consumer, scope_path_of(imp), declared);
    }
    owners: (dict[str, list[(Ability | ImplDef)]] | None) = None;
    for wire in spec.consumer_wires(consumer) {
        for scope in spec.consumer_scopes(consumer, wire) {
            target = ".".join([consumer, *scope]);
            if scope {
                if owners is None {
                    owners = scope_owners(mod);
                }
                if ".".join(scope) not in owners {
                    self.ctx.emit(
                        E1142,
                        node_override=mod,
                        module=target,
                        detail=f"'{consumer}' has no function or method '{'.'.join(
                            scope
                        )}'"
                    );
                    continue;
                }
            }
            if wire.is_injected {
                continue;
            }
            for binding in wire.bindings() {
                if (".".join(scope), binding.key()) not in declared {
                    self.ctx.emit(
                        E1147,
                        node_override=mod,
                        name=binding.bound_name() or binding.provider,
                        consumer=target,
                        line=wire.line
                    );
                }
            }
        }
    }
}

impl ImportWiringPass._check_import(
    spec: WiringSpec,
    imp: Import,
    consumer: str,
    scope: (list[str] | None),
    declared: set[tuple[str, tuple[str, str, str, str]]]
) -> None {
    src = imp.loc.mod_path;
    if src == spec.path or src.endswith(".test.jac") {
        return;
    }
    provided = spec.consumer_bindings(consumer, scope) if scope is not None else {};
    positional = is_positional_import(imp);
    for (binding, item) in spec.import_bindings(imp) {
        if binding.provider == consumer {
            continue;
        }
        held = provided.get(binding.key());
        if scope is None {
            self.ctx.emit(
                E2094,
                node_override=item,
                module=binding.provider,
                consumer=consumer,
                scope="an unnamed ability",
                fix="No wire can name an unnamed ability; move the import into a named"
                " function or method and wire that."
            );
            continue;
        }
        if positional and held is not None and not held.is_injected {
            declared.add((".".join(scope), binding.key()));
            continue;
        }
        fix = ImportWiringPass._written_import_fix(
            spec, binding, ".".join([consumer, *scope]), held, positional
        );
        if scope {
            self.ctx.emit(
                E2094,
                node_override=item,
                module=binding.provider,
                consumer=consumer,
                scope=".".join(scope),
                fix=fix
            );
        } else {
            self.ctx.emit(
                E1144,
                node_override=item,
                module=binding.provider,
                consumer=consumer,
                fix=fix
            );
        }
    }
    from_loc = imp.from_loc;
    if from_loc is not None {
        local = spec.import_provider(from_loc);
        provider = local or from_loc.dot_path_str;
        if provider != consumer {
            names = [
                (item.name.value, item)
                for item in imp.items
                if isinstance(item, ModuleItem)
            ];
            self._check_edge(spec, provider, consumer, names, imp, local is not None);
        }
        return;
    }
    for item in imp.items {
        if isinstance(item, ModulePath) {
            local = spec.import_provider(item);
            provider = local or item.dot_path_str;
            if provider != consumer {
                self._check_edge(
                    spec, provider, consumer, None, item, local is not None
                );
            }
        }
    }
}

impl ImportWiringPass._written_import_fix(
    spec: WiringSpec,
    binding: WireBinding,
    consumer: str,
    held: (WireRec | None),
    positional: bool
) -> str {
    if positional {
        declared = WireBinding(
            provider=binding.provider,
            form=binding.form,
            name=binding.name,
            alias=binding.alias,
            injected=False
        );
        if held is None {
            return f"It runs where it is written (inside a block, or after other"
            f" statements), so it stays written: declare it with"
            f" {spec.wire_suggestion(declared, consumer)} of archwire.jac.";
        }
        return f"It runs where it is written (inside a block, or after other"
        f" statements), so archwire.jac line {held.line} must declare it with '-->'"
        " instead of injecting it with '++>', which would move it to the top of the"
        " body.";
    }
    if held is None {
        return f"Add {spec.wire_suggestion(binding, consumer)} of archwire.jac and"
        " delete this import.";
    }
    if held.is_injected {
        return f"archwire.jac line {held.line} already injects it, so delete this import.";
    }
    return f"archwire.jac line {held.line} only declares it; make that wire '++>' and"
    " delete this import.";
}

impl report_unused_wires(reporter: CompilerPass, mod: Module) -> None {
    for unused in unused_wire_bindings(mod) {
        reporter.ctx.emit(
            E1146,
            node_override=unused.at,
            name=unused.binding.bound_name(),
            consumer=unused.consumer,
            line=unused.wire.line
        );
    }
}

impl unused_wire_bindings(mod: Module) -> list[UnusedBinding] {
    found: list[UnusedBinding] = [];
    path = mod.loc.mod_path;
    if not path or is_arch_file(path) {
        return found;
    }
    spec = wiring_for_path(path);
    consumer = spec.module_name(path) if spec is not None else None;
    if spec is None or consumer is None {
        return found;
    }
    wires = spec.consumer_wires(consumer);
    if not wires {
        return found;
    }
    bound: dict[tuple[str, tuple[str, str, str, str]], UniNode] = {};
    for imp in ModuleFacts.iter_module_imports(mod) {
        for (binding, item) in spec.import_bindings(imp) {
            bound.setdefault(("", binding.key()), item);
        }
    }
    for imp in ModuleFacts.iter_nested_imports(mod) {
        scope_path = scope_path_of(imp);
        if scope_path is not None {
            for (binding, item) in spec.import_bindings(imp) {
                bound.setdefault((".".join(scope_path), binding.key()), item);
            }
        }
    }
    exports = ModuleFacts.literal_exports(mod) or set();
    reads = ScopeReads(mod=mod);
    for (wire, scope) in [
        (w, ".".join(s)) for w in wires for s in spec.consumer_scopes(consumer, w)
    ] {
        for binding in wire.bindings() {
            name = binding.bound_name();
            at = bound.get((scope, binding.key()));
            if at is None
                or is_effect_binding(binding)
                or (not scope and name in exports) {
                continue;
            }
            if name not in reads.names(scope) {
                found.append(
                    UnusedBinding(
                        consumer=consumer + "." + scope if scope else consumer,
                        wire=wire,
                        binding=binding,
                        at=at
                    )
                );
            }
        }
    }
    return found;
}

impl ScopeReads.names(scope: str) -> set[str] {
    held = self.read.get(scope);
    if held is not None {
        return held;
    }
    bodies: list[UniNode] = [self.mod];
    if scope {
        if self.owners is None {
            self.owners = scope_owners(self.mod);
        }
        bodies = list(self.owners.get(scope, [self.mod]));
    }
    names: set[str] = set();
    for b in bodies {
        names.update(names_read_in(b, self.mod));
    }
    self.read[scope] = names;
    return names;
}

impl is_effect_binding(binding: WireBinding) -> bool {
    return "include" in binding.form.split(" ")
        or (binding.is_module_form() and not binding.alias);
}

impl names_read_in(body: UniNode, mod: Module) -> set[str] {
    names: set[str] = set();
    for nd in [
        *body.get_all_sub_nodes(typ=Name),
        *body.get_all_sub_nodes(typ=SpecialVarRef)
    ] {
        parent = nd.parent;
        sym = nd.sym;
        if nd.expr_ctx != ExprCtx.LOAD
            or (
                sym is not None
                and not sym.imported
                and sym.decl is not None
                and sym.decl.find_parent_of_type(Module) is mod
            )
            or (
                isinstance(parent, AtomTrailer)
                and parent.is_attr
                and parent.right is nd
            )
            or (isinstance(parent, KWPair) and parent.key is nd)
            or (isinstance(parent, JsxElementName) and parent.parts[0] is not nd)
            or nd.find_parent_of_type(ModulePath) is not None
            or nd.find_parent_of_type(ModuleItem) is not None {
            continue;
        }
        names.add(nd.value);
    }
    return names;
}
