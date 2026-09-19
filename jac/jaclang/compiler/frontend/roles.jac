import type from jaclang.compiler.frontend.unitree {
    Ability,
    ArchHas,
    Archetype,
    AssertStmt,
    AssignCompr,
    Assignment,
    AstAccessNode,
    AstDocNode,
    AstElseBodyNode,
    AstTypedVarNode,
    AtomTrailer,
    AwaitingClause,
    CastExpr,
    CfgExpr,
    CompareExpr,
    ConcurrentExpr,
    ConnectOp,
    CtrlStmt,
    DictCompr,
    DictVal,
    DisconnectOp,
    EdgeOpRef,
    EdgeRefTrailer,
    ElseIf,
    ElseStmt,
    Enum,
    EventSignature,
    Except,
    Expr,
    ExprAsItem,
    FString,
    FilterCompr,
    FinallyStmt,
    FormattedValue,
    FuncSignature,
    GlobalVars,
    HasVar,
    IfElseExpr,
    ImplDef,
    Import,
    IndexSlice,
    InnerCompr,
    IterForStmt,
    JsxAttribute,
    JsxChild,
    JsxElement,
    JsxElementName,
    KVPair,
    KWPair,
    ListCompr,
    MatchArch,
    MatchCase,
    MatchKVPair,
    MatchOr,
    MatchPattern,
    Module,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    NameAtom,
    ParamVar,
    ProgramModule,
    PyInlineCode,
    RaiseStmt,
    Slice,
    String,
    SubTag,
    SwitchCase,
    Test,
    Token,
    TryStmt,
    TypeParam,
    TypedCtxBlock,
    UnaryExpr,
    UniNode,
    VisitStmt
}

edge Role: UniNode --> UniNode {}

edge Kid: UniNode --> UniNode {}

edge ImplOf: UniNode --> UniNode {}

edge AccessRole(Role): AstAccessNode --> SubTag[Token] {}

edge AccessorsRole(Role): HasVar --> Ability {}

edge AliasRole(Role): UniNode --> Expr {}

edge ArchTagInfoRole(Role): EventSignature --> Expr {}

edge ArchTypeRole(Role): Archetype --> Token {}

edge ArgPatternsRole(Role): MatchArch --> MatchPattern {}

edge AssignmentsRole(Role): GlobalVars --> Assignment {}

edge AssignsRole(Role): AssignCompr --> KWPair {}

edge AttributesRole(Role): JsxElement --> JsxAttribute {}

edge AugOpRole(Role): Assignment --> Token {}

edge AwaitingBodyRole(Role): TryStmt --> AwaitingClause {}

edge BaseClassesRole(Role): UniNode --> Expr {}

edge BodyRole(Role): UniNode --> UniNode {}

edge BoundRole(Role): TypeParam --> Expr {}

edge CasesRole(Role): UniNode --> MatchCase | SwitchCase {}

edge CastTypeRole(Role): CastExpr --> Expr {}

edge CauseRole(Role): RaiseStmt --> Expr {}

edge ChainRole(Role): EdgeRefTrailer --> Expr {}

edge ChildrenRole(Role): JsxElement --> JsxChild | JsxElement {}

edge ClibDeclsRole(Role): Import --> UniNode {}

edge CodeRole(Role): PyInlineCode --> Token {}

edge CollectionRole(Role): UniNode --> Expr {}

edge ComparesRole(Role): FilterCompr --> Expr {}

edge ComprRole(Role): UniNode --> InnerCompr {}

edge ConditionRole(Role): UniNode --> Expr {}

edge ConditionalRole(Role): InnerCompr --> Expr {}

edge ConnAssignRole(Role): ConnectOp --> AssignCompr {}

edge ConnTypeRole(Role): ConnectOp --> Expr {}

edge CountByRole(Role): IterForStmt --> Assignment {}

edge CtrlRole(Role): CtrlStmt --> Token {}

edge DecoratorsRole(Role): UniNode --> Expr {}

edge DefaultValRole(Role): TypeParam --> Expr {}

edge DescriptionRole(Role): Test --> String {}

edge DocRole(Role): AstDocNode --> String {}

edge DynamicTagRole(Role): JsxElement --> Expr {}

edge EdgeSpecRole(Role): DisconnectOp --> EdgeOpRef {}

edge ElseBodyRole(Role): AstElseBodyNode --> ElseIf | ElseStmt {}

