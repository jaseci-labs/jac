impl NaIRGenPass._codegen_assignment(nd: uni.Assignment) -> None {
    if nd.aug_op is not None {
        self._guard_unbound_aug(nd);
    }
    self._codegen_assignment_core(nd);
    self._mark_unbound_targets(nd);
}

impl NaIRGenPass._unbound_root(nd: uni.UniNode) -> (uni.UniNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, (uni.Ability, uni.ImplDef, uni.Test)) {
            return cur;
        }
        if isinstance(cur, (uni.Archetype, uni.Enum, uni.ModuleCode, uni.Module)) {
            return None;
        }
        cur = cur.parent;
    }
    return None;
}

impl NaIRGenPass._unbound_facts(nd: uni.UniNode) -> (NativeUnboundFacts | None) {
    frame = self._unbound_root(nd);
    if frame is None {
        return None;
    }
    facts = self._unbound_memo.get(id(frame));
    if facts is None or facts.frame is not frame {
        facts = self._unbound_scan(frame);
        self._unbound_memo[id(frame)] = facts;
    }
    return facts;
}

impl NaIRGenPass._unbound_is_nested(frame: uni.UniNode) -> bool {
    cur = frame.parent;
    while cur is not None {
        if isinstance(cur, (uni.Ability, uni.Test, uni.LambdaExpr)) {
            return True;
        }
        if isinstance(cur, uni.ImplDef)
            and isinstance(cur.spec, (uni.FuncSignature, uni.EventSignature)) {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl NaIRGenPass._unbound_params(frame: uni.UniNode) -> set[str] {
    names: set[str] = set();
    names.add("self");
    sigs: list[uni.UniNode] = [];
    if isinstance(frame, uni.Ability) and frame.signature is not None {
        sigs.append(frame.signature);
    } elif isinstance(frame, uni.ImplDef) {
        if isinstance(frame.spec, (uni.FuncSignature, uni.EventSignature)) {
            sigs.append(frame.spec);
        }
        decl = frame.decl_link;
        if isinstance(decl, uni.Ability) and decl.signature is not None {
            sigs.append(decl.signature);
        }
    }
    for sig in sigs {
        for nm in sig.get_all_sub_nodes(uni.Name) {
            names.add(nm.value);
        }
    }
    return names;
}

impl NaIRGenPass._unbound_block(nd: uni.UniNode) -> (Sequence[uni.UniNode] | None) {
    if isinstance(nd, (uni.Ability, uni.ImplDef)) {
        return ModuleFacts.unwrap_body(nd);
    }
    if isinstance(
        nd,
        (
            uni.Test,
            uni.IfStmt,
            uni.ElseStmt,
            uni.WhileStmt,
            uni.ForeverStmt,
            uni.InForStmt,
            uni.IterForStmt,
            uni.TryStmt,
            uni.Except,
            uni.FinallyStmt,
            uni.WithStmt,
            uni.MatchCase,
            uni.SwitchCase,
            uni.TypedCtxBlock,
            uni.OpenStmt
        )
    ) {
        return nd.body;
    }
    return None;
}

impl NaIRGenPass._unbound_target_names(
    target: uni.UniNode, out: list[uni.Name]
) -> None {
    if isinstance(target, uni.SpecialVarRef) {
        return;
    }
    if isinstance(target, uni.Name) {
        out.append(target);
    } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
        for value in target.values {
            self._unbound_target_names(value, out);
        }
    } elif isinstance(target, uni.UnaryExpr) {
        self._unbound_target_names(target.operand, out);
    } elif isinstance(target, uni.AtomUnit) {
        self._unbound_target_names(target.value, out);
    }
}

impl NaIRGenPass._unbound_role(nm: uni.Name, frame: uni.UniNode, top: set[int]) -> int {
    parent = nm.parent;
    if isinstance(parent, uni.AtomTrailer) and parent.is_attr and parent.right is nm {
        return UNBOUND_ROLE_SKIP;
    }
    if isinstance(parent, uni.KWPair) and parent.key is nm {
        return UNBOUND_ROLE_SKIP;
    }
    role = UNBOUND_ROLE_READ;
    held: uni.UniNode = nm;
    holder = parent;
    while isinstance(
        holder, (uni.TupleVal, uni.ListVal, uni.AtomUnit, uni.UnaryExpr)
    ) {
        held = holder;
        holder = holder.parent;
    }
    if isinstance(holder, uni.Assignment) {
        for target in holder.target {
            if target is held {
                if holder.value is None {
                    role = UNBOUND_ROLE_EXCLUDE;
                } elif holder.aug_op is not None {
                    role = UNBOUND_ROLE_AUG;
                } else {
                    role = UNBOUND_ROLE_ASSIGN;
                }
            }
        }
    } elif isinstance(parent, uni.BinaryExpr)
        and isinstance(parent.op, uni.Token)
        and parent.op.name == Tok.WALRUS_EQ
        and parent.left is nm {
        role = UNBOUND_ROLE_ASSIGN;
    }
    child: uni.UniNode = nm;
    cur = parent;
    while cur is not None and cur is not frame {
        if isinstance(
            cur,
            (
                uni.LambdaExpr,
                uni.Ability,
                uni.Archetype,
                uni.Enum,
                uni.ImplDef,
                uni.Test,
                uni.GlobalVars,
                uni.Import,
                uni.TypeAlias,
                uni.DeleteStmt,
                uni.ConcurrentExpr
            )
        ) {
            return UNBOUND_ROLE_EXCLUDE;
        }
        if isinstance(cur, uni.InForStmt) and self._unbound_is_flow(cur) {
            return UNBOUND_ROLE_EXCLUDE;
        }
        if isinstance(
            cur, (uni.ListCompr, uni.DictCompr, uni.FilterCompr, uni.AssignCompr)
        ) {
            return UNBOUND_ROLE_EXCLUDE
                if role == UNBOUND_ROLE_ASSIGN
                else UNBOUND_ROLE_SKIP;
        }
        if (isinstance(cur, uni.InForStmt) and child is cur.target)
            or (isinstance(cur, uni.Except) and child is cur.name)
            or (isinstance(cur, uni.ExprAsItem) and child is cur.alias)
            or (
                isinstance(cur, (uni.MatchCase, uni.SwitchCase))
                and child is cur.pattern
            ) {
            return UNBOUND_ROLE_EXCLUDE;
        }
        child = cur;
        cur = cur.parent;
    }
    if cur is None or id(child) not in top {
        return UNBOUND_ROLE_SKIP;
    }
    return role;
}

impl NaIRGenPass._unbound_inside(nd: (uni.UniNode | None), frame: uni.UniNode) -> bool {
    cur = nd;
    while cur is not None {
        if cur is frame {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl NaIRGenPass._unbound_is_flow(nd: uni.InForStmt) -> bool {
    for kid in [nd->:Kid:->] {
        if isinstance(kid, uni.Token) and kid.name == Tok.KW_FLOW {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._unbound_firsts(
    owner: uni.UniNode, firsts: dict[int, dict[str, int]], places: dict[int, int]
) -> dict[str, int] {
    known = firsts.get(id(owner));
    if known is not None {
        return known;
    }
    found: dict[str, int] = {};
    body = self._unbound_block(owner);
    if body is not None {
        for (i, stmt) in enumerate(body) {
            places[id(stmt)] = i;
            if isinstance(stmt, uni.Assignment) and stmt.value is not None {
                names: list[uni.Name] = [];
                for target in stmt.target {
                    self._unbound_target_names(target, names);
                }
                for name in names {
                    if name.value not in found {
                        found[name.value] = i;
                    }
                }
            }
        }
    }
    firsts[id(owner)] = found;
    return found;
}

impl NaIRGenPass._unbound_dominated(
    start: uni.UniNode,
    name: str,
    frame: uni.UniNode,
    firsts: dict[int, dict[str, int]],
    places: dict[int, int]
) -> bool {
    child: uni.UniNode = start;
    cur = start.parent;
    while cur is not None {
        if isinstance(cur, uni.IterForStmt) and child is not cur.iter {
            names: list[uni.Name] = [];
            for target in cur.iter.target {
                self._unbound_target_names(target, names);
            }
            for found in names {
                if found.value == name {
                    return True;
                }
            }
        }
        if self._unbound_block(cur) is not None {
            first = self._unbound_firsts(cur, firsts, places).get(name);
            at = places.get(id(child));
            if first is not None and at is not None and first < at {
                return True;
            }
        }
        if cur is frame {
            return False;
        }
        child = cur;
        cur = cur.parent;
    }
    return False;
}

impl NaIRGenPass._unbound_scan(frame: uni.UniNode) -> NativeUnboundFacts {
    facts = NativeUnboundFacts(frame=frame, guarded=set(), reads=set(), augs=set());
    body = self._unbound_block(frame);
    if not body or self._unbound_is_nested(frame) {
        return facts;
    }
    if isinstance(frame, uni.ImplDef)
        and not isinstance(frame.decl_link, uni.Ability)
        and not isinstance(frame.spec, (uni.FuncSignature, uni.EventSignature)) {
        return facts;
    }
    if frame.get_all_sub_nodes(uni.PyInlineCode) {
        return facts;
    }
    top: set[int] = set();
    for stmt in body {
        top.add(id(stmt));
    }
    assigned: set[str] = set();
    excluded = self._unbound_params(frame);
    reads: list[uni.Name] = [];
    augs: list[uni.Name] = [];
    for nm in frame.get_all_sub_nodes(uni.Name) {
        if isinstance(nm, uni.SpecialVarRef) {
            continue;
        }
        role = self._unbound_role(nm, frame, top);
        if role == UNBOUND_ROLE_READ {
            reads.append(nm);
        } elif role == UNBOUND_ROLE_EXCLUDE {
            excluded.add(nm.value);
        } elif role == UNBOUND_ROLE_ASSIGN or role == UNBOUND_ROLE_AUG {
            assigned.add(nm.value);
            sym = nm.sym;
            if sym is not None
                and (
                    sym.sym_type != SymbolType.VAR
                    or sym.imported
                    or not self._unbound_inside(sym.decl, frame)
                ) {
                excluded.add(nm.value);
            }
            if self._clib_global_of(nm) is not None {
                excluded.add(nm.value);
            }
            if role == UNBOUND_ROLE_AUG {
                augs.append(nm);
            }
        }
    }
    firsts: dict[int, dict[str, int]] = {};
    places: dict[int, int] = {};
    for nm in reads {
        name = nm.value;
        if name not in assigned
            or name in excluded
            or name in self.global_vars
            or self.scope.binds_function(name) {
            continue;
        }
        if not self._unbound_dominated(nm, name, frame, firsts, places) {
            facts.reads.add(id(nm));
            facts.guarded.add(name);
        }
    }
    for nm in augs {
        name = nm.value;
        if name in excluded
            or name in self.global_vars
            or self.scope.binds_function(name) {
            continue;
        }
        stmt = nm.parent;
        while stmt is not None and not isinstance(stmt, uni.Assignment) {
            stmt = stmt.parent;
        }
        if stmt is not None
            and not self._unbound_dominated(stmt, name, frame, firsts, places) {
            facts.augs.add(id(stmt));
            facts.guarded.add(name);
        }
    }
    return facts;
}

impl NaIRGenPass._unbound_key(name: str) -> str {
    return f"{self.builder.function.name}|{name}";
}

impl NaIRGenPass._unbound_flag(name: str) -> ir.Value {
    key = self._unbound_key(name);
    func = self.builder.function;
    slot = self._unbound_flags.get(key);
    if isinstance(slot, ir.Instruction) and slot.parent.parent is func {
        return slot;
    }
    made = self._entry_alloca(ir.IntType(1), f"{name}.bound");
    self._unbound_flags[key] = made;
    return made;
}

impl NaIRGenPass._guard_unbound_read(nd: uni.Name) -> None {
    facts = self._unbound_facts(nd);
    if facts is not None and id(nd) in facts.reads {
        self._emit_unbound_check(nd.value, nd);
    }
}

impl NaIRGenPass._guard_unbound_aug(nd: uni.Assignment) -> None {
    facts = self._unbound_facts(nd);
    if facts is None or id(nd) not in facts.augs {
        return;
    }
    names: list[uni.Name] = [];
    for target in nd.target {
        self._unbound_target_names(target, names);
    }
    for name in names {
        if name.value in facts.guarded {
            self._emit_unbound_check(name.value, name);
        }
    }
}

impl NaIRGenPass._emit_unbound_check(name: str, typed: uni.UniNode) -> None {
    if self._builder is None or self.builder.block.is_terminated {
        return;
    }
    if name not in self.local_vars {
        if name in self.global_vars or self.scope.binds_function(name) {
            return;
        }
        slot_ty: (ir.Type | None) = None;
        if isinstance(typed, uni.Expr) and typed.type is not None {
            slot_ty = self._lower_type(typed.type);
        }
        if slot_ty is None or isinstance(slot_ty, ir.VoidType) {
            return;
        }
        slot = self._entry_alloca(slot_ty, name);
        self.local_vars[name] = slot;
        self._unbound_early[self._unbound_key(name)] = slot;
    }
    is_bound = self.builder.load(self._unbound_flag(name), name=f"{name}.is_bound");
    self._emit_runtime_raise(
        self.builder.not_(is_bound, name=f"{name}.unbound"),
        "UnboundLocalError",
        f"cannot access local variable '{name}' where it is not associated with a value"
    );
}

impl NaIRGenPass._mark_unbound_targets(nd: uni.Assignment) -> None {
    if nd.value is None {
        return;
    }
    facts = self._unbound_facts(nd);
    if facts is None or not facts.guarded {
        return;
    }
    names: list[uni.Name] = [];
    for target in nd.target {
        self._unbound_target_names(target, names);
    }
    for name in names {
        self._mark_bound(name.value, name);
    }
}

impl NaIRGenPass._mark_bound(name: str, at: uni.UniNode) -> None {
    if self._builder is None or self.builder.block.is_terminated {
        return;
    }
    facts = self._unbound_facts(at);
    if facts is None or name not in facts.guarded {
        return;
    }
    key = self._unbound_key(name);
    early = self._unbound_early.get(key);
    if isinstance(early, ir.Instruction)
        and early.parent.parent is self.builder.function
        and self.local_vars.get(name) is not early {
        self.emit(
            E5092,
            node_override=at,
            kind="local variable",
            name=name,
            help_text="This local is read before the statement that assigns it, and that assignment gives it a different native type than the read expects."
        );
        return;
    }
    self.builder.store(ir.Constant(ir.IntType(1), 1), self._unbound_flag(name));
}
