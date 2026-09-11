import from jaclang.compiler.ir.base { TypedNode }
import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
import from jaclang.compiler.ir.syntax.nodes { Ability }
import from jaclang.compiler.ir.types.nodes {
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
import from jaclang.compiler.ir.types.syntax { Expr }

edge TypeOf: TypedNode --> TypeBase {}

edge NarrowedTypeOf: Expr --> TypeBase {}

edge EventTriggerOf: Ability --> TypeBase {}

edge SharedOf: ClassType --> ClassDetailsShared {}

edge PrivOf: ClassType --> ClassDetailsPrivate {}

edge BaseOf: ClassDetailsShared --> TypeBase {}

edge MroOf: ClassDetailsShared --> ClassType {}

edge TypeParamOf: (ClassDetailsShared | FunctionType) --> TypeVarType {}

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

edge ValueTypeOf: (ClassDetailsShared | EnumMemberInfo) --> TypeBase {}

edge MemberInfoOf: EnumMemberType --> EnumMemberInfo {}

edge TypeMemberOf: ClassDetailsShared --> TypeBase {
    has name: str = "";
}

edge EnumMemberOf: ClassDetailsShared --> EnumMemberInfo {
    has name: str = "";
}

edge DeclScopeOf: (ModuleType | ClassDetailsShared) --> UniScopeNode {}
