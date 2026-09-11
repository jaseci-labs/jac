impl AstTypedVarNode.type_tag.getter -> (SubTag[Expr] | None) {
    import from jaclang.compiler.ir.syntax.edges { TypeTagRole }

    found = [self->:TypeTagRole:->];
    return found[0] if found else None;
}

impl AstTypedVarNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Expr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstTypedVarNode.init(
    *,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from collections.abc { Sequence }
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.ir.syntax.edges { TypeTagRole }
    import from collections.abc { Sequence }

    self.type = type;
    self._link(kid, {TypeTagRole: type_tag});
    self.postinit();
}

impl Expr.init(*, kid: Sequence[UniNode] = []) -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from collections.abc { Sequence }
    import from collections.abc { Sequence }

    self._link(kid, {});
    self.postinit();
}
