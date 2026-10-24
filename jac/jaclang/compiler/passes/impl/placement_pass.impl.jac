impl _reference_targets(nm: Name) -> list[UniNode] {
    sym = nm.sym;
    if sym is None or sym.decl is None {
        return [];
    }
    declared = sym.decl.name_of;
    if isinstance(declared, Ability) {
        return [declared];
    }
    if isinstance(declared, Archetype) {
        found: list[UniNode] = [];
        body = ModuleFacts.unwrap_body(declared);
        if body is not None {
            for member in body {
                if isinstance(member, Ability)
                    and member.name_ref is not None
                    and member.name_ref.sym_name in ("init", "postinit", "__init__") {
                    found.append(member);
                }
            }
        }
        return found;
    }
    return [];
}

impl unmet_label(need: NativeRefusal) -> tuple[str, str] {
    site = need.site;
    if isinstance(site, Name) {
        return ("this use of native-only builtin", site.value);
    }
    return ("native-only construct", need.name);
}

impl NativeRefusal.message -> str {
    if self.code == "E5090" {
        return f"Native pathway does not yet support {self.kind} '{self.name}'";
    }
    return f"Native lowering failed for {self.kind} '{self.name}'";
}

impl NativeRefusal.headline -> str {
    if self.text {
        return self.text;
    }
    return f"error[{self.code}]: {self.message()}";
}

impl NativeRefusal.located -> str {
    if self.brief {
        return self.brief;
    }
    nd = self.site;
    if nd is None or nd.loc is None {
        return self.message();
    }
    return f"{nd.loc.mod_path}, line {nd.loc.first_line}, col {nd.loc.col_start}: "
    f"{self.message()}";
}

impl NativeRefusal.full -> str {
    if self.detail {
        return self.detail;
    }
    if self.help {
        return f"{self.headline()}\nhelp: {self.help}";
    }
    return self.headline();
}

impl NativeLegality.refuse_unit(owner: UniNode, refusal: NativeRefusal) -> None {
    key = id(owner);
    self.owners[key] = owner;
    if key not in self.units {
        self.units[key] = [];
    }
    self.units[key].append(refusal);
}

impl NativeLegality.refuse_module(refusal: NativeRefusal) -> None {
    self.module.append(refusal);
}

impl NativeLegality.refuse_site(mod: Module, refusal: NativeRefusal) -> None {
    top = refusal.site.element_in(mod) if refusal.site is not None else None;
    if top is None {
        self.module.append(refusal);
        return;
    }
    self.tops[id(top)] = top;
    if id(top) not in self.elements {
        self.elements[id(top)] = refusal;
    }
}

impl NativeLegality.prefer_against(mod: Module, refusal: NativeRefusal) -> None {
    top = refusal.site.element_in(mod) if refusal.site is not None else None;
    if top is not None and id(top) not in self.preferences {
        self.preferences[id(top)] = refusal;
    }
}

impl NativeLegality.refused_elements(mod: Module) -> set[int] {
    out: set[int] = set(self.elements.keys());
    for (uid, owner) in self.owners.items() {
        if uid in self.units and owner.parent is mod {
            out.add(uid);
        }
    }
    if self.module {
        for elem in mod.elements {
            out.add(id(elem));
        }
    }
    return out;
}

impl NativeLegality.unit_refusals(owner: UniNode) -> list[NativeRefusal] {
    return self.units.get(id(owner), []);
}

impl NativeLegality.unit_refused(owner: UniNode) -> bool {
    return id(owner) in self.units;
}

impl NativeLegality.module_refused -> bool {
    return len(self.module) > 0;
}

