impl ContextAwareNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ContextAwareNode.init(
    *, codespace_dual: bool = False, kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self._link(kid, {});
    self.postinit();
}
