import from jaclang.compiler.passes.context { Alert, CompilerPass }
import os;
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    ContextAwareNode,
    ImplDef,
    Import,
    Module,
    ModuleCode,
    Name,
    Test,
    UniNode
}
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.diagnostics { E5090, E5114 }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.placement.placement_facts { native_placement_soft }
import type from jaclang.compiler.driver.program { JacProgram }

class NativeRefused(Exception) {}

obj NativeRefusal {
    has kind: str,
        name: str,
        site: (UniNode | None) = None,
        help: (str | None) = None,
        code: str = "E5090",
        late: bool = False,
        text: str = "",
        brief: str = "",
        detail: str = "";

    def message -> str;
    def headline -> str;
    def located -> str;
    def full -> str;
}

obj NativeLegality {
    has units: dict[int, list[NativeRefusal]] = {},
        owners: dict[int, UniNode] = {},
        refs: dict[int, set[int]] = {},
        anchored: set[int] = set(),
        module: list[NativeRefusal] = [],
        reach: list[NativeRefusal] = [],
        reached: dict[int, int] = {},
        late: dict[str, list[NativeRefusal]] = {},
        requires: dict[int, NativeRefusal] = {},
        module_requires: list[NativeRefusal] = [];

    def refuse_unit(owner: UniNode, refusal: NativeRefusal) -> None;
    def refuse_module(refusal: NativeRefusal) -> None;
    def unit_refusals(owner: UniNode) -> list[NativeRefusal];
    def unit_refused(owner: UniNode) -> bool;
    def module_refused -> bool;
    def settle -> None;
    def static_units -> int;
    def late_units -> int;
    def unmet -> list[tuple[NativeRefusal, NativeRefusal]];
}

def native_unit_name(owner: UniNode) -> str;
def native_enclosing_unit(nd: UniNode) -> (UniNode | None);
def refusal_from_alert(alert: Alert) -> NativeRefusal;
def build_native_legality(
    mod: Module, prog: (JacProgram | None) = None
) -> NativeLegality;

def stamp_native(mod: Module) -> list[ContextAwareNode];
def unstamp_native(stamped: list[ContextAwareNode]) -> None;
def import_placed_native(prog: JacProgram, dep_path: str) -> bool;
def place_module_server(mod: Module, prog: JacProgram, refusal: NativeRefusal) -> None;
def settle_native_module(
    mod: Module, prog: JacProgram, pending: list[Alert], warnings: list[Alert]
) -> (NativeRefusal | None);

