impl cfg_dot_from_file(file_name: str) -> str {
    import from jaclang.jac0core.compiler { run_pass }
    import from jaclang.jac0core.program { JacProgram }
    with open(file_name, encoding="utf-8") as f {
        file_source = f.read();
    }
    ir = (prog := JacProgram()).compile(use_str=file_source, file_path=file_name);
    cfg_pass = run_pass(CoalesceBBPass, ir, prog);
    dot = cfg_pass.printgraph_cfg();
    return dot;
}


impl CoalesceBBPass.printgraph_cfg -> str {
    bb_tails: dict[int, (UniCFGNode | None)] = {};
    bb_heads: dict[int, (UniCFGNode | None)] = {};
    cfg_outs: dict[int, list[int]] = {};
    cfg_labels: dict[int, list[str]] = {};
    for (key, bb) in self.basic_blocks.items() {
        stmts = bb['bb_stmts'];
        bb_tails[key] = stmts[-1] if stmts else None;
        bb_heads[key] = stmts[0] if stmts else None;
    }
    dot = 'digraph G {\n';
    for (key, bb) in self.basic_blocks.items() {
        bb_out = bb['bb_out'];
        cfg_labels[key] = [self._node_label(s) for s in bb['bb_stmts']];
        if bb_out {
            out_ids: list[int] = [];
            for out_obj in bb_out {
                for (k, v) in self.basic_blocks.items() {
                    if (out_obj == v['bb_stmts'][0]) {
                        out_ids.append(k);
                        break;
                    }
                }
            }
            cfg_outs[key] = out_ids;
        }
    }
    for (key, labels) in cfg_labels.items() {
        if labels {
            stmts_str = '\\n'.join(
                [
                    stmt.replace('"', '\\"')
                    for stmt in labels
                    if stmt
                ]
            );
            dot += f'  {key} [label="BB{key}\\n{stmts_str}", shape=box];' + "\n";
        } else {
            dot += f'  {key} [label="BB{key}"];' + "\n";
        }
    }
    for (key, outs) in cfg_outs.items() {
        if outs {
            tail = bb_tails[key];
            for out_id in outs {
                label = "";
                if isinstance(tail, CfgExpr) {
                    out_head = bb_heads[out_id];
                    if tail.sc_true_target is out_head {
                        label = ' [label="T"]';
                    } elif tail.sc_false_target is out_head {
                        label = ' [label="F"]';
                    }
                } elif isinstance(tail, (IfStmt, WhileStmt)) {
                    out_head = bb_heads[out_id];
                    if tail.body and out_head is tail.body[0] {
                        label = ' [label="T"]';
                    } elif tail.else_body {
                        eb = tail.else_body;
                        if isinstance(eb, ElseIf) and out_head is eb {
                            label = ' [label="F"]';
                        } elif isinstance(eb, ElseStmt)
                            and eb.body
                            and out_head is eb.body[0] {
                            label = ' [label="F"]';
                        }
                    }
                }
                dot += f"  {key} -> {out_id}{label};\n";
            }
        }
    }
    dot += '}\n';
    return dot;
}

impl CoalesceBBPass._has_bool_sc(condition: Expr) -> bool {
    return isinstance(condition, BoolExpr);
}

