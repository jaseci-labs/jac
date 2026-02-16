"""Print the control flow graph."""

impl cfg_dot_from_file(file_name: str) -> str {
    import from jaclang.jac0core.program { JacProgram }
    with open(file_name) as f {
        file_source = f.read();
    }
    ir = (prog := JacProgram()).compile(use_str=file_source, file_path=file_name);
    cfg_pass = CoalesceBBPass(ir_in=ir, prog=prog);
    dot = cfg_pass.printgraph_cfg();
    return dot;
}

"""Initialize CoalesceBBPass."""
impl CoalesceBBPass.init(
    ir_in: uni.Module, prog: Any, cancel_token: Any = None
) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Generate dot graph for CFG."""
impl CoalesceBBPass.printgraph_cfg -> str {
    cfg: dict = {};
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
            if isinstance(bbs, uni.ElseIf) {
                cfg[key]['bb_stmts'][i] = 'elif ' + bbs.condition.unparse();
            } elif isinstance(bbs, uni.IfStmt) {
                cfg[key]['bb_stmts'][i] = 'if ' + bbs.condition.unparse();
            } elif isinstance(bbs, uni.ElseStmt) {
                cfg[key]['bb_stmts'][i] = 'else';
            } elif isinstance(bbs, uni.Archetype) {
                cfg[key]['bb_stmts'][i] = 'obj ' + bbs.name.unparse();
            } elif isinstance(bbs, uni.Ability) {
                cfg[key]['bb_stmts'][i] = 'can ' + bbs.name_ref.unparse() + bbs.signature.unparse()
                if bbs.signature
                else '';
            } elif isinstance(bbs, (uni.InForStmt, uni.IterForStmt)) {
                cfg[key]['bb_stmts'][i] = (
                    'for ' + bbs.target.unparse() + ' in ' + bbs.collection.unparse()
                )
                if isinstance(bbs, uni.InForStmt)
                else (
                    'for ' + bbs.iter.unparse() + bbs.condition.unparse() + bbs.count_by.unparse()
                );
            } elif isinstance(bbs, uni.WhileStmt) {
                cfg[key]['bb_stmts'][i] = 'while ' + bbs.condition.unparse();
            } else {
                cfg[key]['bb_stmts'][i] = bbs.unparse();
            }
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
            for out_id in value['bb_out'] {
                dot += f"  {key} -> {out_id};\n";
            }
        }
    }
    dot += '}\n';
    return dot;
}

"""Enter BasicBlockStmt nodes."""
impl CoalesceBBPass.enter_node(nd: uni.UniNode) -> None {
    if (isinstance(nd, uni.UniCFGNode) and not isinstance(nd, uni.Semi)) {
        tail = nd.get_tail();
        bb = self.get_bb(nd);
        for bbs in self.basic_blocks.values() {
            if (bbs['bb_stmts'] == bb) {
                return;
            }
        }
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

impl CFGBuildPass.init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""After pass."""
impl CFGBuildPass.after_pass -> None {
    if self.to_connect {
        for nd in self.to_connect {
            if isinstance(nd, uni.UniCFGNode) {
                parent_bb = self.get_parent_bb_stmt(nd);
                if parent_bb {
                    self.link_bbs(parent_bb, nd);
                }
            }
        }
    }
}

"""Exit BasicBlockStmt nodes."""
impl CFGBuildPass.exit_node(nd: uni.UniNode) -> None {
    if (isinstance(nd, uni.UniCFGNode) and not isinstance(nd, uni.Semi)) {
        self.first_exit = True;
        if (not nd.bb_out and not isinstance(nd, (uni.ReturnStmt, uni.ArchHas))) {
            self.to_connect.append(nd);
        }
        if (isinstance(nd, (uni.InForStmt, uni.IterForStmt)) and self.for_loop_stack) {
            for from_node in self.for_loop_stack[-1][1:] {
                self.link_bbs(from_node, nd);

                if (from_node in self.to_connect) {
                    self.to_connect.remove(from_node);
                }
            }
            self.pop_loop_stack(nd);
            self.to_connect.append(nd);
        } elif (isinstance(nd, uni.WhileStmt) and self.while_loop_stack) {
            for from_node in self.while_loop_stack[-1][1:] {
                self.link_bbs(from_node, nd);

                if (from_node in self.to_connect) {
                    self.to_connect.remove(from_node);
                }
            }
            self.pop_loop_stack(nd);
            self.to_connect.append(nd);
        } elif (isinstance(nd, uni.Ability) and self.ability_stack) {
            for from_node in self.ability_stack[-1][1:] {
                if (from_node in self.to_connect) {
                    self.to_connect.remove(from_node);
                }
            }
            self.ability_stack.pop();
        } elif (isinstance(nd, (uni.IfStmt, uni.ElseIf)) and not nd.else_body) {
            self.to_connect.append(nd);
        }
    }
}

