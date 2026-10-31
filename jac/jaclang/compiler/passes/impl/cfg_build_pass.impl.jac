impl CFGBuildPass.link_bbs(source: UniCFGNode, target: UniCFGNode) -> None {
    if source and target and self._is_exit_target(source, target) {
        source.cfg_exit_to(target);
        return;
    }
    if source and target {
        source.cfg_link(target);
        new_symbols = source.affected_symbols - target.affected_symbols;
        target.affected_symbols.update(source.affected_symbols);

        if new_symbols {
            visited: set[int] = {id(target)};
            queue: list[UniCFGNode] = list(target.bb_out);
            while queue {
                child = queue.pop(0);
                child_id = id(child);
                if child_id in visited {
                    continue;
                }
                visited.add(child_id);
                if not new_symbols.issubset(child.affected_symbols) {
                    child.affected_symbols.update(new_symbols);
                    queue.extend(child.bb_out);
                }
            }
        }
    }
}

impl CFGBuildPass._is_exit_target(source: UniCFGNode, target: UniCFGNode) -> bool {
    if not isinstance(target, (Ability, ImplDef, Test)) {
        return False;
    }
    cur: (UniNode | None) = source;
    while cur is not None {
        if cur is target {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl CFGBuildPass._link_to(source: UniCFGNode, target: (UniCFGNode | None)) -> None {
    if target is not None and not any(o is target for o in source.bb_out) {
        self.link_bbs(source, target);
    }
}

impl CFGBuildPass._is_terminal(nd: UniNode) -> bool {
    return isinstance(nd, (ReturnStmt, RaiseStmt, CtrlStmt, DisengageStmt));
}

impl CFGBuildPass._stmt_body(parent: UniNode) -> (Sequence[UniNode] | None) {
    if isinstance(
        parent,
        (
            IfStmt,
            ElseStmt,
            WhileStmt,
            ForeverStmt,
            InForStmt,
            IterForStmt,
            TryStmt,
            Except,
            FinallyStmt,
            AwaitingClause,
            WithStmt,
            TypedCtxBlock,
            OpenStmt,
            MatchCase,
            SwitchCase,
            ModuleCode,
            Test
        )
    ) {
        return parent.body;
    }
    if isinstance(parent, (Ability, ImplDef, LambdaExpr, JsxSlot))
        and isinstance(parent.body, Sequence) {
        return cast(Sequence[UniNode], parent.body);
    }
    return None;
}

impl CFGBuildPass._is_flow_frame(nd: UniNode) -> bool {
    return isinstance(
        nd,
        (
            Ability,
            ImplDef,
            LambdaExpr,
            Test,
            ModuleCode,
            JsxSlot,
            Archetype,
            Enum,
            Module
        )
    );
}

impl CFGBuildPass._in_stmt_body(nd: UniNode) -> bool {
    parent = nd.parent;
    if parent is None {
        return False;
    }
    body = self._stmt_body(parent);
    return body is not None and any(s is nd for s in body);
}

impl CFGBuildPass._next_in_body(
    body: Sequence[UniNode], child: UniNode
) -> (UniCFGNode | None) {
    found = False;
    for stmt in body {
        if found and isinstance(stmt, UniCFGNode) {
            return stmt;
        }
        if stmt is child {
            found = True;
        }
    }
    return None;
}

impl CFGBuildPass._body_entry(
    body: Sequence[UniNode], fallback: (UniCFGNode | None)
) -> (UniCFGNode | None) {
    for stmt in body {
        if isinstance(stmt, UniCFGNode) {
            return stmt;
        }
    }
    return fallback;
}

impl CFGBuildPass._follow(nd: UniNode) -> (UniCFGNode | None) {
    child: UniNode = nd;
    parent = nd.parent;
    while parent is not None {
        body = self._stmt_body(parent);
        if body is not None and any(s is child for s in body) {
            nxt = self._next_in_body(body, child);
            if nxt is not None {
                return nxt;
            }
            if isinstance(parent, (WhileStmt, ForeverStmt, InForStmt, IterForStmt)) {
                return parent;
            }
            if isinstance(parent, TryStmt) {
                else_entry = self._else_entry(parent);
                if else_entry is not None {
                    return else_entry;
                }
                if parent.finally_body is not None {
                    return parent.finally_body;
                }
            } elif isinstance(parent, (Except, AwaitingClause))
                or (
                    isinstance(parent, ElseStmt) and isinstance(parent.parent, TryStmt)
                ) {
                owner = parent.parent;
                if isinstance(owner, TryStmt) and owner.finally_body is not None {
                    return owner.finally_body;
                }
                child = owner;
                parent = owner.parent;
                continue;
            } elif isinstance(parent, FinallyStmt) {
                child = parent.parent;
                parent = child.parent;
                continue;
            } elif isinstance(parent, SwitchCase) {
                owner = parent.parent;
                if isinstance(owner, SwitchStmt) {
                    later = False;
                    for sc in owner.cases {
                        if later {
                            fallthrough = self._body_entry(sc.body, None);
                            if fallthrough is not None {
                                return fallthrough;
                            }
                        }
                        if sc is parent {
                            later = True;
                        }
                    }
                }
                child = owner;
                parent = owner.parent;
                continue;
            } elif isinstance(parent, MatchCase) {
                child = parent.parent;
                parent = child.parent;
                continue;
            } elif self._is_flow_frame(parent) {
                return parent if isinstance(parent, (Ability, ImplDef, Test)) else None;
            }
        } elif self._is_flow_frame(parent) {
            return None;
        }
        child = parent;
        parent = parent.parent;
    }
    return None;
}

impl CFGBuildPass._else_entry(nd: UniNode) -> (UniCFGNode | None) {
    if not isinstance(nd, AstElseBodyNode) {
        return None;
    }
    eb = nd.else_body;
    if isinstance(eb, ElseIf) {
        return eb;
    }
    if isinstance(eb, ElseStmt) {
        return self._body_entry(eb.body, None);
    }
    return None;
}

impl CFGBuildPass._break_target(nd: CtrlStmt) -> (UniCFGNode | None) {
    cur = nd.parent;
    while cur is not None and not self._is_flow_frame(cur) {
        if isinstance(cur, SwitchStmt) {
            return self._follow(cur);
        }
        if isinstance(cur, (InForStmt, IterForStmt, WhileStmt, ForeverStmt))
            and not in_loop_else(nd, cur) {
            return self._follow(cur);
        }
        cur = cur.parent;
    }
    return None;
}

impl CFGBuildPass._is_compound(nd: UniNode) -> bool {
    return isinstance(
        nd,
        (
            IfStmt,
            WhileStmt,
            ForeverStmt,
            InForStmt,
            IterForStmt,
            TryStmt,
            WithStmt,
            TypedCtxBlock,
            OpenStmt,
            MatchStmt,
            SwitchStmt,
            VisitStmt
        )
    );
}

impl CFGBuildPass._is_irrefutable_case(nd: MatchCase) -> bool {
    return nd.guard is None and is_irrefutable_pattern(nd.pattern);
}

impl CFGBuildPass._wire_branch(
    nd: UniCFGNode,
    condition: Expr,
    true_target: (UniCFGNode | None),
    false_target: (UniCFGNode | None)
) -> None {
    unwrapped = _unwrap_parens(condition);
    if isinstance(unwrapped, BoolExpr) and len(unwrapped.values) >= 2 {
        `entry = self._wire_bool_operands(
            unwrapped.values, _bool_is_and(unwrapped), true_target, false_target
        );
        self._link_to(nd, `entry);
        return;
    }
    self._link_to(nd, true_target);
    self._link_to(nd, false_target);
}

impl CFGBuildPass.exit_simple_stmt with UniCFGNode exit {
    if self._is_compound(here) or self._is_terminal(here) {
        return;
    }
    if isinstance(here, (Except, FinallyStmt, AwaitingClause, MatchCase, SwitchCase)) {
        return;
    }
    if not self._in_stmt_body(here) {
        return;
    }
    self._link_to(here, self._follow(here));
}

impl CFGBuildPass.exit_if_stmt with IfStmt exit {
    after = self._follow(here);
    true_target = self._body_entry(here.body, after);
    false_target = self._else_entry(here);
    if false_target is None {
        false_target = after;
    }
    self._wire_branch(here, here.condition, true_target, false_target);
}

impl CFGBuildPass.exit_while_stmt with WhileStmt exit {
    true_target = self._body_entry(here.body, here);
    false_target: (UniCFGNode | None) = None;
    if not is_constant_true(here.condition) {
        false_target = self._else_entry(here);
        if false_target is None {
            false_target = self._follow(here);
        }
    }
    self._wire_branch(here, here.condition, true_target, false_target);
}

impl CFGBuildPass.exit_forever_stmt with ForeverStmt exit {
    self._link_to(here, self._body_entry(here.body, here));
}

impl CFGBuildPass.exit_in_for_stmt with InForStmt exit {
    self._link_to(here, self._body_entry(here.body, here));
    exhausted = self._else_entry(here);
    self._link_to(here, exhausted if exhausted is not None else self._follow(here));
}

impl CFGBuildPass.exit_iter_for_stmt with IterForStmt exit {
    true_target = self._body_entry(here.body, here);
    false_target = self._else_entry(here);
    if false_target is None {
        false_target = self._follow(here);
    }
    self._wire_branch(here, here.condition, true_target, false_target);
}

impl CFGBuildPass.exit_ctrl_stmt with CtrlStmt exit {
    if here.ctrl.name == Tok.KW_CONTINUE {
        loop = enclosing_loop(here);
        if loop is not None {
            self.link_bbs(here, loop);
        }
    } elif here.ctrl.name == Tok.KW_BREAK {
        self._link_to(here, self._break_target(here));
    }
}

impl CFGBuildPass.exit_try_stmt with TryStmt exit {
    self._link_to(here, self._body_entry(here.body, None));
    for exc in here.excepts {
        self.link_bbs(here, exc);
    }
    if here.finally_body is not None {
        self.link_bbs(here, here.finally_body);
    }
}

impl CFGBuildPass.exit_except with Except exit {
    self._link_to(here, self._body_entry(here.body, None));
}

impl CFGBuildPass.exit_finally_stmt with FinallyStmt exit {
    owner = here.parent;
    after = self._follow(owner) if owner is not None else None;
    self._link_to(here, self._body_entry(here.body, after));
}

impl CFGBuildPass.exit_match_stmt with MatchStmt exit {
    exhaustive = False;
    for `case in here.cases {
        self.link_bbs(here, `case);
        if self._is_irrefutable_case(`case) {
            exhaustive = True;
        }
    }
    if not exhaustive {
        self._link_to(here, self._follow(here));
    }
}

impl CFGBuildPass.exit_match_case with MatchCase exit {
    owner = here.parent;
    after = self._follow(owner) if owner is not None else None;
    self._link_to(here, self._body_entry(here.body, after));
}

impl CFGBuildPass.exit_switch_stmt with SwitchStmt exit {
    has_default = False;
    for `case in here.cases {
        self.link_bbs(here, `case);
        if `case.pattern is None {
            has_default = True;
        }
    }
    if not has_default {
        self._link_to(here, self._follow(here));
    }
}

impl CFGBuildPass.exit_switch_case with SwitchCase exit {
    owner = here.parent;
    after = self._follow(owner) if owner is not None else None;
    self._link_to(here, self._body_entry(here.body, after));
}

impl CFGBuildPass.exit_with_stmt with WithStmt exit {
    self._link_to(here, self._body_entry(here.body, self._follow(here)));
}

impl CFGBuildPass.exit_typed_ctx_block with TypedCtxBlock exit {
    self._link_to(here, self._body_entry(here.body, self._follow(here)));
}

impl CFGBuildPass.exit_open_stmt with OpenStmt exit {
    self._link_to(here, self._body_entry(here.body, self._follow(here)));
}

impl CFGBuildPass.exit_visit_stmt with VisitStmt exit {
    after = self._follow(here);
    self._link_to(here, after);
    self._link_to(here, self._else_entry(here));
}

impl CFGBuildPass.exit_jsx_slot with JsxSlot exit {
    if here.body and isinstance(here.body, Sequence) {
        enclosing = here.find_parent_of_type(CodeBlockStmt);
        if enclosing is not None {
            self._link_to(enclosing, self._body_entry(here.body, None));
        }
    }
}

impl CFGBuildPass.exit_lambda_expr with LambdaExpr exit {
    if isinstance(here.body, Sequence) {
        enclosing = here.find_parent_of_type(CodeBlockStmt);
        if enclosing is not None {
            self._link_to(enclosing, self._body_entry(here.body, None));
        }
    }
}

impl CFGBuildPass.exit_ability with Ability exit {
    if isinstance(here.body, Sequence) {
        self._link_to(here, self._body_entry(here.body, here));
    }
}

impl CFGBuildPass.exit_archetype with Archetype exit {
    if here.body and isinstance(here.body, Sequence) {
        for s in here.body {
            if isinstance(s, CodeBlockStmt) {
                self.link_bbs(here, s);
            }
        }
    }
}

impl CFGBuildPass.exit_impl_def with ImplDef exit {
    if isinstance(here.body, Sequence) {
        self._link_to(here, self._body_entry(here.body, here));
    }
}

impl CFGBuildPass.exit_test with Test exit {
    if isinstance(here.body, Sequence) {
        self._link_to(here, self._body_entry(here.body, here));
    }
}

impl is_constant_true(expr: Expr) -> bool {
    inner = _unwrap_parens(expr);
    return isinstance(inner, Bool) and inner.value == "True";
}

impl CFGBuildPass._wire_bool_operands(
    values: list[CfgExpr],
    op_is_and: bool,
    true_target: (UniCFGNode | None),
    false_target: (UniCFGNode | None)
) -> CfgExpr {
    for cfg in values {
        cfg.affected_symbols.update(collect_narrowing_symbols(cfg.expr));
    }
    return self._wire_bool_chain(values, op_is_and, true_target, false_target);
}

impl CFGBuildPass._set_and_link(
    cfg: CfgExpr, true_target: (UniCFGNode | None), false_target: (UniCFGNode | None)
) -> None {
    cfg.sc_true_target = None
        if true_target is None or self._is_exit_target(cfg, true_target)
        else true_target;
    cfg.sc_false_target = None
        if false_target is None or self._is_exit_target(cfg, false_target)
        else false_target;
    if true_target {
        self.link_bbs(cfg, true_target);
    }
    if false_target {
        self.link_bbs(cfg, false_target);
    }
}

impl CFGBuildPass._wire_bool_chain(
    values: list[CfgExpr],
    op_is_and: bool,
    true_target: (UniCFGNode | None),
    false_target: (UniCFGNode | None)
) -> CfgExpr {
    n = len(values);

    entries: list[CfgExpr] = [];
    for cfg in values {
        nested = unwrap_to_bool(cfg);
        entries.append(
            nested.values[0] if (nested and len(nested.values) >= 2) else cfg
        );
    }

    for i in range(n) {
        next_entry = entries[i + 1] if i < n - 1 else None;
        my_true = (next_entry or true_target) if op_is_and else true_target;
        my_false = false_target if op_is_and else (next_entry or false_target);
        cfg = values[i];
        nested = unwrap_to_bool(cfg);
        if nested and len(nested.values) >= 2 {
            self._wire_bool_chain(
                nested.values, _bool_is_and(nested), my_true, my_false
            );
            self.link_bbs(cfg, entries[i]);
        } else {
            self._set_and_link(cfg, my_true, my_false);
        }
    }
    return entries[0];
}

impl CFGBuildPass.exit_bool_expr with BoolExpr exit {
    if isinstance(here.parent, (IfStmt, WhileStmt, ElseIf))
        and here is here.parent.condition {
        return;
    }
    if len(here.values) >= 2 {
        `entry = self._wire_bool_operands(here.values, _bool_is_and(here), None, None);

        enclosing_flow = here.find_parent_of_type(UniCFGNode);
        if enclosing_flow is not None {
            self.link_bbs(enclosing_flow, `entry);
        }
    }
}

impl CFGBuildPass.exit_if_else_expr with IfElseExpr exit {
    here.condition.affected_symbols.update(
        collect_narrowing_symbols(here.condition.expr)
    );

