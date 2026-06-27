"""§5.3 2×2 routing table: C node type → (Tier, Mechanism).

default_tier — TIER_A for the recognized-construct allowlist, TIER_B otherwise.
default_mechanism — DIRECT_IR for C-for/Enum/Enumerator (no faithful Python-AST analog).
Enum tier is always TIER_A; enum_prepass (P1d) sets the ENUM_AS_ENUM/ENUM_AS_CONSTS idiom.
"""

import from jaclang.compiler.c2jac.tags { Tier, Mechanism }
import from jaclang.vendor.pycparser { c_ast }

# Class refs (not string names) so a pycparser rename fails loudly at import.
glob _TIER_A_TYPES: tuple = (
         c_ast.FileAST,
         c_ast.FuncDef,
         c_ast.FuncDecl,
         c_ast.Decl,
         c_ast.Assignment,
         c_ast.BinaryOp,
         c_ast.If,
         c_ast.While,
         c_ast.For,
         # Case/Default lower to faithful if/elif arms; the whole-switch
         # faithfulness verdict (fall-through, selector purity) is carried on the
         # Switch node by c_Switch, not on each arm. Switch itself stays off this
         # allowlist so an un-handled switch defaults to the conservative Tier-B.
         c_ast.Case,
         c_ast.Default,
         c_ast.Return,
         c_ast.Break,
         c_ast.Continue,
         c_ast.FuncCall,
         c_ast.ID,
         c_ast.Constant,
         c_ast.Enum,
         c_ast.Enumerator,
         c_ast.EnumeratorList,
         c_ast.Struct,
         c_ast.StructRef,
         c_ast.Typedef,
         c_ast.ArrayDecl,
         c_ast.ArrayRef,
         c_ast.InitList,
         c_ast.ParamList,
         c_ast.DeclList,
         c_ast.TypeDecl,
         c_ast.IdentifierType,
         c_ast.PtrDecl,
         c_ast.Typename,
         c_ast.Compound,
         c_ast.UnaryOp,
         # `cond ? a : b` lowers faithfully to a Jac conditional expression —
         # via the mapper (c_TernaryOp → uni.IfElseExpr) and the direct-IR
         # for-body path (_expr_to_uni). Without it on the allowlist the node
         # default-stamps Tier-B with an empty reason, presenting a faithful
         # ternary as a phantom best-effort site.
         c_ast.TernaryOp,
         c_ast.Cast,
         c_ast.ExprList,
         c_ast.NamedInitializer,
         # A bare `;` is a no-op with no lost semantics — the mapper lowers it to
         # a Jac `pass` (c_EmptyStatement) and the direct-IR for-body drops it
         # outright. Without it on the allowlist the node would default-stamp
         # Tier-B with an empty reason, presenting a do-nothing statement as a
         # phantom best-effort site (mirrors the TernaryOp note above).
         c_ast.EmptyStatement,

     ),
     # Node classes routed to the direct-IR builder (no faithful Python-AST analog).
     _DIRECT_IR_TYPES: tuple = (
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
    if isinstance(c_node, _TIER_A_TYPES) {
        return Tier.TIER_A;
    }
    return Tier.TIER_B;
}