impl NativeLegality.settle -> None {
    def blocked_by(target: int) -> (str | None) {
        callee = self.owners[target];
        if not isinstance(callee, Ability) {
            return "it is not a function";
        }
        return ability_crossing(callee, TARGET_NATIVE, TARGET_SERVER);
    }
    changed = True;
    while changed {
        changed = False;
        for (uid, targets) in self.refs.items() {
            if uid in self.units {
                continue;
            }
            for target in targets {
                if target == uid or target not in self.units {
                    continue;
                }
                why = blocked_by(target);
                if why is None {
                    continue;
                }
                blocker = native_unit_name(self.owners[target]);
                caller = native_unit_name(self.owners[uid]);
                self.units[uid] = [
                    NativeRefusal(
                        kind="function",
                        name=blocker,
                        site=self.owners[uid],
                        code="E5092",
                        help=f"'{blocker}' is placed in Python and a call to it from "
                        f"'{caller}' cannot cross into native code ({why}); hoist the "
                        f"blocking construct out of '{blocker}' or give it a signature "
                        f"that crosses."
                    )
                ];
                self.reached[uid] = target;
                changed = True;
                break;
            }
        }
    }
    for (eid, targets) in self.anchored_by.items() {
        if eid in self.elements {
            continue;
        }
        for target in targets {
            if target not in self.units or blocked_by(target) is None {
                continue;
            }
            blocker = native_unit_name(self.owners[target]);
            cause = target;
            while cause in self.reached {
                cause = self.reached[cause];
            }
            first = self.units[cause][0];
            reaching = NativeRefusal(
                kind=first.kind,
                name=first.name,
                site=first.site,
                code=first.code,
                late=first.late,
                text=first.text,
                brief=first.brief,
                detail=first.detail,
                help=f"This element reaches '{blocker}', which is placed in Python "
                f"and cannot be called from native code."
            );
            self.elements[eid] = reaching;
            self.reach.append(reaching);
            break;
        }
    }
}

impl NativeLegality.static_units -> int {
    return len(self.units);
}

impl NativeLegality.late_units -> int {
    return len(self.late);
}

impl NativeLegality.unmet -> list[tuple[NativeRefusal, NativeRefusal]] {
    out: list[tuple[NativeRefusal, NativeRefusal]] = [];
    blocked = self.module[0] if self.module else None;
    for (uid, need) in self.requires.items() {
        if uid in self.units {
            out.append((need, self.units[uid][0]));
        } elif uid in self.elements {
            out.append((need, self.elements[uid]));
        } elif blocked is not None {
            out.append((need, blocked));
        }
    }
    if blocked is not None {
        for need in self.module_requires {
            out.append((need, blocked));
        }
    }
    return out;
}

impl native_unit_name(owner: UniNode) -> str {
    if isinstance(owner, Test) {
        return owner.name.sym_name;
    }
    if isinstance(owner, Ability) {
        name = owner.name_ref.sym_name if owner.name_ref is not None else "unnamed";
        arch = owner.method_owner;
        if isinstance(arch, Archetype) and arch.name is not None {
            return f"{arch.name.value}.{name}";
        }
        return name;
    }
    return "unit";
}

impl native_enclosing_unit(nd: UniNode) -> (UniNode | None) {
    owner: (UniNode | None) = nd if isinstance(nd, Ability) else None;
    nxt = nd.enclosing_decl(Ability);
    while nxt is not None {
        owner = nxt;
        nxt = nxt.enclosing_decl(Ability);
    }
    if owner is not None {
        return owner;
    }
    if isinstance(nd, Test) {
        return nd;
    }
    return nd.enclosing_decl(Test);
}

impl refusal_from_alert(alert: Alert) -> NativeRefusal {
    code = alert.code.code if alert.code is not None else "";
    return NativeRefusal(
        kind="lowering",
        name=alert.msg,
        code=code,
        late=True,
        help=alert.help_text,
        text=alert.pretty_print().split('\n')[0],
        brief=str(alert).split('\n')[0],
        detail=alert.pretty_print()
    );
}

