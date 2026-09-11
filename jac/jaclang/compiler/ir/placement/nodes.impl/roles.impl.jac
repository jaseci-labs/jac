impl ContextAwareNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ContextAwareNode.init(
    *, codespace_dual: bool = False, kid: Sequence[UniNode] = []
) -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from collections.abc { Sequence }
    import from collections.abc { Sequence }

    self.codespace_dual = codespace_dual;
    self._link(kid, {});
    self.postinit();
}
