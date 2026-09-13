impl AstSymbolNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstSymbolStubNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstImplNeedingNode.body.getter -> (Sequence[UniNode] | UniNode | None) {
    import from jaclang.compiler.ir.symbols.edges { ImplOf }
    import from jaclang.compiler.ir.syntax.edges { BodyRole }

    impl_of = [self->:ImplOf:->];
    if impl_of {
        return impl_of[0];
    }
    return self._role_shaped(BodyRole, [self->:BodyRole:->]);
}


impl AstImplNeedingNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl UniScopeNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstSymbolNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstSymbolStubNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstImplNeedingNode.init(
    *, body: (Sequence[UniNode] | UniNode | None), kid: Sequence[UniNode] = []
) -> None {
    import from jaclang.compiler.ir.syntax.edges { BodyRole }

    self._link(kid, {BodyRole: body});
    self.postinit();
}