    unwrapped_cond = _unwrap_parens(here.condition.expr);
    if isinstance(unwrapped_cond, BoolExpr) and len(unwrapped_cond.values) >= 2 {
        op_is_and = _bool_is_and(unwrapped_cond);
        `entry = self._wire_bool_operands(
            unwrapped_cond.values, op_is_and, here.value, here.else_value
        );
        if `entry {
            self.link_bbs(here.condition, `entry);
        }
    } else {
        here.condition.sc_true_target = here.value;
        here.condition.sc_false_target = here.else_value;
        self.link_bbs(here.condition, here.value);
        self.link_bbs(here.condition, here.else_value);
    }

    enclosing_flow = here.find_parent_of_type(UniCFGNode);
    if enclosing_flow is not None {
        self.link_bbs(enclosing_flow, here.condition);
    }

    for branch in [here.value, here.else_value] {
        inner = _unwrap_parens(branch.expr);
        if isinstance(inner, IfElseExpr) {
            self.link_bbs(branch, inner.condition);
        } elif isinstance(inner, BoolExpr) and len(inner.values) > 0 {
            self.link_bbs(branch, inner.values[0]);
        }
    }
}

impl CFGBuildPass.exit_list_compr with ListCompr exit {
    if here.__class__ is not ListCompr {
        return;
    }
    self._wire_compr_filters(here, here.compr);
}

impl CFGBuildPass.exit_set_compr with SetCompr exit {
    self._wire_compr_filters(here, here.compr);
}

impl CFGBuildPass.exit_gen_compr with GenCompr exit {
    self._wire_compr_filters(here, here.compr);
}

impl CFGBuildPass.exit_dict_compr with DictCompr exit {
    self._wire_compr_filters(here, here.compr);
}

impl CFGBuildPass._wire_compr_filters(
    target_node: UniCFGNode, comprs: list[InnerCompr]
) -> None {
    if not comprs {
        return;
    }

    encl: UniNode | None = target_node.parent;
    while encl is not None {
        if isinstance(encl, UniCFGNode) and not isinstance(encl, InnerCompr) {
            self.link_bbs(encl, comprs[0]);
            break;
        }
        encl = encl.parent;
    }
    passed: UniCFGNode = comprs[0];
    for compr in comprs {
        if compr is not comprs[0] {
            self._link_on_pass(passed, compr);
        }
        passed = compr;
        for cond in (compr.conditional or []) {
            cfg_pred: CfgExpr;
            if isinstance(cond, CfgExpr) {
                cfg_pred = cond;
            } else {
                cfg_pred = CfgExpr(expr=cond, kid=[cond]);
                compr.replace_kid(cond, cfg_pred);
            }
            cfg_pred.affected_symbols.update(collect_narrowing_symbols(cfg_pred.expr));
            self._link_on_pass(passed, cfg_pred);
            passed = cfg_pred;
        }
    }
    self._link_on_pass(passed, target_node);
}

impl CFGBuildPass._link_on_pass(step: UniCFGNode, nxt: UniCFGNode) -> None {
    if isinstance(step, CfgExpr) {
        self._set_and_link(step, nxt, None);
    } else {
        self.link_bbs(step, nxt);
    }
}

impl is_structural_child(nd: UniNode) -> bool {
    if isinstance(nd.parent, IterForStmt) {
        p: IterForStmt = nd.parent;
        if nd is p.iter or nd is p.count_by {
            return True;
        }
    }
    return False;
}

impl CFGBuildPass.cfg_collect_affected with UniNode entry {
    if isinstance(here, (CodeBlockStmt, Archetype))
        and not isinstance(here, (Semi, ModuleCode, GlobalVars, SemDef, TypeAlias))
        and not is_structural_child(here) {
        here.affected_symbols.update(collect_assigned_symbols(here));
    }
}

impl CFGBuildPass.enter_if_stmt with IfStmt entry {
    if here.__class__ is not IfStmt {
        return;
    }

    here.affected_symbols.update(collect_narrowing_symbols(here.condition));
}

impl CFGBuildPass.enter_else_if with ElseIf entry {
    here.affected_symbols.update(collect_narrowing_symbols(here.condition));
}

impl CFGBuildPass.enter_assert_stmt with AssertStmt entry {
    here.affected_symbols.update(collect_narrowing_symbols(here.condition));
}

impl CFGBuildPass.enter_match_stmt with MatchStmt entry {
    if isinstance(here.target, Name) {
        here.affected_symbols.add(here.target.value);
    }
}


impl _unwrap_parens(expr: Expr) -> Expr {
    while isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
        expr = expr.value;
    }
    return expr;
}

impl unwrap_to_bool(cfg: CfgExpr) -> BoolExpr | None {
    inner = _unwrap_parens(cfg.expr);
    return inner if isinstance(inner, BoolExpr) else None;
}

impl _bool_is_and(expr: BoolExpr) -> bool {
    return isinstance(expr.op, Token) and expr.op.name == Tok.KW_AND;
}

impl is_abrupt_entry(pred: UniCFGNode, succ: UniCFGNode) -> bool {
    return isinstance(pred, TryStmt) and pred.finally_body is succ;
}

impl falls_off_end(
    frame: UniCFGNode, live: Callable[[UniCFGNode, UniCFGNode], bool]
) -> bool {
    exits = frame.cfg_exits;
    if not exits {
        return False;
    }
    exit_ids = {id(e) for e in exits};
    if id(frame) in exit_ids {
        return True;
    }
    seen: set[int] = {id(frame)};
    pending: list[UniCFGNode] = [s for s in frame.bb_out if live(frame, s)];
    while pending {
        nd = pending.pop();
        if id(nd) in seen {
            continue;
        }
        seen.add(id(nd));
        if id(nd) in exit_ids and live(nd, frame) {
            return True;
        }
        for succ in nd.bb_out {
            if not is_abrupt_entry(nd, succ) and live(nd, succ) {
                pending.append(succ);
            }
        }
    }
    return False;
}