impl build_native_legality(
    mod: Module, prog: (JacProgram | None) = None
) -> NativeLegality {
    legality = NativeLegality();
    mod_path = mod.loc.mod_path if mod.loc is not None else "";
    base_dir = os.path.dirname(os.path.abspath(mod_path)) if mod_path else ".";
    judging: (JacProgram | None) = prog if not mod.gen.placement_mode else None;
    refused_imports: dict[int, NativeRefusal] = {};
    bridged_imports: set[int] = set();
    refused_names: dict[str, NativeRefusal] = {};
    bridged_names: set[str] = set();
    if judging is not None {
        scan = native_blocker_scan(mod, base_dir);
        if scan.module {
            legality.blockers.append(
                NativeRefusal(kind="module", name=scan.module, site=mod)
            );
        }
        for (site, why) in scan.sites {
            legality.blockers.append(NativeRefusal(kind="module", name=why, site=site));
        }
        for (blocked_test, why) in scan.tests {
            legality.refuse_unit(
                blocked_test,
                NativeRefusal(
                    kind="test",
                    name=why,
                    site=blocked_test,
                    help="A test does not decide where its module runs, so this "
                    "test is placed on the server and the module it tests is not."
                )
            );
        }
        import from jaclang.compiler.native_bindings { import_gaps }
        for elem in mod.elements {
            if isinstance(elem, Import) and not legality.blockers {
                for gap in import_gaps(judging, elem, base_dir) {
                    legality.blockers.append(
                        NativeRefusal(kind="library import", name=gap, site=elem)
                    );
                    break;
                }
            }
        }
        for (dep_test, test_imp, test_dep) in scan.test_dep_imports {
            if legality.unit_refused(dep_test) {
                continue;
            }
            (test_closure, _test_bridged) = native_closure_blocker(
                judging, mod_path, [test_dep]
            );
            if test_closure {
                legality.refuse_unit(
                    dep_test,
                    NativeRefusal(
                        kind="test",
                        name=test_closure,
                        site=test_imp,
                        help="A module this test imports cannot be placed native, so "
                        "the test is placed on the server and the module it tests "
                        "is not."
                    )
                );
            }
        }
        for (imp, dep) in scan.dep_imports {
            top = imp.element_in(mod);
            if top is None or id(top) in refused_imports or legality.blockers {
                continue;
            }
            (closure, bridged) = native_closure_blocker(judging, mod_path, [dep]);
            if not closure {
                continue;
            }
            if bridged {
                refused_imports[id(top)] = NativeRefusal(
                    kind="import of Python code", name=closure, site=imp
                );
                bridged_imports.add(id(top));
                continue;
            }
            legality.blockers.append(
                NativeRefusal(
                    kind="import closure",
                    name=closure,
                    site=imp,
                    help="A module this import reaches, directly or through "
                    "another import, cannot be placed native."
                )
            );
        }
        for note in capability_notes_of(judging, mod_path, TARGET_NATIVE) {
            noted = NativeRefusal(
                kind="construct",
                name=note.text,
                site=note.site,
                code=note.code,
                noted=True,
                text=f"error[{note.code}]: {note.text}"
            );
            if note.requires {
                unit = native_enclosing_unit(note.site) or note.site.element_in(mod);
                if unit is None {
                    legality.module_requires.append(noted);
                } else {
                    legality.owners[id(unit)] = unit;
                    legality.requires[id(unit)] = noted;
                }
                continue;
            }
            owner = native_capability_demotion_owner(note.site);
            if owner is None {
                legality.refuse_site(mod, noted);
            } else {
                legality.refuse_unit(owner, noted);
            }
        }
    }
    for (vnode, vkind, vname, vhelp) in native_capability_violations(mod) {
        owner = native_capability_demotion_owner(vnode);
        if owner is None {
            note = "No owning method or function can absorb this construct as a "
            "native seam, so the element that contains it is placed in Python.";
            legality.refuse_site(
                mod,
                NativeRefusal(
                    kind=vkind,
                    name=vname,
                    site=vnode,
                    help=f"{vhelp} {note}" if vhelp else note
                )
            );
        } else {
            legality.refuse_unit(
                owner, NativeRefusal(kind=vkind, name=vname, site=vnode, help=vhelp)
            );
        }
    }
    for elem in mod.elements {
        if isinstance(elem, Import) and id(elem) in refused_imports {
            for bound_name in import_bindings(elem) {
                refused_names[bound_name] = refused_imports[id(elem)];
                if id(elem) in bridged_imports {
                    bridged_names.add(bound_name);
                }
            }
        }
    }
    for stmt in ModuleFacts.iter_context_stmts(mod, CodeContext.NATIVE) {
        if isinstance(stmt, Import) {
            continue;
        }
        for nm in stmt.element_sub_nodes(Name) {
            cause = refused_names.get(nm.value) if refused_names else None;
            why: (str | None) = "";
            if cause is not None and nm.value in bridged_names {
                why = bridged_use_crosses(nm);
                if why is None {
                    cause = None;
                }
            }
            if cause is not None and binds_module_name(mod, nm) {
                uses = NativeRefusal(
                    kind="use of an import native code cannot reach",
                    name=nm.value,
                    site=nm,
                    help=f"'{nm.value}' comes from an import that stays in "
                    f"Python: {cause.name}."
                        + (f" A native call cannot reach it: {why}." if why else "")
                );
                legality.prefer_against(mod, uses);
            }
            if judging is not None {
                for gap in binding_gaps(judging, nm, base_dir) {
                    missing = NativeRefusal(
                        kind="library member",
                        name=gap,
                        site=nm,
                        text=f"error[E5090]: {gap}"
                    );
                    gap_owner = native_capability_demotion_owner(nm);
                    if gap_owner is None {
                        legality.refuse_site(mod, missing);
                    } else {
                        legality.refuse_unit(gap_owner, missing);
                    }
                }
            }
            targets = _reference_targets(nm);
            if not targets {
                continue;
            }
            source = native_enclosing_unit(nm);
            for target in targets {
                if target is source {
                    continue;
                }
                legality.owners[id(target)] = target;
                if source is None {
                    top = nm.element_in(mod);
                    if top is not None {
                        legality.tops[id(top)] = top;
                        if id(top) not in legality.anchored_by {
                            legality.anchored_by[id(top)] = set();
                        }
                        legality.anchored_by[id(top)].add(id(target));
                    }
                } else {
                    legality.owners[id(source)] = source;
                    if id(source) not in legality.refs {
                        legality.refs[id(source)] = set();
                    }
                    legality.refs[id(source)].add(id(target));
                }
            }
        }
    }
    legality.settle();
    return legality;
}

