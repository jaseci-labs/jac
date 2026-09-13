import from jaclang.compiler.ir.symbols.nodes { ScopeBinding }
import from jaclang.compiler.ir.symbols.nodes {
    AstImplNeedingNode,
    Symbol,
    UniScopeNode
}
import from jaclang.compiler.ir.syntax.nodes {
    Ability,
    FuncCall,
    ImplDef,
    Import,
    Module,
    NameAtom
}

edge SymOf: NameAtom --> Symbol {}

edge Defines: Symbol --> NameAtom {}

edge Uses: Symbol --> NameAtom {}

edge InScope: UniScopeNode --> Symbol {}

edge ScopePrimary: UniScopeNode --> ScopeBinding {}

edge ScopeOverload: UniScopeNode --> ScopeBinding {}

edge BindingTarget: ScopeBinding --> Symbol {}

edge ScopeChild: UniScopeNode --> UniScopeNode {}

edge ScopeParent: UniScopeNode --> UniScopeNode {}

edge CalleeDecl: FuncCall --> Ability {}

edge Absorbs: Import --> Module {}

edge ImplOf: AstImplNeedingNode --> ImplDef {}
