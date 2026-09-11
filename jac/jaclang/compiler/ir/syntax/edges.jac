import from jaclang.compiler.ir.base { UniNode }
import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
import from jaclang.compiler.ir.syntax.nodes {
    Ability,
    ArchHas,
    ArchSpec,
    Archetype,
    AssertStmt,
    AssignCompr,
    Assignment,
    AstAccessNode,
    AstAsyncNode,
    AstDocNode,
    AstElseBodyNode,
    AtomExpr,
    AwaitingClause,
    CastExpr,
    CfgExpr,
    CodeBlockStmt,
    CompareExpr,
    ConcurrentExpr,
    ConnectOp,
    CtrlStmt,
    DictCompr,
    DictVal,
    DisconnectOp,
    EdgeOpRef,
    EdgeRefTrailer,
    Enum,
    EventSignature,
    Except,
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
    JsxElement,
    KVPair,
    KWPair,
    ListCompr,
    MatchArch,
    MatchCase,
    MatchKVPair,
    MatchOr,
    MatchPattern,
    Module,
    ModulePath,
    MultiString,
    NameAtom,
    ParamVar,
    ProgramModule,
    PyInlineCode,
    RaiseStmt,
    Slice,
    String,
    SubTag,
    Test,
    Token,
    TryStmt,
    TypeParam,
    TypedCtxBlock,
    UnaryExpr,
    VisitStmt
}
import from jaclang.compiler.ir.types.syntax { AstTypedVarNode, Expr }

edge Role: UniNode --> UniNode {}

edge Kid: UniNode --> UniNode {}

edge AccessRole(Role): AstAccessNode --> SubTag {}

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

edge BaseClassesRole(Role): ArchSpec --> Expr {}

edge BodyRole(Role): UniNode --> UniNode {}

edge BoundRole(Role): TypeParam --> Expr {}

edge CasesRole(Role): CodeBlockStmt --> CodeBlockStmt {}

edge CastTypeRole(Role): CastExpr --> Expr {}

edge CauseRole(Role): RaiseStmt --> Expr {}

edge ChainRole(Role): EdgeRefTrailer --> Expr {}

edge ChildrenRole(Role): JsxElement --> UniNode {}

edge ClibDeclsRole(Role): Import --> UniNode {}

edge CodeRole(Role): PyInlineCode --> Token {}

edge CollectionRole(Role): AstAsyncNode --> Expr {}

edge ComparesRole(Role): FilterCompr --> Expr {}

edge ComprRole(Role): AtomExpr --> InnerCompr {}

edge ConditionRole(Role): UniNode --> Expr {}

edge ConditionalRole(Role): InnerCompr --> Expr {}

edge ConnAssignRole(Role): ConnectOp --> AssignCompr {}

edge ConnTypeRole(Role): ConnectOp --> Expr {}

edge CountByRole(Role): IterForStmt --> Assignment {}

edge CtrlRole(Role): CtrlStmt --> Token {}

edge DecoratorsRole(Role): CodeBlockStmt --> Expr {}

edge DefaultValRole(Role): TypeParam --> Expr {}

edge DescriptionRole(Role): Test --> String {}

edge DocRole(Role): AstDocNode --> String {}

edge DynamicTagRole(Role): JsxElement --> Expr {}

edge EdgeSpecRole(Role): DisconnectOp --> EdgeOpRef {}

edge ElseBodyRole(Role): AstElseBodyNode --> UniScopeNode {}

edge ElseValueRole(Role): IfElseExpr --> CfgExpr {}

edge EndRole(Role): FString --> Token {}

edge ErrorMsgRole(Role): AssertStmt --> Expr {}

edge EventRole(Role): EventSignature --> Token {}

edge ExTypeRole(Role): Except --> Expr {}

edge ExceptsRole(Role): TryStmt --> Except {}

edge ExprRole(Role): UniNode --> Expr {}

edge ExprsRole(Role): UniNode --> UniNode {}

edge FTypeRole(Role): FilterCompr --> Expr {}

edge FilterCondRole(Role): EdgeOpRef --> FilterCompr {}

edge FinallyBodyRole(Role): TryStmt --> FinallyStmt {}

edge FormatPartRole(Role): FormattedValue --> Expr {}

edge FormatSpecRole(Role): FormattedValue --> Expr {}

edge FromLocRole(Role): Import --> ModulePath {}

edge FromTargetRole(Role): RaiseStmt --> Expr {}

edge GuardRole(Role): MatchCase --> Expr {}

edge HintRole(Role): Import --> SubTag {}

edge InsertLocRole(Role): VisitStmt --> Expr {}

edge ItemsRole(Role): Import --> UniNode {}

edge IterRole(Role): IterForStmt --> Assignment {}

edge KeyRole(Role): UniNode --> UniNode {}

edge KeywordsRole(Role): Archetype --> KWPair {}

edge KvPairRole(Role): DictCompr --> KVPair {}

edge KvPairsRole(Role): DictVal --> KVPair {}

edge KwPatternsRole(Role): MatchArch --> MatchKVPair {}

edge KwargsRole(Role): FuncSignature --> ParamVar {}

edge KwonlyargsRole(Role): FuncSignature --> ParamVar {}

edge LeftRole(Role): Expr --> Expr {}

edge MainRole(Role): ProgramModule --> Module {}

edge NameRole(Role): UniNode --> UniNode {}

edge NameRefRole(Role): Ability --> NameAtom {}

edge OpRole(Role): Expr --> UniNode {}

edge OperandRole(Role): UnaryExpr --> Expr {}

edge OpsRole(Role): CompareExpr --> Token {}

edge OutExprRole(Role): ListCompr --> Expr {}

edge ParamsRole(Role): UniNode --> UniNode {}

edge PartsRole(Role): UniNode --> UniNode {}

edge PathRole(Role): ModulePath --> AtomExpr {}

edge PatternRole(Role): UniNode --> MatchPattern {}

edge PatternsRole(Role): MatchOr --> MatchPattern {}

edge PosonlyParamsRole(Role): FuncSignature --> ParamVar {}

edge ReturnTypeRole(Role): FuncSignature --> Expr {}

edge RightRole(Role): Expr --> Expr {}

edge RightsRole(Role): CompareExpr --> Expr {}

edge SignatureRole(Role): UniScopeNode --> UniNode {}

edge SlicesRole(Role): IndexSlice --> Slice {}

edge SpecRole(Role): ImplDef --> UniNode {}

edge SrcEndpointRole(Role): Archetype --> Expr {}

edge StartRole(Role): UniNode --> UniNode {}

edge StepRole(Role): Slice --> Expr {}

edge StopRole(Role): Slice --> Expr {}

edge StringsRole(Role): MultiString --> AtomExpr {}

edge TargetRole(Role): UniNode --> Expr {}

edge TgtEndpointRole(Role): Archetype --> Expr {}

edge TokRole(Role): ConcurrentExpr --> Token {}

edge TypeCtxRole(Role): TypedCtxBlock --> Expr {}

edge TypeParamsRole(Role): CodeBlockStmt --> TypeParam {}

edge TypeTagRole(Role): AstTypedVarNode --> SubTag {}

edge UnpackRole(Role): ParamVar --> Token {}

edge ValueRole(Role): UniNode --> UniNode {}

edge ValueTypeRole(Role): Enum --> Expr {}

edge ValuesRole(Role): UniNode --> UniNode {}

edge VarargsRole(Role): FuncSignature --> ParamVar {}

edge VarsRole(Role): ArchHas --> HasVar {}
