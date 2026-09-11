import from jaclang.compiler.ir.identity { RelationFamily }
impl UniNode.postinit -> None {
    import from jaclang.compiler.frontend.source_locations { CodeLocInfo }

    self.__sub_node_tab = None;
    self._ctx_parent = None;
    self._struct_frozen = False;
    self._in_mod_nodes = [];
    self.ct_pruned = False;
    if self?._role_shapes is None {
        self._role_shapes = None;
    }
    (first_tok, last_tok) = self.resolve_tok_range();
    self.loc = CodeLocInfo(first_tok, last_tok);
}

impl UniNode.walk_kids with TreeWalker entry {
    visit : 0 : [
        k
        for k in self.kid
        if k and not k.ct_pruned
    ];
}

impl UniNode._attach(
    child: UniNode, role: type[Role], check_only: bool = False
) -> None {
    import from jaclang.compiler.ir.syntax.edges {
        Role,
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

    if role is Role {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:Role:+> child;
        return;
    }
    if role is AccessRole {
        import from jaclang.compiler.ir.syntax.nodes { AstAccessNode, SubTag }
        if not isinstance(self, AstAccessNode) {
            raise TypeError("AccessRole requires a AstAccessNode source");
        }
        if not isinstance(child, SubTag) {
            raise TypeError("AccessRole requires a SubTag target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AccessRole:+> child;
        return;
    }
    if role is AccessorsRole {
        import from jaclang.compiler.ir.syntax.nodes { Ability, HasVar }
        if not isinstance(self, HasVar) {
            raise TypeError("AccessorsRole requires a HasVar source");
        }
        if not isinstance(child, Ability) {
            raise TypeError("AccessorsRole requires a Ability target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AccessorsRole:+> child;
        return;
    }
    if role is AliasRole {
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(child, Expr) {
            raise TypeError("AliasRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AliasRole:+> child;
        return;
    }
    if role is ArchTagInfoRole {
        import from jaclang.compiler.ir.syntax.nodes { EventSignature }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, EventSignature) {
            raise TypeError("ArchTagInfoRole requires a EventSignature source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ArchTagInfoRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ArchTagInfoRole:+> child;
        return;
    }
    if role is ArchTypeRole {
        import from jaclang.compiler.ir.syntax.nodes { Archetype, Token }
        if not isinstance(self, Archetype) {
            raise TypeError("ArchTypeRole requires a Archetype source");
        }
        if not isinstance(child, Token) {
            raise TypeError("ArchTypeRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ArchTypeRole:+> child;
        return;
    }
    if role is ArgPatternsRole {
        import from jaclang.compiler.ir.syntax.nodes { MatchArch, MatchPattern }
        if not isinstance(self, MatchArch) {
            raise TypeError("ArgPatternsRole requires a MatchArch source");
        }
        if not isinstance(child, MatchPattern) {
            raise TypeError("ArgPatternsRole requires a MatchPattern target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ArgPatternsRole:+> child;
        return;
    }
    if role is AssignmentsRole {
        import from jaclang.compiler.ir.syntax.nodes { Assignment, GlobalVars }
        if not isinstance(self, GlobalVars) {
            raise TypeError("AssignmentsRole requires a GlobalVars source");
        }
        if not isinstance(child, Assignment) {
            raise TypeError("AssignmentsRole requires a Assignment target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AssignmentsRole:+> child;
        return;
    }
    if role is AssignsRole {
        import from jaclang.compiler.ir.syntax.nodes { AssignCompr, KWPair }
        if not isinstance(self, AssignCompr) {
            raise TypeError("AssignsRole requires a AssignCompr source");
        }
        if not isinstance(child, KWPair) {
            raise TypeError("AssignsRole requires a KWPair target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AssignsRole:+> child;
        return;
    }
    if role is AttributesRole {
        import from jaclang.compiler.ir.syntax.nodes { JsxAttribute, JsxElement }
        if not isinstance(self, JsxElement) {
            raise TypeError("AttributesRole requires a JsxElement source");
        }
        if not isinstance(child, JsxAttribute) {
            raise TypeError("AttributesRole requires a JsxAttribute target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AttributesRole:+> child;
        return;
    }
    if role is AugOpRole {
        import from jaclang.compiler.ir.syntax.nodes { Assignment, Token }
        if not isinstance(self, Assignment) {
            raise TypeError("AugOpRole requires a Assignment source");
        }
        if not isinstance(child, Token) {
            raise TypeError("AugOpRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AugOpRole:+> child;
        return;
    }
    if role is AwaitingBodyRole {
        import from jaclang.compiler.ir.syntax.nodes { AwaitingClause, TryStmt }
        if not isinstance(self, TryStmt) {
            raise TypeError("AwaitingBodyRole requires a TryStmt source");
        }
        if not isinstance(child, AwaitingClause) {
            raise TypeError("AwaitingBodyRole requires a AwaitingClause target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:AwaitingBodyRole:+> child;
        return;
    }
    if role is BaseClassesRole {
        import from jaclang.compiler.ir.syntax.nodes { ArchSpec }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, ArchSpec) {
            raise TypeError("BaseClassesRole requires a ArchSpec source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("BaseClassesRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:BaseClassesRole:+> child;
        return;
    }
    if role is BodyRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:BodyRole:+> child;
        return;
    }
    if role is BoundRole {
        import from jaclang.compiler.ir.syntax.nodes { TypeParam }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, TypeParam) {
            raise TypeError("BoundRole requires a TypeParam source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("BoundRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:BoundRole:+> child;
        return;
    }
    if role is CasesRole {
        import from jaclang.compiler.ir.syntax.nodes { CodeBlockStmt }
        if not isinstance(self, CodeBlockStmt) {
            raise TypeError("CasesRole requires a CodeBlockStmt source");
        }
        if not isinstance(child, CodeBlockStmt) {
            raise TypeError("CasesRole requires a CodeBlockStmt target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:CasesRole:+> child;
        return;
    }
    if role is CastTypeRole {
        import from jaclang.compiler.ir.syntax.nodes { CastExpr }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, CastExpr) {
            raise TypeError("CastTypeRole requires a CastExpr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("CastTypeRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:CastTypeRole:+> child;
        return;
    }
    if role is CauseRole {
        import from jaclang.compiler.ir.syntax.nodes { RaiseStmt }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, RaiseStmt) {
            raise TypeError("CauseRole requires a RaiseStmt source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("CauseRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:CauseRole:+> child;
        return;
    }
    if role is ChainRole {
        import from jaclang.compiler.ir.syntax.nodes { EdgeRefTrailer }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, EdgeRefTrailer) {
            raise TypeError("ChainRole requires a EdgeRefTrailer source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ChainRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ChainRole:+> child;
        return;
    }
    if role is ChildrenRole {
        import from jaclang.compiler.ir.syntax.nodes { JsxElement }
        if not isinstance(self, JsxElement) {
            raise TypeError("ChildrenRole requires a JsxElement source");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ChildrenRole:+> child;
        return;
    }
    if role is ClibDeclsRole {
        import from jaclang.compiler.ir.syntax.nodes { Import }
        if not isinstance(self, Import) {
            raise TypeError("ClibDeclsRole requires a Import source");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ClibDeclsRole:+> child;
        return;
    }
    if role is CodeRole {
        import from jaclang.compiler.ir.syntax.nodes { PyInlineCode, Token }
        if not isinstance(self, PyInlineCode) {
            raise TypeError("CodeRole requires a PyInlineCode source");
        }
        if not isinstance(child, Token) {
            raise TypeError("CodeRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:CodeRole:+> child;
        return;
    }
    if role is CollectionRole {
        import from jaclang.compiler.ir.syntax.nodes { AstAsyncNode }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, AstAsyncNode) {
            raise TypeError("CollectionRole requires a AstAsyncNode source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("CollectionRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:CollectionRole:+> child;
        return;
    }
    if role is ComparesRole {
        import from jaclang.compiler.ir.syntax.nodes { FilterCompr }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, FilterCompr) {
            raise TypeError("ComparesRole requires a FilterCompr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ComparesRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ComparesRole:+> child;
        return;
    }
    if role is ComprRole {
        import from jaclang.compiler.ir.syntax.nodes { AtomExpr, InnerCompr }
        if not isinstance(self, AtomExpr) {
            raise TypeError("ComprRole requires a AtomExpr source");
        }
        if not isinstance(child, InnerCompr) {
            raise TypeError("ComprRole requires a InnerCompr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ComprRole:+> child;
        return;
    }
    if role is ConditionRole {
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(child, Expr) {
            raise TypeError("ConditionRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ConditionRole:+> child;
        return;
    }
    if role is ConditionalRole {
        import from jaclang.compiler.ir.syntax.nodes { InnerCompr }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, InnerCompr) {
            raise TypeError("ConditionalRole requires a InnerCompr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ConditionalRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ConditionalRole:+> child;
        return;
    }
    if role is ConnAssignRole {
        import from jaclang.compiler.ir.syntax.nodes { AssignCompr, ConnectOp }
        if not isinstance(self, ConnectOp) {
            raise TypeError("ConnAssignRole requires a ConnectOp source");
        }
        if not isinstance(child, AssignCompr) {
            raise TypeError("ConnAssignRole requires a AssignCompr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ConnAssignRole:+> child;
        return;
    }
    if role is ConnTypeRole {
        import from jaclang.compiler.ir.syntax.nodes { ConnectOp }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, ConnectOp) {
            raise TypeError("ConnTypeRole requires a ConnectOp source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ConnTypeRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ConnTypeRole:+> child;
        return;
    }
    if role is CountByRole {
        import from jaclang.compiler.ir.syntax.nodes { Assignment, IterForStmt }
        if not isinstance(self, IterForStmt) {
            raise TypeError("CountByRole requires a IterForStmt source");
        }
        if not isinstance(child, Assignment) {
            raise TypeError("CountByRole requires a Assignment target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:CountByRole:+> child;
        return;
    }
    if role is CtrlRole {
        import from jaclang.compiler.ir.syntax.nodes { CtrlStmt, Token }
        if not isinstance(self, CtrlStmt) {
            raise TypeError("CtrlRole requires a CtrlStmt source");
        }
        if not isinstance(child, Token) {
            raise TypeError("CtrlRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:CtrlRole:+> child;
        return;
    }
    if role is DecoratorsRole {
        import from jaclang.compiler.ir.syntax.nodes { CodeBlockStmt }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, CodeBlockStmt) {
            raise TypeError("DecoratorsRole requires a CodeBlockStmt source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("DecoratorsRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:DecoratorsRole:+> child;
        return;
    }
    if role is DefaultValRole {
        import from jaclang.compiler.ir.syntax.nodes { TypeParam }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, TypeParam) {
            raise TypeError("DefaultValRole requires a TypeParam source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("DefaultValRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:DefaultValRole:+> child;
        return;
    }
    if role is DescriptionRole {
        import from jaclang.compiler.ir.syntax.nodes { String, Test }
        if not isinstance(self, Test) {
            raise TypeError("DescriptionRole requires a Test source");
        }
        if not isinstance(child, String) {
            raise TypeError("DescriptionRole requires a String target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:DescriptionRole:+> child;
        return;
    }
    if role is DocRole {
        import from jaclang.compiler.ir.syntax.nodes { AstDocNode, String }
        if not isinstance(self, AstDocNode) {
            raise TypeError("DocRole requires a AstDocNode source");
        }
        if not isinstance(child, String) {
            raise TypeError("DocRole requires a String target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:DocRole:+> child;
        return;
    }
    if role is DynamicTagRole {
        import from jaclang.compiler.ir.syntax.nodes { JsxElement }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, JsxElement) {
            raise TypeError("DynamicTagRole requires a JsxElement source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("DynamicTagRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:DynamicTagRole:+> child;
        return;
    }
    if role is EdgeSpecRole {
        import from jaclang.compiler.ir.syntax.nodes { DisconnectOp, EdgeOpRef }
        if not isinstance(self, DisconnectOp) {
            raise TypeError("EdgeSpecRole requires a DisconnectOp source");
        }
        if not isinstance(child, EdgeOpRef) {
            raise TypeError("EdgeSpecRole requires a EdgeOpRef target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:EdgeSpecRole:+> child;
        return;
    }
    if role is ElseBodyRole {
        import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
        import from jaclang.compiler.ir.syntax.nodes { AstElseBodyNode }
        if not isinstance(self, AstElseBodyNode) {
            raise TypeError("ElseBodyRole requires a AstElseBodyNode source");
        }
        if not isinstance(child, UniScopeNode) {
            raise TypeError("ElseBodyRole requires a UniScopeNode target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ElseBodyRole:+> child;
        return;
    }
    if role is ElseValueRole {
        import from jaclang.compiler.ir.syntax.nodes { CfgExpr, IfElseExpr }
        if not isinstance(self, IfElseExpr) {
            raise TypeError("ElseValueRole requires a IfElseExpr source");
        }
        if not isinstance(child, CfgExpr) {
            raise TypeError("ElseValueRole requires a CfgExpr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ElseValueRole:+> child;
        return;
    }
    if role is EndRole {
        import from jaclang.compiler.ir.syntax.nodes { FString, Token }
        if not isinstance(self, FString) {
            raise TypeError("EndRole requires a FString source");
        }
        if not isinstance(child, Token) {
            raise TypeError("EndRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:EndRole:+> child;
        return;
    }
    if role is ErrorMsgRole {
        import from jaclang.compiler.ir.syntax.nodes { AssertStmt }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, AssertStmt) {
            raise TypeError("ErrorMsgRole requires a AssertStmt source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ErrorMsgRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ErrorMsgRole:+> child;
        return;
    }
    if role is EventRole {
        import from jaclang.compiler.ir.syntax.nodes { EventSignature, Token }
        if not isinstance(self, EventSignature) {
            raise TypeError("EventRole requires a EventSignature source");
        }
        if not isinstance(child, Token) {
            raise TypeError("EventRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:EventRole:+> child;
        return;
    }
    if role is ExTypeRole {
        import from jaclang.compiler.ir.syntax.nodes { Except }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Except) {
            raise TypeError("ExTypeRole requires a Except source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ExTypeRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ExTypeRole:+> child;
        return;
    }
    if role is ExceptsRole {
        import from jaclang.compiler.ir.syntax.nodes { Except, TryStmt }
        if not isinstance(self, TryStmt) {
            raise TypeError("ExceptsRole requires a TryStmt source");
        }
        if not isinstance(child, Except) {
            raise TypeError("ExceptsRole requires a Except target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ExceptsRole:+> child;
        return;
    }
    if role is ExprRole {
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(child, Expr) {
            raise TypeError("ExprRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ExprRole:+> child;
        return;
    }
    if role is ExprsRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ExprsRole:+> child;
        return;
    }
    if role is FTypeRole {
        import from jaclang.compiler.ir.syntax.nodes { FilterCompr }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, FilterCompr) {
            raise TypeError("FTypeRole requires a FilterCompr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("FTypeRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:FTypeRole:+> child;
        return;
    }
    if role is FilterCondRole {
        import from jaclang.compiler.ir.syntax.nodes { EdgeOpRef, FilterCompr }
        if not isinstance(self, EdgeOpRef) {
            raise TypeError("FilterCondRole requires a EdgeOpRef source");
        }
        if not isinstance(child, FilterCompr) {
            raise TypeError("FilterCondRole requires a FilterCompr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:FilterCondRole:+> child;
        return;
    }
    if role is FinallyBodyRole {
        import from jaclang.compiler.ir.syntax.nodes { FinallyStmt, TryStmt }
        if not isinstance(self, TryStmt) {
            raise TypeError("FinallyBodyRole requires a TryStmt source");
        }
        if not isinstance(child, FinallyStmt) {
            raise TypeError("FinallyBodyRole requires a FinallyStmt target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:FinallyBodyRole:+> child;
        return;
    }
    if role is FormatPartRole {
        import from jaclang.compiler.ir.syntax.nodes { FormattedValue }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, FormattedValue) {
            raise TypeError("FormatPartRole requires a FormattedValue source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("FormatPartRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:FormatPartRole:+> child;
        return;
    }
    if role is FormatSpecRole {
        import from jaclang.compiler.ir.syntax.nodes { FormattedValue }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, FormattedValue) {
            raise TypeError("FormatSpecRole requires a FormattedValue source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("FormatSpecRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:FormatSpecRole:+> child;
        return;
    }
    if role is FromLocRole {
        import from jaclang.compiler.ir.syntax.nodes { Import, ModulePath }
        if not isinstance(self, Import) {
            raise TypeError("FromLocRole requires a Import source");
        }
        if not isinstance(child, ModulePath) {
            raise TypeError("FromLocRole requires a ModulePath target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:FromLocRole:+> child;
        return;
    }
    if role is FromTargetRole {
        import from jaclang.compiler.ir.syntax.nodes { RaiseStmt }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, RaiseStmt) {
            raise TypeError("FromTargetRole requires a RaiseStmt source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("FromTargetRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:FromTargetRole:+> child;
        return;
    }
    if role is GuardRole {
        import from jaclang.compiler.ir.syntax.nodes { MatchCase }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, MatchCase) {
            raise TypeError("GuardRole requires a MatchCase source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("GuardRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:GuardRole:+> child;
        return;
    }
    if role is HintRole {
        import from jaclang.compiler.ir.syntax.nodes { Import, SubTag }
        if not isinstance(self, Import) {
            raise TypeError("HintRole requires a Import source");
        }
        if not isinstance(child, SubTag) {
            raise TypeError("HintRole requires a SubTag target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:HintRole:+> child;
        return;
    }
    if role is InsertLocRole {
        import from jaclang.compiler.ir.syntax.nodes { VisitStmt }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, VisitStmt) {
            raise TypeError("InsertLocRole requires a VisitStmt source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("InsertLocRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:InsertLocRole:+> child;
        return;
    }
    if role is ItemsRole {
        import from jaclang.compiler.ir.syntax.nodes { Import }
        if not isinstance(self, Import) {
            raise TypeError("ItemsRole requires a Import source");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ItemsRole:+> child;
        return;
    }
    if role is IterRole {
        import from jaclang.compiler.ir.syntax.nodes { Assignment, IterForStmt }
        if not isinstance(self, IterForStmt) {
            raise TypeError("IterRole requires a IterForStmt source");
        }
        if not isinstance(child, Assignment) {
            raise TypeError("IterRole requires a Assignment target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:IterRole:+> child;
        return;
    }
    if role is KeyRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:KeyRole:+> child;
        return;
    }
    if role is KeywordsRole {
        import from jaclang.compiler.ir.syntax.nodes { Archetype, KWPair }
        if not isinstance(self, Archetype) {
            raise TypeError("KeywordsRole requires a Archetype source");
        }
        if not isinstance(child, KWPair) {
            raise TypeError("KeywordsRole requires a KWPair target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:KeywordsRole:+> child;
        return;
    }
    if role is KvPairRole {
        import from jaclang.compiler.ir.syntax.nodes { DictCompr, KVPair }
        if not isinstance(self, DictCompr) {
            raise TypeError("KvPairRole requires a DictCompr source");
        }
        if not isinstance(child, KVPair) {
            raise TypeError("KvPairRole requires a KVPair target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:KvPairRole:+> child;
        return;
    }
    if role is KvPairsRole {
        import from jaclang.compiler.ir.syntax.nodes { DictVal, KVPair }
        if not isinstance(self, DictVal) {
            raise TypeError("KvPairsRole requires a DictVal source");
        }
        if not isinstance(child, KVPair) {
            raise TypeError("KvPairsRole requires a KVPair target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:KvPairsRole:+> child;
        return;
    }
    if role is KwPatternsRole {
        import from jaclang.compiler.ir.syntax.nodes { MatchArch, MatchKVPair }
        if not isinstance(self, MatchArch) {
            raise TypeError("KwPatternsRole requires a MatchArch source");
        }
        if not isinstance(child, MatchKVPair) {
            raise TypeError("KwPatternsRole requires a MatchKVPair target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:KwPatternsRole:+> child;
        return;
    }
    if role is KwargsRole {
        import from jaclang.compiler.ir.syntax.nodes { FuncSignature, ParamVar }
        if not isinstance(self, FuncSignature) {
            raise TypeError("KwargsRole requires a FuncSignature source");
        }
        if not isinstance(child, ParamVar) {
            raise TypeError("KwargsRole requires a ParamVar target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:KwargsRole:+> child;
        return;
    }
    if role is KwonlyargsRole {
        import from jaclang.compiler.ir.syntax.nodes { FuncSignature, ParamVar }
        if not isinstance(self, FuncSignature) {
            raise TypeError("KwonlyargsRole requires a FuncSignature source");
        }
        if not isinstance(child, ParamVar) {
            raise TypeError("KwonlyargsRole requires a ParamVar target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:KwonlyargsRole:+> child;
        return;
    }
    if role is LeftRole {
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Expr) {
            raise TypeError("LeftRole requires a Expr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("LeftRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:LeftRole:+> child;
        return;
    }
    if role is MainRole {
        import from jaclang.compiler.ir.syntax.nodes { Module, ProgramModule }
        if not isinstance(self, ProgramModule) {
            raise TypeError("MainRole requires a ProgramModule source");
        }
        if not isinstance(child, Module) {
            raise TypeError("MainRole requires a Module target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:MainRole:+> child;
        return;
    }
    if role is NameRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:NameRole:+> child;
        return;
    }
    if role is NameRefRole {
        import from jaclang.compiler.ir.syntax.nodes { Ability, NameAtom }
        if not isinstance(self, Ability) {
            raise TypeError("NameRefRole requires a Ability source");
        }
        if not isinstance(child, NameAtom) {
            raise TypeError("NameRefRole requires a NameAtom target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:NameRefRole:+> child;
        return;
    }
    if role is OpRole {
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Expr) {
            raise TypeError("OpRole requires a Expr source");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:OpRole:+> child;
        return;
    }
    if role is OperandRole {
        import from jaclang.compiler.ir.syntax.nodes { UnaryExpr }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, UnaryExpr) {
            raise TypeError("OperandRole requires a UnaryExpr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("OperandRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:OperandRole:+> child;
        return;
    }
    if role is OpsRole {
        import from jaclang.compiler.ir.syntax.nodes { CompareExpr, Token }
        if not isinstance(self, CompareExpr) {
            raise TypeError("OpsRole requires a CompareExpr source");
        }
        if not isinstance(child, Token) {
            raise TypeError("OpsRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:OpsRole:+> child;
        return;
    }
    if role is OutExprRole {
        import from jaclang.compiler.ir.syntax.nodes { ListCompr }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, ListCompr) {
            raise TypeError("OutExprRole requires a ListCompr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("OutExprRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:OutExprRole:+> child;
        return;
    }
    if role is ParamsRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ParamsRole:+> child;
        return;
    }
    if role is PartsRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:PartsRole:+> child;
        return;
    }
    if role is PathRole {
        import from jaclang.compiler.ir.syntax.nodes { AtomExpr, ModulePath }
        if not isinstance(self, ModulePath) {
            raise TypeError("PathRole requires a ModulePath source");
        }
        if not isinstance(child, AtomExpr) {
            raise TypeError("PathRole requires a AtomExpr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:PathRole:+> child;
        return;
    }
    if role is PatternRole {
        import from jaclang.compiler.ir.syntax.nodes { MatchPattern }
        if not isinstance(child, MatchPattern) {
            raise TypeError("PatternRole requires a MatchPattern target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:PatternRole:+> child;
        return;
    }
    if role is PatternsRole {
        import from jaclang.compiler.ir.syntax.nodes { MatchOr, MatchPattern }
        if not isinstance(self, MatchOr) {
            raise TypeError("PatternsRole requires a MatchOr source");
        }
        if not isinstance(child, MatchPattern) {
            raise TypeError("PatternsRole requires a MatchPattern target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:PatternsRole:+> child;
        return;
    }
    if role is PosonlyParamsRole {
        import from jaclang.compiler.ir.syntax.nodes { FuncSignature, ParamVar }
        if not isinstance(self, FuncSignature) {
            raise TypeError("PosonlyParamsRole requires a FuncSignature source");
        }
        if not isinstance(child, ParamVar) {
            raise TypeError("PosonlyParamsRole requires a ParamVar target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:PosonlyParamsRole:+> child;
        return;
    }
    if role is ReturnTypeRole {
        import from jaclang.compiler.ir.syntax.nodes { FuncSignature }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, FuncSignature) {
            raise TypeError("ReturnTypeRole requires a FuncSignature source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ReturnTypeRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ReturnTypeRole:+> child;
        return;
    }
    if role is RightRole {
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Expr) {
            raise TypeError("RightRole requires a Expr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("RightRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:RightRole:+> child;
        return;
    }
    if role is RightsRole {
        import from jaclang.compiler.ir.syntax.nodes { CompareExpr }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, CompareExpr) {
            raise TypeError("RightsRole requires a CompareExpr source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("RightsRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:RightsRole:+> child;
        return;
    }
    if role is SignatureRole {
        import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
        if not isinstance(self, UniScopeNode) {
            raise TypeError("SignatureRole requires a UniScopeNode source");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:SignatureRole:+> child;
        return;
    }
    if role is SlicesRole {
        import from jaclang.compiler.ir.syntax.nodes { IndexSlice, Slice }
        if not isinstance(self, IndexSlice) {
            raise TypeError("SlicesRole requires a IndexSlice source");
        }
        if not isinstance(child, Slice) {
            raise TypeError("SlicesRole requires a Slice target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:SlicesRole:+> child;
        return;
    }
    if role is SpecRole {
        import from jaclang.compiler.ir.syntax.nodes { ImplDef }
        if not isinstance(self, ImplDef) {
            raise TypeError("SpecRole requires a ImplDef source");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:SpecRole:+> child;
        return;
    }
    if role is SrcEndpointRole {
        import from jaclang.compiler.ir.syntax.nodes { Archetype }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Archetype) {
            raise TypeError("SrcEndpointRole requires a Archetype source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("SrcEndpointRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:SrcEndpointRole:+> child;
        return;
    }
    if role is StartRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:StartRole:+> child;
        return;
    }
    if role is StepRole {
        import from jaclang.compiler.ir.syntax.nodes { Slice }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Slice) {
            raise TypeError("StepRole requires a Slice source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("StepRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:StepRole:+> child;
        return;
    }
    if role is StopRole {
        import from jaclang.compiler.ir.syntax.nodes { Slice }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Slice) {
            raise TypeError("StopRole requires a Slice source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("StopRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:StopRole:+> child;
        return;
    }
    if role is StringsRole {
        import from jaclang.compiler.ir.syntax.nodes { AtomExpr, MultiString }
        if not isinstance(self, MultiString) {
            raise TypeError("StringsRole requires a MultiString source");
        }
        if not isinstance(child, AtomExpr) {
            raise TypeError("StringsRole requires a AtomExpr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:StringsRole:+> child;
        return;
    }
    if role is TargetRole {
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(child, Expr) {
            raise TypeError("TargetRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:TargetRole:+> child;
        return;
    }
    if role is TgtEndpointRole {
        import from jaclang.compiler.ir.syntax.nodes { Archetype }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Archetype) {
            raise TypeError("TgtEndpointRole requires a Archetype source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("TgtEndpointRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:TgtEndpointRole:+> child;
        return;
    }
    if role is TokRole {
        import from jaclang.compiler.ir.syntax.nodes { ConcurrentExpr, Token }
        if not isinstance(self, ConcurrentExpr) {
            raise TypeError("TokRole requires a ConcurrentExpr source");
        }
        if not isinstance(child, Token) {
            raise TypeError("TokRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:TokRole:+> child;
        return;
    }
    if role is TypeCtxRole {
        import from jaclang.compiler.ir.syntax.nodes { TypedCtxBlock }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, TypedCtxBlock) {
            raise TypeError("TypeCtxRole requires a TypedCtxBlock source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("TypeCtxRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:TypeCtxRole:+> child;
        return;
    }
    if role is TypeParamsRole {
        import from jaclang.compiler.ir.syntax.nodes { CodeBlockStmt, TypeParam }
        if not isinstance(self, CodeBlockStmt) {
            raise TypeError("TypeParamsRole requires a CodeBlockStmt source");
        }
        if not isinstance(child, TypeParam) {
            raise TypeError("TypeParamsRole requires a TypeParam target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:TypeParamsRole:+> child;
        return;
    }
    if role is TypeTagRole {
        import from jaclang.compiler.ir.syntax.nodes { SubTag }
        import from jaclang.compiler.ir.types.syntax { AstTypedVarNode }
        if not isinstance(self, AstTypedVarNode) {
            raise TypeError("TypeTagRole requires a AstTypedVarNode source");
        }
        if not isinstance(child, SubTag) {
            raise TypeError("TypeTagRole requires a SubTag target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:TypeTagRole:+> child;
        return;
    }
    if role is UnpackRole {
        import from jaclang.compiler.ir.syntax.nodes { ParamVar, Token }
        if not isinstance(self, ParamVar) {
            raise TypeError("UnpackRole requires a ParamVar source");
        }
        if not isinstance(child, Token) {
            raise TypeError("UnpackRole requires a Token target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:UnpackRole:+> child;
        return;
    }
    if role is ValueRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ValueRole:+> child;
        return;
    }
    if role is ValueTypeRole {
        import from jaclang.compiler.ir.syntax.nodes { Enum }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Enum) {
            raise TypeError("ValueTypeRole requires a Enum source");
        }
        if not isinstance(child, Expr) {
            raise TypeError("ValueTypeRole requires a Expr target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ValueTypeRole:+> child;
        return;
    }
    if role is ValuesRole {
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:ValuesRole:+> child;
        return;
    }
    if role is VarargsRole {
        import from jaclang.compiler.ir.syntax.nodes { FuncSignature, ParamVar }
        if not isinstance(self, FuncSignature) {
            raise TypeError("VarargsRole requires a FuncSignature source");
        }
        if not isinstance(child, ParamVar) {
            raise TypeError("VarargsRole requires a ParamVar target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:VarargsRole:+> child;
        return;
    }
    if role is VarsRole {
        import from jaclang.compiler.ir.syntax.nodes { ArchHas, HasVar }
        if not isinstance(self, ArchHas) {
            raise TypeError("VarsRole requires a ArchHas source");
        }
        if not isinstance(child, HasVar) {
            raise TypeError("VarsRole requires a HasVar target");
        }
        if check_only {
            self.check_connection(child, RelationFamily.STRUCTURE);
            return;
        }
        self.prepare_connection(child, RelationFamily.STRUCTURE);
        self +>:VarsRole:+> child;
        return;
    }
    raise ValueError("Unregistered compiler structural role");
}

impl UniNode._as_node_list(value: Sequence[UniNode]) -> list[UniNode] {
    return list(value);
}

impl UniNode._link(
    kid: Sequence[UniNode], roles: dict[type, UniNode | Sequence[UniNode] | None]
) -> None {
    import from collections.abc { Sequence }
    import from jaclang.compiler.ir.syntax.edges { Kid }

    if not roles {
        for k in kid {
            if k is not None {
                self.prepare_connection(k, RelationFamily.STRUCTURE);
                self +>:Kid:+> k;
            }
        }
        return;
    }

    role_of: dict[int, type] = {};
    extra_roles: dict[int, list[type]] = {};
    if roles {
        shapes: dict[type, str] = self?._role_shapes or {};
        self._role_shapes = shapes;
        for (role, value) in roles.items() {
            if value is None {
                shapes[role] = "none";
            } elif isinstance(value, (list, tuple)) {
                shapes[role] = "many";
                vlist = self._as_node_list(value);
                for v in vlist {
                    if isinstance(v, UniNode) {
                        prev = role_of.get(id(v));
                        if prev is None {
                            role_of[id(v)] = role;
                        } elif prev is not role {
                            extra_roles.setdefault(id(v), []).append(role);
                        }
                    }
                }
            } elif isinstance(value, UniNode) {
                shapes[role] = "one";
                prev = role_of.get(id(value));
                if prev is None {
                    role_of[id(value)] = role;
                } elif prev is not role {
                    extra_roles.setdefault(id(value), []).append(role);
                }
            } else {
                shapes[role] = "none";
            }
        }
    }
    attached: set[int] = set();
    for k in kid {
        if k is not None {
            self.prepare_connection(k, RelationFamily.STRUCTURE);
            self +>:Kid:+> k;
            role = role_of.get(id(k));
            if role is not None and id(k) not in attached {
                self._attach(k, role);
                attached.add(id(k));
                if extra_roles {
                    for extra in extra_roles.get(id(k), []) {
                        self._attach(k, extra);
                    }
                }
            }
        }
    }
    for (role, value) in roles.items() {
        if isinstance(value, (list, tuple)) {
            vlist2 = self._as_node_list(value);
            for v in vlist2 {
                if isinstance(v, UniNode) and id(v) not in attached {
                    self._attach(v, role);
                    attached.add(id(v));
                    if extra_roles {
                        for extra in extra_roles.get(id(v), []) {
                            if extra is not role {
                                self._attach(v, extra);
                            }
                        }
                    }
                }
            }
        } elif isinstance(value, UniNode) and id(value) not in attached {
            one: UniNode = value;
            self._attach(one, role);
            attached.add(id(one));
            if extra_roles {
                for extra in extra_roles.get(id(one), []) {
                    if extra is not role {
                        self._attach(one, extra);
                    }
                }
            }
        }
    }
}

impl UniNode._children -> list[UniNode] {
    import from jaclang.compiler.ir.syntax.edges { Role }

    out: list[UniNode] = self.kid;
    seen: set[int] = {id(k) for k in out};
    for tgt in [self->:Role:->] {
        if id(tgt) not in seen {
            seen.add(id(tgt));
            out.append(tgt);
        }
    }
    return out;
}

impl UniNode.kid.getter -> list[UniNode] {
    import from jaclang.compiler.ir.syntax.edges { Kid }

    return [self->:Kid:->];
}

impl UniNode.parent.getter -> (UniNode | None) {
    import from jaclang.compiler.ir.syntax.edges { Role, Kid }

    found = [self<-:Kid:<-];
    if found {
        return found[-1];
    }
    holders = [self<-:Role:<-];
    return holders[-1] if holders else self._ctx_parent;
}

impl UniNode._role_shaped(
    role: type[Role], found: list[UniNode]
) -> UniNode | list[UniNode] | None {
    import from jaclang.compiler.ir.syntax.edges { Role }

    shape = (self?._role_shapes or {}).get(role, "none");
    if shape == "many" {
        return found;
    }
    if shape == "one" {
        return found[0] if found else None;
    }
    return None;
}

impl UniNode._assert_thawed -> None {
    if self.mutation_permit is not None {
        self.mutation_permit.require(RelationFamily.STRUCTURE);
    }
    if self._struct_frozen {
        raise RuntimeError(
            f"structural mutation of frozen node {type(self).__name__}; "
            "call thaw_structure() on the module first"
        );
    }
}

impl UniNode.freeze_structure -> None {
    stack: list[UniNode] = [self];
    seen: set[int] = set();
    while stack {
        nd = stack.pop();
        if id(nd) in seen {
            continue;
        }
        seen.add(id(nd));
        nd._struct_frozen = True;
        for tgt in nd._children() {
            if id(tgt) not in seen {
                stack.append(tgt);
            }
        }
    }
}

impl UniNode.thaw_structure -> None {
    stack: list[UniNode] = [self];
    seen: set[int] = set();
    while stack {
        nd = stack.pop();
        if id(nd) in seen {
            continue;
        }
        seen.add(id(nd));
        nd._struct_frozen = False;
        for tgt in nd._children() {
            if id(tgt) not in seen {
                stack.append(tgt);
            }
        }
    }
}

impl UniNode.structure_thawed -> StructureThaw {
    return StructureThaw(target=self);
}

impl StructureThaw.__enter__ -> StructureThaw {
    self.refreeze = self.target._struct_frozen;
    if self.refreeze {
        self.target.thaw_structure();
    }
    return self;
}

impl StructureThaw.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    if self.refreeze {
        self.target.freeze_structure();
    }
    return False;
}

impl UniNode._role_clear(role: type[Role]) -> None {
    self.changed_relations(RelationFamily.STRUCTURE);
    import from jaclang.compiler.ir.syntax.edges {
        Role,
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

    if role is Role {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:Role:->];
        return;
    }
    if role is AccessRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AccessRole:->];
        return;
    }
    if role is AccessorsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AccessorsRole:->];
        return;
    }
    if role is AliasRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AliasRole:->];
        return;
    }
    if role is ArchTagInfoRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ArchTagInfoRole:->];
        return;
    }
    if role is ArchTypeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ArchTypeRole:->];
        return;
    }
    if role is ArgPatternsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ArgPatternsRole:->];
        return;
    }
    if role is AssignmentsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AssignmentsRole:->];
        return;
    }
    if role is AssignsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AssignsRole:->];
        return;
    }
    if role is AttributesRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AttributesRole:->];
        return;
    }
    if role is AugOpRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AugOpRole:->];
        return;
    }
    if role is AwaitingBodyRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:AwaitingBodyRole:->];
        return;
    }
    if role is BaseClassesRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:BaseClassesRole:->];
        return;
    }
    if role is BodyRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:BodyRole:->];
        return;
    }
    if role is BoundRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:BoundRole:->];
        return;
    }
    if role is CasesRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:CasesRole:->];
        return;
    }
    if role is CastTypeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:CastTypeRole:->];
        return;
    }
    if role is CauseRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:CauseRole:->];
        return;
    }
    if role is ChainRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ChainRole:->];
        return;
    }
    if role is ChildrenRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ChildrenRole:->];
        return;
    }
    if role is ClibDeclsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ClibDeclsRole:->];
        return;
    }
    if role is CodeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:CodeRole:->];
        return;
    }
    if role is CollectionRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:CollectionRole:->];
        return;
    }
    if role is ComparesRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ComparesRole:->];
        return;
    }
    if role is ComprRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ComprRole:->];
        return;
    }
    if role is ConditionRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ConditionRole:->];
        return;
    }
    if role is ConditionalRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ConditionalRole:->];
        return;
    }
    if role is ConnAssignRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ConnAssignRole:->];
        return;
    }
    if role is ConnTypeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ConnTypeRole:->];
        return;
    }
    if role is CountByRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:CountByRole:->];
        return;
    }
    if role is CtrlRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:CtrlRole:->];
        return;
    }
    if role is DecoratorsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:DecoratorsRole:->];
        return;
    }
    if role is DefaultValRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:DefaultValRole:->];
        return;
    }
    if role is DescriptionRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:DescriptionRole:->];
        return;
    }
    if role is DocRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:DocRole:->];
        return;
    }
    if role is DynamicTagRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:DynamicTagRole:->];
        return;
    }
    if role is EdgeSpecRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:EdgeSpecRole:->];
        return;
    }
    if role is ElseBodyRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ElseBodyRole:->];
        return;
    }
    if role is ElseValueRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ElseValueRole:->];
        return;
    }
    if role is EndRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:EndRole:->];
        return;
    }
    if role is ErrorMsgRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ErrorMsgRole:->];
        return;
    }
    if role is EventRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:EventRole:->];
        return;
    }
    if role is ExTypeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ExTypeRole:->];
        return;
    }
    if role is ExceptsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ExceptsRole:->];
        return;
    }
    if role is ExprRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ExprRole:->];
        return;
    }
    if role is ExprsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ExprsRole:->];
        return;
    }
    if role is FTypeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:FTypeRole:->];
        return;
    }
    if role is FilterCondRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:FilterCondRole:->];
        return;
    }
    if role is FinallyBodyRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:FinallyBodyRole:->];
        return;
    }
    if role is FormatPartRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:FormatPartRole:->];
        return;
    }
    if role is FormatSpecRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:FormatSpecRole:->];
        return;
    }
    if role is FromLocRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:FromLocRole:->];
        return;
    }
    if role is FromTargetRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:FromTargetRole:->];
        return;
    }
    if role is GuardRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:GuardRole:->];
        return;
    }
    if role is HintRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:HintRole:->];
        return;
    }
    if role is InsertLocRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:InsertLocRole:->];
        return;
    }
    if role is ItemsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ItemsRole:->];
        return;
    }
    if role is IterRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:IterRole:->];
        return;
    }
    if role is KeyRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:KeyRole:->];
        return;
    }
    if role is KeywordsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:KeywordsRole:->];
        return;
    }
    if role is KvPairRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:KvPairRole:->];
        return;
    }
    if role is KvPairsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:KvPairsRole:->];
        return;
    }
    if role is KwPatternsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:KwPatternsRole:->];
        return;
    }
    if role is KwargsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:KwargsRole:->];
        return;
    }
    if role is KwonlyargsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:KwonlyargsRole:->];
        return;
    }
    if role is LeftRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:LeftRole:->];
        return;
    }
    if role is MainRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:MainRole:->];
        return;
    }
    if role is NameRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:NameRole:->];
        return;
    }
    if role is NameRefRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:NameRefRole:->];
        return;
    }
    if role is OpRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:OpRole:->];
        return;
    }
    if role is OperandRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:OperandRole:->];
        return;
    }
    if role is OpsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:OpsRole:->];
        return;
    }
    if role is OutExprRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:OutExprRole:->];
        return;
    }
    if role is ParamsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ParamsRole:->];
        return;
    }
    if role is PartsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:PartsRole:->];
        return;
    }
    if role is PathRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:PathRole:->];
        return;
    }
    if role is PatternRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:PatternRole:->];
        return;
    }
    if role is PatternsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:PatternsRole:->];
        return;
    }
    if role is PosonlyParamsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:PosonlyParamsRole:->];
        return;
    }
    if role is ReturnTypeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ReturnTypeRole:->];
        return;
    }
    if role is RightRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:RightRole:->];
        return;
    }
    if role is RightsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:RightsRole:->];
        return;
    }
    if role is SignatureRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:SignatureRole:->];
        return;
    }
    if role is SlicesRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:SlicesRole:->];
        return;
    }
    if role is SpecRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:SpecRole:->];
        return;
    }
    if role is SrcEndpointRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:SrcEndpointRole:->];
        return;
    }
    if role is StartRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:StartRole:->];
        return;
    }
    if role is StepRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:StepRole:->];
        return;
    }
    if role is StopRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:StopRole:->];
        return;
    }
    if role is StringsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:StringsRole:->];
        return;
    }
    if role is TargetRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:TargetRole:->];
        return;
    }
    if role is TgtEndpointRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:TgtEndpointRole:->];
        return;
    }
    if role is TokRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:TokRole:->];
        return;
    }
    if role is TypeCtxRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:TypeCtxRole:->];
        return;
    }
    if role is TypeParamsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:TypeParamsRole:->];
        return;
    }
    if role is TypeTagRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:TypeTagRole:->];
        return;
    }
    if role is UnpackRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:UnpackRole:->];
        return;
    }
    if role is ValueRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ValueRole:->];
        return;
    }
    if role is ValueTypeRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ValueTypeRole:->];
        return;
    }
    if role is ValuesRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:ValuesRole:->];
        return;
    }
    if role is VarargsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:VarargsRole:->];
        return;
    }
    if role is VarsRole {
        self.changed_relations(RelationFamily.STRUCTURE);
        del [edge self->:VarsRole:->];
        return;
    }
}

