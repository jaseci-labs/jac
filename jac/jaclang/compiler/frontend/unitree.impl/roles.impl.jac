import from collections.abc { Sequence }

import from jaclang.compiler.frontend.roles {
    ImplOf,
    AccessRole,
    AccessorsRole,
    AliasRole,
    ArchTagInfoRole,
    ArchTypeRole,
    ArgPatternsRole,
    AssignmentsRole,
    AssignsRole,
    AttributesRole,
    AugOpRole,
    AwaitingBodyRole,
    BaseClassesRole,
    BodyRole,
    BoundRole,
    CasesRole,
    CastTypeRole,
    CauseRole,
    ChainRole,
    ChildrenRole,
    ClibDeclsRole,
    CodeRole,
    CollectionRole,
    ComparesRole,
    ComprRole,
    ConditionRole,
    ConditionalRole,
    ConnAssignRole,
    ConnTypeRole,
    CountByRole,
    CtrlRole,
    DecoratorsRole,
    DefaultValRole,
    DescriptionRole,
    DocRole,
    DynamicTagRole,
    EdgeSpecRole,
    ElseBodyRole,
    ElseValueRole,
    EndRole,
    ErrorMsgRole,
    EventRole,
    ExTypeRole,
    ExceptsRole,
    ExprRole,
    ExprsRole,
    FTypeRole,
    FilterCondRole,
    FinallyBodyRole,
    FormatPartRole,
    FormatSpecRole,
    FromLocRole,
    FromTargetRole,
    GuardRole,
    HintRole,
    InsertLocRole,
    ItemsRole,
    IterRole,
    KeyRole,
    KeywordsRole,
    KvPairRole,
    KvPairsRole,
    KwPatternsRole,
    KwargsRole,
    KwonlyargsRole,
    LeftRole,
    MainRole,
    NameRole,
    NameRefRole,
    OpRole,
    OperandRole,
    OpsRole,
    OutExprRole,
    ParamsRole,
    PartsRole,
    PathRole,
    PatternRole,
    PatternsRole,
    PosonlyParamsRole,
    ReturnTypeRole,
    RightRole,
    RightsRole,
    SignatureRole,
    SlicesRole,
    SpecRole,
    SrcEndpointRole,
    StartRole,
    StepRole,
    StopRole,
    StringsRole,
    TargetRole,
    TgtEndpointRole,
    TokRole,
    TypeCtxRole,
    TypeParamsRole,
    TypeTagRole,
    UnpackRole,
    ValueRole,
    ValueTypeRole,
    ValuesRole,
    VarargsRole,
    VarsRole
}

impl UniNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstSymbolNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstSymbolStubNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstAccessNode.access.getter -> (SubTag[Token] | None) {
    found = [self->:AccessRole:->];
    return found[0] if found else None;
}

impl AstAccessNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ContextAwareNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstDocNode.doc.getter -> (String | None) {
    found = [self->:DocRole:->];
    return found[0] if found else None;
}

impl AstDocNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstAsyncNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstElseBodyNode.else_body.getter -> (ElseStmt | ElseIf | None) {
    found = [self->:ElseBodyRole:->];
    return found[0] if found else None;
}

impl AstElseBodyNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstTypedVarNode.type_tag.getter -> (SubTag[Expr] | None) {
    found = [self->:TypeTagRole:->];
    return found[0] if found else None;
}

impl AstTypedVarNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl WalkerStmtOnlyNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl UniCFGNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ConditionalNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Expr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CfgExpr.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl CfgExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EnumBlockStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CodeBlockStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstImplNeedingNode.body.getter -> (Sequence[UniNode] | UniNode | None) {
    impl_of = [self->:ImplOf:->];
    if impl_of {
        return impl_of[0];
    }
    return self._role_shaped(BodyRole, [self->:BodyRole:->]);
}

impl AstImplNeedingNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl NameAtom.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ArchSpec.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl ArchSpec.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl SubTag.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Module.body.getter -> Sequence[ElementStmt | String | EmptyToken] {
    return [self->:BodyRole:->];
}

impl Module.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ProgramModule.main.getter -> Module {
    return [self->:MainRole:->][0];
}

impl ProgramModule.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TypeParam.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl TypeParam.bound.getter -> (Expr | None) {
    found = [self->:BoundRole:->];
    return found[0] if found else None;
}

impl TypeParam.default_val.getter -> (Expr | None) {
    found = [self->:DefaultValRole:->];
    return found[0] if found else None;
}

impl TypeParam.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TypeAlias.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl TypeAlias.type_params.getter -> list[TypeParam] {
    return [self->:TypeParamsRole:->][?:TypeParam];
}

impl TypeAlias.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl TypeAlias.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl GlobalVars.assignments.getter -> Sequence[Assignment] {
    return [self->:AssignmentsRole:->];
}

impl GlobalVars.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Test.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl Test.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl Test.description.getter -> (String | None) {
    found = [self->:DescriptionRole:->];
    return found[0] if found else None;
}

impl Test.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl Test.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ModuleCode.name.getter -> (Name | None) {
    found = [self->:NameRole:->];
    return found[0] if found else None;
}

impl ModuleCode.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl ModuleCode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl PyInlineCode.code.getter -> Token {
    return [self->:CodeRole:->][0];
}

impl PyInlineCode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Import.from_loc.getter -> (ModulePath | None) {
    found = [self->:FromLocRole:->];
    return found[0] if found else None;
}

impl Import.items.getter -> Sequence[(ModuleItem | ModulePath)] {
    return [self->:ItemsRole:->];
}

impl Import.clib_decls.getter -> (Sequence[UniNode] | None) {
    return [self->:ClibDeclsRole:->];
}

impl Import.hint.getter -> (SubTag[Token] | None) {
    found = [self->:HintRole:->];
    return found[0] if found else None;
}

impl Import.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ModulePath.path.getter -> (Sequence[(Name | String)] | None) {
    return [self->:PathRole:->];
}

impl ModulePath.alias.getter -> (Name | None) {
    found = [self->:AliasRole:->];
    return found[0] if found else None;
}

impl ModulePath.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ModuleItem.name.getter -> (Name | Token) {
    return [self->:NameRole:->][0];
}

impl ModuleItem.alias.getter -> (Name | None) {
    found = [self->:AliasRole:->];
    return found[0] if found else None;
}

impl ModuleItem.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Archetype.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl Archetype.arch_type.getter -> Token {
    return [self->:ArchTypeRole:->][0];
}

impl Archetype.base_classes.getter -> list[Expr] {
    return [self->:BaseClassesRole:->][?:Expr];
}

