impl cfg_dot_from_file(file_name: str) -> str {
    import from jaclang.jac0core.program { JacProgram }
    with open(file_name, encoding="utf-8") as f {
        file_source = f.read();
    }
    ir = (prog := JacProgram()).compile(use_str=file_source, file_path=file_name);
    cfg_pass = CoalesceBBPass(ir_in=ir, prog=prog);
    dot = cfg_pass.printgraph_cfg();
    return dot;
}


impl CoalesceBBPass.printgraph_cfg -> str {
    bb_tails: dict[int, (uni.UniCFGNode | None)] = {};
    bb_heads: dict[int, (uni.UniCFGNode | None)] = {};
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
                if isinstance(tail, uni.CfgExpr) {
                    out_head = bb_heads[out_id];
                    if tail.sc_true_target is out_head {
                        label = ' [label="T"]';
                    } elif tail.sc_false_target is out_head {
                        label = ' [label="F"]';
                    }
                } elif isinstance(tail, (uni.IfStmt, uni.WhileStmt)) {
                    out_head = bb_heads[out_id];
                    if tail.body and out_head is tail.body[0] {
                        label = ' [label="T"]';
                    } elif tail.else_body {
                        eb = tail.else_body;
                        if isinstance(eb, uni.ElseIf) and out_head is eb {
                            label = ' [label="F"]';
                        } elif isinstance(eb, uni.ElseStmt)
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

impl CoalesceBBPass._has_bool_sc(condition: uni.Expr) -> bool {
    return isinstance(condition, uni.BoolExpr);
}

impl CoalesceBBPass._node_label(nd: uni.UniNode) -> str {
    import from jaclang.jac0core.constant { Tokens as Tok }

    if isinstance(nd, uni.ElseIf) {
        return 'elif'
            if self._has_bool_sc(nd.condition)
            else 'elif ' + nd.condition.unparse();
    }
    if isinstance(nd, uni.IfStmt) {
        return 'if'
            if self._has_bool_sc(nd.condition)
            else 'if ' + nd.condition.unparse();
    }
    if isinstance(nd, uni.ElseStmt) {
        return 'else';
    }

    if isinstance(nd, uni.WhileStmt) {
        return 'while'
            if self._has_bool_sc(nd.condition)
            else 'while ' + nd.condition.unparse();
    }
    if isinstance(nd, uni.ForeverStmt) {
        return 'forever';
    }
    if isinstance(nd, uni.InForStmt) {
        return 'for ' + nd.target.unparse() + ' in ' + nd.collection.unparse();
    }
    if isinstance(nd, uni.IterForStmt) {
        return 'for ' + nd.iter.unparse() + nd.condition.unparse() + nd.count_by.unparse();
    }

    if isinstance(nd, uni.MatchStmt) {
        return 'match ' + nd.target.unparse();
    }
    if isinstance(nd, uni.MatchCase) {
        return 'case ' + nd.pattern.unparse() if nd.pattern else 'case';
    }
    if isinstance(nd, uni.SwitchStmt) {
        return 'switch ' + nd.target.unparse();
    }
    if isinstance(nd, uni.SwitchCase) {
        return 'case ' + nd.pattern.unparse() if nd.pattern else 'default';
    }

    if isinstance(nd, uni.TryStmt) {
        return 'try';
    }
    if isinstance(nd, uni.Except) {
        return 'except ' + nd.ex_type.unparse() if nd.ex_type else 'except';
    }
    if isinstance(nd, uni.FinallyStmt) {
        return 'finally';
    }

    if isinstance(nd, uni.WithStmt) {
        label = 'with ';
        for (idx, e) in enumerate(nd.exprs) {
            if idx > 0 {
                label += ', ';
            }
            label += str(e.unparse());
        }
        return label;
    }

    if isinstance(nd, uni.Archetype) {
        return 'obj ' + nd.name.unparse();
    }
    if isinstance(nd, uni.Ability) {
        kw: str = 'can';
        for c in nd.kid {
            if isinstance(c, uni.Token) {
                if c.name == Tok.KW_DEF or c.name == Tok.KW_CAN {
                    kw = str(c.value);
                    break;
                }
            }
        }
        if nd.name_ref and nd.signature {
            return kw + ' ' + nd.name_ref.unparse() + nd.signature.unparse();
        } elif nd.name_ref {
            return kw + ' ' + nd.name_ref.unparse();
        }
        return kw;
    }

    if isinstance(nd, uni.ReturnStmt) {
        if nd.expr and isinstance(nd.expr, uni.IfElseExpr) {
            return "";
        }
        return nd.unparse();
    }

    if isinstance(nd, uni.CfgExpr) {
        par = nd.parent;
        if (
            isinstance(par, uni.IfElseExpr)
            and (nd is par.value or nd is par.else_value)
            and isinstance(par.parent, uni.ReturnStmt)
        ) {
            return "return " + nd.unparse();
        }
    }
    return nd.unparse();
}

impl CoalesceBBPass.enter_node(nd: uni.UniNode) -> None {
    is_cfg_node = (
        isinstance(nd, (uni.CodeBlockStmt, uni.Archetype))
        and not isinstance(nd, uni.Semi)
        and not _is_structural_child(nd)
    );

    if isinstance(nd, uni.CfgExpr) {
        cfg_nd: uni.CfgExpr = nd;
        if (cfg_nd.bb_in or cfg_nd.bb_out) and _unwrap_to_bool(cfg_nd) is None {
            is_cfg_node = True;
        }
    }
    if is_cfg_node and isinstance(nd, uni.UniCFGNode) {
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

impl CoalesceBBPass.get_bb(nd: uni.UniCFGNode) -> list[uni.UniCFGNode] {
    head = nd.get_head();
    tail = nd.get_tail();
    bb_list: list[uni.UniCFGNode] = [];
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

impl CFGBuildPass.link_bbs(source: uni.UniCFGNode, target: uni.UniCFGNode) -> None {
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
            queue: list[uni.UniCFGNode] = list(target.bb_out);
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

impl CFGBuildPass._link_sequential(body: Sequence[uni.CodeBlockStmt]) -> None {
    for i in range(1, len(body)) {
        prev = body[i - 1];
        next = body[i];
        if self._is_terminal(prev) {
            continue;
        }
        has_else = isinstance(prev, uni.AstElseBodyNode) and prev.else_body is not None;

        has_bool_sc = False;
        if isinstance(prev, (uni.IfStmt, uni.ElseIf, uni.WhileStmt)) {
            has_bool_sc = isinstance(_unwrap_parens(prev.condition), uni.BoolExpr);
        }
        if has_else
        and isinstance(
            prev, (uni.IfStmt, uni.WhileStmt, uni.InForStmt, uni.IterForStmt)
        ) {
            self._connect_tails(prev, next);
            if isinstance(prev, uni.IfStmt) {
                empty_true = not prev.body;
                eb = prev.else_body;
                empty_else = isinstance(eb, uni.ElseStmt) and not eb.body;
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

impl CFGBuildPass._connect_tails(parent: uni.UniNode, target: uni.UniCFGNode) -> None {
    for k in parent.kid {
        if not k or isinstance(k, uni.Expr) or isinstance(k, uni.Semi) {
            continue;
        }

        if isinstance(parent, uni.IterForStmt) {
            if k is parent.iter or k is parent.count_by {
                continue;
            }
        }
        if isinstance(k, (uni.Ability, uni.Archetype, uni.ImplDef, uni.Test)) {
            continue;
        }
        if isinstance(
            k, (uni.WhileStmt, uni.ForeverStmt, uni.InForStmt, uni.IterForStmt)
        ) {
            if not k.bb_out and not self._is_terminal(k) {
                self.link_bbs(k, target);
            }
            continue;
        }
        if isinstance(k, uni.UniCFGNode) {
            if not k.bb_out and not self._is_terminal(k) {
                self.link_bbs(k, target);
            } elif isinstance(k, uni.IfStmt) and not k.else_body {
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

def _unwrap_parens(expr: uni.Expr) -> uni.Expr {
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    return expr;
}

def _unwrap_to_bool(cfg: uni.CfgExpr) -> uni.BoolExpr | None {
    inner = _unwrap_parens(cfg.expr);
    return inner if isinstance(inner, uni.BoolExpr) else None;
}

def _bool_is_and(expr: uni.BoolExpr) -> bool {
    import from jaclang.jac0core.constant { Tokens as Tok }
    return isinstance(expr.op, uni.Token) and expr.op.name == Tok.KW_AND;
}

impl CFGBuildPass._wire_bool_operands(
    values: list[uni.CfgExpr],
    op_is_and: bool,
    true_target: (uni.UniCFGNode | None),
    false_target: (uni.UniCFGNode | None)
) -> uni.CfgExpr {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    n = len(values);

    entries: list[uni.CfgExpr] = [];
    for cfg in values {
        cfg.affected_symbols.update(collect_narrowing_symbols(cfg.expr));
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
            self._patch_inner_bool(nested, my_true, my_false);
            self.link_bbs(cfg, entries[i]);
        } else {
            self._set_and_link(cfg, my_true, my_false);
        }
    }
    return entries[0];
}

impl CFGBuildPass._set_and_link(
    cfg: uni.CfgExpr,
    true_target: (uni.UniCFGNode | None),
    false_target: (uni.UniCFGNode | None)
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

impl CFGBuildPass._patch_inner_bool(
    nested: uni.BoolExpr,
    my_true: (uni.UniCFGNode | None),
    my_false: (uni.UniCFGNode | None)
) -> None {
    inner_is_and = _bool_is_and(nested);
    last = nested.values[-1];
    for iv in nested.values {
        if inner_is_and {
            iv.sc_false_target = my_false;
            if my_false {
                self.link_bbs(iv, my_false);
            }
        } else {
            iv.sc_true_target = my_true;
            if my_true {
                self.link_bbs(iv, my_true);
            }
        }
    }
    if inner_is_and {
        last.sc_true_target = my_true;
        if my_true {
            self.link_bbs(last, my_true);
        }
    } else {
        last.sc_false_target = my_false;
        if my_false {
            self.link_bbs(last, my_false);
        }
    }
}

impl CFGBuildPass.exit_bool_expr(nd: uni.BoolExpr) -> None {
    if isinstance(nd.parent, (uni.IfStmt, uni.WhileStmt, uni.ElseIf))
    and nd is nd.parent.condition {
        return;
    }
    if len(nd.values) >= 2 {
        entry = self._wire_bool_operands(nd.values, _bool_is_and(nd), None, None);

        enclosing_flow = nd.find_parent_of_type(uni.UniCFGNode);
        if enclosing_flow is not None {
            self.link_bbs(enclosing_flow, entry);
        }
    }
}

impl CFGBuildPass.exit_if_else_expr(nd: uni.IfElseExpr) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.condition.affected_symbols.update(collect_narrowing_symbols(nd.condition.expr));

    unwrapped_cond = _unwrap_parens(nd.condition.expr);
    if isinstance(unwrapped_cond, uni.BoolExpr) and len(unwrapped_cond.values) >= 2 {
        op_is_and = _bool_is_and(unwrapped_cond);
        entry = self._wire_bool_operands(
            unwrapped_cond.values, op_is_and, nd.value, nd.else_value
        );
        if entry {
            self.link_bbs(nd.condition, entry);
        }
    } else {
        nd.condition.sc_true_target = nd.value;
        nd.condition.sc_false_target = nd.else_value;
        self.link_bbs(nd.condition, nd.value);
        self.link_bbs(nd.condition, nd.else_value);
    }

    enclosing_flow = nd.find_parent_of_type(uni.UniCFGNode);
    if enclosing_flow is not None {
        self.link_bbs(enclosing_flow, nd.condition);
    }

    for branch in [nd.value, nd.else_value] {
        inner = _unwrap_parens(branch.expr);
        if isinstance(inner, uni.IfElseExpr) {
            self.link_bbs(branch, inner.condition);
        } elif isinstance(inner, uni.BoolExpr) and len(inner.values) > 0 {
            self.link_bbs(branch, inner.values[0]);
        }
    }
}

impl CFGBuildPass._is_terminal(nd: uni.UniNode) -> bool {
    return isinstance(
        nd, (uni.ReturnStmt, uni.RaiseStmt, uni.CtrlStmt, uni.DisengageStmt)
    );
}

impl CFGBuildPass._find_parent_of_types(
    nd: uni.UniNode, types: tuple[type[uni.UniCFGNode], ...]
) -> (uni.UniCFGNode | None) {
    cur = nd.parent;
    while cur {
        if isinstance(cur, types) {
            return cast(uni.UniCFGNode, cur);
        }
        cur = cur?.parent;
    }
    return None;
}

impl CFGBuildPass._find_next_cfg_stmt_after(
    parent: uni.UniNode, child: uni.UniNode
) -> (uni.UniCFGNode | None) {
    body = parent?.body;
    if body is not None and isinstance(body, Sequence) {
        found = False;
        for stmt in body {
            if found and isinstance(stmt, uni.CodeBlockStmt) {
                return stmt;
            }
            if stmt is child {
                found = True;
            }
        }
    }
    return None;
}

impl _is_structural_child(nd: uni.UniNode) -> bool {
    if isinstance(nd.parent, uni.IterForStmt) {
        p: uni.IterForStmt = nd.parent;
        if nd is p.iter or nd is p.count_by {
            return True;
        }
    }
    return False;
}

impl CFGBuildPass.enter_node(nd: uni.UniNode) -> None {
    import from jaclang.compiler.symbol_utils { collect_assigned_symbols }
    if isinstance(nd, (uni.CodeBlockStmt, uni.Archetype))
    and not isinstance(nd, uni.Semi)
    and not _is_structural_child(nd) {
        nd.affected_symbols.update(collect_assigned_symbols(nd));
    }

    super.enter_node(nd);
}

impl CFGBuildPass.enter_if_stmt(nd: uni.IfStmt) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

impl CFGBuildPass.enter_else_if(nd: uni.ElseIf) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

impl CFGBuildPass.enter_assert_stmt(nd: uni.AssertStmt) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

impl CFGBuildPass.enter_match_stmt(nd: uni.MatchStmt) -> None {
    if isinstance(nd.target, uni.Name) {
        nd.affected_symbols.add(nd.target.value);
    }
}

impl CFGBuildPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    true_target: (uni.UniCFGNode | None) = nd.body[0] if nd.body else None;

    false_target: (uni.UniCFGNode | None) = None;
    if nd.else_body {
        if isinstance(nd.else_body, uni.ElseIf) {
            false_target = nd.else_body;
        } elif isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
            false_target = nd.else_body.body[0];
        }
    }

    unwrapped = _unwrap_parens(nd.condition);
    cond_bool = unwrapped if isinstance(unwrapped, uni.BoolExpr) else None;

    if cond_bool is not None and true_target {
        if not false_target and not nd.else_body and nd.parent {
            false_target = self._find_next_cfg_stmt_after(nd.parent, nd);
        }
        op_is_and = _bool_is_and(cond_bool);
        entry = self._wire_bool_operands(
            cond_bool.values, op_is_and, true_target, false_target
        );
        if entry {
            self.link_bbs(nd, entry);
        }
    } else {
        if true_target {
            self.link_bbs(nd, true_target);
        }
        if false_target {
            self.link_bbs(nd, false_target);
        }
    }

    if nd.body {
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_else_if(nd: uni.ElseIf) -> None {
    self.exit_if_stmt(nd);
}

impl CFGBuildPass.exit_else_stmt(nd: uni.ElseStmt) -> None {
    if nd.body {
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_while_stmt(nd: uni.WhileStmt) -> None {
    true_target: (uni.UniCFGNode | None) = nd.body[0] if nd.body else None;

    false_target: (uni.UniCFGNode | None) = None;
    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
        false_target = nd.else_body.body[0];
    } elif nd.parent {
        false_target = self._find_next_cfg_stmt_after(nd.parent, nd);
    }

    unwrapped = _unwrap_parens(nd.condition);
    cond_bool = unwrapped if isinstance(unwrapped, uni.BoolExpr) else None;

    if cond_bool is not None and true_target {
        op_is_and = _bool_is_and(cond_bool);
        entry = self._wire_bool_operands(
            cond_bool.values, op_is_and, true_target, false_target
        );
        if entry {
            self.link_bbs(nd, entry);
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

impl CFGBuildPass.exit_forever_stmt(nd: uni.ForeverStmt) -> None {
    self._link_body_tails_to_header(nd);
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
    }
}

impl CFGBuildPass._link_body_tails_to_header(
    nd: uni.WhileStmt | uni.ForeverStmt | uni.InForStmt | uni.IterForStmt
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

impl CFGBuildPass.exit_in_for_stmt(nd: uni.InForStmt) -> None {
    self._link_body_tails_to_header(nd);
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
    }
    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
        self.link_bbs(nd, nd.else_body.body[0]);
    }
}

impl CFGBuildPass.exit_iter_for_stmt(nd: uni.IterForStmt) -> None {
    self._link_body_tails_to_header(nd);
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
    }
    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
        self.link_bbs(nd, nd.else_body.body[0]);
    }
}

impl CFGBuildPass.exit_list_compr(nd: uni.ListCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass.exit_set_compr(nd: uni.SetCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass.exit_gen_compr(nd: uni.GenCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass.exit_dict_compr(nd: uni.DictCompr) -> None {
    self._wire_compr_filters(nd, nd.compr);
}

impl CFGBuildPass._wire_compr_filters(
    target_node: uni.UniCFGNode, comprs: list[uni.InnerCompr]
) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    if not comprs {
        return;
    }

    encl: uni.UniNode | None = target_node.parent;
    while encl is not None {
        if isinstance(encl, uni.UniCFGNode)
        and not isinstance(encl, (uni.InnerCompr, uni.Assignment)) {
            self.link_bbs(encl, comprs[0]);
            break;
        }
        encl = encl.parent;
    }
    prev_node: uni.UniCFGNode | None = None;
    for compr in comprs {
        if prev_node is not None {
            self.link_bbs(prev_node, compr);
        }
        prev_node = compr;
        if not compr.conditional {
            continue;
        }
        new_conditional: list[uni.Expr] = [];
        for cond in compr.conditional {
            cfg_pred: uni.CfgExpr;
            if isinstance(cond, uni.CfgExpr) {
                cfg_pred = cond;
            } else {
                cfg_pred = uni.CfgExpr(expr=cond, kid=[cond]);
                cfg_pred.parent = compr;
                idx = compr.kid.index(cond);
                compr.kid[idx] = cfg_pred;
            }
            cfg_pred.affected_symbols.update(collect_narrowing_symbols(cfg_pred.expr));
            self.link_bbs(prev_node, cfg_pred);
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

impl CFGBuildPass.exit_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    loop = self._find_parent_of_types(
        nd, (uni.WhileStmt, uni.ForeverStmt, uni.InForStmt, uni.IterForStmt)
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

impl CFGBuildPass.exit_try_stmt(nd: uni.TryStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }

    for exc in nd.excepts {
        self.link_bbs(nd, exc);
    }

    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
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

impl CFGBuildPass.exit_except(nd: uni.Except) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_finally_stmt(nd: uni.FinallyStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_match_stmt(nd: uni.MatchStmt) -> None {
    for case in nd.cases {
        self.link_bbs(nd, case);
    }
}

impl CFGBuildPass.exit_match_case(nd: uni.MatchCase) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_switch_stmt(nd: uni.SwitchStmt) -> None {
    for case in nd.cases {
        self.link_bbs(nd, case);
    }
}

impl CFGBuildPass.exit_switch_case(nd: uni.SwitchCase) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_with_stmt(nd: uni.WithStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_region_stmt(nd: uni.RegionStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_jsx_slot(nd: uni.JsxSlot) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, uni.CodeBlockStmt)
        ];
        if body {
            enclosing = nd.find_parent_of_type(uni.CodeBlockStmt);
            if enclosing is not None {
                self.link_bbs(enclosing, body[0]);
            }
            self._link_sequential(body);
        }
    }
}

impl CFGBuildPass.exit_ability(nd: uni.Ability) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, uni.CodeBlockStmt)
        ];
        if body {
            self.link_bbs(nd, body[0]);
            self._link_sequential(body);
        }
    }
}

impl CFGBuildPass.exit_archetype(nd: uni.Archetype) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        for s in nd.body {
            if isinstance(s, uni.CodeBlockStmt) {
                self.link_bbs(nd, s);
            }
        }
    }
}

impl CFGBuildPass.exit_impl_def(nd: uni.ImplDef) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, uni.CodeBlockStmt)
        ];
        if body {
            self.link_bbs(nd, body[0]);
            self._link_sequential(body);
        }
    }
}

impl CFGBuildPass.exit_module_code(nd: uni.ModuleCode) -> None {
    if nd.body {
        self._link_sequential(nd.body);
    }
}

impl CFGBuildPass.exit_test(nd: uni.Test) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        body = [
            s
            for s in nd.body
            if isinstance(s, uni.CodeBlockStmt)
        ];
        if body {
            self.link_bbs(nd, body[0]);
            self._link_sequential(body);
        }
    }
}