impl CoalesceBBPass._node_label(nd: UniNode) -> str {
    import from jaclang.jac0core.constant { Tokens as Tok }
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }

    if isinstance(nd, ElseIf) {
        return 'elif'
            if self._has_bool_sc(nd.condition)
            else 'elif ' + unparse_node(nd.condition);
    }
    if isinstance(nd, IfStmt) {
        return 'if'
            if self._has_bool_sc(nd.condition)
            else 'if ' + unparse_node(nd.condition);
    }
    if isinstance(nd, ElseStmt) {
        return 'else';
    }

    if isinstance(nd, WhileStmt) {
        return 'while'
            if self._has_bool_sc(nd.condition)
            else 'while ' + unparse_node(nd.condition);
    }
    if isinstance(nd, ForeverStmt) {
        return 'forever';
    }
    if isinstance(nd, InForStmt) {
        return 'for ' + unparse_node(nd.target) + ' in ' + unparse_node(nd.collection);
    }
    if isinstance(nd, IterForStmt) {
        return 'for '
            + unparse_node(nd.iter)
            + unparse_node(nd.condition)
            + unparse_node(nd.count_by);
    }

    if isinstance(nd, MatchStmt) {
        return 'match ' + unparse_node(nd.target);
    }
    if isinstance(nd, MatchCase) {
        return 'case ' + unparse_node(nd.pattern) if nd.pattern else 'case';
    }
    if isinstance(nd, SwitchStmt) {
        return 'switch ' + unparse_node(nd.target);
    }
    if isinstance(nd, SwitchCase) {
        return 'case ' + unparse_node(nd.pattern) if nd.pattern else 'default';
    }

    if isinstance(nd, TryStmt) {
        return 'try';
    }
    if isinstance(nd, Except) {
        return 'except ' + unparse_node(nd.ex_type) if nd.ex_type else 'except';
    }
    if isinstance(nd, FinallyStmt) {
        return 'finally';
    }

    if isinstance(nd, WithStmt) {
        label = 'with ';
        for (idx, e) in enumerate(nd.exprs) {
            if idx > 0 {
                label += ', ';
            }
            label += str(unparse_node(e));
        }
        return label;
    }

    if isinstance(nd, Archetype) {
        return 'obj ' + unparse_node(nd.name);
    }
    if isinstance(nd, Ability) {
        kw: str = 'can';
        for c in nd.kid {
            if isinstance(c, Token) {
                if c.name == Tok.KW_DEF or c.name == Tok.KW_CAN {
                    kw = str(c.value);
                    break;
                }
            }
        }
        if nd.name_ref and nd.signature {
            return kw + ' ' + unparse_node(nd.name_ref) + unparse_node(nd.signature);
        } elif nd.name_ref {
            return kw + ' ' + unparse_node(nd.name_ref);
        }
        return kw;
    }

    if isinstance(nd, ReturnStmt) {
        if nd.expr and isinstance(nd.expr, IfElseExpr) {
            return "";
        }
        return unparse_node(nd);
    }

    if isinstance(nd, CfgExpr) {
        par = nd.parent;
        if (
            isinstance(par, IfElseExpr)
            and (nd is par.value or nd is par.else_value)
            and isinstance(par.parent, ReturnStmt)
        ) {
            return "return " + unparse_node(nd);
        }
    }
    return unparse_node(nd);
}

impl CoalesceBBPass.enter_node(nd: UniNode) -> None {
    is_cfg_node = (
        isinstance(nd, (CodeBlockStmt, Archetype))
        and not isinstance(nd, (Semi, ModuleCode, GlobalVars, SemDef, TypeAlias))
        and not _is_structural_child(nd)
    );

    if isinstance(nd, CfgExpr) {
        cfg_nd: CfgExpr = nd;
        if (cfg_nd.bb_in or cfg_nd.bb_out) and _unwrap_to_bool(cfg_nd) is None {
            is_cfg_node = True;
        }
    }
    if is_cfg_node and isinstance(nd, UniCFGNode) {
        for bbs in self.basic_blocks.values() {
            if (nd in bbs['bb_stmts']) {
                return;
            }
        }
        tail = nd.get_tail();
        bb = self.get_bb(nd);
        self.basic_blocks[self.bb_counter] = {'bb_stmts': bb, 'bb_out': tail.bb_out};
        self.bb_counter += 1;
    }
}

impl CoalesceBBPass.get_bb(nd: UniCFGNode) -> list[UniCFGNode] {
    head = nd.get_head();
    tail = nd.get_tail();
    bb_list: list[UniCFGNode] = [];
    if (head and tail) {
        cur_node = head;
        while (cur_node != tail) {
            if (cur_node not in bb_list) {
                bb_list.append(cur_node);
            }

            if cur_node.bb_out {
                cur_node = cur_node.bb_out[0];
            }
        }
        bb_list.append(tail) if (tail not in bb_list) else None;
    }
    return bb_list;
}