impl Archetype.keywords.getter -> (Sequence[KWPair] | None) {
    return [self->:KeywordsRole:->];
}

impl Archetype.type_params.getter -> list[TypeParam] {
    return [self->:TypeParamsRole:->][?:TypeParam];
}

impl Archetype.src_endpoint.getter -> (Expr | None) {
    found = [self->:SrcEndpointRole:->];
    return found[0] if found else None;
}

impl Archetype.tgt_endpoint.getter -> (Expr | None) {
    found = [self->:TgtEndpointRole:->];
    return found[0] if found else None;
}

impl Archetype.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ImplDef.decl_link.getter -> (UniNode | None) {
    found = [self<-:ImplOf:<-];
    return found[0] if found else None;
}

impl ImplDef.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl ImplDef.target.getter -> Sequence[NameAtom] {
    return [self->:TargetRole:->];
}

impl ImplDef.spec.getter -> (Sequence[Expr] | FuncSignature | EventSignature | None) {
    return self._role_shaped(SpecRole, [self->:SpecRole:->]);
}

impl ImplDef.body.getter -> Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr {
    return self._role_shaped(BodyRole, [self->:BodyRole:->]);
}

impl ImplDef.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl SemDef.target.getter -> Sequence[NameAtom] {
    return [self->:TargetRole:->];
}

impl SemDef.value.getter -> MultiString {
    return [self->:ValueRole:->][0];
}

impl SemDef.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl Enum.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl Enum.value_type.getter -> (Expr | None) {
    found = [self->:ValueTypeRole:->];
    return found[0] if found else None;
}

impl Enum.base_classes.getter -> list[Expr] {
    return [self->:BaseClassesRole:->][?:Expr];
}

impl Enum.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl Ability.name_ref.getter -> (NameAtom | None) {
    found = [self->:NameRefRole:->];
    return found[0] if found else None;
}

impl Ability.signature.getter -> FuncSignature | EventSignature | None {
    found = [self->:SignatureRole:->];
    return found[0] if found else None;
}

impl Ability.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl Ability.type_params.getter -> list[TypeParam] {
    return [self->:TypeParamsRole:->][?:TypeParam];
}

impl Ability.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl FuncSignature.posonly_params.getter -> Sequence[ParamVar] {
    return [self->:PosonlyParamsRole:->];
}

impl FuncSignature.params.getter -> (Sequence[ParamVar] | None) {
    return [self->:ParamsRole:->];
}

impl FuncSignature.varargs.getter -> (ParamVar | None) {
    found = [self->:VarargsRole:->];
    return found[0] if found else None;
}

impl FuncSignature.kwonlyargs.getter -> Sequence[ParamVar] {
    return [self->:KwonlyargsRole:->];
}

impl FuncSignature.kwargs.getter -> (ParamVar | None) {
    found = [self->:KwargsRole:->];
    return found[0] if found else None;
}

impl FuncSignature.return_type.getter -> (Expr | None) {
    found = [self->:ReturnTypeRole:->];
    return found[0] if found else None;
}

impl FuncSignature.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EventSignature.event.getter -> Token {
    return [self->:EventRole:->][0];
}

impl EventSignature.arch_tag_info.getter -> (Expr | None) {
    found = [self->:ArchTagInfoRole:->];
    return found[0] if found else None;
}

impl EventSignature.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ParamVar.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl ParamVar.unpack.getter -> (Token | None) {
    found = [self->:UnpackRole:->];
    return found[0] if found else None;
}

