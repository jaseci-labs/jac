impl FlowCheckPass._run_impl(ir_in: Module) -> Module {
    if ir_in.is_raised_from_py or ir_in.stub_only {
        return ir_in;
    }
    flat = ir_in.flatten();
    by_owner: dict[int, list[UniCFGNode]] = {};
    for nd in flat {
        if isinstance(nd, UniCFGNode) and self._is_flow_node(nd) {
            owner = self._frame_of(nd);
            if owner is not None {
                by_owner.setdefault(id(owner), []).append(nd);
            }
        }
    }
    for start in self._frames(flat) {
        fr = self._build_frame(start, by_owner);
        if fr is not None and fr.tracked {
            self._check_frame(fr);
        }
    }
    return ir_in;
}

impl FlowCheckPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}

impl FlowCheckPass._frames(flat: list[UniNode]) -> list[UniCFGNode] {
    frames: list[UniCFGNode] = [];
    for nd in flat {
        if isinstance(nd, (Ability, ImplDef, Test)) and self._frame_body(nd) {
            frames.append(nd);
        } elif isinstance(nd, LambdaExpr) {
            body = self._frame_body(nd);
            if body {
                for stmt in body {
                    if isinstance(stmt, UniCFGNode) {
                        frames.append(stmt);
                        break;
                    }
                }
            }
        }
    }
    return frames;
}

impl FlowCheckPass._frame_body(owner: UniNode) -> (Sequence[UniNode] | None) {
    if isinstance(owner, ImplDef)
        and not isinstance(owner.decl_link, Ability)
        and not isinstance(owner.spec, (FuncSignature, EventSignature)) {
        return None;
    }
    if isinstance(owner, (Ability, ImplDef, Test, LambdaExpr))
        and isinstance(owner.body, Sequence) {
        return cast(Sequence[UniNode], owner.body);
    }
    return None;
}