impl import_bindings(imp: Import) -> set[str] {
    bound: set[str] = set();
    for item in imp.items {
        if isinstance(item, ModuleItem) {
            binding = item.binding_name;
            if binding is not None {
                bound.add(binding.value);
            }
        } elif isinstance(item, ModulePath) {
            if item.alias is not None {
                bound.add(item.alias.value);
            } elif item.path and isinstance(item.path[0], Name) {
                bound.add(item.path[0].value);
            }
        }
    }
    return bound;
}

impl binds_module_name(mod: Module, nm: Name) -> bool {
    if nm.sym is None {
        return False;
    }
    owner = nm.parent;
    if isinstance(owner, AtomTrailer) and owner.is_attr and owner.target is not nm {
        return False;
    }
    if nm.sym.parent_tab is mod {
        return True;
    }
    decl = nm.sym.decl;
    return decl is None or decl.find_parent_of_type(Module) is not mod;
}

impl bridged_use_crosses(nm: Name) -> (str | None) {
    decl = nm.sym.decl if nm.sym is not None else None;
    target = decl.name_of if decl is not None else None;
    if isinstance(target, Archetype) {
        return None;
    }
    if not isinstance(target, Ability) {
        return "it is not a function";
    }
    return ability_crossing(target, TARGET_NATIVE, TARGET_SERVER);
}

impl element_requirements(mod: Module, prog: JacProgram) -> dict[int, tuple[str, str]] {
    out: dict[int, tuple[str, str]] = {};
    mod_path = mod.loc.mod_path if mod.loc is not None else "";
    declared = prog.declared_codespace(mod_path) if mod_path else "";
    preferred = declared == TARGET_NATIVE and prog.prefers_native_codespace(mod_path);
    if preferred {
        declared = "";
    }
    for elem in mod.elements {
        if not isinstance(elem, ContextAwareNode) {
            continue;
        }
        name = element_display_name(elem);
        pin = (
            config_element_pin(mod_path, name)
                if preferred
                else config_pin_for(mod_path, name)
        )
            if mod_path
            else "";
        if pin {
            out[id(elem)] = (pin, "pinned in jac.toml");
        } elif declared {
            out[id(elem)] = (declared, "declared for the module");
        } elif isinstance(elem, Import) and elem.has_clib_decls {
            out[id(elem)] = (TARGET_NATIVE, "declares C library functions");
        }
    }
    for note in capability_notes_of(prog, mod_path) {
        if not note.requires {
            continue;
        }
        top = note.site.element_in(mod);
        if top is not None and id(top) not in out {
            out[id(top)] = (note.target, note.text);
        }
    }
    return out;
}

impl client_refused_elements(mod: Module) -> dict[int, list[tuple[UniNode, str]]] {
    out: dict[int, list[tuple[UniNode, str]]] = {};
    for (vnode, vkind) in client_capability_violations(mod) {
        top = vnode.element_in(mod);
        if top is None {
            continue;
        }
        if id(top) not in out {
            out[id(top)] = [];
        }
        out[id(top)].append((vnode, vkind));
    }
    return out;
}