impl ParamVar.value.getter -> (Expr | None) {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl ParamVar.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ArchHas.vars.getter -> Sequence[HasVar] {
    return [self->:VarsRole:->];
}

impl ArchHas.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl HasVar.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl HasVar.value.getter -> (Expr | None) {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl HasVar.accessors.getter -> (Sequence[Ability] | None) {
    return self._role_shaped(AccessorsRole, [self->:AccessorsRole:->]);
}

impl HasVar.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TypedCtxBlock.type_ctx.getter -> Expr {
    return [self->:TypeCtxRole:->][0];
}

impl TypedCtxBlock.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl TypedCtxBlock.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl OpenStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl OpenStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl OpenStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl IfStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl IfStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl IfStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ElseIf.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ElseStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl ElseStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ExprStmt.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl ExprStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TryStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl TryStmt.excepts.getter -> Sequence[Except] {
    return [self->:ExceptsRole:->];
}

impl TryStmt.awaiting_body.getter -> (AwaitingClause | None) {
    found = [self->:AwaitingBodyRole:->];
    return found[0] if found else None;
}

impl TryStmt.finally_body.getter -> (FinallyStmt | None) {
    found = [self->:FinallyBodyRole:->];
    return found[0] if found else None;
}

impl TryStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl AwaitingClause.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl AwaitingClause.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl Except.ex_type.getter -> Expr {
    return [self->:ExTypeRole:->][0];
}

impl Except.name.getter -> (Name | None) {
    found = [self->:NameRole:->];
    return found[0] if found else None;
}

impl Except.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl Except.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl FinallyStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl FinallyStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl IterForStmt.iter.getter -> Assignment {
    return [self->:IterRole:->][0];
}

impl IterForStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl IterForStmt.count_by.getter -> Assignment {
    return [self->:CountByRole:->][0];
}

impl IterForStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl IterForStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl InForStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl InForStmt.collection.getter -> Expr {
    return [self->:CollectionRole:->][0];
}

impl InForStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl InForStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl WhileStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl WhileStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl WhileStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ForeverStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl ForeverStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl WithStmt.exprs.getter -> Sequence[ExprAsItem] {
    return [self->:ExprsRole:->];
}

impl WithStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl WithStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ExprAsItem.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl ExprAsItem.alias.getter -> (Expr | None) {
    found = [self->:AliasRole:->];
    return found[0] if found else None;
}

impl ExprAsItem.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl RaiseStmt.cause.getter -> (Expr | None) {
    found = [self->:CauseRole:->];
    return found[0] if found else None;
}

impl RaiseStmt.from_target.getter -> (Expr | None) {
    found = [self->:FromTargetRole:->];
    return found[0] if found else None;
}

impl RaiseStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AssertStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl AssertStmt.error_msg.getter -> (Expr | None) {
    found = [self->:ErrorMsgRole:->];
    return found[0] if found else None;
}

impl AssertStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CtrlStmt.ctrl.getter -> Token {
    return [self->:CtrlRole:->][0];
}

impl CtrlStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DeleteStmt.targets.getter -> list[Expr] {
    return [self->:TargetRole:->];
}

impl DeleteStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ReportStmt.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl ReportStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ReturnStmt.expr.getter -> (Expr | None) {
    found = [self->:ExprRole:->];
    return found[0] if found else None;
}

impl ReturnStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl VisitStmt.insert_loc.getter -> (Expr | None) {
    found = [self->:InsertLocRole:->];
    return found[0] if found else None;
}

impl VisitStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl VisitStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DisengageStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AwaitExpr.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl AwaitExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CastExpr.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl CastExpr.cast_type.getter -> Expr {
    return [self->:CastTypeRole:->][0];
}

impl CastExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Assignment.target.getter -> Sequence[Expr] {
    return [self->:TargetRole:->];
}

impl Assignment.value.getter -> Expr | YieldExpr | None {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl Assignment.aug_op.getter -> (Token | None) {
    found = [self->:AugOpRole:->];
    return found[0] if found else None;
}

impl Assignment.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ConcurrentExpr.tok.getter -> (Token | None) {
    found = [self->:TokRole:->];
    return found[0] if found else None;
}

impl ConcurrentExpr.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl ConcurrentExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl BinaryExpr.left.getter -> Expr {
    return [self->:LeftRole:->][0];
}

impl BinaryExpr.right.getter -> Expr {
    return [self->:RightRole:->][0];
}

impl BinaryExpr.op.getter -> Token | DisconnectOp | ConnectOp {
    return [self->:OpRole:->][0];
}

impl BinaryExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CompareExpr.left.getter -> Expr {
    return [self->:LeftRole:->][0];
}

impl CompareExpr.rights.getter -> list[Expr] {
    return [self->:RightsRole:->];
}

impl CompareExpr.ops.getter -> list[Token] {
    return [self->:OpsRole:->];
}

impl CompareExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl BoolExpr.op.getter -> Token {
    return [self->:OpRole:->][0];
}

impl BoolExpr.values.getter -> list[CfgExpr] {
    return [self->:ValuesRole:->];
}

impl BoolExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl LambdaExpr.body.getter -> (Expr | Sequence[CodeBlockStmt]) {
    return self._role_shaped(BodyRole, [self->:BodyRole:->]);
}

impl LambdaExpr.signature.getter -> (FuncSignature | None) {
    found = [self->:SignatureRole:->];
    return found[0] if found else None;
}

impl LambdaExpr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl UnaryExpr.operand.getter -> Expr {
    return [self->:OperandRole:->][0];
}

impl UnaryExpr.op.getter -> Token {
    return [self->:OpRole:->][0];
}

impl UnaryExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl IfElseExpr.condition.getter -> CfgExpr {
    return [self->:ConditionRole:->][0];
}

impl IfElseExpr.value.getter -> CfgExpr {
    return [self->:ValueRole:->][0];
}

impl IfElseExpr.else_value.getter -> CfgExpr {
    return [self->:ElseValueRole:->][0];
}

impl IfElseExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MultiString.strings.getter -> Sequence[(String | FString)] {
    return [self->:StringsRole:->];
}

impl MultiString.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FString.start.getter -> (Token | None) {
    found = [self->:StartRole:->];
    return found[0] if found else None;
}

impl FString.parts.getter -> Sequence[(String | FormattedValue)] {
    return [self->:PartsRole:->];
}

impl FString.end.getter -> (Token | None) {
    found = [self->:EndRole:->];
    return found[0] if found else None;
}

impl FString.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FormattedValue.format_part.getter -> Expr {
    return [self->:FormatPartRole:->][0];
}

impl FormattedValue.format_spec.getter -> (Expr | None) {
    found = [self->:FormatSpecRole:->];
    return found[0] if found else None;
}

impl FormattedValue.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ListVal.values.getter -> Sequence[Expr] {
    return [self->:ValuesRole:->];
}

impl ListVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl SetVal.values.getter -> (Sequence[Expr] | None) {
    return [self->:ValuesRole:->];
}

impl SetVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TupleVal.values.getter -> Sequence[(Expr | KWPair)] {
    return [self->:ValuesRole:->];
}

impl TupleVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DictVal.kv_pairs.getter -> Sequence[KVPair] {
    return [self->:KvPairsRole:->];
}

impl DictVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl KVPair.key.getter -> (Expr | None) {
    found = [self->:KeyRole:->];
    return found[0] if found else None;
}

impl KVPair.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl KVPair.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl KWPair.key.getter -> (NameAtom | None) {
    found = [self->:KeyRole:->];
    return found[0] if found else None;
}

impl KWPair.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl KWPair.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl InnerCompr.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl InnerCompr.collection.getter -> Expr {
    return [self->:CollectionRole:->][0];
}

impl InnerCompr.conditional.getter -> (list[Expr] | None) {
    return [self->:ConditionalRole:->];
}

impl InnerCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ListCompr.out_expr.getter -> Expr {
    return [self->:OutExprRole:->][0];
}

impl ListCompr.compr.getter -> list[InnerCompr] {
    return [self->:ComprRole:->];
}

impl ListCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl GenCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl SetCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl DictCompr.kv_pair.getter -> KVPair {
    return [self->:KvPairRole:->][0];
}

impl DictCompr.compr.getter -> list[InnerCompr] {
    return [self->:ComprRole:->];
}

impl DictCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl AtomTrailer.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl AtomTrailer.right.getter -> (AtomExpr | Expr) {
    return [self->:RightRole:->][0];
}

impl AtomTrailer.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AtomUnit.value.getter -> Expr | YieldExpr | Ability {
    return [self->:ValueRole:->][0];
}

impl AtomUnit.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl YieldExpr.expr.getter -> (Expr | None) {
    found = [self->:ExprRole:->];
    return found[0] if found else None;
}

impl YieldExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FuncCall.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl FuncCall.params.getter -> (Sequence[(Expr | KWPair)] | None) {
    return [self->:ParamsRole:->];
}

impl FuncCall.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Slice.start.getter -> (Expr | None) {
    found = [self->:StartRole:->];
    return found[0] if found else None;
}

impl Slice.stop.getter -> (Expr | None) {
    found = [self->:StopRole:->];
    return found[0] if found else None;
}

impl Slice.step.getter -> (Expr | None) {
    found = [self->:StepRole:->];
    return found[0] if found else None;
}

impl Slice.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl IndexSlice.slices.getter -> list[Slice] {
    return [self->:SlicesRole:->];
}

impl IndexSlice.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EdgeRefTrailer.chain.getter -> list[(Expr | FilterCompr)] {
    return [self->:ChainRole:->];
}

impl EdgeRefTrailer.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EdgeOpRef.filter_cond.getter -> (FilterCompr | None) {
    found = [self->:FilterCondRole:->];
    return found[0] if found else None;
}

impl EdgeOpRef.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DisconnectOp.edge_spec.getter -> EdgeOpRef {
    return [self->:EdgeSpecRole:->][0];
}

impl DisconnectOp.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ConnectOp.conn_type.getter -> (Expr | None) {
    found = [self->:ConnTypeRole:->];
    return found[0] if found else None;
}

impl ConnectOp.conn_assign.getter -> (AssignCompr | None) {
    found = [self->:ConnAssignRole:->];
    return found[0] if found else None;
}

impl ConnectOp.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FilterCompr.f_type.getter -> (Expr | None) {
    found = [self->:FTypeRole:->];
    return found[0] if found else None;
}

impl FilterCompr.compares.getter -> Sequence[Expr] {
    return [self->:ComparesRole:->];
}

impl FilterCompr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AssignCompr.assigns.getter -> Sequence[KWPair] {
    return [self->:AssignsRole:->];
}

impl AssignCompr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxElement.name.getter -> (JsxElementName | None) {
    found = [self->:NameRole:->];
    return found[0] if found else None;
}

impl JsxElement.attributes.getter -> (Sequence[JsxAttribute] | None) {
    return [self->:AttributesRole:->];
}

impl JsxElement.children.getter -> (Sequence[(JsxChild | JsxElement)] | None) {
    return [self->:ChildrenRole:->];
}

impl JsxElement.dynamic_tag.getter -> (Expr | None) {
    found = [self->:DynamicTagRole:->];
    return found[0] if found else None;
}

impl JsxElement.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxElementName.parts.getter -> Sequence[(Name | Token)] {
    return [self->:PartsRole:->];
}

impl JsxElementName.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxAttribute.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxSpreadAttribute.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl JsxSpreadAttribute.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxNormalAttribute.name.getter -> (Name | Token) {
    return [self->:NameRole:->][0];
}

impl JsxNormalAttribute.value.getter -> String | Expr | None {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl JsxNormalAttribute.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxChild.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxText.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxExpression.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl JsxExpression.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxSlot.body.getter -> list[UniNode] {
    return [self->:BodyRole:->];
}

impl JsxSlot.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxComment.value.getter -> Token {
    return [self->:ValueRole:->][0];
}

impl JsxComment.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl MatchStmt.cases.getter -> list[MatchCase] {
    return [self->:CasesRole:->];
}

impl MatchStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchCase.pattern.getter -> MatchPattern {
    return [self->:PatternRole:->][0];
}

impl MatchCase.guard.getter -> (Expr | None) {
    found = [self->:GuardRole:->];
    return found[0] if found else None;
}

impl MatchCase.body.getter -> list[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl MatchCase.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl SwitchStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl SwitchStmt.cases.getter -> list[SwitchCase] {
    return [self->:CasesRole:->];
}

impl SwitchStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl SwitchCase.pattern.getter -> (MatchPattern | None) {
    found = [self->:PatternRole:->];
    return found[0] if found else None;
}

impl SwitchCase.body.getter -> list[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl SwitchCase.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl MatchOr.patterns.getter -> list[MatchPattern] {
    return [self->:PatternsRole:->];
}

impl MatchOr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchAs.name.getter -> NameAtom {
    return [self->:NameRole:->][0];
}

impl MatchAs.pattern.getter -> (MatchPattern | None) {
    found = [self->:PatternRole:->];
    return found[0] if found else None;
}

impl MatchAs.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchWild.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchValue.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl MatchValue.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchSingleton.value.getter -> (Bool | Null) {
    return [self->:ValueRole:->][0];
}

impl MatchSingleton.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchSequence.values.getter -> list[MatchPattern] {
    return [self->:ValuesRole:->];
}

impl MatchSequence.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchMapping.values.getter -> list[(MatchKVPair | MatchStar)] {
    return [self->:ValuesRole:->];
}

impl MatchMapping.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchKVPair.key.getter -> MatchPattern | NameAtom | AtomExpr {
    return [self->:KeyRole:->][0];
}

impl MatchKVPair.value.getter -> MatchPattern {
    return [self->:ValueRole:->][0];
}

impl MatchKVPair.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchStar.name.getter -> NameAtom {
    return [self->:NameRole:->][0];
}

impl MatchStar.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchArch.name.getter -> (AtomTrailer | NameAtom) {
    return [self->:NameRole:->][0];
}

impl MatchArch.arg_patterns.getter -> (Sequence[MatchPattern] | None) {
    return [self->:ArgPatternsRole:->];
}

impl MatchArch.kw_patterns.getter -> (Sequence[MatchKVPair] | None) {
    return [self->:KwPatternsRole:->];
}

impl MatchArch.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Name.__repr__ -> str {
    return Token.__repr__(self);
}

impl SpecialVarRef.__repr__ -> str {
    return Token.__repr__(self);
}

impl Literal.__repr__ -> str {
    return Token.__repr__(self);
}

impl BuiltinType.__repr__ -> str {
    return Token.__repr__(self);
}

impl Float.__repr__ -> str {
    return Token.__repr__(self);
}

impl Int.__repr__ -> str {
    return Token.__repr__(self);
}

impl String.__repr__ -> str {
    return Token.__repr__(self);
}

impl Bool.__repr__ -> str {
    return Token.__repr__(self);
}

impl Null.__repr__ -> str {
    return Token.__repr__(self);
}

impl Ellipsis.__repr__ -> str {
    return Token.__repr__(self);
}

impl EmptyToken.__repr__ -> str {
    return Token.__repr__(self);
}

impl Semi.__repr__ -> str {
    return Token.__repr__(self);
}

impl CommentToken.__repr__ -> str {
    return Token.__repr__(self);
}

impl Source.__repr__ -> str {
    return Token.__repr__(self);
}

impl PythonModuleAst.__repr__ -> str {
    return Token.__repr__(self);
}


impl UniScopeNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstSymbolNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstSymbolStubNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstAccessNode.init(
    *, access: (SubTag[Token] | None) = None, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {AccessRole: access});
    self.postinit();
}

impl ContextAwareNode.init(
    *, codespace_dual: bool = False, kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self._link(kid, {});
    self.postinit();
}

impl AstDocNode.init(
    *, doc: (String | None) = None, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {DocRole: doc});
    self.postinit();
}

impl AstAsyncNode.init(*, is_async: bool = False, kid: Sequence[UniNode] = []) -> None {
    self.is_async = is_async;
    self._link(kid, {});
    self.postinit();
}

impl AstElseBodyNode.init(
    *, else_body: (ElseStmt | ElseIf | None) = None, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ElseBodyRole: else_body});
    self.postinit();
}

impl AstTypedVarNode.init(
    *,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.type = type;
    self._link(kid, {TypeTagRole: type_tag});
    self.postinit();
}

impl WalkerStmtOnlyNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl UniCFGNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl ConditionalNode.init(
    *,
    sc_true_target: (UniCFGNode | None) = None,
    sc_false_target: (UniCFGNode | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.sc_true_target = sc_true_target;
    self.sc_false_target = sc_false_target;
    self._link(kid, {});
    self.postinit();
}

impl Expr.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl CfgExpr.init(
    *,
    sc_true_target: (UniCFGNode | None) = None,
    sc_false_target: (UniCFGNode | None) = None,
    expr: Expr,
    kid: Sequence[UniNode] = []
) -> None {
    self.sc_true_target = sc_true_target;
    self.sc_false_target = sc_false_target;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl EnumBlockStmt.init(
    *, is_enum_stmt: bool = False, kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self._link(kid, {});
    self.postinit();
}

impl CodeBlockStmt.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstImplNeedingNode.init(
    *, body: (Sequence[UniNode] | UniNode | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl NameAtom.init(
    *,
    is_enum_stmt: bool = False,
    is_getattr_resolved: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self.is_getattr_resolved = is_getattr_resolved;
    self._link(kid, {});
    self.postinit();
}

impl ArchSpec.init(
    *,
    doc: (String | None) = None,
    is_async: bool = False,
    decorators: (Sequence[Expr] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(kid, {DocRole: doc, DecoratorsRole: decorators});
    self.postinit();
}

impl SubTag.init(
    *,
    tag: T,
    ownership: OwnershipKind = OwnershipKind.NONE,
    linear: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.tag = tag;
    self.ownership = ownership;
    self.linear = linear;
    self._link(kid, {});
    self.postinit();
}

impl Module.init(
    *,
    doc: (String | None) = None,
    name: str,
    source: Source,
    body: Sequence[ElementStmt | String | EmptyToken],
    terminals: list[Token],
    stub_only: bool = False,
    src_terminals: list[Token] = [],
    is_raised_from_py: bool = False,
    parse_failed: bool = False,
    mobui_enforced_root: (str | None) = None,
    jac_project_root: (str | None) = None,
    access_enforced: bool = False,
    ct_resolved: bool = False,
    native_viols_reported: bool = False,
    client_viols_reported: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.name = name;
    self.source = source;
    self.terminals = terminals;
    self.stub_only = stub_only;
    self.src_terminals = src_terminals;
    self.is_raised_from_py = is_raised_from_py;
    self.parse_failed = parse_failed;
    self.mobui_enforced_root = mobui_enforced_root;
    self.jac_project_root = jac_project_root;
    self.access_enforced = access_enforced;
    self.ct_resolved = ct_resolved;
    self.native_viols_reported = native_viols_reported;
    self.client_viols_reported = client_viols_reported;
    self._link(kid, {DocRole: doc, BodyRole: body});
    self.postinit();
}

impl ProgramModule.init(
    *, main_mod: (Module | None) = None, kid: Sequence[UniNode] = []
) -> None {
    target = main_mod or Module.make_stub();
    self._link([*kid, target], {MainRole: target});
    self.postinit();
}

impl ProgramModule.main_mod.getter -> (Module | None) {
    found = [self->:MainRole:->][?:Module];
    if not found {
        return None;
    }
    return None if found[0].stub_only else found[0];
}

impl ProgramModule.main_mod.setter(main_mod: (Module | None)) {
    self._role_set(MainRole, main_mod or Module.make_stub());
}

impl TypeParam.init(
    *,
    name: Name,
    bound: (Expr | None),
    default_val: (Expr | None),
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_comptime = is_comptime;
    self._link(kid, {NameRole: name, BoundRole: bound, DefaultValRole: default_val});
    self.postinit();
}

impl TypeAlias.init(
    *,
    doc: (String | None) = None,
    access: (SubTag[Token] | None) = None,
    codespace_dual: bool = False,
    name: Name,
    type_params: (Sequence[TypeParam] | None),
    value: Expr,
    is_distinct: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self.is_distinct = is_distinct;
    self._link(
        kid,
        {
            DocRole: doc,
            AccessRole: access,
            NameRole: name,
            TypeParamsRole: type_params,
            ValueRole: value
        }
    );
    self.postinit();
}

impl GlobalVars.init(
    *,
    access: (SubTag[Token] | None) = None,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    assignments: Sequence[Assignment],
    is_frozen: bool,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self.is_frozen = is_frozen;
    self._link(kid, {AccessRole: access, DocRole: doc, AssignmentsRole: assignments});
    self.postinit();
}

impl Test.init(
    *,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    name: Name,
    body: Sequence[CodeBlockStmt],
    description: (String | None) = None,
    decorators: (Sequence[Expr] | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            NameRole: name,
            BodyRole: body,
            DescriptionRole: description,
            DecoratorsRole: decorators
        }
    );
    self.postinit();
}

impl ModuleCode.init(
    *,
    is_enum_stmt: bool = False,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    name: (Name | None),
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self.codespace_dual = codespace_dual;
    self._link(kid, {DocRole: doc, NameRole: name, BodyRole: body});
    self.postinit();
}

impl PyInlineCode.init(
    *,
    is_enum_stmt: bool = False,
    doc: (String | None) = None,
    code: Token,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self._link(kid, {DocRole: doc, CodeRole: code});
    self.postinit();
}

impl Import.init(
    *,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    from_loc: (ModulePath | None),
    items: Sequence[(ModuleItem | ModulePath)],
    is_absorb: bool,
    is_typed: bool = False,
    clib_decls: (Sequence[UniNode] | None) = None,
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self.is_absorb = is_absorb;
    self.is_typed = is_typed;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {
            DocRole: doc,
            FromLocRole: from_loc,
            ItemsRole: items,
            ClibDeclsRole: clib_decls
        }
    );
    self.postinit();
}

impl ModulePath.init(
    *,
    path: (Sequence[(Name | String)] | None),
    level: int,
    alias: (Name | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.level = level;
    self._link(kid, {PathRole: path, AliasRole: alias});
    self.postinit();
}

impl ModuleItem.init(
    *, name: (Name | Token), alias: (Name | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {NameRole: name, AliasRole: alias});
    self.postinit();
}

impl Archetype.init(
    *,
    doc: (String | None) = None,
    is_async: bool = False,
    body: (Sequence[UniNode] | UniNode | None),
    access: (SubTag[Token] | None) = None,
    decorators: (Sequence[Expr] | None),
    codespace_dual: bool = False,
    name: Name,
    arch_type: Token,
    base_classes: (Sequence[Expr] | None),
    keywords: (Sequence[KWPair] | None) = None,
    type_params: (Sequence[TypeParam] | None) = None,
    src_endpoint: (Expr | None) = None,
    tgt_endpoint: (Expr | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            BodyRole: body,
            AccessRole: access,
            DecoratorsRole: decorators,
            NameRole: name,
            ArchTypeRole: arch_type,
            BaseClassesRole: base_classes,
            KeywordsRole: keywords,
            TypeParamsRole: type_params,
            SrcEndpointRole: src_endpoint,
            TgtEndpointRole: tgt_endpoint
        }
    );
    self.postinit();
}

impl ImplDef.init(
    *,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    decorators: (Sequence[Expr] | None),
    target: Sequence[NameAtom],
    spec: (Sequence[Expr] | FuncSignature | EventSignature | None),
    body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            DecoratorsRole: decorators,
            TargetRole: target,
            SpecRole: spec,
            BodyRole: body
        }
    );
    self.postinit();
}

impl SemDef.init(
    *,
    doc: (String | None) = None,
    target: Sequence[NameAtom],
    value: MultiString,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {DocRole: doc, TargetRole: target, ValueRole: value});
    self.postinit();
}

impl Enum.init(
    *,
    doc: (String | None) = None,
    is_async: bool = False,
    body: (Sequence[UniNode] | UniNode | None),
    access: (SubTag[Token] | None) = None,
    decorators: (Sequence[Expr] | None),
    codespace_dual: bool = False,
    name: Name,
    value_type: (Expr | None),
    base_classes: (Sequence[Expr] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            BodyRole: body,
            AccessRole: access,
            DecoratorsRole: decorators,
            NameRole: name,
            ValueTypeRole: value_type,
            BaseClassesRole: base_classes
        }
    );
    self.postinit();
}

impl Ability.init(
    *,
    body: (Sequence[UniNode] | UniNode | None),
    is_async: bool = False,
    doc: (String | None) = None,
    access: (SubTag[Token] | None) = None,
    codespace_dual: bool = False,
    name_ref: (NameAtom | None),
    is_override: bool,
    is_static: bool,
    is_classmethod: bool,
    is_abstract: bool,
    signature: FuncSignature | EventSignature | None,
    decorators: (Sequence[Expr] | None) = None,
    type_params: (Sequence[TypeParam] | None) = None,
    accessor_kind: str = "",
    is_comptime: bool = False,
    event_triggers: (list[TypeBase] | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.codespace_dual = codespace_dual;
    self.is_override = is_override;
    self.is_static = is_static;
    self.is_classmethod = is_classmethod;
    self.is_abstract = is_abstract;
    self.accessor_kind = accessor_kind;
    self.is_comptime = is_comptime;
    self.event_triggers = event_triggers;
    self._link(
        kid,
        {
            BodyRole: body,
            DocRole: doc,
            AccessRole: access,
            NameRefRole: name_ref,
            SignatureRole: signature,
            DecoratorsRole: decorators,
            TypeParamsRole: type_params
        }
    );
    self.postinit();
}

impl FuncSignature.init(
    *,
    posonly_params: Sequence[ParamVar],
    params: (Sequence[ParamVar] | None),
    varargs: (ParamVar | None),
    kwonlyargs: Sequence[ParamVar],
    kwargs: (ParamVar | None),
    return_type: (Expr | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid,
        {
            PosonlyParamsRole: posonly_params,
            ParamsRole: params,
            VarargsRole: varargs,
            KwonlyargsRole: kwonlyargs,
            KwargsRole: kwargs,
            ReturnTypeRole: return_type
        }
    );
    self.postinit();
}

impl EventSignature.init(
    *, event: Token, arch_tag_info: (Expr | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {EventRole: event, ArchTagInfoRole: arch_tag_info});
    self.postinit();
}

impl ParamVar.init(
    *,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    name: Name,
    unpack: (Token | None),
    value: (Expr | None),
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.type = type;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {TypeTagRole: type_tag, NameRole: name, UnpackRole: unpack, ValueRole: value}
    );
    self.postinit();
}

impl ArchHas.init(
    *,
    doc: (String | None) = None,
    access: (SubTag[Token] | None) = None,
    is_static: bool,
    vars: Sequence[HasVar],
    is_frozen: bool,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_static = is_static;
    self.is_frozen = is_frozen;
    self._link(kid, {DocRole: doc, AccessRole: access, VarsRole: vars});
    self.postinit();
}

impl HasVar.init(
    *,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    name: Name,
    value: (Expr | None),
    defer: bool,
    accessors: (Sequence[Ability] | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.type = type;
    self.defer = defer;
    self._link(
        kid,
        {
            TypeTagRole: type_tag,
            NameRole: name,
            ValueRole: value,
            AccessorsRole: accessors
        }
    );
    self.postinit();
}

impl TypedCtxBlock.init(
    *, type_ctx: Expr, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TypeCtxRole: type_ctx, BodyRole: body});
    self.postinit();
}

