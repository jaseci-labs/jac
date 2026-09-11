impl UniCFGNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ConditionalNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl UniCFGNode.init(*, kid: Sequence[UniNode] = []) -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from collections.abc { Sequence }
    import from collections.abc { Sequence }

    self._link(kid, {});
    self.postinit();
}

impl ConditionalNode.init(
    *,
    sc_true_target: (UniCFGNode | None) = None,
    sc_false_target: (UniCFGNode | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from collections.abc { Sequence }
    import from collections.abc { Sequence }

    self.sc_true_target = sc_true_target;
    self.sc_false_target = sc_false_target;
    self._link(kid, {});
    self.postinit();
}
