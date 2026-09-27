impl cfg_dot_from_file(file_name: str) -> str {
    import from jaclang.compiler.driver.pipeline_runner { run_utility }
    import from jaclang.compiler.driver.pipeline_types { UtilityProduct }
    import from jaclang.compiler.driver.program { JacProgram }
    with open(file_name, encoding="utf-8") as f {
        file_source = f.read();
    }
    ir = (prog := JacProgram()).compile(use_str=file_source, file_path=file_name);
    import from typing { cast }
    cfg_pass = cast(CoalesceBBPass, run_utility(UtilityProduct.CFG_DOT, ir, prog));
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
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    import from jaclang.compiler.frontend.unparse { unparse_node }

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
        keywords = [nd->:Kid:->[?:Token, name in (Tok.KW_DEF, Tok.KW_CAN)]];
        if keywords {
            kw = str(keywords[0].value);
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

impl CoalesceBBPass.coalesce_collect with UniNode entry {
    is_cfg_node = (
        isinstance(here, (CodeBlockStmt, Archetype))
        and not isinstance(here, (Semi, ModuleCode, GlobalVars, SemDef, TypeAlias))
        and not is_structural_child(here)
    );

    if isinstance(here, CfgExpr) {
        cfg_nd: CfgExpr = here;
        if (cfg_nd.bb_in or cfg_nd.bb_out) and unwrap_to_bool(cfg_nd) is None {
            is_cfg_node = True;
        }
    }
    if is_cfg_node and isinstance(here, UniCFGNode) {
        for bbs in self.basic_blocks.values() {
            if (here in bbs['bb_stmts']) {
                return;
            }
        }
        tail = here.get_tail();
        bb = self.get_bb(here);
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

impl CoalesceBBPass.prepare with entry {
    if self.ctx.nested_depth {
        return;
    }
    self.basic_blocks = {};
    self.bb_counter = 0;
}