impl OpenStmt.init(
    *, target: Expr, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TargetRole: target, BodyRole: body});
    self.postinit();
}

impl IfStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    condition: Expr,
    body: Sequence[CodeBlockStmt],
    is_comptime: bool = False,
    ct_taken: (bool | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_comptime = is_comptime;
    self.ct_taken = ct_taken;
    self._link(
        kid, {ElseBodyRole: else_body, ConditionRole: condition, BodyRole: body}
    );
    self.postinit();
}

impl ElseIf.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    condition: Expr,
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ElseBodyRole: else_body, ConditionRole: condition, BodyRole: body}
    );
    self.postinit();
}

impl ElseStmt.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl ExprStmt.init(
    *, expr: Expr, in_fstring: bool, has_semi: bool = True, kid: Sequence[UniNode] = []
) -> None {
    self.in_fstring = in_fstring;
    self.has_semi = has_semi;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl TryStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    body: Sequence[CodeBlockStmt],
    excepts: Sequence[Except],
    awaiting_body: (AwaitingClause | None),
    finally_body: (FinallyStmt | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid,
        {
            ElseBodyRole: else_body,
            BodyRole: body,
            ExceptsRole: excepts,
            AwaitingBodyRole: awaiting_body,
            FinallyBodyRole: finally_body
        }
    );
    self.postinit();
}