impl UniNode._role_set(
    role: type[Role], value: UniNode | Sequence[UniNode] | None
) -> None {
    import from jaclang.compiler.ir.syntax.edges { Role }
    proposed: list[UniNode] = [];
    shape = "none";
    if isinstance(value, UniNode) {
        proposed.append(value);
        shape = "one";
    } elif value is not None {
        proposed = self._as_node_list(value);
        shape = "many";
    }
    for node in proposed {
        self._attach(node, role, check_only=True);
    }
    shapes: dict[type, str] = self?._role_shapes or {};
    self._role_shapes = shapes;
    self._role_clear(role);
    shapes[role] = shape;
    for node in proposed {
        self._attach(node, role);
    }
    self._invalidate_sub_node_tab();
}


impl UniNode._sub_node_tab.getter -> dict[(type, list[UniNode])] {
    if (self.__sub_node_tab is None) {
        self.__sub_node_tab = {};
        self._construct_sub_node_tab();
    }
    return self.__sub_node_tab;
}

impl UniNode._construct_sub_node_tab -> None {
    index = self.__sub_node_tab;
    assert index is not None;
    pending: list[tuple[UniNode, bool]] = [
        (child, False) for child in reversed(self.kid)
    ];
    active: set[int] = {id(self)};
    while pending {
        (node, visited) = pending.pop();
        if node.ct_pruned {
            continue;
        }
        if visited {
            active.remove(id(node));
            index.setdefault(type(node), []).append(node);
        } else {
            if id(node) in active {
                raise ValueError("Cycle in compiler syntax structure");
            }
            active.add(id(node));
            pending.append((node, True));
            pending.extend((child, False) for child in reversed(node.kid));
        }
    }
}