impl FlowCheckPass._frame_of(nd: UniNode) -> (UniNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, (Archetype, Enum, Module, ModuleCode)) {
            return None;
        }
        if isinstance(cur, (Ability, ImplDef, Test, LambdaExpr))
            and self._frame_body(cur) is not None {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl FlowCheckPass._is_flow_node(nd: UniCFGNode) -> bool {
    return not isinstance(nd, (CfgExpr, InnerCompr, ListCompr, DictCompr));
}

impl FlowCheckPass._build_frame(
    start: UniCFGNode, by_owner: dict[int, list[UniCFGNode]]
) -> (FrameFlow | None) {
    owner: UniNode = start
        if isinstance(start, (Ability, ImplDef, Test))
        else start.parent;
    body = self._frame_body(owner);
    if not body {
        return None;
    }
    scope = find_python_scope_node_of(body[0]);
    fr = FrameFlow(owner=owner, start=start, scope=scope);
    fr.nodes.append(start);
    fr.members.add(id(start));
    for nd in by_owner.get(id(owner), []) {
        if id(nd) not in fr.members {
            fr.nodes.append(nd);
            fr.members.add(id(nd));
        }
    }
    if scope is None {
        return fr;
    }
    for nm in owner.get_all_sub_nodes(Name) {
        sym = nm.sym;
        if sym is None or id(sym) in fr.tracked {
            continue;
        }
        if sym.storage in (SymbolStorage.LOCAL, SymbolStorage.CAPTURED)
            and frame_owns(scope, sym) {
            fr.tracked.add(id(sym));
        }
    }
    return fr;
}

impl FlowCheckPass._successors(fr: FrameFlow, nd: UniCFGNode) -> list[UniCFGNode] {
    known = fr.succ_memo.get(id(nd));
    if known is not None {
        return known;
    }
    found: list[UniCFGNode] = [];
    evaluator = self.prog.type_evaluator;
    seen: set[int] = {id(nd)};
    pending: list[UniCFGNode] = [
        nxt
        for nxt in nd.bb_out
        if evaluator is None or evaluator.flow_edge_live(nd, nxt)
    ];
    while pending {
        nxt = pending.pop(0);
        if id(nxt) in seen {
            continue;
        }
        seen.add(id(nxt));
        if id(nxt) in fr.members {
            found.append(nxt);
        } elif not self._is_flow_node(nxt) {
            pending.extend(nxt.bb_out);
        }
    }
    fr.succ_memo[id(nd)] = found;
    return found;
}

impl FlowCheckPass._transfer(
    fr: FrameFlow, pred: UniCFGNode, succ: UniCFGNode, in_set: set[SymId]
) -> set[SymId] {
    if is_abrupt_entry(pred, succ) {
        return set(fr.tracked);
    }
    eff = fr.effects[id(pred)];
    out = in_set | eff.always;
    if eff.branch {
        if eff.true_entry is None {
            out |= eff.on_true & eff.on_false;
        } elif succ is eff.true_entry {
            out |= eff.on_true;
        } else {
            out |= eff.on_false;
        }
    }
    if eff.body_entry is not None and succ is eff.body_entry {
        out |= eff.into_body;
    }
    out -= eff.kills;
    cur: (UniNode | None) = pred;
    while cur is not None and cur is not fr.owner {
        if isinstance(cur, Except)
            and cur.name is not None
            and not succ.is_within(cur) {
            sid = self._sym_of(fr, cur.name);
            if sid is not None {
                out.discard(sid);
            }
        }
        cur = cur.parent;
    }
    return out;
}

impl FlowCheckPass._check_frame(fr: FrameFlow) -> None {
    empty: set[SymId] = set();
    for nd in fr.nodes {
        fr.effects[id(nd)] = self._effect(fr, nd, empty, False);
    }
    fr.state = solve_forward_must_edges(
        fr.nodes,
        lambda (nd: UniCFGNode) -> list[UniCFGNode] { return self._successors(
            fr, nd
        ); },
        [fr.start],
        lambda (pred: UniCFGNode, succ: UniCFGNode, in_set: set[SymId]) -> set[SymId] { return self._transfer(
            fr, pred, succ, in_set
        ); },
        fr.tracked
    );
    self._solve_finally_bodies(fr);
    self._check_defaults(fr);
    for nd in fr.nodes {
        self._effect(fr, nd, self._read_state(fr, nd), True);
    }
}

impl FlowCheckPass._check_defaults(fr: FrameFlow) -> None {
    decl = fr.owner.decl_link if isinstance(fr.owner, ImplDef) else fr.owner;
    if not isinstance(decl, Ability) or not isinstance(decl.signature, FuncSignature) {
        return;
    }
    sig = decl.signature;
    empty: set[SymId] = set();
    for param in list(sig.posonly_params)
        + list(sig.params or [])
        + list(sig.kwonlyargs) {
        if param.value is not None {
            self._eval_all(fr, param.value, empty, True);
        }
    }
}

impl FlowCheckPass._solve_finally_bodies(fr: FrameFlow) -> None {
    for fin in fr.nodes {
        if not isinstance(fin, FinallyStmt) {
            continue;
        }
        inner = [
            nd
            for nd in fr.nodes
            if self._encloses(fin, nd)
        ];
        fr.finally_state[id(fin)] = solve_forward_must_edges(
            inner,
            lambda (nd: UniCFGNode) -> list[UniCFGNode] { return self._successors(
                fr, nd
            ); },
            [fin],
            lambda (
                pred: UniCFGNode, succ: UniCFGNode, in_set: set[SymId]
            ) -> set[SymId] { return self._transfer(fr, pred, succ, in_set); },
            fr.tracked
        );
    }
}

impl FlowCheckPass._encloses(outer: UniNode, nd: UniNode) -> bool {
    cur: (UniNode | None) = nd;
    while cur is not None {
        if cur is outer {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl FlowCheckPass._read_state(fr: FrameFlow, nd: UniCFGNode) -> set[SymId] {
    state = set(fr.state.get(id(nd), fr.tracked));
    cur = nd.parent;
    while cur is not None and cur is not fr.owner {
        if isinstance(cur, FinallyStmt) and isinstance(cur.parent, TryStmt) {
            at_try = fr.state.get(id(cur.parent), fr.tracked);
            within = fr.finally_state.get(id(cur), {}).get(id(nd), fr.tracked);
            state = state & (at_try | within);
        }
        cur = cur.parent;
    }
    return state;
}

impl FlowCheckPass._effect(
    fr: FrameFlow, nd: UniCFGNode, da: set[SymId], check: bool
) -> NodeEffect {
    eff = NodeEffect();
    if nd is fr.start and isinstance(nd, (Ability, ImplDef, Test)) {
        return eff;
    }
    if isinstance(nd, IfStmt) or isinstance(nd, WhileStmt) {
        (t, f) = self._eval(fr, nd.condition, da, check);
        eff.branch = True;
        eff.on_true = t;
        eff.on_false = f;
        eff.true_entry = self._first_flow(fr, nd.body);
    } elif isinstance(nd, IterForStmt) {
        start = self._eval_assignment(fr, nd.iter, da, check);
        (t, f) = self._eval(fr, nd.condition, start, check);
        self._eval_assignment(fr, nd.count_by, t, check);
        eff.always = start;
        eff.branch = True;
        eff.on_true = t;
        eff.on_false = f;
        eff.true_entry = self._first_flow(fr, nd.body);
    } elif isinstance(nd, InForStmt) {
        eff.always = self._eval_all(fr, nd.collection, da, check);
        eff.into_body = self._bind_target(fr, nd.target, eff.always, check);
        eff.body_entry = self._first_flow(fr, nd.body);
    } elif isinstance(nd, Assignment) {
        eff.always = self._eval_assignment(fr, nd, da, check);
    } elif isinstance(nd, Except) {
        cur = self._eval_all(fr, nd.ex_type, da, check) if nd.ex_type else set(da);
        if nd.name is not None {
            cur = self._bind_target(fr, nd.name, cur, check);
        }
        eff.always = cur;
    } elif isinstance(nd, WithStmt) {
        cur = set(da);
        for item in nd.exprs {
            cur = self._eval_all(fr, item.expr, cur, check);
            if item.alias is not None {
                cur = self._bind_target(fr, item.alias, cur, check);
            }
        }
        eff.always = cur;
    } elif isinstance(nd, (MatchStmt, SwitchStmt)) {
        eff.always = self._eval_all(fr, nd.target, da, check);
    } elif isinstance(nd, MatchCase) {
        cur = self._eval_pattern(fr, nd.pattern, da, check);
        if nd.guard is not None {
            (t, _) = self._eval(fr, nd.guard, cur, check);
            cur = t;
        }
        eff.always = cur;
    } elif isinstance(nd, SwitchCase) {
        eff.always = self._eval_pattern(fr, nd.pattern, da, check)
            if nd.pattern is not None
            else set(da);
    } elif isinstance(nd, Import) {
        bound = set(da);
        for nm in nd.get_all_sub_nodes(Name) {
            sid = self._sym_of(fr, nm);
            if sid is not None {
                bound.add(sid);
            }
        }
        eff.always = bound;
    } elif isinstance(nd, DeleteStmt) {
        cur = set(da);
        for target in nd.targets {
            sid = self._sym_of(fr, target) if isinstance(target, NameAtom) else None;
            if sid is not None {
                self._read(fr, target, cur, check);
                eff.kills.add(sid);
            } else {
                cur = self._eval_all(fr, target, cur, check);
            }
        }
        eff.always = cur;
    } elif isinstance(
        nd, (TryStmt, FinallyStmt, ForeverStmt, AwaitingClause, CtrlStmt, Semi)
    ) {
        eff.always = set(da);
    } else {
        eff.always = self._eval_kids(fr, nd, da, check);
    }
    return eff;
}

impl FlowCheckPass._first_flow(
    fr: FrameFlow, body: Sequence[UniNode]
) -> (UniCFGNode | None) {
    for stmt in body {
        if isinstance(stmt, UniCFGNode) and id(stmt) in fr.members {
            return stmt;
        }
    }
    return None;
}

impl FlowCheckPass._eval(
    fr: FrameFlow, nd: UniNode, da: set[SymId], check: bool
) -> tuple[set[SymId], set[SymId]] {
    if isinstance(nd, NameAtom) {
        sid = self._sym_of(fr, nd);
        if sid is not None {
            if nd.expr_ctx == ExprCtx.LOAD and not any(d is nd for d in nd.sym.defn) {
                if not is_identifier_slot(nd) {
                    self._read(fr, nd, da, check);
                }
            } elif nd.expr_ctx != ExprCtx.DEL {
                bound = da | {sid};
                return (bound, bound);
            }
        }
        return (da, da);
    }
    if isinstance(nd, Token) {
        return (da, da);
    }
    if isinstance(
        nd, (LambdaExpr, Ability, Archetype, Enum, ImplDef, Test, FuncSignature, SubTag)
    ) {
        return (da, da);
    }
    if isinstance(nd, CfgExpr) {
        return self._eval(fr, nd.expr, da, check);
    }
    if isinstance(nd, AtomUnit) {
        return self._eval(fr, nd.value, da, check);
    }
    if isinstance(nd, BoolExpr) and len(nd.values) >= 2 {
        return self._eval_bool(fr, nd, da, check);
    }
    if isinstance(nd, UnaryExpr) and nd.op.name == Tok.NOT {
        (t, f) = self._eval(fr, nd.operand, da, check);
        return (f, t);
    }
    if isinstance(nd, BinaryExpr)
        and isinstance(nd.op, Token)
        and nd.op.name == Tok.WALRUS_EQ {
        bound = self._bind_target(
            fr, nd.left, self._eval_all(fr, nd.right, da, check), check
        );
        return (bound, bound);
    }
    if isinstance(nd, IfElseExpr) {
        (ct, cf) = self._eval(fr, nd.condition, da, check);
        (vt, vf) = self._eval(fr, nd.value, ct, check);
        (et, ef) = self._eval(fr, nd.else_value, cf, check);
        return (vt & et, vf & ef);
    }
    if isinstance(nd, ListCompr) {
        done = self._eval_compr(fr, nd.out_expr, nd.compr, da, check);
        return (done, done);
    }
    if isinstance(nd, DictCompr) {
        done = self._eval_compr(fr, nd.kv_pair, nd.compr, da, check);
        return (done, done);
    }
    if isinstance(nd, Assignment) {
        done = self._eval_assignment(fr, nd, da, check);
        return (done, done);
    }
    done = self._eval_kids(fr, nd, da, check);
    return (done, done);
}

impl FlowCheckPass._eval_all(
    fr: FrameFlow, nd: UniNode, da: set[SymId], check: bool
) -> set[SymId] {
    (t, f) = self._eval(fr, nd, da, check);
    return t & f;
}

impl FlowCheckPass._eval_kids(
    fr: FrameFlow, nd: UniNode, da: set[SymId], check: bool
) -> set[SymId] {
    cur = set(da);
    for kid in [nd->:Kid:->] {
        if isinstance(kid, (CodeBlockStmt, ElseStmt, Except, FinallyStmt, MatchCase)) {
            continue;
        }
        cur = self._eval_all(fr, kid, cur, check);
    }
    return cur;
}

impl FlowCheckPass._eval_bool(
    fr: FrameFlow, nd: BoolExpr, da: set[SymId], check: bool
) -> tuple[set[SymId], set[SymId]] {
    cur = set(da);
    other: (set[SymId] | None) = None;
    is_and = _bool_is_and(nd);
    for value in nd.values {
        (t, f) = self._eval(fr, value, cur, check);
        if is_and {
            other = f if other is None else other & f;
            cur = t;
        } else {
            other = t if other is None else other & t;
            cur = f;
        }
    }
    settled = other if other is not None else cur;
    return (cur, settled) if is_and else (settled, cur);
}

impl FlowCheckPass._eval_compr(
    fr: FrameFlow, nd: UniNode, comprs: list[InnerCompr], da: set[SymId], check: bool
) -> set[SymId] {
    if not comprs {
        return self._eval_all(fr, nd, da, check);
    }
    done = self._eval_all(fr, comprs[0].collection, da, check);
    for compr in comprs {
        if compr is not comprs[0] {
            self._eval_all(fr, compr.collection, done, check);
        }
        for cond in (compr.conditional or []) {
            self._eval_all(fr, cond, done, check);
        }
    }
    self._eval_all(fr, nd, done, check);
    return done;
}

impl FlowCheckPass._bind_target(
    fr: FrameFlow, target: UniNode, da: set[SymId], check: bool
) -> set[SymId] {
    if isinstance(target, NameAtom) {
        sid = self._sym_of(fr, target);
        return da | {sid} if sid is not None else set(da);
    }
    if isinstance(target, (TupleVal, ListVal)) {
        cur = set(da);
        for value in target.values {
            cur = self._bind_target(fr, value, cur, check);
        }
        return cur;
    }
    if isinstance(target, UnaryExpr) {
        return self._bind_target(fr, target.operand, da, check);
    }
    if isinstance(target, AtomUnit) {
        return self._bind_target(fr, target.value, da, check);
    }
    return self._eval_all(fr, target, da, check);
}

impl FlowCheckPass._eval_pattern(
    fr: FrameFlow, pat: UniNode, da: set[SymId], check: bool
) -> set[SymId] {
    if isinstance(pat, (MatchAs, MatchStar)) {
        cur = set(da);
        if isinstance(pat, MatchAs) and pat.pattern is not None {
            cur = self._eval_pattern(fr, pat.pattern, cur, check);
        }
        return self._bind_target(fr, pat.name, cur, check)
            if pat.name is not None
            else cur;
    }
    if isinstance(pat, MatchValue) {
        return self._eval_all(fr, pat.value, da, check);
    }
    if isinstance(pat, MatchOr) {
        joined: (set[SymId] | None) = None;
        for alt in pat.patterns {
            got = self._eval_pattern(fr, alt, da, check);
            joined = got if joined is None else joined & got;
        }
        return joined if joined is not None else set(da);
    }
    if isinstance(pat, MatchArch) {
        cur = self._eval_all(fr, pat.name, da, check);
        for arg in (pat.arg_patterns or []) {
            cur = self._eval_pattern(fr, arg, cur, check);
        }
        for kw in (pat.kw_patterns or []) {
            cur = self._eval_pattern(fr, kw.value, cur, check);
        }
        return cur;
    }
    if isinstance(pat, MatchKVPair) {
        cur = set(da);
        if not isinstance(pat.key, NameAtom) {
            cur = self._eval_pattern(fr, pat.key, cur, check);
        }
        return self._eval_pattern(fr, pat.value, cur, check);
    }
    if isinstance(pat, (MatchSequence, MatchMapping)) {
        cur = set(da);
        for value in pat.values {
            cur = self._eval_pattern(fr, value, cur, check);
        }
        return cur;
    }
    if isinstance(pat, MatchPattern) {
        return set(da);
    }
    return self._eval_all(fr, pat, da, check);
}

impl FlowCheckPass._eval_assignment(
    fr: FrameFlow, nd: Assignment, da: set[SymId], check: bool
) -> set[SymId] {
    if nd.aug_op is not None {
        for target in nd.target {
            if isinstance(target, NameAtom) {
                sid = self._sym_of(fr, target);
                if sid is not None {
                    self._read(fr, target, da, check);
                }
            } else {
                self._eval_all(fr, target, da, check);
            }
        }
        cur = self._eval_all(fr, nd.value, da, check)
            if nd.value is not None
            else set(da);
        for target in nd.target {
            cur = self._bind_target(fr, target, cur, False)
                if isinstance(target, NameAtom)
                else cur;
        }
        return cur;
    }
    if nd.value is None {
        return set(da);
    }
    cur = self._eval_all(fr, nd.value, da, check);
    for target in nd.target {
        cur = self._bind_target(fr, target, cur, check);
    }
    return cur;
}

impl FlowCheckPass._sym_of(fr: FrameFlow, nd: UniNode) -> (SymId | None) {
    if not isinstance(nd, NameAtom) or nd.sym is None {
        return None;
    }
    sid = id(nd.sym);
    return sid if sid in fr.tracked else None;
}

impl FlowCheckPass._read(
    fr: FrameFlow, nm: NameAtom, da: set[SymId], check: bool
) -> None {
    if not check {
        return;
    }
    sid = self._sym_of(fr, nm);
    if sid is None or sid in da {
        return;
    }
    self.ctx.emit(E1006, node_override=nm, name=nm.sym_name);
}