impl AwaitingClause.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl Except.init(
    *,
    ex_type: Expr,
    name: (Name | None),
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ExTypeRole: ex_type, NameRole: name, BodyRole: body});
    self.postinit();
}

impl FinallyStmt.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl IterForStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    is_async: bool = False,
    iter: Assignment,
    condition: Expr,
    count_by: Assignment,
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(
        kid,
        {
            ElseBodyRole: else_body,
            IterRole: iter,
            ConditionRole: condition,
            CountByRole: count_by,
            BodyRole: body
        }
    );
    self.postinit();
}

impl InForStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    is_async: bool = False,
    target: Expr,
    collection: Expr,
    body: Sequence[CodeBlockStmt],
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {
            ElseBodyRole: else_body,
            TargetRole: target,
            CollectionRole: collection,
            BodyRole: body
        }
    );
    self.postinit();
}

impl WhileStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    condition: Expr,
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ElseBodyRole: else_body, ConditionRole: condition, BodyRole: body}
    );
    self.postinit();
}

impl ForeverStmt.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl WithStmt.init(
    *,
    is_async: bool = False,
    exprs: Sequence[ExprAsItem],
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(kid, {ExprsRole: exprs, BodyRole: body});
    self.postinit();
}

impl ExprAsItem.init(
    *, expr: Expr, alias: (Expr | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ExprRole: expr, AliasRole: alias});
    self.postinit();
}

