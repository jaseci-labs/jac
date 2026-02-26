"""Tests for compound AND narrowing in the type checker.

When multiple isinstance checks on the SAME variable are combined with AND,
the type should be narrowed to the most specific (intersection) type.
"""

obj BaseNode {
    has name: str = "base";
}

obj CFGNode(BaseNode) {
    has bb_out: list[CFGNode] | None = None;
}

obj SemiNode(CFGNode) {
    has is_semi: bool = True;
}

# 1. Multiple isinstance checks - most specific wins
def test_and_most_specific(
    x: BaseNode
) -> None {
    if isinstance(x, BaseNode) and isinstance(x, CFGNode) {
        # x should be CFGNode here (most specific)
        x.bb_out;  # <-- Ok after narrowing (CFGNode has bb_out)
    }
}

# 2. Order doesn't matter - most specific wins
def test_and_order_independent(
    x: BaseNode
) -> None {
    if isinstance(x, CFGNode) and isinstance(x, BaseNode) {
        # x should be CFGNode here (most specific)
        x.bb_out;  # <-- Ok after narrowing
    }
}

# 3. With negative isinstance - positive wins for narrowing
def test_and_with_not_isinstance(
    x: BaseNode
) -> None {
    if isinstance(x, CFGNode) and not isinstance(x, SemiNode) {
        # x should be CFGNode here (SemiNode excluded but CFGNode is the narrowed type)
        x.bb_out;  # <-- Ok after narrowing
    }
}

# 4. Three-way inheritance narrowing
def test_and_three_types(x: BaseNode) -> None {
    if isinstance(x, BaseNode) and isinstance(x, CFGNode) and isinstance(x, SemiNode) {
        # x should be SemiNode here (most specific)
        x.is_semi;  # <-- Ok after narrowing (SemiNode has is_semi)
    }
}

# 5. Mixed with other conditions
def test_and_with_flag(x: BaseNode, flag: bool) -> None {
    if isinstance(x, CFGNode) and flag {
        # x should be CFGNode here
        x.bb_out;  # <-- Ok after narrowing
    }
}

# 6. Progressive narrowing - method call AFTER isinstance in same AND
def test_progressive_narrowing_method(
    x: BaseNode
) -> None {
    if isinstance(x, CFGNode) and x.bb_out {
        # x.bb_out sees x as CFGNode due to preceding isinstance
        return;  # Ok

    }
}

# 7. Progressive narrowing - multiple isinstance then method
def test_progressive_narrowing_multi(
    x: BaseNode
) -> None {
    if isinstance(x, BaseNode)
    and isinstance(x, CFGNode)
    and isinstance(x, SemiNode)
    and x.is_semi {
        # x.is_semi sees x as SemiNode (most specific)
        return;  # Ok

    }
}

# E1. After AND block, type reverts
def test_error_after_and_block(
    x: BaseNode
) -> list[CFGNode] | None {
    if isinstance(x, CFGNode) {
        return x.bb_out;  # Ok inside

    }
    return x.bb_out;  # <-- Error: BaseNode has no attribute bb_out

}
