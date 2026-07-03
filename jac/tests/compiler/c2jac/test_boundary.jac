"""P0.5 phase-exit: the default (Tier, Mechanism) boundary routing.

Tier is NOT class-derived: every node defaults to TIER_B (un-earned) and earns
Tier-A only when the mapper faithfully lowers it (CMapper._earn_tier_a), so these
pin the uniform default rather than a per-class allowlist. Mechanism IS class-
routed: only For/Enum are direct-IR roots (uni_builder/splice); Enumerator/
EnumeratorList are children of Enum and route PY_AST because they are never
lowered individually. Everything else is PY_AST.
"""

import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }

def _make_node(cls: type) -> object {
    return cls.__new__(cls);
}

test "every node defaults to TIER_B (Tier-A is earned at lowering, not by class)" {
    for cls in [
        c_ast.For,
        c_ast.Enum,
        c_ast.Enumerator,
        c_ast.If,
        c_ast.While,
        c_ast.Struct,
        c_ast.FuncDef,
        c_ast.Goto,
        c_ast.Label,
        c_ast.Constant
    ] {
        assert default_tier(_make_node(cls)) == Tier.TIER_B , f"{cls.__name__} should default to TIER_B (Tier-A is earned per lowering, not inherited from the class)";
    }
}

test "direct-IR mechanism is class-routed (For/Enum only)" {
    for cls in [c_ast.For, c_ast.Enum] {
        assert default_mechanism(_make_node(cls)) == Mechanism.DIRECT_IR , f"{cls.__name__} should route to the direct-IR builder";
    }
}

test "Enumerator/EnumeratorList are PY_AST (consumed under Enum, not spliced)" {
    for cls in [c_ast.Enumerator, c_ast.EnumeratorList] {
        assert default_mechanism(_make_node(cls)) == Mechanism.PY_AST , f"{cls.__name__} is never lowered individually";
    }
}

test "py-ast mechanism is the default (If/While/Struct/FuncDef/Goto/Label)" {
    for cls in [
        c_ast.If,
        c_ast.While,
        c_ast.Struct,
        c_ast.FuncDef,
        c_ast.Goto,
        c_ast.Label
    ] {
        assert default_mechanism(_make_node(cls)) == Mechanism.PY_AST , f"{cls.__name__} should route to PY_AST";
    }
}