impl RaiseStmt.init(
    *, cause: (Expr | None), from_target: (Expr | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {CauseRole: cause, FromTargetRole: from_target});
    self.postinit();
}

impl AssertStmt.init(
    *,
    condition: Expr,
    error_msg: (Expr | None),
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_comptime = is_comptime;
    self._link(kid, {ConditionRole: condition, ErrorMsgRole: error_msg});
    self.postinit();
}

impl CtrlStmt.init(*, ctrl: Token, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {CtrlRole: ctrl});
    self.postinit();
}

impl DeleteStmt.init(*, targets: list[Expr], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {TargetRole: targets});
    self.postinit();
}

impl ReportStmt.init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl ReturnStmt.init(
    *, expr: (Expr | None), is_implicit: bool = False, kid: Sequence[UniNode] = []
) -> None {
    self.is_implicit = is_implicit;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl VisitStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    insert_loc: (Expr | None),
    target: Expr,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ElseBodyRole: else_body, InsertLocRole: insert_loc, TargetRole: target}
    );
    self.postinit();
}

impl DisengageStmt.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AwaitExpr.init(*, target: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {TargetRole: target});
    self.postinit();
}

impl CastExpr.init(
    *, value: Expr, cast_type: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValueRole: value, CastTypeRole: cast_type});
    self.postinit();
}