impl UniNode._invalidate_sub_node_tab -> None {
    cur: (UniNode | None) = self;
    while cur is not None {
        cur.__sub_node_tab = None;
        cur = cur.parent;
    }
}

impl UniNode.sym_tab.getter -> UniScopeNode {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    import from jaclang.compiler.ir.syntax.nodes { Module }

    nd: (UniNode | None) = self;

    while nd is not None {
        if isinstance(nd, UniScopeNode) {
            if isinstance(nd, Module) {
                return nd;
            }

            if nd.parent_scope is not None {
                return nd;
            }
        }
        nd = nd.parent;
    }
    raise ValueError("No scope found");
}

impl UniNode.add_kids_left(
    nodes: Sequence[UniNode],
    pos_update: bool = True,
    parent_update: bool = False,
    role: (type[Role] | None) = None
) -> UniNode {
    import from collections.abc { Sequence }
    import from jaclang.compiler.ir.syntax.edges { Role }

    self.set_kids([*nodes, *self.kid], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.add_kids_right(
    nodes: Sequence[UniNode],
    pos_update: bool = True,
    parent_update: bool = False,
    role: (type[Role] | None) = None
) -> UniNode {
    import from collections.abc { Sequence }
    import from jaclang.compiler.ir.syntax.edges { Role }

    self.set_kids([*self.kid, *nodes], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.insert_kids_at_pos(
    nodes: Sequence[UniNode],
    pos: int,
    pos_update: bool = True,
    role: (type[Role] | None) = None
) -> UniNode {
    import from collections.abc { Sequence }
    import from jaclang.compiler.ir.syntax.edges { Role }

    cur = self.kid;
    self.set_kids([*cur[:pos], *nodes, *cur[pos:]], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.set_kids(nodes: Sequence[UniNode], pos_update: bool = True) -> UniNode {
    import from collections.abc { Sequence }
    import from jaclang.compiler.ir.syntax.edges { Kid }

    for node in nodes {
        if not isinstance(node, UniNode) {
            raise TypeError("Kid requires a compiler syntax node");
        }
    }
    self._assert_thawed();
    self.changed_relations(RelationFamily.STRUCTURE);
    del [edge self->:Kid:->];
    for n in nodes {
        if n is not None {
            self.prepare_connection(n, RelationFamily.STRUCTURE);
            self +>:Kid:+> n;
        }
    }
    self._invalidate_sub_node_tab();
    if pos_update {
        self.loc.update_token_range(*self.resolve_tok_range());
    }
    return self;
}

impl UniNode.replace_kid(old: UniNode, new: UniNode) -> UniNode {
    import from jaclang.compiler.ir.syntax.edges { Role }

    self._assert_thawed();
    roles: list[type] = [];
    for e in [edge self->:Role:->] {
        if getattr(e, "__jac__").target.archetype is old and `type(e) not in roles {
            roles.append(`type(e));
        }
    }
    for role in roles {
        targets = [self->:role:->];
        del [edge self->:role:->];
        for t in targets {
            self._attach(new if t is old else t, role);
        }
    }
    self.set_kids([new if k is old else k for k in self.kid], pos_update=False);
    return self;
}

impl UniNode.detached_copy -> UniNode {
    import copy;

    return copy.deepcopy(self);
}

impl UniNode.__deepcopy__(memo: dict) -> UniNode {
    import from jaclang.compiler.ir.syntax.edges { Role, Kid }

    import copy;

    dup = object.__new__(type(self));
    memo[id(self)] = dup;
    for (key, val) in self.__dict__.items() {
        if key == "__jac__" {
            continue;
        }
        if key
            in (
                "mutation_permit",
                "_ctx_parent",
                "_type_sym_tab",
                "_type_cache",
                "_names_index",
                "_overload_index",
                "declaration_symbol",
                "ct_value"
            )
            or key.endswith("__sub_node_tab") {
            dup.__dict__[key] = None;
        } elif key in ("_struct_frozen", "_type_cache_ok") {
            dup.__dict__[key] = False;
        } elif key == "capture_symbols" {
            dup.__dict__[key] = [];
        } elif key == "implicit_rebinds" {
            dup.__dict__[key] = {};
        } elif key
            in ("_type_generation", "_names_generation", "_overload_generation") {
            dup.__dict__[key] = -1;
        } elif key == "orig_src" {
            dup.__dict__[key] = val;
        } else {
            dup.__dict__[key] = copy.deepcopy(val, memo);
        }
    }
    for k in self.kid {
        kc = copy.deepcopy(k, memo);
        dup.prepare_connection(kc, RelationFamily.STRUCTURE);
        dup +>:Kid:+> kc;
    }
    roles: list[type] = [];
    for e in [edge self->:Role:->] {
        if `type(e) not in roles {
            roles.append(`type(e));
        }
    }
    for role in roles {
        for tgt in [self->:role:->] {
            dup._attach(copy.deepcopy(tgt, memo), role);
        }
    }
    return dup;
}

impl UniNode.set_parent(parent: UniNode) -> UniNode {
    self._ctx_parent = parent;
    return self;
}

impl UniNode.resolve_tok_range -> tuple[(Token, Token)] {
    import from jaclang.compiler.ir.syntax.nodes { Token }

    kids = self.kid;
    if kids {
        return (kids[0].loc.first_tok, kids[-1].loc.last_tok);
    } elif isinstance(self, Token) {
        return (self, self);
    } else {
        raise ValueError(f"Empty kid for Token {type(self).__name__}");
    }
}

impl UniNode.gen_token(name: Tok, value: (str | None) = None) -> Token {
    import from jaclang.compiler.ir.syntax.nodes { Token }
    import from jaclang.compiler.ir.enums { DELIM_MAP }
    import from jaclang.compiler.ir.enums { Tokens as Tok }

    import from jaclang.compiler.ir.enums { TOKEN_MAP }
    if value is None {
        value = DELIM_MAP[name]
            if (name in DELIM_MAP)
            else TOKEN_MAP.get(name.value, name.value);
    }
    return Token(
        name=name,
        value=value,
        orig_src=self.loc.orig_src,
        col_start=self.loc.col_start,
        col_end=0,
        line=self.loc.first_line,
        end_line=self.loc.last_line,
        pos_start=0,
        pos_end=0
    );
}


impl UniNode.codespace -> CodeContext {
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.syntax.nodes { Module }
    import from jaclang.compiler.ir.enums { CodeContext }

    if isinstance(self, ContextAwareNode) {
        if (self.code_context == CodeContext.CLIENT) {
            return CodeContext.CLIENT;
        }
        if (self.code_context == CodeContext.NATIVE) {
            return CodeContext.NATIVE;
        }
    }
    nd: (UniNode | None) = self.parent;
    while (nd is not None) {
        if isinstance(nd, ContextAwareNode) {
            context = nd.code_context;
            if (context == CodeContext.CLIENT) {
                return CodeContext.CLIENT;
            }
            if (context == CodeContext.NATIVE) {
                return CodeContext.NATIVE;
            }
        }
        if isinstance(nd, Module) {
            if nd.decided_codespace == CodeContext.NATIVE.value {
                return CodeContext.NATIVE;
            }
            if nd.decided_codespace == CodeContext.CLIENT.value {
                return CodeContext.CLIENT;
            }
            return CodeContext.SERVER;
        }
        nd = nd.parent;
    }
    return CodeContext.SERVER;
}

impl UniNode.in_client_context -> bool {
    import from jaclang.compiler.ir.enums { CodeContext }

    return self.codespace() == CodeContext.CLIENT;
}

impl UniNode.in_native_context -> bool {
    import from jaclang.compiler.ir.enums { CodeContext }

    return self.codespace() == CodeContext.NATIVE;
}

impl UniNode.flatten -> list[UniNode] {
    ret: list[UniNode] = [self];
    for k in self.kid {
        if k.ct_pruned {
            continue;
        }
        ret += k.flatten();
    }
    return ret;
}
