"""Control flow graph build pass implementation."""

"""Print the control flow graph."""
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


"""Generate dot graph for CFG."""
impl CoalesceBBPass.printgraph_cfg -> str {
    cfg: dict = {};
    # Save tail/head nodes before bb_stmts gets mutated to strings below.
    bb_tails: dict = {};
    bb_heads: dict = {};
    for (key, bb) in self.basic_blocks.items() {
        bb_tails[key] = bb['bb_stmts'][-1] if bb['bb_stmts'] else None;
        bb_heads[key] = bb['bb_stmts'][0] if bb['bb_stmts'] else None;
    }
    dot = 'digraph G {\n';
    for (key, bb) in self.basic_blocks.items() {
        cfg[key] = {
            'bb_stmts': bb['bb_stmts'],
            'bb_out': [0 for _ in range(len(bb['bb_out']))] if bb['bb_out'] else None
        };

        if bb['bb_out'] {
            for out_obj in bb['bb_out'] {
                for (k, v) in self.basic_blocks.items() {
                    if (out_obj == v['bb_stmts'][0]) {
                        cfg[key]['bb_out'][bb['bb_out'].index(out_obj)] = k;
                        break;
                    }
                }
            }
        }
    }
    for (key, bb) in cfg.items() {
        for (i, bbs) in enumerate(bb['bb_stmts']) {
            cfg[key]['bb_stmts'][i] = self._node_label(bbs);
        }
    }
    for (key, value) in cfg.items() {
        if value.get('bb_stmts') {
            stmts = '\\n'.join(
                [stmt.replace('"', '\\"') for stmt in value['bb_stmts']]
            );
            dot += f'  {key} [label="BB{key}\\n{stmts}", shape=box];' + "\n";
        } else {
            dot += f'  {key} [label="BB{key}"];' + "\n";
        }
    }
    for (key, value) in cfg.items() {
        if value.get('bb_out') {
            # Use saved tail/head nodes (bb_stmts was mutated to strings above).
            tail = bb_tails[key];
            for out_id in value['bb_out'] {
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
                        if isinstance(tail.else_body, uni.ElseIf)
                        and out_head is tail.else_body {
                            label = ' [label="F"]';
                        } elif isinstance(tail.else_body, uni.ElseStmt)
                        and tail.else_body.body
                        and out_head is tail.else_body.body[0] {
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

"""Check if condition is a BoolExpr (short-circuit wiring active)."""
impl CoalesceBBPass._has_bool_sc(condition: uni.Expr) -> bool {
    return isinstance(condition, uni.BoolExpr);
}

"""Generate a compact label for a CFG node."""
impl CoalesceBBPass._node_label(nd: uni.UniNode) -> str {
    import from jaclang.jac0core.constant { Tokens as Tok }
    # -- Branch --
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
    # -- Loop --
    if isinstance(nd, uni.WhileStmt) {
        return 'while'
            if self._has_bool_sc(nd.condition)
            else 'while ' + nd.condition.unparse();
    }
    if isinstance(nd, uni.InForStmt) {
        return 'for ' + nd.target.unparse() + ' in ' + nd.collection.unparse();
    }
    if isinstance(nd, uni.IterForStmt) {
        return 'for ' + nd.iter.unparse() + nd.condition.unparse() + nd.count_by.unparse();
    }
    # -- Match/Switch --
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
    # -- Exception --
    if isinstance(nd, uni.TryStmt) {
        return 'try';
    }
    if isinstance(nd, uni.Except) {
        return 'except ' + nd.ex_type.unparse() if nd.ex_type else 'except';
    }
    if isinstance(nd, uni.FinallyStmt) {
        return 'finally';
    }
    # -- With --
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
    # -- Scope boundaries --
    if isinstance(nd, uni.Archetype) {
        return 'obj ' + nd.name.unparse();
    }
    if isinstance(nd, uni.Ability) {
        # Use actual keyword (def vs can)
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
    return nd.unparse();
}

"""Enter CFG nodes (statements, archetypes, and leaf CfgExprs)."""
impl CoalesceBBPass.enter_node(nd: uni.UniNode) -> None {
    is_cfg_node = (
        isinstance(nd, (uni.CodeBlockStmt, uni.Archetype))
        and not isinstance(nd, uni.Semi)
        and not _is_structural_child(nd)
    );
    # Leaf CfgExprs participate; container CfgExprs (wrapping nested BoolExpr)
    # are pass-throughs handled by the inner operands.
    if isinstance(nd, uni.CfgExpr) {
        cfg_nd: uni.CfgExpr = nd;
        if (cfg_nd.bb_in or cfg_nd.bb_out) and _unwrap_to_bool(cfg_nd) is None {
            is_cfg_node = True;
        }
    }
    if (is_cfg_node) {
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

"""Get basic block."""
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

"""Before pass."""
impl CoalesceBBPass.before_pass -> None {
    self.basic_blocks: dict = {};
    self.bb_counter: int = 0;
}

# ============================================================================
# CFGBuildPass
# ============================================================================
"""Before pass -- no state needed."""
impl CFGBuildPass.before_pass -> None { }

# ============================================================================
# Utilities
# ============================================================================
"""Link two CFG nodes: source.bb_out -> target, target.bb_in -> source.
Also propagates affected_symbols for the Pyright-style branch-skipping optimization.
When target already has internal bb_out edges (e.g., an IfStmt whose exit handler
already linked to its body), new symbols from source are propagated to those internal
nodes so that the backward CFG walk can find narrowing predicates through them."""
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
        # Propagate newly added symbols to already-linked internal nodes.
        # This handles the case where exit_if_stmt linked S2→body before
        # _link_sequential linked S1→S2, so body nodes missed S1's symbols.
        # Uses iterative BFS to avoid recursion issues with cyclic CFGs.
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

"""Link sequential statements in a body, skipping after terminals.
For compound statements (if/while/for/try/match/etc.), also connects
their internal unconnected tails to the next sibling."""
impl CFGBuildPass._link_sequential(body: Sequence[uni.CodeBlockStmt]) -> None {
    for i in range(1, len(body)) {
        prev = body[i - 1];
        next = body[i];
        if self._is_terminal(prev) {
            continue;
        }
        has_else = prev?.else_body and prev.else_body is not None;
        # Did the exit handler already wire a short-circuit chain? Peel
        # parentheses so `(a and b)` matches `a and b`.
        has_bool_sc = False;
        if isinstance(prev, (uni.IfStmt, uni.ElseIf, uni.WhileStmt)) {
            has_bool_sc = isinstance(_unwrap_parens(prev.condition), uni.BoolExpr);
        }
        if has_else
        and isinstance(
            prev, (uni.IfStmt, uni.WhileStmt, uni.InForStmt, uni.IterForStmt)
        ) {
            # Exit paths covered -- no direct prev→next edge, unless an
            # empty true body or empty ElseStmt body creates a fall-through.
            self._connect_tails(prev, next);
            if isinstance(prev, uni.IfStmt)
            and (
                not prev.body
                or (
                    isinstance(prev.else_body, uni.ElseStmt) and not prev.else_body.body
                )
            ) {
                self.link_bbs(prev, next);
            }
        } elif has_bool_sc {
            # Short-circuit wiring handled false path via BoolExpr chain -- no direct prev→next.
            self._connect_tails(prev, next);
        } else {
            # Direct prev→next edge (includes false-branch fallthrough for if-without-else).
            self.link_bbs(prev, next);
            # Also connect internal tails for compound stmts.
            self._connect_tails(prev, next);
        }
    }
}

"""Find non-terminal CFG nodes with empty bb_out in parent's subtree and link to target.
Skips expression subtrees and scope boundaries (Ability, Archetype, ImplDef).
Recurses into compound stmts and non-CFG containers (ElseStmt, MatchCase, etc.)."""
impl CFGBuildPass._connect_tails(parent: uni.UniNode, target: uni.UniCFGNode) -> None {
    for k in parent.kid {
        if not k or isinstance(k, uni.Expr) or isinstance(k, uni.Semi) {
            continue;
        }
        # Skip structural Assignment fields of IterForStmt (iter, count_by)
        if isinstance(parent, uni.IterForStmt)
        and (k is parent.iter or k is parent.count_by) {
            continue;
        }
        if isinstance(k, (uni.Ability, uni.Archetype, uni.ImplDef, uni.Test)) {
            # Scope boundary -- don't recurse into nested scopes
            continue;
        }
        if isinstance(k, uni.UniCFGNode) {
            if not k.bb_out and not self._is_terminal(k) {
                # Unconnected tail -- link to target
                self.link_bbs(k, target);
            } elif isinstance(k, uni.IfStmt) and not k.else_body {
                # If/elif without else: false branch falls through to target,
                # but only if not already connected by _link_sequential in its own body context.
                first_body = k.body[0] if k.body else None;
                has_false_branch = any(o is not first_body for o in k.bb_out);
                if not has_false_branch {
                    self.link_bbs(k, target);
                }
                self._connect_tails(k, target);
            } else {
                # Has outgoing edges or is terminal -- check children
                self._connect_tails(k, target);
            }
        } else {
            # Non-CFG container (ElseStmt, MatchCase, etc.) -- check children
            self._connect_tails(k, target);
        }
    }
}

"""Unwrap AtomUnit (parentheses) to reach the actual expression."""
def _unwrap_parens(expr: uni.Expr) -> uni.Expr {
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    return expr;
}

"""Return the nested BoolExpr wrapped by a CfgExpr (through parens), or None."""
def _unwrap_to_bool(cfg: uni.CfgExpr) -> uni.BoolExpr | None {
    inner = _unwrap_parens(cfg.expr);
    return inner if isinstance(inner, uni.BoolExpr) else None;
}

"""Check if a BoolExpr uses AND (vs OR)."""
def _bool_is_and(expr: uni.BoolExpr) -> bool {
    import from jaclang.jac0core.constant { Tokens as Tok }
    return isinstance(expr.op, uni.Token) and expr.op.name == Tok.KW_AND;
}

"""Wire short-circuit boolean flow through CfgExpr operands.
Each operand branches to the next operand on its continuing edge (true for
AND, false for OR) and to the external target on its exit edge. Nested
BoolExpr operands are flattened: all inner operands short-circuit to the
outer exit target, and the last inner operand's continuing target becomes
the outer continuation. Returns the entry CfgExpr (first operand)."""
impl CFGBuildPass._wire_bool_operands(
    values: list[uni.CfgExpr],
    op_is_and: bool,
    true_target: (uni.UniCFGNode | None),
    false_target: (uni.UniCFGNode | None)
) -> uni.CfgExpr {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    n = len(values);
    # Resolve entry nodes — for operands wrapping a nested BoolExpr, the
    # entry is the first inner operand (already wired by exit_bool_expr).
    entries: list[uni.CfgExpr] = [];
    for cfg in values {
        cfg.affected_symbols.update(collect_narrowing_symbols(cfg.expr));
        nested = _unwrap_to_bool(cfg);
        entries.append(
            nested.values[0] if (nested and len(nested.values) >= 2) else cfg
        );
    }
    # Wire each operand's true/false edges.
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

"""Set sc targets on a CfgExpr and link them."""
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

"""Patch a nested BoolExpr's inner operand edges with outer targets.
All inner operands' short-circuit-exit edge points to the outer exit; the
last inner operand's continuing edge points to the outer continuation."""
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

"""Wire CfgExpr operand chain for standalone BoolExpr (not a condition).
Conditions of if/while/elif are wired by exit_if_stmt/exit_while_stmt."""
impl CFGBuildPass.exit_bool_expr(nd: uni.BoolExpr) -> None {
    if isinstance(nd.parent, (uni.IfStmt, uni.WhileStmt, uni.ElseIf))
    and nd is nd.parent.condition {
        return;
    }
    if len(nd.values) >= 2 {
        entry = self._wire_bool_operands(nd.values, _bool_is_and(nd), None, None);
        # Connect the operand sub-CFG to the nearest enclosing CFG node so
        # that upstream narrowing (e.g., isinstance guard on an enclosing
        # if-stmt) flows into the operand chain. Without this edge the
        # sub-CFG is orphaned and narrowing established before the BoolExpr
        # cannot be discovered by the backward CFG walk.
        enclosing_flow = nd.find_parent_of_type(uni.UniCFGNode);
        if enclosing_flow is not None {
            self.link_bbs(enclosing_flow, entry);
        }
    }
}

"""Wire CfgExpr branches for IfElseExpr (ternary). Also links into nested
IfElseExpr/BoolExpr so narrowing propagates through nested ternaries."""
impl CFGBuildPass.exit_if_else_expr(nd: uni.IfElseExpr) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.condition.affected_symbols.update(collect_narrowing_symbols(nd.condition.expr));

    # If the condition is a BoolExpr, wire the operand short-circuit chain
    # through to the branches the same way `exit_if_stmt` does. This lets
    # the backward walker traverse operands individually, so per-operand
    # narrowings accumulate on the edge into the branch (critical for
    # patterns like `0 if s is None or not isinstance(s, T) else s.m()`
    # where the else branch needs s narrowed to T via double negation).
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
        # Simple condition: the outer CfgExpr is the branch point.
        nd.condition.sc_true_target = nd.value;
        nd.condition.sc_false_target = nd.else_value;
        self.link_bbs(nd.condition, nd.value);
        self.link_bbs(nd.condition, nd.else_value);
    }

    # Connect the ternary sub-CFG to its nearest enclosing CFG node so
    # that narrowing established upstream flows into the condition and
    # branches. For a top-level ternary this is the enclosing statement
    # (CodeBlockStmt); for a nested ternary it is the outer ternary's
    # branch CfgExpr, which correctly carries the outer ternary's own
    # narrowing (skipping past it would lose the enclosing narrowing).
    # Without this edge the sub-CFG is orphaned from surrounding flow
    # and patterns like
    # `if x is None { return } return x.m() if isinstance(x, T) else x.m()`
    # bottom out with the declared type.
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

"""Check if a node is a terminal (no control flow continues past it)."""
impl CFGBuildPass._is_terminal(nd: uni.UniNode) -> bool {
    return isinstance(
        nd, (uni.ReturnStmt, uni.RaiseStmt, uni.CtrlStmt, uni.DisengageStmt)
    );
}

"""Find the nearest ancestor matching one of the given types."""
impl CFGBuildPass._find_parent_of_types(
    nd: uni.UniNode, types: tuple[type[uni.UniCFGNode], ...]
) -> (uni.UniCFGNode | None) {
    cur = nd.parent;
    while cur {
        if isinstance(cur, types) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

"""Find the next CodeBlockStmt sibling after child in parent.body."""
impl CFGBuildPass._find_next_cfg_stmt_after(
    parent: uni.UniNode, child: uni.UniNode
) -> (uni.UniCFGNode | None) {
    if parent?.body and isinstance(parent.body, Sequence) {
        found = False;
        for stmt in parent.body {
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

# ============================================================================
# Symbol collection (enter handlers)
# ============================================================================
"""Check if a node is a structural part of its parent (not a flow participant).
E.g. IterForStmt.iter and IterForStmt.count_by are structural assignments."""
impl _is_structural_child(nd: uni.UniNode) -> bool {
    if isinstance(nd.parent, uni.IterForStmt) {
        p: uni.IterForStmt = nd.parent;
        if nd is p.iter or nd is p.count_by {
            return True;
        }
    }
    return False;
}

"""Collect affected_symbols for all CFG nodes, then dispatch to type-specific enter."""
impl CFGBuildPass.enter_node(nd: uni.UniNode) -> None {
    import from jaclang.compiler.symbol_utils { collect_assigned_symbols }
    if isinstance(nd, (uni.CodeBlockStmt, uni.Archetype))
    and not isinstance(nd, uni.Semi)
    and not _is_structural_child(nd) {
        nd.affected_symbols.update(collect_assigned_symbols(nd));
    }
    # Dispatch to enter_if_stmt, enter_assert_stmt, etc.
    super.enter_node(nd);
}

"""Collect narrowing symbols from if condition."""
impl CFGBuildPass.enter_if_stmt(nd: uni.IfStmt) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

"""Collect narrowing symbols from elif condition."""
impl CFGBuildPass.enter_else_if(nd: uni.ElseIf) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

"""Collect narrowing symbols from assert condition."""
impl CFGBuildPass.enter_assert_stmt(nd: uni.AssertStmt) -> None {
    import from jaclang.compiler.symbol_utils { collect_narrowing_symbols }
    nd.affected_symbols.update(collect_narrowing_symbols(nd.condition));
}

"""Collect affected symbols from match target."""
impl CFGBuildPass.enter_match_stmt(nd: uni.MatchStmt) -> None {
    if isinstance(nd.target, uni.Name) {
        nd.affected_symbols.add(nd.target.value);
    }
}

# ============================================================================
# Edge building (exit handlers) -- Branch
# ============================================================================
"""IfStmt: link to body + else_body, with short-circuit wiring for BoolExpr conditions."""
impl CFGBuildPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    true_target: (uni.UniCFGNode | None) = nd.body[0] if nd.body else None;

    # Determine false target
    false_target: (uni.UniCFGNode | None) = None;
    if nd.else_body {
        if isinstance(nd.else_body, uni.ElseIf) {
            false_target = nd.else_body;
        } elif isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
            false_target = nd.else_body.body[0];
        }
    }

    # Peel parens so `if (a and b)` wires the same as `if a and b`.
    unwrapped = _unwrap_parens(nd.condition);
    cond_bool = unwrapped if isinstance(unwrapped, uni.BoolExpr) else None;

    if cond_bool is not None and true_target {
        # For if-without-else, the false path falls through to the next sibling.
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
        # Simple condition — direct edges
        if true_target {
            self.link_bbs(nd, true_target);
        }
        if false_target {
            self.link_bbs(nd, false_target);
        }
    }

    # Sequential linking within body
    if nd.body {
        self._link_sequential(nd.body);
    }
}

"""ElseIf: same structure as IfStmt (ElseIf extends IfStmt)."""
impl CFGBuildPass.exit_else_if(nd: uni.ElseIf) -> None {
    self.exit_if_stmt(nd);
}

"""ElseStmt: sequential link within body (incoming edge set by parent IfStmt/ElseIf)."""
impl CFGBuildPass.exit_else_stmt(nd: uni.ElseStmt) -> None {
    if nd.body {
        self._link_sequential(nd.body);
    }
}

# ============================================================================
# Edge building (exit handlers) -- Loop
# ============================================================================
"""WhileStmt: body + back-edge + else_body, with short-circuit wiring for BoolExpr conditions."""
impl CFGBuildPass.exit_while_stmt(nd: uni.WhileStmt) -> None {
    true_target: (uni.UniCFGNode | None) = nd.body[0] if nd.body else None;

    # Determine false target: else_body or next sibling
    false_target: (uni.UniCFGNode | None) = None;
    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
        false_target = nd.else_body.body[0];
    } elif nd.parent {
        false_target = self._find_next_cfg_stmt_after(nd.parent, nd);
    }

    # Peel parens so `while (a and b)` wires the same as `while a and b`.
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

    if nd.body {
        self._link_sequential(nd.body);
        # Back-edge: last body stmt -> loop header
        if not self._is_terminal(nd.body[-1]) {
            self.link_bbs(nd.body[-1], nd);
        }
    }
}

"""InForStmt: body + back-edge + else_body."""
impl CFGBuildPass.exit_in_for_stmt(nd: uni.InForStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
        if not self._is_terminal(nd.body[-1]) {
            self.link_bbs(nd.body[-1], nd);
        }
    }
    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
        self.link_bbs(nd, nd.else_body.body[0]);
    }
}

"""IterForStmt: body + back-edge + else_body."""
impl CFGBuildPass.exit_iter_for_stmt(nd: uni.IterForStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
        if not self._is_terminal(nd.body[-1]) {
            self.link_bbs(nd.body[-1], nd);
        }
    }
    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
        self.link_bbs(nd, nd.else_body.body[0]);
    }
}

# ============================================================================
# Edge building (exit handlers) -- Control flow
# ============================================================================
"""CtrlStmt: break -> next after loop, continue -> loop header."""
impl CFGBuildPass.exit_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    loop = self._find_parent_of_types(
        nd, (uni.WhileStmt, uni.InForStmt, uni.IterForStmt)
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

# ============================================================================
# Edge building (exit handlers) -- Exception
# ============================================================================
"""TryStmt: body + except handlers + finally."""
impl CFGBuildPass.exit_try_stmt(nd: uni.TryStmt) -> None {
    # Try body
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
    # Conservative: any stmt in try could throw -> link to each except handler
    for exc in nd.excepts {
        self.link_bbs(nd, exc);
    }
    # Try-else: runs on normal completion (no exception)
    if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) and nd.else_body.body {
        if nd.body and not self._is_terminal(nd.body[-1]) {
            self.link_bbs(nd.body[-1], nd.else_body.body[0]);
        }
    }
    # Finally: all paths flow through it — always link, even from terminal
    # statements (return/raise). The finally block executes regardless, and
    # the link propagates affected_symbols needed for narrowing analysis.
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

"""Except: link to body."""
impl CFGBuildPass.exit_except(nd: uni.Except) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

"""FinallyStmt: link to body."""
impl CFGBuildPass.exit_finally_stmt(nd: uni.FinallyStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

# ============================================================================
# Edge building (exit handlers) -- Multi-branch
# ============================================================================
"""MatchStmt: link to each MatchCase node."""
impl CFGBuildPass.exit_match_stmt(nd: uni.MatchStmt) -> None {
    for case in nd.cases {
        self.link_bbs(nd, case);
    }
}

"""MatchCase: link to body (incoming set by MatchStmt)."""
impl CFGBuildPass.exit_match_case(nd: uni.MatchCase) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

"""SwitchStmt: link to each SwitchCase node."""
impl CFGBuildPass.exit_switch_stmt(nd: uni.SwitchStmt) -> None {
    for case in nd.cases {
        self.link_bbs(nd, case);
    }
}

"""SwitchCase: link to body (incoming set by SwitchStmt)."""
impl CFGBuildPass.exit_switch_case(nd: uni.SwitchCase) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

# ============================================================================
# Edge building (exit handlers) -- Other
# ============================================================================
"""WithStmt: link to body."""
impl CFGBuildPass.exit_with_stmt(nd: uni.WithStmt) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

"""TypedCtxBlock: link to body."""
impl CFGBuildPass.exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None {
    if nd.body {
        self.link_bbs(nd, nd.body[0]);
        self._link_sequential(nd.body);
    }
}

# ============================================================================
# Edge building (exit handlers) -- Scope boundaries
# ============================================================================
"""Ability: scope boundary, link to body."""
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

"""Archetype: scope boundary, link to each child (declarations are independent)."""
impl CFGBuildPass.exit_archetype(nd: uni.Archetype) -> None {
    if nd.body and isinstance(nd.body, Sequence) {
        for s in nd.body {
            if isinstance(s, uni.CodeBlockStmt) {
                self.link_bbs(nd, s);
            }
        }
    }
}

"""ImplDef: scope boundary, link to body."""
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

"""ModuleCode: sequential link body (not a CFG node, no parent edge)."""
impl CFGBuildPass.exit_module_code(nd: uni.ModuleCode) -> None {
    if nd.body {
        self._link_sequential(nd.body);
    }
}

"""Test: scope boundary, link to body (same as Ability)."""
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