impl Assignment.init(
    *,
    is_enum_stmt: bool = False,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    target: Sequence[Expr],
    value: Expr | YieldExpr | None,
    mutable: bool = True,
    aug_op: (Token | None) = None,
    na_move_lowerable: bool = False,
    na_overwrite_consumed: bool = False,
    na_flow_reduce: str = "",
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self.type = type;
    self.mutable = mutable;
    self.na_move_lowerable = na_move_lowerable;
    self.na_overwrite_consumed = na_overwrite_consumed;
    self.na_flow_reduce = na_flow_reduce;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {TypeTagRole: type_tag, TargetRole: target, ValueRole: value, AugOpRole: aug_op}
    );
    self.postinit();
}

impl ConcurrentExpr.init(
    *, tok: (Token | None), target: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TokRole: tok, TargetRole: target});
    self.postinit();
}

impl BinaryExpr.init(
    *,
    left: Expr,
    right: Expr,
    op: Token | DisconnectOp | ConnectOp,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {LeftRole: left, RightRole: right, OpRole: op});
    self.postinit();
}

impl CompareExpr.init(
    *, left: Expr, rights: list[Expr], ops: list[Token], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {LeftRole: left, RightsRole: rights, OpsRole: ops});
    self.postinit();
}

impl BoolExpr.init(
    *, op: Token, values: list[CfgExpr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OpRole: op, ValuesRole: values});
    self.postinit();
}

impl LambdaExpr.init(
    *,
    body: (Expr | Sequence[CodeBlockStmt]),
    signature: (FuncSignature | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body, SignatureRole: signature});
    self.postinit();
}

impl UnaryExpr.init(
    *,
    operand: Expr,
    op: Token,
    ownership: OwnershipKind = OwnershipKind.NONE,
    kid: Sequence[UniNode] = []
) -> None {
    self.ownership = ownership;
    self._link(kid, {OperandRole: operand, OpRole: op});
    self.postinit();
}

impl IfElseExpr.init(
    *,
    condition: CfgExpr,
    value: CfgExpr,
    else_value: CfgExpr,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ConditionRole: condition, ValueRole: value, ElseValueRole: else_value}
    );
    self.postinit();
}

impl MultiString.init(
    *, strings: Sequence[(String | FString)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {StringsRole: strings});
    self.postinit();
}

impl FString.init(
    *,
    start: (Token | None),
    parts: Sequence[(String | FormattedValue)],
    end: (Token | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {StartRole: start, PartsRole: parts, EndRole: end});
    self.postinit();
}

impl FormattedValue.init(
    *,
    format_part: Expr,
    conversion: int,
    format_spec: (Expr | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.conversion = conversion;
    self._link(kid, {FormatPartRole: format_part, FormatSpecRole: format_spec});
    self.postinit();
}

impl ListVal.init(*, values: Sequence[Expr], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl SetVal.init(
    *, values: (Sequence[Expr] | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl TupleVal.init(
    *, values: Sequence[(Expr | KWPair)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl DictVal.init(*, kv_pairs: Sequence[KVPair], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {KvPairsRole: kv_pairs});
    self.postinit();
}

impl KVPair.init(
    *, key: (Expr | None), value: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KeyRole: key, ValueRole: value});
    self.postinit();
}

impl KWPair.init(
    *, key: (NameAtom | None), value: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KeyRole: key, ValueRole: value});
    self.postinit();
}

impl InnerCompr.init(
    *,
    is_async: bool = False,
    target: Expr,
    collection: Expr,
    conditional: (list[Expr] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(
        kid,
        {TargetRole: target, CollectionRole: collection, ConditionalRole: conditional}
    );
    self.postinit();
}

impl ListCompr.init(
    *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OutExprRole: out_expr, ComprRole: compr});
    self.postinit();
}

impl GenCompr.init(
    *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OutExprRole: out_expr, ComprRole: compr});
    self.postinit();
}

impl SetCompr.init(
    *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OutExprRole: out_expr, ComprRole: compr});
    self.postinit();
}

impl DictCompr.init(
    *, kv_pair: KVPair, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KvPairRole: kv_pair, ComprRole: compr});
    self.postinit();
}

