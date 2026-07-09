import from jaclang.compiler.c2jac.tags { Tier, Mechanism }

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