impl uncrossable_native(mod: Module, prog: JacProgram, held: set[int]) -> set[int] {
    refresh_placement_module(mod, prog);
    refs = placement_work(prog).refs(mod);
    tops: dict[int, ContextAwareNode] = {};
    for elem in mod.elements {
        if isinstance(elem, ContextAwareNode) and not isinstance(elem, Import) {
            tops[id(elem)] = elem;
        }
    }
    def crosses(callee: ContextAwareNode, src: str, dst: str) -> bool {
        return isinstance(callee, Ability)
            and ability_crossing(callee, src, dst) is None;
    }
    moved: set[int] = set();
    changed = True;
    while changed {
        changed = False;
        runs = [
            e
            for e in tops.values()
            if not isinstance(e, Test)
        ];
        mixed = any(e.code_context == CodeContext.NATIVE for e in runs)
            and any(e.code_context == CodeContext.SERVER for e in runs);
        split = _runs_split(mod);
        if mixed {
            for (eid, elem) in tops.items() {
                if eid not in held
                    and elem.code_context == CodeContext.NATIVE
                    and not crosses(elem, TARGET_SERVER, TARGET_NATIVE) {
                    _stamp_context_element(elem, CodeContext.SERVER);
                    moved.add(eid);
                    changed = True;
                }
            }
        }
        for (eid, elem) in tops.items() {
            if elem.code_context == CodeContext.CLIENT {
                continue;
            }
            caller_native = elem.code_context == CodeContext.NATIVE;
            for target_id in refs.get(eid, set()) {
                target = tops.get(target_id);
                if target is None or target.code_context == CodeContext.CLIENT {
                    continue;
                }
                target_native = target.code_context == CodeContext.NATIVE;
                if caller_native == target_native {
                    continue;
                }
                src = TARGET_NATIVE if caller_native else TARGET_SERVER;
                dst = TARGET_SERVER if caller_native else TARGET_NATIVE;
                if crosses(target, src, dst) {
                    continue;
                }
                native_side = elem if caller_native else target;
                if id(native_side) in held
                    or (
                        isinstance(elem, Test) and native_side is not elem and not split
                    ) {
                    continue;
                }
                _stamp_context_element(native_side, CodeContext.SERVER);
                moved.add(id(native_side));
                changed = True;
            }
        }
    }
    return moved;
}

impl _demote_unreached_imports(
    mod: Module, tentative: list[ContextAwareNode], prog: JacProgram
) -> None {
    refresh_placement_module(mod, prog);
    refs = placement_work(prog).refs(mod);
    reached: set[int] = set();
    for elem in mod.elements {
        if isinstance(elem, ContextAwareNode)
            and elem.code_context == CodeContext.NATIVE
            and not isinstance(elem, Import) {
            reached.update(refs.get(id(elem), set()));
        }
    }
    for elem in tentative {
        if isinstance(elem, Import)
            and elem.parent is mod
            and elem.code_context == CodeContext.NATIVE
            and id(elem) not in reached {
            elem.code_context = CodeContext.SERVER;
        }
    }
}

impl _runs_split(mod: Module) -> bool {
    has_native = False;
    has_server = False;
    for elem in mod.elements {
        if not isinstance(elem, ContextAwareNode) or isinstance(elem, Test) {
            continue;
        }
        if elem.code_context == CodeContext.NATIVE {
            has_native = True;
        } elif elem.code_context == CodeContext.SERVER {
            has_server = True;
        }
    }
    return has_native and has_server;
}

impl stamp_native(mod: Module, held: set[int]) -> list[ContextAwareNode] {
    stamped: list[ContextAwareNode] = [];
    for elem in mod.elements {
        if not isinstance(elem, ContextAwareNode)
            or elem.code_context != CodeContext.SERVER
            or id(elem) in held {
            continue;
        }
        elem.code_context = CodeContext.NATIVE;
        stamped.append(elem);
        if isinstance(elem, ModuleCode) and elem.body {
            for inner in elem.body {
                if isinstance(inner, ContextAwareNode)
                    and inner.code_context == CodeContext.SERVER {
                    inner.code_context = CodeContext.NATIVE;
                    stamped.append(inner);
                }
            }
        }
    }
    return stamped;
}