edge ElseValueRole(Role): IfElseExpr --> CfgExpr {}

edge EndRole(Role): FString --> Token {}

edge ErrorMsgRole(Role): AssertStmt --> Expr {}

edge EventRole(Role): EventSignature --> Token {}

edge ExTypeRole(Role): Except --> Expr {}

edge ExceptsRole(Role): TryStmt --> Except {}

edge ExprRole(Role): UniNode --> Expr {}

edge ExprsRole(Role): UniNode --> Expr | ExprAsItem {}

edge FTypeRole(Role): FilterCompr --> Expr {}

edge FilterCondRole(Role): EdgeOpRef --> FilterCompr {}

edge FinallyBodyRole(Role): TryStmt --> FinallyStmt {}

edge FormatPartRole(Role): FormattedValue --> Expr {}

edge FormatSpecRole(Role): FormattedValue --> Expr {}

edge FromLocRole(Role): Import --> ModulePath {}

edge FromTargetRole(Role): RaiseStmt --> Expr {}

edge GuardRole(Role): MatchCase --> Expr {}

edge HintRole(Role): Import --> SubTag[Token] {}

edge InsertLocRole(Role): VisitStmt --> Expr {}

edge ItemsRole(Role): Import --> ModuleItem | ModulePath {}

edge IterRole(Role): IterForStmt --> Assignment {}

edge KeyRole(Role): UniNode --> Expr | MatchPattern {}

edge KeywordsRole(Role): Archetype --> KWPair {}

edge KvPairRole(Role): DictCompr --> KVPair {}

edge KvPairsRole(Role): DictVal --> KVPair {}

edge KwPatternsRole(Role): MatchArch --> MatchKVPair {}

edge KwargsRole(Role): FuncSignature --> ParamVar {}

edge KwonlyargsRole(Role): FuncSignature --> ParamVar {}

edge LeftRole(Role): UniNode --> Expr {}

edge MainRole(Role): ProgramModule --> Module {}

edge NameRole(Role): UniNode --> AtomTrailer | JsxElementName | NameAtom | Token {}

edge NameRefRole(Role): Ability --> NameAtom {}

edge OpRole(Role): UniNode --> ConnectOp | DisconnectOp | Token {}

edge OperandRole(Role): UnaryExpr --> Expr {}

edge OpsRole(Role): CompareExpr --> Token {}

edge OutExprRole(Role): ListCompr --> Expr {}

edge ParamsRole(Role): UniNode --> Expr | KWPair | ParamVar {}

edge PartsRole(Role): UniNode --> FormattedValue | Token {}

edge PathRole(Role): ModulePath --> Name | String {}

edge PatternRole(Role): UniNode --> MatchPattern {}

edge PatternsRole(Role): MatchOr --> MatchPattern {}

edge PosonlyParamsRole(Role): FuncSignature --> ParamVar {}

edge ReturnTypeRole(Role): FuncSignature --> Expr {}

edge RightRole(Role): UniNode --> Expr {}

edge RightsRole(Role): CompareExpr --> Expr {}

edge SignatureRole(Role): UniNode --> EventSignature | FuncSignature {}

edge SlicesRole(Role): IndexSlice --> Slice {}

edge SpecRole(Role): ImplDef --> EventSignature | Expr | FuncSignature {}

edge SrcEndpointRole(Role): Archetype --> Expr {}

edge StartRole(Role): UniNode --> Expr | Token {}

edge StepRole(Role): Slice --> Expr {}

edge StopRole(Role): Slice --> Expr {}

edge StringsRole(Role): MultiString --> FString | String {}

edge TargetRole(Role): UniNode --> Expr {}

edge TgtEndpointRole(Role): Archetype --> Expr {}

edge TokRole(Role): ConcurrentExpr --> Token {}

edge TypeCtxRole(Role): TypedCtxBlock --> Expr {}

edge TypeParamsRole(Role): UniNode --> TypeParam {}

edge TypeTagRole(Role): AstTypedVarNode --> SubTag[Expr] {}

edge UnpackRole(Role): ParamVar --> Token {}

edge ValueRole(Role): UniNode --> Ability | Expr | MatchPattern | Token {}

edge ValueTypeRole(Role): Enum --> Expr {}

edge ValuesRole(Role): UniNode --> Expr | KWPair | MatchPattern {}

edge VarargsRole(Role): FuncSignature --> ParamVar {}

edge VarsRole(Role): ArchHas --> HasVar {}
