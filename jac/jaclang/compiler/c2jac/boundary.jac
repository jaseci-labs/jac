"""§5.3 2×2 routing table: C node type → (Tier, Mechanism).

default_tier  — TIER_A for the recognized-construct allowlist, TIER_B otherwise.
default_mechanism — DIRECT_IR for constructs with no faithful Python-AST analog
                    (C-for, Enum/Enumerator); PY_AST otherwise.

Note on Enum: tier is TIER_A regardless of verdict (both ENUM_AS_ENUM and
ENUM_AS_CONSTS are correct lowerings), but the idiom is NOT set here; the
enum_prepass (P1d) fills ENUM_AS_ENUM / ENUM_AS_CONSTS later.
"""

import from jaclang.compiler.c2jac.tags { Tier, Mechanism }

# Node type names that belong to Tier-A (recognized constructs).
glob _TIER_A_TYPES: set[str] = {
         "FileAST",
         "FuncDef",
         "FuncDecl",
         "Decl",
         "Assignment",
         "BinaryOp",
         "If",
         "While",
         "For",
         "Return",
         "Break",
         "Continue",
         "FuncCall",
         "ID",
         "Constant",
         "Enum",
         "Enumerator",
         "EnumeratorList",
         "Struct",
         "StructRef",
         "Typedef",
         "ArrayDecl",
         "ArrayRef",
         "InitList",
         "ParamList",
         "DeclList",
         "TypeDecl",
         "IdentifierType",
         "PtrDecl",
         "Typename",
         "Compound",
         "UnaryOp",
         "Cast",
         "ExprList",
         "NamedInitializer",

     },
     # Node types routed to the direct-IR builder (no faithful Python-AST analog).
     _DIRECT_IR_TYPES: set[str] = {"For", "Enum", "Enumerator", "EnumeratorList", };

def default_mechanism(c_node: object) -> Mechanism {
    tp = type(c_node).__name__;
    if tp in _DIRECT_IR_TYPES {
        return Mechanism.DIRECT_IR;
    }
    return Mechanism.PY_AST;
}

def default_tier(c_node: object) -> Tier {
    tp = type(c_node).__name__;
    if tp in _TIER_A_TYPES {
        return Tier.TIER_A;
    }
    return Tier.TIER_B;
}
