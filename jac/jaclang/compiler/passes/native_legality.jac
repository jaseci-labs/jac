import from jaclang.compiler.passes.context { Alert, CompilerPass }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    ImplDef,
    Import,
    Module,
    Name,
    Test,
    UniNode
}
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.diagnostics { E5090 }
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
        late: dict[str, list[NativeRefusal]] = {};

    def refuse_unit(owner: UniNode, refusal: NativeRefusal) -> None;
    def refuse_module(refusal: NativeRefusal) -> None;
    def unit_refusals(owner: UniNode) -> list[NativeRefusal];
    def unit_refused(owner: UniNode) -> bool;
    def module_refused -> bool;
    def settle -> None;
    def static_units -> int;
    def late_units -> int;
}

def native_unit_name(owner: UniNode) -> str;
def native_enclosing_unit(nd: UniNode) -> (UniNode | None);
def refusal_from_alert(alert: Alert) -> NativeRefusal;
def build_native_legality(mod: Module) -> NativeLegality;
def settle_native_module(
    mod: Module, prog: JacProgram, pending: list[Alert], warnings: list[Alert]
) -> (NativeRefusal | None);

walker NativeLegalityPass(CompilerPass) {
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

impl build_native_legality(mod: Module) -> NativeLegality {
    import from jaclang.compiler.passes.capability_check_pass {
        native_capability_demotion_owner,
        native_capability_violations
    }
    legality = NativeLegality();
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
    gen.native_refusal_code = refusal.code;
    gen.native_refusal = refusal.headline();
    gen.llvm_ir = None;
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_object = None;
    gen.native_iface = None;
    gen.native_layout = None;
    gen.native_deps = [];
    return refusal;
}

impl NativeLegalityPass._run_impl(ir_in: Module) -> Module {
    ir_in.native_viols_reported = True;
    if not ModuleFacts.has_native_context_stmts(ir_in) {
        return ir_in;
    }
    legality = build_native_legality(ir_in);
    if not legality.module_refused() {
        return ir_in;
    }
    if native_placement_soft(self.prog, ir_in) {
        first = legality.module[0] if legality.module else legality.reach[0];
        ir_in.gen.native_refusal_code = first.code;
        ir_in.gen.native_refusal = first.headline();
        return ir_in;
    }
    if not legality.module {
        return ir_in;
    }
    shown: list[NativeRefusal] = [];
    seen: set[int] = set();
    candidates: list[NativeRefusal] = list(legality.module);
    for refusals in legality.units.values() {
        candidates.extend(refusals);
    }
    for refusal in candidates {
        if refusal.site is None
            or refusal.code != "E5090"
            or id(refusal.site) in seen {
            continue;
        }
        seen.add(id(refusal.site));
        shown.append(refusal);
    }
    for refusal in shown {
        if refusal.help is None {
            self.ctx.emit(
                E5090, node_override=refusal.site, kind=refusal.kind, name=refusal.name
            );
        } else {
            self.ctx.emit(
                E5090,
                node_override=refusal.site,
                kind=refusal.kind,
                name=refusal.name,
                help_text=refusal.help
            );
        }
    }
    return ir_in;
}

impl NativeLegalityPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}