impl CoalesceBBPass.before_pass -> None {
    self.basic_blocks = {};
    self.bb_counter = 0;
}

impl CFGBuildPass.before_pass -> None { }

impl CFGBuildPass.link_bbs(source: UniCFGNode, target: UniCFGNode) -> None {
    if source and target {
        if target not in source.bb_out {
            source.bb_out.append(target);
        }
        if source not in target.bb_in {
            target.bb_in.append(source);
        }
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

impl CFGBuildPass._link_sequential(body: Sequence[CodeBlockStmt]) -> None {
    for i in range(1, len(body)) {
        prev = body[i - 1];
        next = body[i];
        if self._is_terminal(prev) {
            continue;
        }
        has_else = isinstance(prev, AstElseBodyNode) and prev.else_body is not None;

        has_bool_sc = False;
        if isinstance(prev, (IfStmt, ElseIf, WhileStmt)) {
            has_bool_sc = isinstance(_unwrap_parens(prev.condition), BoolExpr);
        }
        if has_else and isinstance(prev, (IfStmt, WhileStmt, InForStmt, IterForStmt)) {
            self._connect_tails(prev, next);
            if isinstance(prev, IfStmt) {
                empty_true = not prev.body;
                eb = prev.else_body;
                empty_else = isinstance(eb, ElseStmt) and not eb.body;
                if empty_true or empty_else {
                    self.link_bbs(prev, next);
                }
            }
        } elif has_bool_sc {
            self._connect_tails(prev, next);
        } else {
            self.link_bbs(prev, next);
            self._connect_tails(prev, next);
        }
    }
}

impl CFGBuildPass._exit_wired(nd: UniCFGNode) -> bool {
    if isinstance(nd, IfStmt) {
        return bool(nd.bb_out);
    }
    for succ in nd.bb_out {
        if not isinstance(succ, CfgExpr)
            or succ.find_parent_of_type(UniCFGNode) is not nd {
            return True;
        }
    }
    return False;
}

impl CFGBuildPass._connect_tails(parent: UniNode, target: UniCFGNode) -> None {
    for k in parent.kid {
        if not k or isinstance(k, Expr) or isinstance(k, Semi) {
            continue;
        }

        if isinstance(parent, IterForStmt) {
            if k is parent.iter or k is parent.count_by {
                continue;
            }
        }
        if isinstance(k, (Ability, Archetype, ImplDef, Test)) {
            continue;
        }
        if isinstance(k, (WhileStmt, ForeverStmt, InForStmt, IterForStmt)) {
            body_entry = k.body[0] if k.body else None;
            exit_wired = any([o is not body_entry for o in k.bb_out]);
            if not exit_wired
                and not self._is_terminal(k)
                and not isinstance(k, ForeverStmt) {
                self.link_bbs(k, target);
            }
            continue;
        }
        if isinstance(k, UniCFGNode) {
            if not self._exit_wired(k) and not self._is_terminal(k) {
                self.link_bbs(k, target);
            } elif isinstance(k, IfStmt) and not k.else_body {
                first_body = k.body[0] if k.body else None;
                has_false_branch = any(o is not first_body for o in k.bb_out);
                if not has_false_branch {
                    self.link_bbs(k, target);
                }
                self._connect_tails(k, target);
            } else {
                self._connect_tails(k, target);
            }
        } else {
            self._connect_tails(k, target);
        }
    }
}

def _unwrap_parens(expr: Expr) -> Expr {
    while isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
        expr = expr.value;
    }
    return expr;
}

def _unwrap_to_bool(cfg: CfgExpr) -> BoolExpr | None {
    inner = _unwrap_parens(cfg.expr);
    return inner if isinstance(inner, BoolExpr) else None;
}

def _bool_is_and(expr: BoolExpr) -> bool {
    import from jaclang.jac0core.constant { Tokens as Tok }
    return isinstance(expr.op, Token) and expr.op.name == Tok.KW_AND;
}

impl CFGBuildPass._wire_bool_operands(
    values: list[CfgExpr],
    op_is_and: bool,
    true_target: (UniCFGNode | None),
    false_target: (UniCFGNode | None)
) -> CfgExpr {
    import from jaclang.compiler.expr_keys { collect_narrowing_symbols }
    for cfg in values {
        cfg.affected_symbols.update(collect_narrowing_symbols(cfg.expr));
    }
    return self._wire_bool_chain(values, op_is_and, true_target, false_target);
}

impl CFGBuildPass._set_and_link(
    cfg: CfgExpr, true_target: (UniCFGNode | None), false_target: (UniCFGNode | None)
) -> None {
    cfg.sc_true_target = true_target;
    cfg.sc_false_target = false_target;
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
        nested = _unwrap_to_bool(cfg);
        entries.append(
            nested.values[0] if (nested and len(nested.values) >= 2) else cfg
        );
    }