walker NativeLegalityPass(CompilerPass) {
    def _emit_refusal(refusal: NativeRefusal) -> None;
    def _report_unmet(legality: NativeLegality, why: str) -> None;
    def _check_conformance(ir_in: Module) -> None;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
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

impl NativeLegality.unit_refusals(owner: UniNode) -> list[NativeRefusal] {
    return self.units.get(id(owner), []);
}

impl NativeLegality.unit_refused(owner: UniNode) -> bool {
    return id(owner) in self.units;
}

impl NativeLegality.module_refused -> bool {
    return len(self.module) > 0 or len(self.reach) > 0;
}

impl NativeLegality.settle -> None {
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
                blocker = native_unit_name(self.owners[target]);
                caller = native_unit_name(self.owners[uid]);
                self.units[uid] = [
                    NativeRefusal(
                        kind="function",
                        name=blocker,
                        site=self.owners[uid],
                        code="E5092",
                        help=f"'{blocker}' is placed on its Python-only implementation "
                        f"(native seam), so '{caller}' cannot reach it natively; hoist the "
                        f"blocking construct out of '{blocker}' or move '{caller}' off the "
                        f"native pathway."
                    )
                ];
                self.reached[uid] = target;
                changed = True;
                break;
            }
        }
    }
    if self.module {
        return;
    }
    for target in self.anchored {
        if target not in self.units {
            continue;
        }
        blocker = native_unit_name(self.owners[target]);
        cause = target;
        while cause in self.reached {
            cause = self.reached[cause];
        }
        first = self.units[cause][0];
        self.reach.append(
            NativeRefusal(
                kind=first.kind,
                name=first.name,
                site=first.site,
                code=first.code,
                late=first.late,
                text=first.text,
                brief=first.brief,
                detail=first.detail,
                help=f"Module-level native code reaches '{blocker}', which is placed "
                f"on its Python-only implementation, so the module cannot run on "
                f"the native pathway."
            )
        );
        return;
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
    blocked = self.module[0]
        if self.module
        else (self.reach[0] if self.reach else None);
    for (uid, need) in self.requires.items() {
        if uid in self.units {
            out.append((need, self.units[uid][0]));
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
    cur: UniNode = nd;
    while True {
        nxt: (UniNode | None) = cur.find_parent_of_type(Ability);
        if nxt is None {
            impl_def = cur.find_parent_of_type(ImplDef);
            if impl_def is None and isinstance(cur, ImplDef) {
                impl_def = cur;
            }
            if impl_def is not None
                and isinstance(impl_def.decl_link, Ability)
                and impl_def.decl_link is not cur {
                nxt = impl_def.decl_link;
            }
        }
        if nxt is None {
            break;
        }
        owner = nxt;
        cur = nxt;
    }
    if owner is not None {
        return owner;
    }
    if isinstance(nd, Test) {
        return nd;
    }
    return nd.find_parent_of_type(Test);
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

def _reference_targets(nm: Name) -> list[UniNode] {
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

impl build_native_legality(
    mod: Module, prog: (JacProgram | None) = None
) -> NativeLegality {
    import from jaclang.compiler.passes.capability_check_pass {
        native_capability_demotion_owner,
        native_capability_violations
    }
    import from jaclang.compiler.placement.placement { scan_native_blockers }
    import from jaclang.compiler.capability_notes { TARGET_NATIVE, capability_notes_of }
    import from jaclang.compiler.native_bindings { binding_gaps }
    legality = NativeLegality();
    mod_path = mod.loc.mod_path if mod.loc is not None else "";
    base_dir = os.path.dirname(os.path.abspath(mod_path)) if mod_path else ".";
    (blocker, deps) = scan_native_blockers(mod, base_dir);
    if blocker {
        legality.refuse_module(NativeRefusal(kind="module", name=blocker, site=mod));
    }
    if prog is not None {
        for dep in deps {
            if not import_placed_native(prog, dep) {
                legality.refuse_module(
                    NativeRefusal(
                        kind="import",
                        name=os.path.basename(dep),
                        site=mod,
                        help="The imported module is placed on the server, and "
                        "native code cannot call into it."
                    )
                );
                break;
            }
        }
        for note in capability_notes_of(prog, mod_path, TARGET_NATIVE) {
            noted = NativeRefusal(
                kind="construct",
                name=note.text,
                site=note.site,
                code=note.code,
                text=f"error[{note.code}]: {note.text}"
            );
            if note.requires {
                unit = native_enclosing_unit(note.site);
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
                legality.refuse_module(noted);
            } else {
                legality.refuse_unit(owner, noted);
            }
        }
    }
    for (vnode, vkind, vname, vhelp) in native_capability_violations(mod) {
        owner = native_capability_demotion_owner(vnode);
        if owner is None {
            note = "No owning method or function can absorb this construct as a "
            "native seam, so the whole module refuses to lower.";
            legality.refuse_module(
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
    for stmt in ModuleFacts.iter_context_stmts(mod, CodeContext.NATIVE) {
        if isinstance(stmt, Import) {
            continue;
        }
        for nm in stmt.get_all_sub_nodes(Name) {
            if prog is not None {
                for gap in binding_gaps(prog, nm, base_dir) {
                    missing = NativeRefusal(
                        kind="library member",
                        name=gap,
                        site=nm,
                        text=f"error[E5090]: {gap}"
                    );
                    gap_owner = native_capability_demotion_owner(nm);
                    if gap_owner is None {
                        legality.refuse_module(missing);
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
                    legality.anchored.add(id(target));
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

impl stamp_native(mod: Module) -> list[ContextAwareNode] {
    stamped: list[ContextAwareNode] = [];
    for elem in mod.body {
        if not isinstance(elem, ContextAwareNode)
            or elem.code_context != CodeContext.SERVER {
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

impl unstamp_native(stamped: list[ContextAwareNode]) -> None {
    for elem in stamped {
        elem.code_context = CodeContext.SERVER;
    }
}

impl import_placed_native(prog: JacProgram, dep_path: str) -> bool {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
    resolved = os.path.realpath(dep_path);
    placing = prog.analysis.native_placing;
    if resolved in placing {
        return True;
    }
    target = prog.mod.hub.get(resolved);
    if target is None
        or not prog.analysis.analyses_run.provides(target, AnalysisFact.CAPABILITY) {
        placing.add(resolved);
        try {
            target = prog.compile(resolved, options=CompileOptions(no_cgen=True));
        } finally {
            placing.discard(resolved);
        }
    }
    return target is not None and target.declares_codespace(CodeContext.NATIVE);
}

impl place_module_server(
    mod: Module, prog: JacProgram, refusal: NativeRefusal
) -> None {
    import from jaclang.compiler.frontend.host { active_host }
    import from jaclang.compiler.placement.placement_solver {
        invalidate_importers_es,
        placement_work
    }
    import from jaclang.compiler.driver.session_compile { drop_native_bindings }
    for elem in mod.body {
        if not isinstance(elem, ContextAwareNode)
            or elem.code_context != CodeContext.NATIVE
            or (isinstance(elem, Import) and elem.has_clib_decls) {
            continue;
        }
        elem.code_context = CodeContext.SERVER;
        if isinstance(elem, ModuleCode) and elem.body {
            for inner in elem.body {
                if isinstance(inner, ContextAwareNode) {
                    inner.code_context = CodeContext.SERVER;
                }
            }
        }
    }
    mod.decided_codespace = "";
    mod.codespace_inferred = False;
    mod_path = mod.loc.mod_path if mod.loc is not None else "";
    if not mod_path {
        return;
    }
    resolved = os.path.realpath(mod_path);
    host = active_host();
    host.record_native_coverage(resolved, 'server', refusal.code, refusal.headline());
    for stale in invalidate_importers_es(prog, resolved) {
        drop_native_bindings(stale, resolved);
    }
    placement_work(prog).changed(mod);
    host.note(
        f"note: {mod_path} preferred native but did not lower; "
        f"compiled in the server codespace ({refusal.headline()})",
        "dim"
    );
}

impl settle_native_module(
    mod: Module, prog: JacProgram, pending: list[Alert], warnings: list[Alert]
) -> (NativeRefusal | None) {
    if not pending or not native_placement_soft(prog, mod) {
        return None;
    }
    refusal = refusal_from_alert(pending[0]);
    del pending[:];
    del warnings[:];
    gen = mod.gen;
    gen.native_refusal = refusal.headline();
    gen.llvm_ir = None;
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_object = None;
    gen.native_iface = None;
    gen.native_layout = None;
    gen.native_deps = [];
    place_module_server(mod, prog, refusal);
    return refusal;
}

impl NativeLegalityPass._emit_refusal(refusal: NativeRefusal) -> None {
    if refusal.site is None {
        return;
    }
    self.ctx.emit(
        E5090,
        node_override=refusal.site,
        kind=refusal.kind,
        name=refusal.name,
        help_text=refusal.help
    );
}

impl NativeLegalityPass._run_impl(ir_in: Module) -> Module {
    import from jaclang.compiler.frontend.host { active_host }
    import from jaclang.compiler.placement.placement_solver {
        native_placement_candidate,
        placement_work
    }
    ir_in.native_viols_reported = True;
    mod_path = ir_in.loc.mod_path if ir_in.loc is not None else "";
    declared = ModuleFacts.has_native_context_stmts(ir_in);
    stamped: list[ContextAwareNode] = [];
    if not declared {
        (candidate, why) = native_placement_candidate(ir_in, self.prog);
        if not candidate {
            active_host().record_native_coverage(mod_path, 'server', '', why);
            self._report_unmet(build_native_legality(ir_in, self.prog), why);
            return ir_in;
        }
        stamped = stamp_native(ir_in);
    }
    self._check_conformance(ir_in);
    legality = build_native_legality(ir_in, self.prog);
    if not legality.module_refused() {
        if stamped {
            ir_in.decided_codespace = CodeContext.NATIVE.value;
            ir_in.codespace_inferred = True;
            placement_work(self.prog).changed(ir_in);
        }
        active_host().record_native_coverage(mod_path, 'native');
        self._report_unmet(legality, "");
        return ir_in;
    }
    first = legality.module[0] if legality.module else legality.reach[0];
    if stamped {
        unstamp_native(stamped);
        active_host().record_native_coverage(
            mod_path, 'server', first.code, first.headline()
        );
        self._report_unmet(legality, first.headline());
        return ir_in;
    }
    seen: set[int] = set();
    candidates: list[NativeRefusal] = list(legality.module);
    for refusals in legality.units.values() {
        candidates.extend(refusals);
    }
    for refusal in candidates {
        if refusal.site is None or id(refusal.site) in seen {
            continue;
        }
        seen.add(id(refusal.site));
        self._emit_refusal(refusal);
    }
    return ir_in;
}

impl NativeLegalityPass._check_conformance(ir_in: Module) -> None {
    import from jaclang.compiler.native_bindings {
        conformance_mismatches,
        native_library_module_name,
        typeshed_stub_path
    }
    mod_path = ir_in.loc.mod_path if ir_in.loc is not None else "";
    lib_name = native_library_module_name(mod_path) if mod_path else None;
    if lib_name is None {
        return;
    }
    stub_path = typeshed_stub_path(lib_name);
    if stub_path is None {
        return;
    }
    stub_mod = self.prog.load_dependency_module(stub_path, need_tree=True);
    for (decl, why) in conformance_mismatches(stub_mod, ir_in) {
        self.ctx.emit(E5114, node_override=decl, reason=why);
    }
}

impl NativeLegalityPass._report_unmet(legality: NativeLegality, why: str) -> None {
    for (need, blocked) in legality.unmet() {
        if need.site is None {
            continue;
        }
        self.ctx.emit(
            E5090,
            node_override=need.site,
            kind="native-only construct",
            name=need.name,
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
            self.ctx.emit(
                E5090,
                node_override=need.site,
                kind="native-only construct",
                name=need.name,
                help_text="This construct only exists natively, but this module "
                f"is not a candidate for native placement: {why}"
            );
        }
    }
}

impl NativeLegalityPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}