impl settle_native_module(
    mod: Module, prog: JacProgram, pending: list[Alert], warnings: list[Alert]
) -> (NativeRefusal | None) {
    """The backend refused a module whose native placement was a preference,
    for a reason the legality rules did not predict. The module was typed for
    no codespace, so placing it on the server is a restamp of the same tree:
    the Python backend, which runs after this one, emits it as it is. The
    module's importers drop what they bound to its native code. A module with
    an element that must be native (a native-only construct, an element pin,
    a C declaration) cannot move, so its refusal stays an error.""";
    if not pending or not native_placement_soft(prog, mod) {
        return None;
    }
    if mod.gen.placement_mode == "inferred" {
        for (need, _why) in element_requirements(mod, prog).values() {
            if need == "native" {
                return None;
            }
        }
    }

    refusal = refusal_from_alert(pending[0]);
    del pending[:];
    del warnings[:];
    gen = mod.gen;
    gen.native_refusal_code = refusal.code;
    gen.native_refusal = refusal.headline();
    gen.llvm_ir = None;
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_object = None;
    gen.native_iface = None;
    gen.native_layout = None;
    gen.native_deps = [];
    settle_server(mod);

    record_decided(prog, mod);
    mod_path = mod.loc.mod_path if mod.loc is not None else "";
    resolved = os.path.realpath(mod_path);
    for stale in invalidate_importers_es(prog, resolved) {
        drop_native_bindings(stale, resolved);
    }
    host = active_host();
    host.record_native_coverage(resolved, 'demoted', refusal.code, refusal.headline());
    host.note(
        f"note: {mod_path} preferred native but did not lower; "
        f"compiled in the server codespace ({refusal.headline()})",
        "dim"
    );
    return refusal;
}

impl PlacementPass._emit_refusal(refusal: NativeRefusal, required_by: str) -> None {
    if refusal.site is None {
        return;
    }
    note = f"The element must be native ({required_by}), so this is an error "
    "rather than a reason to place it elsewhere."
        if required_by
        else None;
    recorded = DIAGNOSTICS.get(refusal.code) if refusal.noted else None;
    if recorded is not None {
        policy = self.ctx.policy;
        if policy is not None and policy.is_suppressed(recorded, refusal.site.loc) {
            return;
        }
        self.ctx.errors_had.append(
            Alert(
                msg=refusal.name,
                loc=refusal.site.loc.span(),
                from_pass=self.ctx.from_pass,
                code=recorded,
                related=[],
                help_text=note or recorded.help_text
            )
        );
        return;
    }
    self.ctx.emit(
        E5090,
        node_override=refusal.site,
        kind=refusal.kind,
        name=refusal.name,
        help_text=f"{refusal.help} {note}"
            if refusal.help and note
            else (refusal.help or note)
    );
}

impl PlacementPass._run_impl(ir_in: Module) -> Module {
    """Placement is decided once, on the typed module. A module whose
    codespace was declared has its elements placed already: what remains is
    to hold that placement to account. Any other module was typed for no
    codespace, and this is where its elements are placed. Nothing types it
    again: what was placed is the tree every backend reads.""";
    ir_in.native_viols_reported = True;
    ir_in.client_viols_reported = True;
    self._check_conformance(ir_in);
    if ir_in.gen.placement_mode {
        return self._run_decided(ir_in);
    }
    return self._run_undecided(ir_in);
}

impl PlacementPass._run_decided(ir_in: Module) -> Module {
    mod_path = ir_in.loc.mod_path if ir_in.loc is not None else "";
    self.prog.analysis.placement_refusals.pop(os.path.realpath(mod_path), None);
    client_refused = client_refused_elements(ir_in);
    placed: list[CodeContext] = [];
    for elem in ir_in.elements {
        if not isinstance(elem, ContextAwareNode) {
            continue;
        }
        placed.append(elem.code_context);
        if elem.code_context == CodeContext.CLIENT and id(elem) in client_refused {
            for (vnode, vkind) in client_refused[id(elem)] {
                self.ctx.emit(E5096, node_override=vnode, kind=vkind);
            }
        }
    }
    has_native = CodeContext.NATIVE in placed;
    if has_native {
        legality = build_native_legality(ir_in, self.prog);
        refused: list[NativeRefusal] = list(legality.module);
        refused.extend(legality.elements.values());
        if refused {
            reached: set[int] = {id(refusal) for refusal in legality.reach};
            direct: list[NativeRefusal] = [
                refusal
                for refusal in refused
                if id(refusal) not in reached
            ];
            if direct {
                for unit_refusals in legality.units.values() {
                    for unit_refusal in unit_refusals {
                        if unit_refusal.code == "E5090" {
                            direct.append(unit_refusal);
                        }
                    }
                }
            }
            seen: set[int] = set();
            for refusal in direct {
                if refusal.site is None or id(refusal.site) in seen {
                    continue;
                }
                seen.add(id(refusal.site));
                self._emit_refusal(refusal, "");
            }
        }
        active_host().record_native_coverage(mod_path, 'native');
    }
    refresh_placement_module(ir_in, self.prog);
    if solve_module_placement(ir_in, self.prog) {
        placement_work(self.prog).changed(ir_in);
    }
    report_serverless_kind_errors(self, ir_in);
    return ir_in;
}

