import type from jaclang.compiler.frontend.unitree {
    Ability,
    AstTypedVarNode,
    ConditionalNode,
    ContextAwareNode,
    Expr,
    FuncCall,
    Import,
    Module,
    NameAtom,
    Symbol,
    UniCFGNode,
    UniScopeNode
}
import type from jaclang.compiler.types.types {
    ClassDetailsPrivate,
    ClassDetailsShared,
    ClassType,
    EnumMemberInfo,
    EnumMemberType,
    FunctionType,
    ModuleType,
    OverloadedType,
    Parameter,
    TypeBase,
    TypeVarType,
    UnionType
}

edge SymOf: NameAtom --> Symbol {}

edge Defines: Symbol --> NameAtom {}

edge Uses: Symbol --> NameAtom {}

edge InScope: UniScopeNode --> Symbol {}

edge ScopePrimary: UniScopeNode --> Symbol {}

edge ScopeOverload: UniScopeNode --> Symbol {}

edge ScopeChild: UniScopeNode --> UniScopeNode {}

edge ScopeParent: UniScopeNode --> UniScopeNode {}

edge CfgSucc: UniCFGNode --> UniCFGNode {}

edge CfgTrue: ConditionalNode --> UniCFGNode {}

edge CfgFalse: ConditionalNode --> UniCFGNode {}

edge PlacedIn: ContextAwareNode --> Codespace {}

edge DecidedCodespace: Module --> Codespace {}

edge CalleeDecl: FuncCall --> Ability {}

edge Absorbs: Import --> Module {}

node Codespace {
    has kind: str = "";
}

glob _CODESPACES: dict[str, Codespace] = {
         "server": Codespace(kind="server"),
         "client": Codespace(kind="client"),
         "native": Codespace(kind="native")
     };

def codespace_node(kind: str) -> Codespace {
    found = _CODESPACES.get(kind);
    if found is None {
        found = Codespace(kind=kind);
        _CODESPACES[kind] = found;
    }
    return found;
}

edge TypeOf: AstTypedVarNode | Expr --> TypeBase {}

edge NarrowedTypeOf: Expr --> TypeBase {}

edge EventTriggerOf: Ability --> TypeBase {}

edge SharedOf: ClassType --> ClassDetailsShared {}

edge PrivOf: ClassType --> ClassDetailsPrivate {}

edge BaseOf: ClassDetailsShared --> TypeBase {}

edge MroOf: ClassDetailsShared --> ClassType {}

edge TypeParamOf: ClassDetailsShared | FunctionType --> TypeVarType {}

edge TypeArgOf: ClassDetailsPrivate --> TypeBase {}

edge ParamOf: FunctionType --> Parameter {}

edge ReturnsOf: FunctionType --> TypeBase {}

edge GuardOf: FunctionType --> TypeBase {}

edge ParamTypeOf: Parameter --> TypeBase {}

edge ParamDefaultOf: Parameter --> Expr {}

edge UnionMemberOf: UnionType --> TypeBase {}

edge BoundOf: TypeVarType --> TypeBase {}

edge ConstraintOf: TypeVarType --> TypeBase {}

edge OverloadOf: OverloadedType --> FunctionType {}

edge EnumClassOf: EnumMemberType --> ClassType {}

edge ValueTypeOf: ClassDetailsShared | EnumMemberInfo --> TypeBase {}

edge MemberInfoOf: EnumMemberType --> EnumMemberInfo {}

edge TypeMemberOf: ClassDetailsShared --> TypeBase {
    has name: str = "";
}

edge EnumMemberOf: ClassDetailsShared --> EnumMemberInfo {
    has name: str = "";
}

edge DeclScopeOf: ClassDetailsShared | ModuleType --> UniScopeNode {}
