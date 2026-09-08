import type from jaclang.compiler.frontend.unitree {
    Import,
    Module,
    NameAtom,
    Symbol,
    UniScopeNode
}

edge SymOf: NameAtom --> Symbol {}

edge Defines: Symbol --> NameAtom {}

edge Uses: Symbol --> NameAtom {}

edge InScope: UniScopeNode --> Symbol {}

edge ScopePrimary: UniScopeNode --> Symbol {}

edge ScopeOverload: UniScopeNode --> Symbol {}

edge ScopeChild: UniScopeNode --> UniScopeNode {}

edge ScopeParent: UniScopeNode --> UniScopeNode {}

edge CfgSucc {}

edge CfgTrue {}

edge CfgFalse {}

edge PlacedIn {}

edge DecidedCodespace {}

edge CalleeDecl {}

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

edge TypeOf {}

edge NarrowedTypeOf {}

edge EventTriggerOf {}

edge SharedOf {}

edge PrivOf {}

edge BaseOf {}

edge MroOf {}

edge TypeParamOf {}

edge TypeArgOf {}

edge ParamOf {}

edge ReturnsOf {}

edge GuardOf {}

edge ParamTypeOf {}

edge ParamDefaultOf {}

edge UnionMemberOf {}

edge BoundOf {}

edge ConstraintOf {}

edge OverloadOf {}

edge EnumClassOf {}

edge ValueTypeOf {}

edge MemberInfoOf {}

edge TypeMemberOf {
    has name: str = "";
}

edge EnumMemberOf {
    has name: str = "";
}

edge DeclScopeOf {}
