"""P0.5 phase-exit: assert the 2×2 (tier, mechanism) boundary table for one
representative node of each §5.3 cell."""

import from pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }

def _make_node(cls: type) -> object {
    return cls.__new__(cls);
}

test "For maps to TIER_A DIRECT_IR" {
    nd = _make_node(c_ast.For);
    assert default_tier(nd) == Tier.TIER_A;
    assert default_mechanism(nd) == Mechanism.DIRECT_IR;
}

test "Enum maps to TIER_A DIRECT_IR idiom deferred" {
    nd = _make_node(c_ast.Enum);
    assert default_tier(nd) == Tier.TIER_A;
    assert default_mechanism(nd) == Mechanism.DIRECT_IR;
    # Idiom is not set at boundary time — that's enum_prepass.
}

test "If maps to TIER_A PY_AST" {
    nd = _make_node(c_ast.If);
    assert default_tier(nd) == Tier.TIER_A;
    assert default_mechanism(nd) == Mechanism.PY_AST;
}

test "While maps to TIER_A PY_AST" {
    nd = _make_node(c_ast.While);
    assert default_tier(nd) == Tier.TIER_A;
    assert default_mechanism(nd) == Mechanism.PY_AST;
}

test "Struct maps to TIER_A PY_AST" {
    nd = _make_node(c_ast.Struct);
    assert default_tier(nd) == Tier.TIER_A;
    assert default_mechanism(nd) == Mechanism.PY_AST;
}

test "FuncDef maps to TIER_A PY_AST" {
    nd = _make_node(c_ast.FuncDef);
    assert default_tier(nd) == Tier.TIER_A;
    assert default_mechanism(nd) == Mechanism.PY_AST;
}

test "Goto maps to TIER_B PY_AST (unsupported)" {
    nd = _make_node(c_ast.Goto);
    assert default_tier(nd) == Tier.TIER_B;
    assert default_mechanism(nd) == Mechanism.PY_AST;
}

test "Label maps to TIER_B PY_AST (unsupported)" {
    nd = _make_node(c_ast.Label);
    assert default_tier(nd) == Tier.TIER_B;
    assert default_mechanism(nd) == Mechanism.PY_AST;
}

test "Enumerator maps to TIER_A DIRECT_IR" {
    nd = _make_node(c_ast.Enumerator);
    assert default_tier(nd) == Tier.TIER_A;
    assert default_mechanism(nd) == Mechanism.DIRECT_IR;
}