impl AtomTrailer.init(
    *,
    target: Expr,
    right: (AtomExpr | Expr),
    is_attr: bool,
    is_null_ok: bool,
    is_genai: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_attr = is_attr;
    self.is_null_ok = is_null_ok;
    self.is_genai = is_genai;
    self._link(kid, {TargetRole: target, RightRole: right});
    self.postinit();
}

impl AtomUnit.init(
    *, value: Expr | YieldExpr | Ability, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}

impl GraphExpr.init(*, exprs: Sequence[Expr], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprsRole: exprs});
    self.postinit();
}

impl GraphExpr.exprs.getter -> Sequence[Expr] {
    return [self->:ExprsRole:->];
}

impl GraphExpr.__repr__ -> str {
    return f"GraphExpr(exprs={self.exprs!r})";
}

impl YieldExpr.init(
    *, expr: (Expr | None), with_from: bool, kid: Sequence[UniNode] = []
) -> None {
    self.with_from = with_from;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl FuncCall.init(
    *,
    target: Expr,
    params: (Sequence[(Expr | KWPair)] | None),
    genai_call: (Expr | None),
    call_kind: (str | None) = None,
    chunks_recv_type: (str | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.genai_call = genai_call;
    self.call_kind = call_kind;
    self.chunks_recv_type = chunks_recv_type;
    self._link(kid, {TargetRole: target, ParamsRole: params});
    self.postinit();
}

impl Slice.init(
    *,
    start: (Expr | None),
    stop: (Expr | None),
    step: (Expr | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {StartRole: start, StopRole: stop, StepRole: step});
    self.postinit();
}

impl IndexSlice.init(
    *, slices: list[Slice], is_range: bool, kid: Sequence[UniNode] = []
) -> None {
    self.is_range = is_range;
    self._link(kid, {SlicesRole: slices});
    self.postinit();
}

impl EdgeRefTrailer.init(
    *,
    chain: list[(Expr | FilterCompr)],
    edges_only: bool,
    is_async: bool,
    kid: Sequence[UniNode] = []
) -> None {
    self.edges_only = edges_only;
    self.is_async = is_async;
    self._link(kid, {ChainRole: chain});
    self.postinit();
}

impl EdgeOpRef.init(
    *, filter_cond: (FilterCompr | None), edge_dir: EdgeDir, kid: Sequence[UniNode] = []
) -> None {
    self.edge_dir = edge_dir;
    self._link(kid, {FilterCondRole: filter_cond});
    self.postinit();
}

impl DisconnectOp.init(*, edge_spec: EdgeOpRef, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {EdgeSpecRole: edge_spec});
    self.postinit();
}

impl ConnectOp.init(
    *,
    conn_type: (Expr | None),
    conn_assign: (AssignCompr | None),
    edge_dir: EdgeDir,
    kid: Sequence[UniNode] = []
) -> None {
    self.edge_dir = edge_dir;
    self._link(kid, {ConnTypeRole: conn_type, ConnAssignRole: conn_assign});
    self.postinit();
}

impl FilterCompr.init(
    *, f_type: (Expr | None), compares: Sequence[Expr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {FTypeRole: f_type, ComparesRole: compares});
    self.postinit();
}

impl AssignCompr.init(
    *, assigns: Sequence[KWPair], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {AssignsRole: assigns});
    self.postinit();
}

impl JsxElement.init(
    *,
    name: (JsxElementName | None),
    attributes: (Sequence[JsxAttribute] | None),
    children: (Sequence[(JsxChild | JsxElement)] | None),
    is_self_closing: bool,
    is_fragment: bool,
    dynamic_tag: (Expr | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_self_closing = is_self_closing;
    self.is_fragment = is_fragment;
    self._link(
        kid,
        {
            NameRole: name,
            AttributesRole: attributes,
            ChildrenRole: children,
            DynamicTagRole: dynamic_tag
        }
    );
    self.postinit();
}

impl JsxElementName.init(
    *, parts: Sequence[(Name | Token)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PartsRole: parts});
    self.postinit();
}

impl JsxAttribute.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl JsxSpreadAttribute.init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl JsxNormalAttribute.init(
    *,
    name: (Name | Token),
    value: String | Expr | None,
    is_shorthand: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_shorthand = is_shorthand;
    self._link(kid, {NameRole: name, ValueRole: value});
    self.postinit();
}

impl JsxChild.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl JsxText.init(*, value: (str | Token), kid: Sequence[UniNode] = []) -> None {
    self.value = value;
    self._link(kid, {});
    self.postinit();
}

impl JsxExpression.init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl JsxSlot.init(*, body: list[UniNode], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl JsxComment.init(*, value: Token, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}

impl MatchStmt.init(
    *, target: Expr, cases: list[MatchCase], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TargetRole: target, CasesRole: cases});
    self.postinit();
}

impl MatchCase.init(
    *,
    pattern: MatchPattern,
    guard: (Expr | None),
    body: list[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PatternRole: pattern, GuardRole: guard, BodyRole: body});
    self.postinit();
}

impl SwitchStmt.init(
    *, target: Expr, cases: list[SwitchCase], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TargetRole: target, CasesRole: cases});
    self.postinit();
}

impl SwitchCase.init(
    *,
    pattern: (MatchPattern | None),
    body: list[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PatternRole: pattern, BodyRole: body});
    self.postinit();
}

impl MatchOr.init(
    *, patterns: list[MatchPattern], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PatternsRole: patterns});
    self.postinit();
}

impl MatchAs.init(
    *, name: NameAtom, pattern: (MatchPattern | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {NameRole: name, PatternRole: pattern});
    self.postinit();
}

impl MatchWild.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl MatchValue.init(*, value: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}

impl MatchSingleton.init(*, value: (Bool | Null), kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}

impl MatchSequence.init(
    *, values: list[MatchPattern], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl MatchMapping.init(
    *, values: list[(MatchKVPair | MatchStar)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl MatchKVPair.init(
    *,
    key: MatchPattern | NameAtom | AtomExpr,
    value: MatchPattern,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KeyRole: key, ValueRole: value});
    self.postinit();
}

impl MatchStar.init(
    *, name: NameAtom, is_list: bool, kid: Sequence[UniNode] = []
) -> None {
    self.is_list = is_list;
    self._link(kid, {NameRole: name});
    self.postinit();
}

impl MatchArch.init(
    *,
    name: (AtomTrailer | NameAtom),
    arg_patterns: (Sequence[MatchPattern] | None),
    kw_patterns: (Sequence[MatchKVPair] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid,
        {NameRole: name, ArgPatternsRole: arg_patterns, KwPatternsRole: kw_patterns}
    );
    self.postinit();
}