"""Enter BasicBlockStmt nodes."""
impl CFGBuildPass.enter_node(nd: uni.UniNode) -> None {
    if (isinstance(nd, uni.UniCFGNode) and not isinstance(nd, uni.Semi)) {
        bb_stmts = self.get_code_block_sequence(nd.parent);
        if (
            isinstance(nd, uni.CodeBlockStmt)
            and nd.parent
            and not isinstance(nd, (uni.ElseIf, uni.ElseStmt))
            and bb_stmts
            and self.first_exit
        ) {
            if (nd.parent and isinstance(nd.parent, uni.Archetype)) {
                parent_obj = nd.parent;
                if parent_obj {
                    self.link_bbs(parent_obj, nd);
                }
            } elif (bb_stmts[0] == nd) {
                if (isinstance(nd.parent, uni.ModuleCode) and self.to_connect) {
                    for bb in self.to_connect {
                        self.link_bbs(bb, nd);
                        self.to_connect.remove(bb);
                    }
                } else {
                    parent_bb = self.get_parent_bb_stmt(nd);
                    if parent_bb {
                        self.link_bbs(parent_bb, nd);
                    }
                }
            } elif (self.to_connect and not isinstance(nd, (uni.ElseIf, uni.ElseStmt))) {
                to_remove = [];
                for parent in self.to_connect {
                    if isinstance(parent, uni.UniCFGNode) {
                        self.link_bbs(parent, nd);
                        to_remove.append(parent);
                    }
                }
                for parent in to_remove {
                    self.to_connect.remove(parent);
                }
            } else {
                for i in range(len(bb_stmts)) {
                    if (bb_stmts[i] == nd) {
                        parent_bb = bb_stmts[(i - 1)];
                        self.link_bbs(parent_bb, nd);
                    }
                }
            }
        } else {
            parent_bb = self.get_parent_bb_stmt(nd);
            if parent_bb {
                self.link_bbs(parent_bb, nd);
            }
        }
        if isinstance(nd, (uni.InForStmt, uni.IterForStmt, uni.WhileStmt)) {
            self.push_loop_stack(nd);
        } else {
            if self.for_loop_stack {
                self.for_loop_stack[-1].append(nd);
            }
            if self.while_loop_stack {
                self.while_loop_stack[-1].append(nd);
            }
        }
        if isinstance(nd, uni.Ability) {
            self.ability_stack.append([nd]);
        } elif self.ability_stack {
            self.ability_stack[-1].append(nd);
        }
    }
}

"""Get code block sequence."""
impl CFGBuildPass.get_code_block_sequence(
    nd: (uni.UniNode | None)
) -> (list[uni.UniCFGNode] | None) {
    sequence: list[uni.UniCFGNode] = [];
    if ((nd is not None) and nd?.body and isinstance(nd?.body, Sequence)) {
        for bbs in nd.body {
            if isinstance(bbs, uni.UniCFGNode) {
                sequence.append(bbs);
            }
        }
        if sequence {
            return sequence;
        } else {
            return None;
        }
    } else {
        return None;
    }
}

"""Link basic blocks."""
impl CFGBuildPass.link_bbs(source: uni.UniCFGNode, target: uni.UniCFGNode) -> None {
    if (source and target) {
        if source.bb_out {
            source.bb_out.append(target);
        } else {
            source.bb_out = [target];
        }
        if target.bb_in {
            target.bb_in.append(source);
        } else {
            target.bb_in = [source];
        }
    }
}

"""Get parent basic block."""
impl CFGBuildPass.get_parent_bb_stmt(nd: uni.UniCFGNode) -> (uni.UniCFGNode | None) {
    if not isinstance(nd, uni.Module) {
        try {
            parent_bb_stmt = nd.parent_of_type(uni.UniCFGNode);
            return parent_bb_stmt;
        } except Exception {
            return None;
        }
    } else {
        return None;
    }
}

"""Pop loop stack."""
impl CFGBuildPass.pop_loop_stack(nd: uni.UniCFGNode) -> None {
    if (isinstance(nd, uni.WhileStmt) and (len(self.while_loop_stack) > 0)) {
        self.while_loop_stack.pop();
    } elif (
        isinstance(nd, (uni.InForStmt, uni.IterForStmt))
        and (len(self.for_loop_stack) > 0)
    ) {
        self.for_loop_stack.pop();
    }
}

"""Push loop stack."""
impl CFGBuildPass.push_loop_stack(loop_header: uni.UniCFGNode) -> None {
    if isinstance(loop_header, uni.WhileStmt) {
        self.while_loop_stack.append([loop_header]);
    } elif isinstance(loop_header, (uni.InForStmt, uni.IterForStmt)) {
        self.for_loop_stack.append([loop_header]);
    }
}

"""Before pass."""
impl CFGBuildPass.before_pass -> None {
    self.while_loop_stack: list[list[uni.UniCFGNode]] = [];
    self.for_loop_stack: list[list[uni.UniCFGNode]] = [];
    self.ability_stack: list[list[uni.UniCFGNode]] = [];
    self.to_connect: list[uni.UniCFGNode] = [];
    self.first_exit: bool = False;
}