    for i in range(n) {
        next_entry = entries[i + 1] if i < n - 1 else None;
        my_true = (next_entry or true_target) if op_is_and else true_target;
        my_false = false_target if op_is_and else (next_entry or false_target);
        cfg = values[i];
        nested = _unwrap_to_bool(cfg);
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

impl CFGBuildPass.exit_bool_expr(nd: BoolExpr) -> None {
    if isinstance(nd.parent, (IfStmt, WhileStmt, ElseIf))
        and nd is nd.parent.condition {
        return;
    }
    if len(nd.values) >= 2 {
        `entry = self._wire_bool_operands(nd.values, _bool_is_and(nd), None, None);

        enclosing_flow = nd.find_parent_of_type(UniCFGNode);
        if enclosing_flow is not None {
            self.link_bbs(enclosing_flow, `entry);
        }
    }
}

impl CFGBuildPass.exit_if_else_expr(nd: IfElseExpr) -> None {
    import from jaclang.compiler.expr_keys { collect_narrowing_symbols }
    nd.condition.affected_symbols.update(collect_narrowing_symbols(nd.condition.expr));

    unwrapped_cond = _unwrap_parens(nd.condition.expr);
    if isinstance(unwrapped_cond, BoolExpr) and len(unwrapped_cond.values) >= 2 {
        op_is_and = _bool_is_and(unwrapped_cond);
        `entry = self._wire_bool_operands(
            unwrapped_cond.values, op_is_and, nd.value, nd.else_value
        );
        if `entry {
            self.link_bbs(nd.condition, `entry);
        }
    } else {
        nd.condition.sc_true_target = nd.value;
        nd.condition.sc_false_target = nd.else_value;
        self.link_bbs(nd.condition, nd.value);
        self.link_bbs(nd.condition, nd.else_value);
    }

    enclosing_flow = nd.find_parent_of_type(UniCFGNode);
    if enclosing_flow is not None {
        self.link_bbs(enclosing_flow, nd.condition);
    }

    for branch in [nd.value, nd.else_value] {
        inner = _unwrap_parens(branch.expr);
        if isinstance(inner, IfElseExpr) {
            self.link_bbs(branch, inner.condition);
        } elif isinstance(inner, BoolExpr) and len(inner.values) > 0 {
            self.link_bbs(branch, inner.values[0]);
        }
    }
}

impl CFGBuildPass._is_terminal(nd: UniNode) -> bool {
    return isinstance(nd, (ReturnStmt, RaiseStmt, CtrlStmt, DisengageStmt));
}

impl CFGBuildPass._find_parent_of_types(
    nd: UniNode, types: tuple[type[UniCFGNode], ...]
) -> (UniCFGNode | None) {
    cur = nd.parent;
    while cur {
        if isinstance(cur, types) {
            return cast(UniCFGNode, cur);
        }
        cur = cur?.parent;
    }
    return None;
}

impl CFGBuildPass._next_in_body(
    body: Sequence[CodeBlockStmt], child: UniNode
) -> (UniCFGNode | None) {
    found = False;
    for stmt in body {
        if found and isinstance(stmt, CodeBlockStmt) {
            return stmt;
        }
        if stmt is child {
            found = True;
        }
    }
    return None;
}

impl CFGBuildPass._find_next_cfg_stmt_after(
    parent: UniNode, child: UniNode
) -> (UniCFGNode | None) {
    if isinstance(parent, IfStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, ElseStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, TryStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, Except) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, FinallyStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, InForStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, IterForStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, WhileStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, ForeverStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, WithStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, MatchCase) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, SwitchCase) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, ModuleCode) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, Test) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, TypedCtxBlock) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, OpenStmt) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, AwaitingClause) {
        return self._next_in_body(parent.body, child);
    }
    if isinstance(parent, Ability) and isinstance(parent.body, list) {
        return self._next_in_body(cast(Sequence[CodeBlockStmt], parent.body), child);
    }
    if isinstance(parent, ImplDef) and isinstance(parent.body, list) {
        return self._next_in_body(cast(Sequence[CodeBlockStmt], parent.body), child);
    }
    if isinstance(parent, LambdaExpr) and isinstance(parent.body, list) {
        return self._next_in_body(cast(Sequence[CodeBlockStmt], parent.body), child);
    }
    return None;
}

impl CFGBuildPass._find_next_cfg_stmt_after_branch(nd: UniNode) -> (UniCFGNode | None) {
    cur: UniNode = nd;
    while cur.parent is not None {
        if (nxt := self._find_next_cfg_stmt_after(cur.parent, cur)) is not None {
            return nxt;
        }
        if not isinstance(cur.parent, (IfStmt, ElseStmt)) {
            return None;
        }
        cur = cur.parent;
    }
    return None;
}

impl _is_structural_child(nd: UniNode) -> bool {
    if isinstance(nd.parent, IterForStmt) {
        p: IterForStmt = nd.parent;
        if nd is p.iter or nd is p.count_by {
            return True;
        }
    }
    return False;
}

impl CFGBuildPass.enter_node(nd: UniNode) -> None {
    import from jaclang.compiler.expr_keys { collect_assigned_symbols }
    if isinstance(nd, (CodeBlockStmt, Archetype))
        and not isinstance(nd, (Semi, ModuleCode, GlobalVars, SemDef, TypeAlias))
        and not _is_structural_child(nd) {
        nd.affected_symbols.update(collect_assigned_symbols(nd));
    }

    super.enter_node(nd);
}

impl CFGBuildPass.enter_if_stmt(nd: IfStmt) -> None {
    import from jaclang.compiler.expr_keys { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

impl CFGBuildPass.enter_else_if(nd: ElseIf) -> None {
    import from jaclang.compiler.expr_keys { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

impl CFGBuildPass.enter_assert_stmt(nd: AssertStmt) -> None {
    import from jaclang.compiler.expr_keys { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

impl CFGBuildPass.enter_match_stmt(nd: MatchStmt) -> None {
    if isinstance(nd.target, Name) {
        nd.affected_symbols.add(nd.target.value);
    }
}

impl CFGBuildPass.exit_if_stmt(nd: IfStmt) -> None {
    true_target: (UniCFGNode | None) = nd.body[0] if nd.body else None;

    false_target: (UniCFGNode | None) = None;
    if nd.else_body {
        if isinstance(nd.else_body, ElseIf) {
            false_target = nd.else_body;
        } elif isinstance(nd.else_body, ElseStmt) and nd.else_body.body {
            false_target = nd.else_body.body[0];
        }
    }

    unwrapped = _unwrap_parens(nd.condition);
    cond_bool = unwrapped if isinstance(unwrapped, BoolExpr) else None;

    if cond_bool is not None and true_target {
        if not false_target and not nd.else_body and nd.parent {
            false_target = self._find_next_cfg_stmt_after_branch(nd);
        }
        op_is_and = _bool_is_and(cond_bool);
        `entry = self._wire_bool_operands(
            cond_bool.values, op_is_and, true_target, false_target
        );
        if `entry {
            self.link_bbs(nd, `entry);
        }
    } else {
        if true_target is not None {
            self.link_bbs(nd, true_target);
        }
        if false_target is not None {
            self.link_bbs(nd, false_target);
        }
    }

