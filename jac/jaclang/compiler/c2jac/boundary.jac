"""§5.3 2×2 routing table: C node type → (Tier, Mechanism).

default_tier — TIER_A for the recognized-construct allowlist, TIER_B otherwise.
default_mechanism — DIRECT_IR for C-for/Enum/Enumerator (no faithful Python-AST analog).
Enum tier is always TIER_A; enum_prepass (P1d) sets the ENUM_AS_ENUM/ENUM_AS_CONSTS idiom.
"""

import from jaclang.compiler.c2jac.tags { Tier, Mechanism }
import from jaclang.vendor.pycparser { c_ast }

# Class refs (not string names) so a pycparser rename fails loudly at import.
# Some entries lower faithfully but would default-stamp Tier-B with an empty
# reason if omitted, presenting a faithful construct as a phantom best-effort
# site; their per-entry notes mark why they belong here.
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
         # Case/Default lower to faithful if/elif arms; the whole-switch verdict
         # (fall-through, selector purity) rides on the Switch node via c_Switch,
         # not each arm. Switch stays off the allowlist so an unhandled one
         # defaults to conservative Tier-B.
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
         c_ast.TernaryOp,  # `cond ? a : b` → Jac conditional expr (faithful).
         c_ast.Cast,
         c_ast.ExprList,
         c_ast.NamedInitializer,
         c_ast.EmptyStatement,  # bare `;` → Jac `pass` / dropped (no-op).
         # `...` → Jac `*args` (faithful); c_FuncDef demotes only a body that
         # actually reaches into the varargs.
         c_ast.EllipsisParam,

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
