import from jaclang.compiler.ir.identity { RelationFamily }
impl ContextAwareNode.postinit -> None {}

impl ContextAwareNode.code_context.getter -> CodeContext {
    import from jaclang.compiler.ir.enums { CodeContext }
    import from jaclang.compiler.ir.placement.nodes { Codespace }
    import from jaclang.compiler.ir.placement.edges { PlacedIn }

    found = [self->:PlacedIn:->];
    if found {
        target: Codespace = found[0];
        return target.kind;
    }
    enclosing = self.find_parent_of_type(ContextAwareNode);
    return enclosing.code_context if enclosing is not None else CodeContext.SERVER;
}

impl ContextAwareNode.code_context.setter(code_context: CodeContext) {
    import from jaclang.compiler.ir.placement.edges { PlacedIn }
    import from jaclang.compiler.ir.placement.nodes { codespace_node }

    self.changed_relations(RelationFamily.PLACEMENT);
    del [edge self->:PlacedIn:->];
    self +>:PlacedIn:+> codespace_node(code_context);
}
