import from jaclang.compiler.ir.identity { RelationFamily }
impl UniCFGNode.postinit -> None {
    _syms: set[str] = set();
    self.affected_symbols = _syms;
}

impl UniCFGNode.bb_out.getter -> list[UniCFGNode] {
    import from jaclang.compiler.ir.flow.edges { CfgSucc }

    return [self->:CfgSucc:->];
}

impl UniCFGNode.bb_in.getter -> list[UniCFGNode] {
    import from jaclang.compiler.ir.flow.edges { CfgSucc }

    return [self<-:CfgSucc:<-];
}

impl UniCFGNode.cfg_link(target: UniCFGNode) -> None {
    import from jaclang.compiler.ir.flow.edges { CfgSucc }

    if target not in [self->:CfgSucc:->] {
        self +>:CfgSucc:+> target;
    }
}

impl ConditionalNode.sc_true_target.getter -> (UniCFGNode | None) {
    import from jaclang.compiler.ir.flow.edges { CfgTrue }

    found = [self->:CfgTrue:->];
    return found[0] if found else None;
}

impl ConditionalNode.sc_true_target.setter(sc_true_target: (UniCFGNode | None)) {
    import from jaclang.compiler.ir.flow.edges { CfgTrue }

    self.changed_relations(RelationFamily.FLOW);
    del [edge self->:CfgTrue:->];
    if sc_true_target is not None {
        self +>:CfgTrue:+> sc_true_target;
    }
}

impl ConditionalNode.sc_false_target.getter -> (UniCFGNode | None) {
    import from jaclang.compiler.ir.flow.edges { CfgFalse }

    found = [self->:CfgFalse:->];
    return found[0] if found else None;
}

impl ConditionalNode.sc_false_target.setter(sc_false_target: (UniCFGNode | None)) {
    import from jaclang.compiler.ir.flow.edges { CfgFalse }

    self.changed_relations(RelationFamily.FLOW);
    del [edge self->:CfgFalse:->];
    if sc_false_target is not None {
        self +>:CfgFalse:+> sc_false_target;
    }
}

impl ConditionalNode.postinit -> None {
    UniCFGNode.postinit(self);
}

impl UniCFGNode.get_head -> UniCFGNode {
    import from jaclang.compiler.ir.syntax.nodes {
        ForeverStmt,
        InForStmt,
        InnerCompr,
        IterForStmt,
        WhileStmt
    }

    nd = self;
    while (
        nd.bb_in
        and (len(nd.bb_in) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_in[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_in[0].bb_out
        and (len(nd.bb_in[0].bb_out) == 1)
    ) {
        nd = nd.bb_in[0];
    }
    return nd;
}

impl UniCFGNode.get_tail -> UniCFGNode {
    import from jaclang.compiler.ir.syntax.nodes {
        ForeverStmt,
        InForStmt,
        InnerCompr,
        IterForStmt,
        WhileStmt
    }

    nd = self;
    while (
        nd.bb_out
        and (len(nd.bb_out) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_out[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_out[0].bb_in
        and (len(nd.bb_out[0].bb_in) == 1)
    ) {
        nd = nd.bb_out[0];
    }
    return nd;
}