impl PlacementPass._run_undecided(ir_in: Module) -> Module {
    spaces: dict[str, CodeContext] = {
        'server': CodeContext.SERVER,
        'client': CodeContext.CLIENT,
        'native': CodeContext.NATIVE
    };

    mod_path = ir_in.loc.mod_path if ir_in.loc is not None else "";
    given = contexts_of(ir_in);

    required = element_requirements(ir_in, self.prog);
    for elem in ir_in.elements {
        need = required.get(id(elem));
        if need is not None and need[0] in spaces {
            _stamp_context_element(elem, spaces[need[0]]);
        }
    }
    (candidate, why) = native_placement_candidate(ir_in, self.prog);
    if candidate and not ir_in.gen.native_undecided {
        candidate = False;
        why = ir_in.gen.native_closed_why
            or "the module was parsed without the native preference";
    }
    tentative: list[ContextAwareNode] = stamp_native(ir_in, set(required.keys()))
        if candidate
        else [];
    judged = candidate
        or ModuleFacts.has_native_context_stmts(ir_in)
        or bool(capability_notes_of(self.prog, mod_path));
    legality = build_native_legality(ir_in, self.prog) if judged else NativeLegality();
    native_refused = legality.refused_elements(ir_in);
    client_refused = client_refused_elements(ir_in);
    inferred_refused: set[int] = set(native_refused);
    inferred_refused.update(legality.preferences.keys());
    for elem in tentative {
        owner = elem.element_in(ir_in);
        if legality.blockers or (owner is not None and id(owner) in inferred_refused) {
            elem.code_context = CodeContext.SERVER;
        }
    }
    if mod_path
        and self.prog.options is not None
        and self.prog.options.native_required_for(mod_path) {
        for elem in tentative {
            if isinstance(elem, Test) and elem.code_context == CodeContext.SERVER {
                for refusal in legality.unit_refusals(elem) {
                    self._emit_refusal(refusal, "the module is native-required");
                }
            }
        }
    }
    if tentative {
        inferred_refused.update(
            uncrossable_native(ir_in, self.prog, set(required.keys()))
        );
    }
    self.prog.analysis.placement_refusals[os.path.realpath(mod_path)] = {
        'native': inferred_refused,
        'client': set(client_refused.keys())
    };
    carries_native = False;
    for elem in ir_in.elements {
        if isinstance(elem, ContextAwareNode)
            and elem.code_context == CodeContext.NATIVE
            and not isinstance(elem, Import) {
            carries_native = True;
            break;
        }
    }
    if not carries_native {
        for elem in tentative {
            if elem.code_context == CodeContext.NATIVE {
                elem.code_context = CodeContext.SERVER;
            }
        }
    }
    refresh_placement_module(ir_in, self.prog);
    if carries_native and inferred_refused {
        _demote_unreached_imports(ir_in, tentative, self.prog);
        if _runs_split(ir_in) {
            split_moved = uncrossable_native(ir_in, self.prog, set(required.keys()));
            if split_moved {
                inferred_refused.update(split_moved);
                _demote_unreached_imports(ir_in, tentative, self.prog);
                still_native = False;
                for elem in ir_in.elements {
                    if isinstance(elem, ContextAwareNode)
                        and elem.code_context == CodeContext.NATIVE
                        and not isinstance(elem, Import) {
                        still_native = True;
                        break;
                    }
                }
                if not still_native {
                    for elem in tentative {
                        if elem.code_context == CodeContext.NATIVE {
                            elem.code_context = CodeContext.SERVER;
                        }
                    }
                }
            }
        }
    }
    pulled = solve_module_placement(ir_in, self.prog);
    if pulled or contexts_of(ir_in) != given {
        placement_work(self.prog).changed(ir_in);
    }

