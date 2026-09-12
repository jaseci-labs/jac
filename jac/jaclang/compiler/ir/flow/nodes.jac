import type from collections.abc { Sequence }

import from jaclang.compiler.ir.base { UniNode }

node UniCFGNode(UniNode) {
    has affected_symbols: set[str] postinit;
    has bb_in: list[UniCFGNode] { getter; }
    has bb_out: list[UniCFGNode] { getter; }

    def cfg_link(target: UniCFGNode) -> None;
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def get_head -> UniCFGNode;
    def get_tail -> UniCFGNode;
    def __repr__ -> str;
}

node ConditionalNode(UniCFGNode) {
    has sc_true_target: (UniCFGNode | None) {
        getter;
        setter(sc_true_target: (UniCFGNode | None));
    }

    has sc_false_target: (UniCFGNode | None) {
        getter;
        setter(sc_false_target: (UniCFGNode | None));
    }

    def init(
        *,
        sc_true_target: (UniCFGNode | None) = None,
        sc_false_target: (UniCFGNode | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}
