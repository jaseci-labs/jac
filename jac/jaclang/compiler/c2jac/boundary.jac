import from jaclang.compiler.c2jac.tags { Tier, Mechanism }
import from jaclang.vendor.pycparser { c_ast }

glob _DIRECT_IR_TYPES: tuple = (
         c_ast.For,
         c_ast.Enum,
         c_ast.Enumerator,
         c_ast.EnumeratorList,

     );

def default_mechanism(c_node: object) -> Mechanism {
    if isinstance(c_node, _DIRECT_IR_TYPES) {
        return Mechanism.DIRECT_IR;
    }
    return Mechanism.PY_AST;
}

def default_tier(c_node: object) -> Tier {
    return Tier.TIER_B;
}