    placed: list[CodeContext] = [];
    runs: list[CodeContext] = [];
    seen: set[int] = set();
    for elem in ir_in.elements {
        if not isinstance(elem, ContextAwareNode) {
            continue;
        }
        placed.append(elem.code_context);
        if not isinstance(elem, Test) {
            runs.append(elem.code_context);
        }
        need = required.get(id(elem));
        if elem.code_context == CodeContext.NATIVE and id(elem) in native_refused {
            refusals: list[NativeRefusal] = list(legality.module);
            if id(elem) in legality.elements {
                refusals.append(legality.elements[id(elem)]);
            }
            for unit_refusal in legality.units.get(id(elem), []) {
                if unit_refusal.noted or (need is not None and need[0] == "native") {
                    refusals.append(unit_refusal);
                }
            }
            for refusal in refusals {
                if refusal.site is None or id(refusal.site) in seen {
                    continue;
                }
                seen.add(id(refusal.site));
                self._emit_refusal(refusal, need[1] if need is not None else "");
            }
        }
        if elem.code_context == CodeContext.NATIVE
            and need is not None
            and need[0] == "native" {
            for (uid, owner) in legality.owners.items() {
                if uid == id(elem)
                    or uid not in legality.units
                    or owner.element_in(ir_in) is not elem {
                    continue;
                }
                for refusal in legality.units[uid] {
                    if refusal.site is None or id(refusal.site) in seen {
                        continue;
                    }
                    seen.add(id(refusal.site));
                    self._emit_refusal(refusal, need[1]);
                }
            }
        }
        if elem.code_context == CodeContext.CLIENT and id(elem) in client_refused {
            for (vnode, vkind) in client_refused[id(elem)] {
                self.ctx.emit(E5096, node_override=vnode, kind=vkind);
            }
        }
    }
    self._report_unmet(legality, "" if candidate else why);

    runs = runs or placed;
    uniform = runs[0] if runs and all(ctx == runs[0] for ctx in runs) else None;
    ir_in.decided_codespace = uniform.value
        if uniform is not None and uniform != CodeContext.SERVER
        else "";
    ir_in.codespace_inferred = any(
        elem.code_context == CodeContext.NATIVE for elem in tentative
    );
    if CodeContext.NATIVE in placed {
        active_host().record_native_coverage(mod_path, 'native');
    } else {
        first = legality.module[0]
            if legality.module
            else (
                legality.blockers[0]
                    if legality.blockers
                    else (
                        next(iter(legality.elements.values()))
                            if legality.elements
                            else (
                                next(iter(legality.preferences.values()))
                                    if legality.preferences
                                    else None
                            )
                    )
            );
        active_host().record_native_coverage(
            mod_path,
            'server',
            first.code if first is not None else '',
            first.headline() if first is not None else why
        );
    }
    report_serverless_kind_errors(self, ir_in);
    ir_in.gen.placement_mode = 'inferred';

    record_decided(self.prog, ir_in);
    return ir_in;
}

impl PlacementPass._check_conformance(ir_in: Module) -> None {
    mod_path = ir_in.loc.mod_path if ir_in.loc is not None else "";
    if "/runtime/na_stdlib/" not in mod_path.replace("\\", "/")
        and os.path.basename(mod_path).count(".") < 2 {
        return;
    }

    for (decl, why) in variant_mismatches(ir_in, self.prog) {
        self.ctx.emit(E5116, node_override=decl, reason=why);
    }
    lib_name = native_library_module_name(mod_path) if mod_path else None;
    if lib_name is None {
        return;
    }
    stub_path = typeshed_stub_path(lib_name);
    if stub_path is None {
        return;
    }
    stub_mod = self.prog.load_dependency_module(stub_path, need_tree=True);
    for (decl, why) in conformance_mismatches(stub_mod, ir_in, self.prog) {
        self.ctx.emit(E5116, node_override=decl, reason=why);
    }
}

impl PlacementPass._report_unmet(legality: NativeLegality, why: str) -> None {
    for (need, blocked) in legality.unmet() {
        if need.site is None {
            continue;
        }
        (kind, name) = unmet_label(need);
        self.ctx.emit(
            E5090,
            node_override=need.site,
            kind=kind,
            name=name,
            help_text="This construct only exists natively, but the code that uses "
            f"it cannot be placed native: {blocked.headline()}"
        );
    }
    if why and not legality.module_refused() {
        needs: list[NativeRefusal] = list(legality.requires.values());
        needs.extend(legality.module_requires);
        for need in needs {
            if need.site is None {
                continue;
            }
            (kind, name) = unmet_label(need);
            self.ctx.emit(
                E5090,
                node_override=need.site,
                kind=kind,
                name=name,
                help_text="This construct only exists natively, but this module "
                f"is not a candidate for native placement: {why}"
            );
        }
    }
}

impl PlacementPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}