    if nd.body {
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_else_if(nd: ElseIf) -> None {
    self.exit_if_stmt(nd);
}

impl CFGBuildPass.exit_else_stmt(nd: ElseStmt) -> None {
    if nd.body {
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_while_stmt(nd: WhileStmt) -> None {
    true_target: (UniCFGNode | None) = nd.body[0] if nd.body else None;

    false_target: (UniCFGNode | None) = None;
    if nd.else_body and isinstance(nd.else_body, ElseStmt) and nd.else_body.body {
        false_target = nd.else_body.body[0];
    } elif nd.parent {
        false_target = self._find_next_cfg_stmt_after(nd.parent, nd);
    }

    unwrapped = _unwrap_parens(nd.condition);
    cond_bool = unwrapped if isinstance(unwrapped, BoolExpr) else None;

    if cond_bool is not None and true_target {
        op_is_and = _bool_is_and(cond_bool);
        `entry = self._wire_bool_operands(
            cond_bool.values, op_is_and, true_target, false_target
        );
        if `entry {
            self.link_bbs(nd, `entry);
        }
    } else {
        if true_target {
            self.link_bbs(nd, true_target);
        }
        if false_target and cond_bool is None {
            self.link_bbs(nd, false_target);
        }
    }

    self._link_body_tails_to_header(nd);
}

impl CFGBuildPass.exit_forever_stmt(nd: ForeverStmt) -> None {
    self._link_body_tails_to_header(nd);
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
    }
}

impl CFGBuildPass._link_body_tails_to_header(
    nd: WhileStmt | ForeverStmt | InForStmt | IterForStmt
) -> None {
    if not nd.body {
        return;
    }
    self._link_sequential(nd.body);
    if not self._is_terminal(nd.body[-1]) {
        self.link_bbs(nd.body[-1], nd);
    }

    for stmt in nd.body {
        self._connect_tails(stmt, nd);
    }
}

impl CFGBuildPass.exit_in_for_stmt(nd: InForStmt) -> None {
    self._link_body_tails_to_header(nd);
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
    }
    if nd.else_body and isinstance(nd.else_body, ElseStmt) and nd.else_body.body {
        self.link_bbs(nd, nd.else_body.body[0]);
    }
}

impl CFGBuildPass.exit_iter_for_stmt(nd: IterForStmt) -> None {
    self._link_body_tails_to_header(nd);
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
    }
    if nd.else_body and isinstance(nd.else_body, ElseStmt) and nd.else_body.body {
        self.link_bbs(nd, nd.else_body.body[0]);
    }
}

impl CFGBuildPass.exit_list_compr(nd: ListCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass.exit_set_compr(nd: SetCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass.exit_gen_compr(nd: GenCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass.exit_dict_compr(nd: DictCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass._wire_compr_filters(
    target_node: UniCFGNode, comprs: list[InnerCompr]
) -> None {
    import from jaclang.compiler.expr_keys { collect_narrowing_symbols }
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
    prev_node: UniCFGNode | None = None;
    for compr in comprs {
        if prev_node is not None {
            self.link_bbs(prev_node, compr);
        }
        prev_node = compr;
        if not compr.conditional {
            continue;
        }
        new_conditional: list[Expr] = [];
        for cond in compr.conditional {
            cfg_pred: CfgExpr;
            if isinstance(cond, CfgExpr) {
                cfg_pred = cond;
            } else {
                cfg_pred = CfgExpr(expr=cond, kid=[cond]);
                cfg_pred.parent = compr;
                idx = compr.kid.index(cond);
                compr.kid[idx] = cfg_pred;
            }
            cfg_pred.affected_symbols.update(collect_narrowing_symbols(cfg_pred.expr));
            if prev_node is not None {
                self.link_bbs(prev_node, cfg_pred);
            }
            self._set_and_link(cfg_pred, target_node, None);
            prev_node = cfg_pred;
            new_conditional.append(cfg_pred);
        }
        compr.conditional = new_conditional;
    }

    if prev_node is not None and prev_node is not target_node {
        self.link_bbs(prev_node, target_node);
    }
}

impl CFGBuildPass.exit_ctrl_stmt(nd: CtrlStmt) -> None {
    loop = self._find_parent_of_types(
        nd, (WhileStmt, ForeverStmt, InForStmt, IterForStmt)
    );
    if not loop {
        return;
    }
    import from jaclang.jac0core.constant { Tokens as Tok }
    if nd.ctrl.name == Tok.KW_CONTINUE {
        self.link_bbs(nd, loop);
    } elif nd.ctrl.name == Tok.KW_BREAK {
        if loop.parent {
            next_node = self._find_next_cfg_stmt_after(loop.parent, loop);
            if next_node {
                self.link_bbs(nd, next_node);
            }
        }
    }
}

impl CFGBuildPass.exit_try_stmt(nd: TryStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }

    for exc in nd.excepts {
        self.link_bbs(nd, exc);
    }

    if nd.else_body and isinstance(nd.else_body, ElseStmt) and nd.else_body.body {
        if nd.body and not self._is_terminal(nd.body[-1]) {
            self.link_bbs(nd.body[-1], nd.else_body.body[0]);
        }
    }

    if nd.finally_body {
        if nd.body {
            self.link_bbs(nd.body[-1], nd.finally_body);
        }
        for exc in nd.excepts {
            if exc.body {
                self.link_bbs(exc.body[-1], nd.finally_body);
            }
        }
    }
}

impl CFGBuildPass.exit_except(nd: Except) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_finally_stmt(nd: FinallyStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_match_stmt(nd: MatchStmt) -> None {
    for `case in nd.cases {
        self.link_bbs(nd, `case);
    }
}

impl CFGBuildPass.exit_match_case(nd: MatchCase) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_switch_stmt(nd: SwitchStmt) -> None {
    for `case in nd.cases {
        self.link_bbs(nd, `case);
    }
}

impl CFGBuildPass.exit_switch_case(nd: SwitchCase) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_with_stmt(nd: WithStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_typed_ctx_block(nd: TypedCtxBlock) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_open_stmt(nd: OpenStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_jsx_slot(nd: JsxSlot) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, CodeBlockStmt)
        ];
        if body {
            enclosing = nd.find_parent_of_type(CodeBlockStmt);
            if enclosing is not None {
                self.link_bbs(enclosing, body[0]);
            }
            self._link_sequential(body);
        }
    }
}

impl CFGBuildPass.exit_ability(nd: Ability) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, CodeBlockStmt)
        ];
        if body {
            self.link_bbs(nd, body[0]);
            self._link_sequential(body);
        }
    }
}

impl CFGBuildPass.exit_archetype(nd: Archetype) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        for s in nd.body {
            if isinstance(s, CodeBlockStmt) {
                self.link_bbs(nd, s);
            }
        }
    }
}

impl CFGBuildPass.exit_impl_def(nd: ImplDef) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, CodeBlockStmt)
        ];
        if body {
            self.link_bbs(nd, body[0]);
            self._link_sequential(body);
        }
    }
}

impl CFGBuildPass.exit_module_code(nd: ModuleCode) -> None {
    if nd.body {
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_test(nd: Test) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, CodeBlockStmt)
        ];
        if body {
            self.link_bbs(nd, body[0]);
            self._link_sequential(body);
        }
    }
}
