impl UniNode.postinit -> None {
    self.__sub_node_tab = None;
    self._ctx_parent = None;
    self._struct_frozen = False;
    self._in_mod_nodes = [];
    self._gen = None;
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

impl UniNode._attach(child: UniNode, role: type[Role]) -> None {
    if role is Role {
        self +>:Role:+> child;
        return;
    }
    if role is ImplOf {
        self +>:ImplOf:+> child;
        return;
    }
    if role is AccessRole {
        self +>:AccessRole:+> child;
        return;
    }
    if role is AccessorsRole {
        self +>:AccessorsRole:+> child;
        return;
    }
    if role is AliasRole {
        self +>:AliasRole:+> child;
        return;
    }
    if role is ArchTagInfoRole {
        self +>:ArchTagInfoRole:+> child;
        return;
    }
    if role is ArchTypeRole {
        self +>:ArchTypeRole:+> child;
        return;
    }
    if role is ArgPatternsRole {
        self +>:ArgPatternsRole:+> child;
        return;
    }
    if role is AssignmentsRole {
        self +>:AssignmentsRole:+> child;
        return;
    }
    if role is AssignsRole {
        self +>:AssignsRole:+> child;
        return;
    }
    if role is AttributesRole {
        self +>:AttributesRole:+> child;
        return;
    }
    if role is AugOpRole {
        self +>:AugOpRole:+> child;
        return;
    }
    if role is AwaitingBodyRole {
        self +>:AwaitingBodyRole:+> child;
        return;
    }
    if role is BaseClassesRole {
        self +>:BaseClassesRole:+> child;
        return;
    }
    if role is BodyRole {
        self +>:BodyRole:+> child;
        return;
    }
    if role is BoundRole {
        self +>:BoundRole:+> child;
        return;
    }
    if role is CasesRole {
        self +>:CasesRole:+> child;
        return;
    }
    if role is CastTypeRole {
        self +>:CastTypeRole:+> child;
        return;
    }
    if role is CauseRole {
        self +>:CauseRole:+> child;
        return;
    }
    if role is ChainRole {
        self +>:ChainRole:+> child;
        return;
    }
    if role is ChildrenRole {
        self +>:ChildrenRole:+> child;
        return;
    }
    if role is ClibDeclsRole {
        self +>:ClibDeclsRole:+> child;
        return;
    }
    if role is CodeRole {
        self +>:CodeRole:+> child;
        return;
    }
    if role is CollectionRole {
        self +>:CollectionRole:+> child;
        return;
    }
    if role is ComparesRole {
        self +>:ComparesRole:+> child;
        return;
    }
    if role is ComprRole {
        self +>:ComprRole:+> child;
        return;
    }
    if role is ConditionRole {
        self +>:ConditionRole:+> child;
        return;
    }
    if role is ConditionalRole {
        self +>:ConditionalRole:+> child;
        return;
    }
    if role is ConnAssignRole {
        self +>:ConnAssignRole:+> child;
        return;
    }
    if role is ConnTypeRole {
        self +>:ConnTypeRole:+> child;
        return;
    }
    if role is CountByRole {
        self +>:CountByRole:+> child;
        return;
    }
    if role is CtrlRole {
        self +>:CtrlRole:+> child;
        return;
    }
    if role is DecoratorsRole {
        self +>:DecoratorsRole:+> child;
        return;
    }
    if role is DefaultValRole {
        self +>:DefaultValRole:+> child;
        return;
    }
    if role is DescriptionRole {
        self +>:DescriptionRole:+> child;
        return;
    }
    if role is DocRole {
        self +>:DocRole:+> child;
        return;
    }
    if role is DynamicTagRole {
        self +>:DynamicTagRole:+> child;
        return;
    }
    if role is EdgeSpecRole {
        self +>:EdgeSpecRole:+> child;
        return;
    }
    if role is ElseBodyRole {
        self +>:ElseBodyRole:+> child;
        return;
    }
    if role is ElseValueRole {
        self +>:ElseValueRole:+> child;
        return;
    }
    if role is EndRole {
        self +>:EndRole:+> child;
        return;
    }
    if role is ErrorMsgRole {
        self +>:ErrorMsgRole:+> child;
        return;
    }
    if role is EventRole {
        self +>:EventRole:+> child;
        return;
    }
    if role is ExTypeRole {
        self +>:ExTypeRole:+> child;
        return;
    }
    if role is ExceptsRole {
        self +>:ExceptsRole:+> child;
        return;
    }
    if role is ExprRole {
        self +>:ExprRole:+> child;
        return;
    }
    if role is ExprsRole {
        self +>:ExprsRole:+> child;
        return;
    }
    if role is FTypeRole {
        self +>:FTypeRole:+> child;
        return;
    }
    if role is FilterCondRole {
        self +>:FilterCondRole:+> child;
        return;
    }
    if role is FinallyBodyRole {
        self +>:FinallyBodyRole:+> child;
        return;
    }
    if role is FormatPartRole {
        self +>:FormatPartRole:+> child;
        return;
    }
    if role is FormatSpecRole {
        self +>:FormatSpecRole:+> child;
        return;
    }
    if role is FromLocRole {
        self +>:FromLocRole:+> child;
        return;
    }
    if role is FromTargetRole {
        self +>:FromTargetRole:+> child;
        return;
    }
    if role is GuardRole {
        self +>:GuardRole:+> child;
        return;
    }
    if role is HintRole {
        self +>:HintRole:+> child;
        return;
    }
    if role is InsertLocRole {
        self +>:InsertLocRole:+> child;
        return;
    }
    if role is ItemsRole {
        self +>:ItemsRole:+> child;
        return;
    }
    if role is IterRole {
        self +>:IterRole:+> child;
        return;
    }
    if role is KeyRole {
        self +>:KeyRole:+> child;
        return;
    }
    if role is KeywordsRole {
        self +>:KeywordsRole:+> child;
        return;
    }
    if role is KvPairRole {
        self +>:KvPairRole:+> child;
        return;
    }
    if role is KvPairsRole {
        self +>:KvPairsRole:+> child;
        return;
    }
    if role is KwPatternsRole {
        self +>:KwPatternsRole:+> child;
        return;
    }
    if role is KwargsRole {
        self +>:KwargsRole:+> child;
        return;
    }
    if role is KwonlyargsRole {
        self +>:KwonlyargsRole:+> child;
        return;
    }
    if role is LeftRole {
        self +>:LeftRole:+> child;
        return;
    }
    if role is MainRole {
        self +>:MainRole:+> child;
        return;
    }
    if role is NameRole {
        self +>:NameRole:+> child;
        return;
    }
    if role is NameRefRole {
        self +>:NameRefRole:+> child;
        return;
    }
    if role is OpRole {
        self +>:OpRole:+> child;
        return;
    }
    if role is OperandRole {
        self +>:OperandRole:+> child;
        return;
    }
    if role is OpsRole {
        self +>:OpsRole:+> child;
        return;
    }
    if role is OutExprRole {
        self +>:OutExprRole:+> child;
        return;
    }
    if role is ParamsRole {
        self +>:ParamsRole:+> child;
        return;
    }
    if role is PartsRole {
        self +>:PartsRole:+> child;
        return;
    }
    if role is PathRole {
        self +>:PathRole:+> child;
        return;
    }
    if role is PatternRole {
        self +>:PatternRole:+> child;
        return;
    }
    if role is PatternsRole {
        self +>:PatternsRole:+> child;
        return;
    }
    if role is PosonlyParamsRole {
        self +>:PosonlyParamsRole:+> child;
        return;
    }
    if role is ReturnTypeRole {
        self +>:ReturnTypeRole:+> child;
        return;
    }
    if role is RightRole {
        self +>:RightRole:+> child;
        return;
    }
    if role is RightsRole {
        self +>:RightsRole:+> child;
        return;
    }
    if role is SignatureRole {
        self +>:SignatureRole:+> child;
        return;
    }
    if role is SlicesRole {
        self +>:SlicesRole:+> child;
        return;
    }
    if role is SpecRole {
        self +>:SpecRole:+> child;
        return;
    }
    if role is SrcEndpointRole {
        self +>:SrcEndpointRole:+> child;
        return;
    }
    if role is StartRole {
        self +>:StartRole:+> child;
        return;
    }
    if role is StepRole {
        self +>:StepRole:+> child;
        return;
    }
    if role is StopRole {
        self +>:StopRole:+> child;
        return;
    }
    if role is StringsRole {
        self +>:StringsRole:+> child;
        return;
    }
    if role is TargetRole {
        self +>:TargetRole:+> child;
        return;
    }
    if role is TgtEndpointRole {
        self +>:TgtEndpointRole:+> child;
        return;
    }
    if role is TokRole {
        self +>:TokRole:+> child;
        return;
    }
    if role is TypeCtxRole {
        self +>:TypeCtxRole:+> child;
        return;
    }
    if role is TypeParamsRole {
        self +>:TypeParamsRole:+> child;
        return;
    }
    if role is TypeTagRole {
        self +>:TypeTagRole:+> child;
        return;
    }
    if role is UnpackRole {
        self +>:UnpackRole:+> child;
        return;
    }
    if role is ValueRole {
        self +>:ValueRole:+> child;
        return;
    }
    if role is ValueTypeRole {
        self +>:ValueTypeRole:+> child;
        return;
    }
    if role is ValuesRole {
        self +>:ValuesRole:+> child;
        return;
    }
    if role is VarargsRole {
        self +>:VarargsRole:+> child;
        return;
    }
    if role is VarsRole {
        self +>:VarsRole:+> child;
        return;
    }
    self +>:(role):+> child;
}

impl UniNode._as_node_list(value: any) -> list[UniNode] {
    return value;
}

impl UniNode._link(kid: Sequence[UniNode], roles: dict[type, any]) -> None {
    if not roles {
        for k in kid {
            if k is not None {
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
    return [self->:Kid:->];
}

impl UniNode.parent.getter -> (UniNode | None) {
    found = [self<-:Kid:<-];
    if found {
        return found[-1];
    }
    holders = [self<-:Role:<-];
    return holders[-1] if holders else self._ctx_parent;
}

impl UniNode._role_shaped(role: type[Role], found: list[UniNode]) -> any {
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
    if role is Role {
        del [edge self->:Role:->];
        return;
    }
    if role is ImplOf {
        del [edge self->:ImplOf:->];
        return;
    }
    if role is AccessRole {
        del [edge self->:AccessRole:->];
        return;
    }
    if role is AccessorsRole {
        del [edge self->:AccessorsRole:->];
        return;
    }
    if role is AliasRole {
        del [edge self->:AliasRole:->];
        return;
    }
    if role is ArchTagInfoRole {
        del [edge self->:ArchTagInfoRole:->];
        return;
    }
    if role is ArchTypeRole {
        del [edge self->:ArchTypeRole:->];
        return;
    }
    if role is ArgPatternsRole {
        del [edge self->:ArgPatternsRole:->];
        return;
    }
    if role is AssignmentsRole {
        del [edge self->:AssignmentsRole:->];
        return;
    }
    if role is AssignsRole {
        del [edge self->:AssignsRole:->];
        return;
    }
    if role is AttributesRole {
        del [edge self->:AttributesRole:->];
        return;
    }
    if role is AugOpRole {
        del [edge self->:AugOpRole:->];
        return;
    }
    if role is AwaitingBodyRole {
        del [edge self->:AwaitingBodyRole:->];
        return;
    }
    if role is BaseClassesRole {
        del [edge self->:BaseClassesRole:->];
        return;
    }
    if role is BodyRole {
        del [edge self->:BodyRole:->];
        return;
    }
    if role is BoundRole {
        del [edge self->:BoundRole:->];
        return;
    }
    if role is CasesRole {
        del [edge self->:CasesRole:->];
        return;
    }
    if role is CastTypeRole {
        del [edge self->:CastTypeRole:->];
        return;
    }
    if role is CauseRole {
        del [edge self->:CauseRole:->];
        return;
    }
    if role is ChainRole {
        del [edge self->:ChainRole:->];
        return;
    }
    if role is ChildrenRole {
        del [edge self->:ChildrenRole:->];
        return;
    }
    if role is ClibDeclsRole {
        del [edge self->:ClibDeclsRole:->];
        return;
    }
    if role is CodeRole {
        del [edge self->:CodeRole:->];
        return;
    }
    if role is CollectionRole {
        del [edge self->:CollectionRole:->];
        return;
    }
    if role is ComparesRole {
        del [edge self->:ComparesRole:->];
        return;
    }
    if role is ComprRole {
        del [edge self->:ComprRole:->];
        return;
    }
    if role is ConditionRole {
        del [edge self->:ConditionRole:->];
        return;
    }
    if role is ConditionalRole {
        del [edge self->:ConditionalRole:->];
        return;
    }
    if role is ConnAssignRole {
        del [edge self->:ConnAssignRole:->];
        return;
    }
    if role is ConnTypeRole {
        del [edge self->:ConnTypeRole:->];
        return;
    }
    if role is CountByRole {
        del [edge self->:CountByRole:->];
        return;
    }
    if role is CtrlRole {
        del [edge self->:CtrlRole:->];
        return;
    }
    if role is DecoratorsRole {
        del [edge self->:DecoratorsRole:->];
        return;
    }
    if role is DefaultValRole {
        del [edge self->:DefaultValRole:->];
        return;
    }
    if role is DescriptionRole {
        del [edge self->:DescriptionRole:->];
        return;
    }
    if role is DocRole {
        del [edge self->:DocRole:->];
        return;
    }
    if role is DynamicTagRole {
        del [edge self->:DynamicTagRole:->];
        return;
    }
    if role is EdgeSpecRole {
        del [edge self->:EdgeSpecRole:->];
        return;
    }
    if role is ElseBodyRole {
        del [edge self->:ElseBodyRole:->];
        return;
    }
    if role is ElseValueRole {
        del [edge self->:ElseValueRole:->];
        return;
    }
    if role is EndRole {
        del [edge self->:EndRole:->];
        return;
    }
    if role is ErrorMsgRole {
        del [edge self->:ErrorMsgRole:->];
        return;
    }
    if role is EventRole {
        del [edge self->:EventRole:->];
        return;
    }
    if role is ExTypeRole {
        del [edge self->:ExTypeRole:->];
        return;
    }
    if role is ExceptsRole {
        del [edge self->:ExceptsRole:->];
        return;
    }
    if role is ExprRole {
        del [edge self->:ExprRole:->];
        return;
    }
    if role is ExprsRole {
        del [edge self->:ExprsRole:->];
        return;
    }
    if role is FTypeRole {
        del [edge self->:FTypeRole:->];
        return;
    }
    if role is FilterCondRole {
        del [edge self->:FilterCondRole:->];
        return;
    }
    if role is FinallyBodyRole {
        del [edge self->:FinallyBodyRole:->];
        return;
    }
    if role is FormatPartRole {
        del [edge self->:FormatPartRole:->];
        return;
    }
    if role is FormatSpecRole {
        del [edge self->:FormatSpecRole:->];
        return;
    }
    if role is FromLocRole {
        del [edge self->:FromLocRole:->];
        return;
    }
    if role is FromTargetRole {
        del [edge self->:FromTargetRole:->];
        return;
    }
    if role is GuardRole {
        del [edge self->:GuardRole:->];
        return;
    }
    if role is HintRole {
        del [edge self->:HintRole:->];
        return;
    }
    if role is InsertLocRole {
        del [edge self->:InsertLocRole:->];
        return;
    }
    if role is ItemsRole {
        del [edge self->:ItemsRole:->];
        return;
    }
    if role is IterRole {
        del [edge self->:IterRole:->];
        return;
    }
    if role is KeyRole {
        del [edge self->:KeyRole:->];
        return;
    }
    if role is KeywordsRole {
        del [edge self->:KeywordsRole:->];
        return;
    }
    if role is KvPairRole {
        del [edge self->:KvPairRole:->];
        return;
    }
    if role is KvPairsRole {
        del [edge self->:KvPairsRole:->];
        return;
    }
    if role is KwPatternsRole {
        del [edge self->:KwPatternsRole:->];
        return;
    }
    if role is KwargsRole {
        del [edge self->:KwargsRole:->];
        return;
    }
    if role is KwonlyargsRole {
        del [edge self->:KwonlyargsRole:->];
        return;
    }
    if role is LeftRole {
        del [edge self->:LeftRole:->];
        return;
    }
    if role is MainRole {
        del [edge self->:MainRole:->];
        return;
    }
    if role is NameRole {
        del [edge self->:NameRole:->];
        return;
    }
    if role is NameRefRole {
        del [edge self->:NameRefRole:->];
        return;
    }
    if role is OpRole {
        del [edge self->:OpRole:->];
        return;
    }
    if role is OperandRole {
        del [edge self->:OperandRole:->];
        return;
    }
    if role is OpsRole {
        del [edge self->:OpsRole:->];
        return;
    }
    if role is OutExprRole {
        del [edge self->:OutExprRole:->];
        return;
    }
    if role is ParamsRole {
        del [edge self->:ParamsRole:->];
        return;
    }
    if role is PartsRole {
        del [edge self->:PartsRole:->];
        return;
    }
    if role is PathRole {
        del [edge self->:PathRole:->];
        return;
    }
    if role is PatternRole {
        del [edge self->:PatternRole:->];
        return;
    }
    if role is PatternsRole {
        del [edge self->:PatternsRole:->];
        return;
    }
    if role is PosonlyParamsRole {
        del [edge self->:PosonlyParamsRole:->];
        return;
    }
    if role is ReturnTypeRole {
        del [edge self->:ReturnTypeRole:->];
        return;
    }
    if role is RightRole {
        del [edge self->:RightRole:->];
        return;
    }
    if role is RightsRole {
        del [edge self->:RightsRole:->];
        return;
    }
    if role is SignatureRole {
        del [edge self->:SignatureRole:->];
        return;
    }
    if role is SlicesRole {
        del [edge self->:SlicesRole:->];
        return;
    }
    if role is SpecRole {
        del [edge self->:SpecRole:->];
        return;
    }
    if role is SrcEndpointRole {
        del [edge self->:SrcEndpointRole:->];
        return;
    }
    if role is StartRole {
        del [edge self->:StartRole:->];
        return;
    }
    if role is StepRole {
        del [edge self->:StepRole:->];
        return;
    }
    if role is StopRole {
        del [edge self->:StopRole:->];
        return;
    }
    if role is StringsRole {
        del [edge self->:StringsRole:->];
        return;
    }
    if role is TargetRole {
        del [edge self->:TargetRole:->];
        return;
    }
    if role is TgtEndpointRole {
        del [edge self->:TgtEndpointRole:->];
        return;
    }
    if role is TokRole {
        del [edge self->:TokRole:->];
        return;
    }
    if role is TypeCtxRole {
        del [edge self->:TypeCtxRole:->];
        return;
    }
    if role is TypeParamsRole {
        del [edge self->:TypeParamsRole:->];
        return;
    }
    if role is TypeTagRole {
        del [edge self->:TypeTagRole:->];
        return;
    }
    if role is UnpackRole {
        del [edge self->:UnpackRole:->];
        return;
    }
    if role is ValueRole {
        del [edge self->:ValueRole:->];
        return;
    }
    if role is ValueTypeRole {
        del [edge self->:ValueTypeRole:->];
        return;
    }
    if role is ValuesRole {
        del [edge self->:ValuesRole:->];
        return;
    }
    if role is VarargsRole {
        del [edge self->:VarargsRole:->];
        return;
    }
    if role is VarsRole {
        del [edge self->:VarsRole:->];
        return;
    }
}

impl UniNode._role_set(role: type[Role], value: any) -> None {
    shapes: dict[type, str] = self?._role_shapes or {};
    self._role_shapes = shapes;
    self._role_clear(role);
    if value is None {
        shapes[role] = "none";
    } elif isinstance(value, (list, tuple)) {
        shapes[role] = "many";
        vsrc = self._as_node_list(value);
        for v in vsrc {
            if isinstance(v, UniNode) {
                self._attach(v, role);
            }
        }
    } elif isinstance(value, UniNode) {
        shapes[role] = "one";
        one: UniNode = value;
        self._attach(one, role);
    } else {
        shapes[role] = "none";
    }
    self._invalidate_sub_node_tab();
}

impl UniNode.link_impl(impl_node: UniNode) -> None {
    self +>:ImplOf:+> impl_node;
}

impl UniNode._sub_node_tab.getter -> dict[(type, list[UniNode])] {
    if (self.__sub_node_tab is None) {
        self.__sub_node_tab = {};
        self._construct_sub_node_tab();
    }
    return self.__sub_node_tab;
}

impl UniNode._construct_sub_node_tab -> None {
    for i in self.kid {
        if not i or i.ct_pruned {
            continue;
        }
        for (k, v) in i._sub_node_tab.items() {
            if (k in self.__sub_node_tab) {
                self.__sub_node_tab[k].extend(v);
            } else {
                self.__sub_node_tab[k] = `list(v);
            }
        }
        if (`type(i) in self.__sub_node_tab) {
            self.__sub_node_tab[`type(i)].append(i);
        } else {
            self.__sub_node_tab[`type(i)] = [i];
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
    self._assert_thawed();
    del [edge self->:Kid:->];
    for n in nodes {
        if n is not None {
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
    import copy;

    dup = object.__new__(type(self));
    memo[id(self)] = dup;
    for (key, val) in self.__dict__.items() {
        if key == "__jac__" {
            continue;
        }
        if key == "_ctx_parent" or key.endswith("__sub_node_tab") {
            dup.__dict__[key] = None;
        } elif key == "_struct_frozen" {
            dup.__dict__[key] = False;
        } elif key == "orig_src" {
            dup.__dict__[key] = val;
        } else {
            dup.__dict__[key] = copy.deepcopy(val, memo);
        }
    }
    for k in self.kid {
        kc = copy.deepcopy(k, memo);
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
    import from jaclang.compiler.frontend.constant { TOKEN_MAP }
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
    return self.codespace() == CodeContext.CLIENT;
}

impl UniNode.in_native_context -> bool {
    return self.codespace() == CodeContext.NATIVE;
}

impl Module.absorb_annex_body(stmts: Sequence[UniNode]) -> None {
    self.add_kids_right(stmts, pos_update=False, parent_update=True, role=BodyRole);
}

impl Module.declares_codespace(ctx: CodeContext, path_hint: str = '') -> bool {
    if ctx != CodeContext.SERVER and self.decided_codespace == ctx.value {
        return True;
    }
    if self.body {
        for _stmt in self.body {
            if ctx != CodeContext.SERVER
                and isinstance(_stmt, ContextAwareNode)
                and _stmt.code_context == ctx {
                return True;
            }
        }
    }
    return False;
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


impl Symbol.init(
    defn: NameAtom,
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> None {
    self.name = defn.sym_name;
    self.imported = imported;
    self.access = access;
    self.semstr = '';
    self +>:Defines:+> defn;
    defn.sym = self;
    if parent_tab is not None {
        parent_tab +>:InScope:+> self;
    }
}

impl Symbol.defn.getter -> list[NameAtom] {
    return [self->:Defines:->];
}

impl Symbol.uses.getter -> list[NameAtom] {
    return [self->:Uses:->];
}

impl Symbol.parent_tab.getter -> (UniScopeNode | None) {
    found = [self<-:InScope:<-];
    return found[0] if found else None;
}

impl Symbol.decl.getter -> NameAtom {
    return self.defn[0];
}

impl Symbol.sym_name.getter -> str {
    return self.decl.sym_name;
}

impl Symbol.sym_type.getter -> SymbolType {
    return self.decl.sym_category;
}

impl Symbol.sym_dotted_name.getter -> str {
    out = [self.defn[0].sym_name];
    current_tab: (UniScopeNode | None) = self.parent_tab;
    while (current_tab is not None) {
        out.append(current_tab.scope_name);
        current_tab = current_tab.parent_scope;
    }
    out.reverse();
    return '.'.join(out);
}

impl Symbol.symbol_table.getter -> (UniScopeNode | None) {
    if self.parent_tab {
        return self.parent_tab.find_scope(self.sym_name);
    }
    return None;
}

impl Symbol.binding_kind.getter -> BindingKind {
    for cur in import_chain_of(self) {
        decl = cur.decl;
        item = decl.parent if isinstance(decl.parent, ModuleItem) else None;
        if item is not None and item.from_parent.is_typed {
            return BindingKind.TYPE;
        }
        if cur._binding_kind is not None {
            return cur._binding_kind;
        }
        if item is None {
            return binding_kind_of_decl(decl);
        }
    }
    return BindingKind.VALUE;
}

impl Symbol.binding_kind.setter(binding_kind: BindingKind) -> None {
    self._binding_kind = binding_kind;
}

impl Symbol.storage.getter -> SymbolStorage {
    owner = self.parent_tab;
    while (owner is not None and not UniScopeNode.is_python_scoping(owner)) {
        owner = owner.parent_scope;
    }
    if (owner is None) or isinstance(owner, Module) {
        return SymbolStorage.MODULE_GLOBAL;
    }
    if isinstance(owner, (Archetype, Enum)) {
        return SymbolStorage.CLASS_FIELD;
    }

    if isinstance(self.decl.name_of, ParamVar) {
        return SymbolStorage.PARAM;
    }

    def_scope: (UniNode | None) = self.decl.parent;
    while (
        def_scope is not None
        and not UniScopeNode.is_python_scoping(def_scope)
        and not isinstance(def_scope, LambdaExpr)
    ) {
        def_scope = def_scope.parent;
    }
    for use in self.uses {
        cur = use.parent;
        while (
            cur is not None
            and not UniScopeNode.is_python_scoping(cur)
            and not isinstance(cur, LambdaExpr)
        ) {
            cur = cur.parent;
        }
        if (cur is None) or (cur is def_scope) {
            continue;
        }

        if isinstance(cur, ImplDef) and (cur.decl_link is def_scope) {
            continue;
        }
        if isinstance(def_scope, ImplDef) and (def_scope.decl_link is cur) {
            continue;
        }
        return SymbolStorage.CAPTURED;
    }
    return SymbolStorage.LOCAL;
}

impl Symbol.add_defn(nd: NameAtom) -> None {
    self +>:Defines:+> nd;
    nd.sym = self;
}

impl Symbol.add_use(nd: NameAtom) -> None {
    nd.sym = self;

    if self.in_stub_scope() {
        return;
    }
    self +>:Uses:+> nd;
}

impl Symbol.in_stub_scope -> bool {
    memo = self._in_stub_scope;
    if memo is not None {
        return memo;
    }
    found = False;
    cur: (UniScopeNode | None) = self.parent_tab;
    while cur is not None {
        if isinstance(cur, Module) {
            found = cur.stub_only;
            break;
        }
        cur = cur.parent_scope;
    }
    self._in_stub_scope = found;
    return found;
}

impl Symbol.__repr__ -> str {
    return f"Symbol({self.sym_name}, {self.sym_type}, {self.access},{self.defn})";
}

impl UniScopeNode._init_scope(
    name: str, parent_scope: (UniScopeNode | None) = None
) -> None {
    self.scope_name = name;
    self.implicit_rebinds: dict[(str, Symbol)] = {};
    self._names_index: dict[(str, Symbol)] = {};
    self._overload_index: dict[(str, list[Symbol])] = {};
    if parent_scope is not None {
        self.parent_scope = parent_scope;
    }
}

impl UniScopeNode.parent_scope.getter -> (UniScopeNode | None) {
    found = [self<-:ScopeChild:<-];
    if found {
        return found[-1];
    }
    owners = [self->:ScopeParent:->];
    return owners[-1] if owners else None;
}

impl UniScopeNode.parent_scope.setter(parent_scope: (UniScopeNode | None)) {
    del [edge self<-:ScopeChild:<-];
    del [edge self->:ScopeParent:->];
    if parent_scope is not None {
        self +>:ScopeParent:+> parent_scope;
    }
}

impl UniScopeNode.kid_scope.getter -> list[UniScopeNode] {
    return [self->:ScopeChild:->];
}

impl UniScopeNode.names_in_scope.getter -> dict[(str, Symbol)] {
    return self?._names_index or {};
}

impl UniScopeNode.names_in_scope_overload.getter -> dict[(str, list[Symbol])] {
    return self?._overload_index or {};
}

impl UniScopeNode.lookup(
    name: str, deep: bool = True, incl_inner_scope: bool = False
) -> (Symbol | None) {
    if (name in self.names_in_scope) {
        return self.names_in_scope[name];
    }
    if (
        (deep and self.parent_scope)
        and (sym := self.parent_scope.lookup(name, deep, incl_inner_scope))
    ) {
        return sym;
    }
    if incl_inner_scope {
        for kid in self.kid_scope {
            if UniScopeNode.is_python_scoping(kid) {
                continue;
            }
            if ((sym := kid.lookup(name, False, True)) is not None) {
                return sym;
            }
        }
    }

    impl_def: ImplDef | None = (
        self if isinstance(self, ImplDef) else self.find_parent_of_type(ImplDef)
    );
    if (impl_def and impl_def.decl_link and impl_def.decl_link.sym_tab) {
        return impl_def.decl_link.sym_tab.lookup(
            name, deep=True, incl_inner_scope=False
        );
    }
    return None;
}

impl UniScopeNode.lookup_all(name: str, deep: bool = True) -> list[Symbol] {
    result: list[Symbol] = [];
    if name in self.names_in_scope {
        result.append(self.names_in_scope[name]);
    }
    if name in self.names_in_scope_overload {
        result.extend(self.names_in_scope_overload[name]);
    }
    if result {
        return result;
    }
    if deep and self.parent_scope {
        return self.parent_scope.lookup_all(name, deep);
    }
    return result;
}

impl UniScopeNode.insert(
    nd: AstSymbolNode,
    access_spec: AstAccessNode | None | SymbolAccess = None,
    single: bool = False,
    force_overwrite: bool = False,
    imported: bool = False
) -> (UniNode | None) {
    collision = self.names_in_scope[nd.sym_name].defn[-1]
        if (single and (nd.sym_name in self.names_in_scope))
        else None;
    symbol = nd.name_spec.create_symbol(
        access=access_spec
            if isinstance(access_spec, SymbolAccess)
            else access_spec.access_type if access_spec else SymbolAccess.PUBLIC,
        parent_tab=self,
        imported=imported
    );
    current = self.names_in_scope;
    if (nd.sym_name in current) {
        self +>:ScopeOverload:+> symbol;
        self._overload_index.setdefault(nd.sym_name, []).append(symbol);
    }
    if (force_overwrite or (nd.sym_name not in current)) {
        prev = current.get(nd.sym_name);
        if prev is not None {
            self._drop_primary(prev);
        }
        self +>:ScopePrimary:+> symbol;
        self._names_index[nd.sym_name] = symbol;
    } else {
        current[nd.sym_name].add_defn(nd.name_spec);
    }
    return collision;
}

impl UniScopeNode.find_scope(name: str) -> (UniScopeNode | None) {
    for k in self.kid_scope {
        if (k.scope_name == name) {
            return k;
        }
    }
    return None;
}

impl UniScopeNode.get_enclosing_captures -> list[Symbol] {
    out: list[Symbol] = [];
    for name in self.get_all_sub_nodes(Name) {
        if is_identifier_slot(name) {
            continue;
        }
        sym = name.sym;
        if (sym is None) {
            continue;
        }
        tab = sym.parent_tab;
        if (
            (tab is None)
            or (tab is self)
            or not isinstance(tab, (Ability, ImplDef, LambdaExpr, Test))
        ) {
            continue;
        }

        scope = self.parent_scope;
        while (scope is not None) {
            if (scope is tab) {
                if sym not in out {
                    out.append(sym);
                }
                break;
            }
            scope = scope.parent_scope;
        }
    }
    return out;
}

impl UniScopeNode.set_primary_names(syms: dict[(str, Symbol)]) -> None {
    del [edge self->:ScopePrimary:->];
    for (key, sym) in syms.items() {
        self +>:ScopePrimary:+> sym;
    }
    self._names_index = dict(syms);
}

impl UniScopeNode.adopt_primary(sym: Symbol, alias: str = "") -> None {
    key = alias or sym.name;
    prev = self._names_index.get(key);
    if prev is not None {
        self._drop_primary(prev);
    }
    self +>:ScopePrimary:+> sym;
    self._names_index[key] = sym;
}

impl UniScopeNode._drop_primary(sym: Symbol) -> None {
    for e in [edge self->:ScopePrimary:->] {
        if getattr(e, "__jac__").target.archetype is sym {
            del e;
            break;
        }
    }
}

impl UniScopeNode.link_kid_scope(key_node: UniScopeNode) -> UniScopeNode {
    del [edge key_node<-:ScopeChild:<-];
    del [edge key_node->:ScopeParent:->];
    self +>:ScopeChild:+> key_node;
    return key_node;
}

impl UniScopeNode.def_insert(
    nd: AstSymbolNode,
    access_spec: AstAccessNode | None | SymbolAccess = None,
    single_decl: (str | None) = None,
    force_overwrite: bool = False,
    imported: bool = False
) -> (Symbol | None) {
    if (nd.sym and (self == nd.sym.parent_tab)) {
        return nd.sym;
    }
    self.insert(
        nd=nd,
        single=(single_decl is not None),
        access_spec=access_spec,
        force_overwrite=force_overwrite,
        imported=imported
    );
    self.update_expr_ctx_for_def(nd);
    return nd.sym;
}

impl UniScopeNode.chain_def_insert(node_list: list[AstSymbolNode]) -> None {
    if not node_list {
        return;
    }
    cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
    node_list[-1].name_spec.expr_ctx = ExprCtx.STORE;
    if isinstance(node_list[-1].name_spec, AstSymbolNode) {
        node_list[-1].name_spec.expr_ctx = ExprCtx.STORE;
    }
    node_list = node_list[:-1];
    for i in node_list {
        cur_sym_tab = lookup.decl.sym_tab
            if (lookup := self.use_lookup(i, sym_table=cur_sym_tab))
            else None;
    }
}

impl UniScopeNode.use_lookup(
    nd: AstSymbolNode, sym_table: (UniScopeNode | None) = None
) -> (Symbol | None) {
    if nd.sym {
        return nd.sym;
    }
    if not sym_table {
        sym_table = nd.sym_tab;
    }
    if sym_table {
        found = sym_table.lookup(name=nd.sym_name, deep=True);
        if found {
            found.add_use(nd.name_spec);
        }
    }
    return nd.sym;
}

impl UniScopeNode.chain_use_lookup(node_list: Sequence[AstSymbolNode]) -> None {
    if not node_list {
        return;
    }
    cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
    for i in node_list {
        if (cur_sym_tab is None) {
            break;
        }
        found = self.use_lookup(i, sym_table=cur_sym_tab);
        if found {
            decl_tab = found.decl.sym_tab;
            cur_sym_tab = decl_tab;
            if decl_tab is not None and (decl_tab.scope_name != i.sym_name) {
                t = decl_tab.find_scope(i.sym_name);
                if t {
                    cur_sym_tab = t;
                }
            }
        } else {
            cur_sym_tab = None;
        }
    }
}

impl UniScopeNode._fix_store_ctx(item: UniNode) -> None {
    if isinstance(item, UnaryExpr) {
        if isinstance(item.operand, AstSymbolNode) {
            item.operand.name_spec.expr_ctx = ExprCtx.STORE;
        }
    } elif isinstance(item, (TupleVal, ListVal)) {
        for i in item.values {
            if isinstance(i, AstSymbolNode) {
                i.name_spec.expr_ctx = ExprCtx.STORE;
            } elif isinstance(i, AtomTrailer) {
                self.chain_def_insert(i.as_attr_list);
            }
            if isinstance(i, (TupleVal, ListVal, UnaryExpr)) {
                self._fix_store_ctx(i);
            }
        }
    }
}

impl UniScopeNode.update_expr_ctx_for_def(nd: AstSymbolNode) -> None {
    nd.name_spec.expr_ctx = ExprCtx.STORE;
    if isinstance(nd, (TupleVal, ListVal)) and nd.values {
        self._fix_store_ctx(nd);
    }
}

impl UniScopeNode.__repr__ -> str {
    out = f"{self.scope_name} {super().__repr__()}:\n";
    for (k, v) in self.names_in_scope.items() {
        out += f"    {k}: {v}\n";
    }
    return out;
}

impl AstDocNode.set_doc(elem_doc: (String | None)) -> None {
    self._role_set(DocRole, elem_doc);
}


impl NameAtom.bind_sym(
    name_of: AstSymbolNode, sym_name: str, sym_category: SymbolType
) -> None {
    self.name_of = name_of;
    self._sym_name = sym_name;
    self._sym_category = sym_category;
}


impl AstSymbolNode._init_symbol(
    sym_name: str, name_spec: NameAtom, sym_category: SymbolType
) -> None {
    self.name_spec = name_spec;
    self.name_spec.bind_sym(self, sym_name, sym_category);
    self.semstr = '';
}


impl AstSymbolNode.sym.getter -> (Symbol | None) {
    return self.name_spec.sym;
}

impl AstSymbolNode.sym_name.getter -> str {
    return self.name_spec.sym_name;
}

impl AstSymbolNode.sym_category.getter -> SymbolType {
    return self.name_spec.sym_category;
}

impl AstSymbolNode.expr_ctx.getter -> ExprCtx {
    return self.name_spec.expr_ctx;
}

impl AstSymbolNode.type_sym_tab.getter -> (UniScopeNode | None) {
    return self.name_spec.type_sym_tab;
}

impl AstSymbolStubNode._init_stub(sym_type: SymbolType) -> None {
    AstSymbolNode._init_symbol(
        self,
        sym_name=f"[{self.__class__.__name__}]",
        name_spec=Name.gen_stub_from_node(self, f"[{self.__class__.__name__}]"),
        sym_category=sym_type
    );
}


impl AstAccessNode.access_type.getter -> SymbolAccess {
    return SymbolAccess.PRIVATE
        if (self.access and (self.access.tag.name == Tok.KW_PRIV))
        else SymbolAccess.PROTECTED
            if (self.access and (self.access.tag.name == Tok.KW_PROT))
            else SymbolAccess.PUBLIC;
}

impl AstAccessNode.public_access.getter -> bool {
    return (self.access_type == SymbolAccess.PUBLIC);
}

impl ContextAwareNode.postinit -> None {}

impl ContextAwareNode.code_context.getter -> CodeContext {
    found = [self->:PlacedIn:->];
    return CodeContext(found[0].kind) if found else CodeContext.SERVER;
}

impl ContextAwareNode.code_context.setter(code_context: CodeContext) {
    del [edge self->:PlacedIn:->];
    self +>:PlacedIn:+> codespace_node(code_context.value);
}

impl Module.decided_codespace.getter -> str {
    found = [self->:DecidedCodespace:->];
    return found[0].kind if found else "";
}

impl Module.decided_codespace.setter(decided_codespace: str) {
    del [edge self->:DecidedCodespace:->];
    if decided_codespace {
        self +>:DecidedCodespace:+> codespace_node(decided_codespace);
    }
}


impl WalkerStmtOnlyNode.postinit -> None {
    self.from_walker = False;
}


impl UniCFGNode.postinit -> None {
    _syms: set[str] = set();
    self.affected_symbols = _syms;
}

impl UniCFGNode.bb_out.getter -> list[UniCFGNode] {
    return [self->:CfgSucc:->];
}

impl UniCFGNode.bb_in.getter -> list[UniCFGNode] {
    return [self<-:CfgSucc:<-];
}

impl UniCFGNode.cfg_link(target: UniCFGNode) -> None {
    if target not in [self->:CfgSucc:->] {
        self +>:CfgSucc:+> target;
    }
}

impl ConditionalNode.sc_true_target.getter -> (UniCFGNode | None) {
    found = [self->:CfgTrue:->];
    return found[0] if found else None;
}

impl ConditionalNode.sc_true_target.setter(sc_true_target: (UniCFGNode | None)) {
    del [edge self->:CfgTrue:->];
    if sc_true_target is not None {
        self +>:CfgTrue:+> sc_true_target;
    }
}

impl ConditionalNode.sc_false_target.getter -> (UniCFGNode | None) {
    found = [self->:CfgFalse:->];
    return found[0] if found else None;
}

impl ConditionalNode.sc_false_target.setter(sc_false_target: (UniCFGNode | None)) {
    del [edge self->:CfgFalse:->];
    if sc_false_target is not None {
        self +>:CfgFalse:+> sc_false_target;
    }
}

impl ConditionalNode.postinit -> None {
    UniCFGNode.postinit(self);
}

impl CfgExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    ConditionalNode.postinit(self);
}


impl UniCFGNode.get_head -> UniCFGNode {
    nd = self;
    while (
        nd.bb_in
        and (len(nd.bb_in) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_in[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_in[0].bb_out
        and (len(nd.bb_in[0].bb_out) == 1)
    ) {
        nd = nd.bb_in[0];
    }
    return nd;
}

impl UniCFGNode.get_tail -> UniCFGNode {
    nd = self;
    while (
        nd.bb_out
        and (len(nd.bb_out) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_out[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_out[0].bb_in
        and (len(nd.bb_out[0].bb_in) == 1)
    ) {
        nd = nd.bb_out[0];
    }
    return nd;
}

impl Expr.postinit -> None {
    self._type_sym_tab = None;
    self._type_cache = None;
    self._type_cache_ok = False;
    self.ct_value = None;
    self.coerce_to = None;
    self.fw = None;
    self.fw_safe = False;
    self.attached_tokens = None;
}


impl CodeBlockStmt.postinit -> None {
    UniCFGNode.postinit(self);
}


impl AstImplNeedingNode.needs_impl.getter -> bool {
    return (self.body is None);
}

impl NameAtom.postinit -> None {
    self.name_of = self;
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._expr_ctx = ExprCtx.LOAD;
    AtomExpr.postinit(self);
}


impl NameAtom.sym_name.getter -> str {
    return self._sym_name;
}

impl NameAtom.sym_category.getter -> SymbolType {
    return self._sym_category;
}

impl NameAtom.create_symbol(
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> Symbol {
    sym = Symbol(defn=self, access=access, parent_tab=parent_tab, imported=imported);
    return sym;
}

impl NameAtom.clean_type.getter -> str {
    if self.type {
        return str(self.type).replace('builtins.', '');
    }
    return '';
}

impl NameAtom.sem_token.getter -> (tuple[(SemTokType, SemTokMod)] | None) {
    if isinstance(self.name_of, BuiltinType) {
        return (SemTokType.CLASS, SemTokMod.DECLARATION);
    }
    name_of = self.sym.decl.name_of
        if (self.sym and not isinstance(self.sym.decl.name_of, Name))
        else self.name_of;
    if isinstance(name_of, ModulePath) {
        return (SemTokType.NAMESPACE, SemTokMod.DEFINITION);
    }
    if isinstance(name_of, Archetype) {
        return (SemTokType.CLASS, SemTokMod.DECLARATION);
    }
    if isinstance(name_of, Enum) {
        return (SemTokType.ENUM, SemTokMod.DECLARATION);
    }
    if (isinstance(name_of, Ability) and name_of.is_method) {
        return (SemTokType.METHOD, SemTokMod.DECLARATION);
    }
    if isinstance(name_of, (Ability, Test)) {
        return (SemTokType.FUNCTION, SemTokMod.DECLARATION);
    }
    if isinstance(name_of, ParamVar) {
        return (SemTokType.PARAMETER, SemTokMod.DECLARATION);
    }
    if (self.sym and self.sym_name.isupper()) {
        return (SemTokType.VARIABLE, SemTokMod.READONLY);
    }
    if (
        self.sym
        and (self.sym.decl.name_of == self.sym.decl)
        and (self.sym_name in BUILTIN_CALLABLE_NAMES)
    ) {
        return (SemTokType.FUNCTION, SemTokMod.DEFINITION);
    }
    if self.sym {
        if self.type is not None
            and type(self.type).__name__ in ('FunctionType', 'OverloadedType') {
            return (SemTokType.FUNCTION, SemTokMod.DEFINITION);
        }
        return (SemTokType.PROPERTY, SemTokMod.DEFINITION);
    }

    if self.is_getattr_resolved {
        return (SemTokType.PROPERTY, SemTokMod.DEFINITION);
    }
    return None;
}

impl ArchSpec.postinit -> None {
    CodeBlockStmt.postinit(self);
}


impl SubTag.postinit -> None {
    UniNode.postinit(self);
}


impl Module.postinit -> None {
    self.src_terminals = self.terminals;
    self.codespace_inferred = False;
    self.ct_file_deps = [];
    self.ct_body_deps = [];
    self.rc_last_use = {};
    _rc_move_in: set[int] = set();
    self.rc_move_in = _rc_move_in;
    _own_move_sites: set[int] = set();
    self.own_move_sites = _own_move_sites;
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=self.name);
}


impl Module.annexable_by.getter -> (str | None) {
    if self.stub_only {
        return None;
    }
    import from jaclang.compiler.driver.bccache { discover_base_file }
    return discover_base_file(self.loc.mod_path);
}

impl ProgramModule.postinit -> None {
    UniNode.postinit(self);
    main = self.main_mod;
    self.hub = {self.loc.mod_path: main} if main else {};
}


impl TypeParam.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
}


impl TypeAlias.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl GlobalVars.postinit -> None {
    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl Test.postinit -> None {
    name_node = self.name;
    name_node.set_parent(self);
    name_node._sym_name = f"test_{name_node.value}"
        if not name_node.value.startswith('test_')
        else name_node.value;
    UniNode.postinit(self);

    if (self.description is None and name_node not in self.kid) {
        self.insert_kids_at_pos([name_node], pos=1, pos_update=False);
    }
    AstSymbolNode._init_symbol(
        self,
        sym_name=name_node.sym_name,
        name_spec=name_node,
        sym_category=SymbolType.TEST
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}


impl ModuleCode.postinit -> None {
    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl PyInlineCode.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl Import.postinit -> None {
    self.jac_detected = None;
    self.boundary_facts = None;
    self.native_only_drop = False;
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}

impl Import.is_jac.getter -> bool {
    if self.jac_detected is not None {
        return self.jac_detected;
    }
    if (self.hint and (self.hint.tag.value == 'jac')) {
        return True;
    }
    if not self.hint {
        return self.__jac_detected;
    }
    return False;
}

impl Import.__jac_detected.getter -> bool {
    import from jaclang.jac0core.ext_registry { is_jac, INIT_FILES }
    if self.from_loc {
        if is_jac(self.from_loc.resolve_relative_path()) {
            return True;
        }
        if os.path.isdir(self.from_loc.resolve_relative_path()) {
            for init_name in INIT_FILES {
                if os.path.exists(
                    os.path.join(self.from_loc.resolve_relative_path(), init_name)
                ) {
                    return True;
                }
            }
            for i in self.items {
                if (
                    isinstance(i, ModuleItem)
                    and is_jac(self.from_loc.resolve_relative_path(i.name.value))
                ) {
                    return True;
                }
            }
        }
    }
    return `any(
        (isinstance(i, ModulePath) and is_jac(i.resolve_relative_path()))
        for i in self.items
    );
}

impl Import.has_string_path.getter -> bool {
    if (self.from_loc is not None and self.from_loc.string_path_value is not None) {
        return True;
    }
    for item in self.items {
        if (isinstance(item, ModulePath) and item.string_path_value is not None) {
            return True;
        }
    }
    return False;
}

impl Import.is_service_import.getter -> bool {
    if self.from_loc is None or not self.items {
        return False;
    }
    import from jaclang.compiler.driver.boundary_classify { is_service_bridge_import }
    return is_service_bridge_import(self);
}

impl Import.is_virtual_jac.getter -> bool {
    if self.from_loc is not None {
        return self.from_loc.dot_path_str.startswith('@jac/');
    }
    for item in self.items {
        if isinstance(item, ModulePath) {
            spv = item.string_path_value;
            if (spv is not None and spv.startswith('@jac/')) {
                return True;
            }
        }
    }
    return False;
}

impl Import.has_clib_decls.getter -> bool {
    return bool(self.clib_decls);
}

impl Import.ecosystem.getter -> str {
    if self.has_clib_decls {
        return 'clib';
    }
    if self.is_virtual_jac {
        return 'virtual';
    }
    if self.has_string_path {
        return 'string';
    }
    if self.is_jac {
        return 'jac';
    }
    return 'py';
}

impl ModulePath.postinit -> None {
    self.abs_path = None;
    UniNode.postinit(self);
}


impl ModulePath.is_import_from.getter -> bool {
    if (self.parent and isinstance(self.parent, Import)) {
        return (self.parent.from_loc == self);
    }
    return False;
}

impl ModulePath.string_path_value.getter -> (str | None) {
    if (self.path and (len(self.path) == 1) and isinstance(self.path[0], String)) {
        lv = self.path[0].lit_value;
        return lv if isinstance(lv, str) else None;
    }
    return None;
}

impl ModulePath.dot_path_str.getter -> str {
    spv = self.string_path_value;
    if spv is not None {
        return (('.' * self.level) + spv);
    }
    return (
        ('.' * self.level) + '.'.join([p.value for p in self.path] if self.path else [])
    );
}

impl ModulePath.base_module_name.getter -> str {
    spv = self.string_path_value;
    if spv is not None {
        return spv;
    }
    return '.'.join([p.value for p in self.path] if self.path else []);
}

impl ModulePath.resolve_relative_path(target_item: (str | None) = None) -> str {
    import from jaclang.compiler.driver.modresolver { resolve_relative_path }
    bundled = self.native_bundled_path();
    if bundled is not None {
        return bundled;
    }
    spv = self.string_path_value;
    if spv is not None {
        return resolve_relative_path(spv, self.loc.mod_path, string_spec=True);
    }
    target = self.dot_path_str + (f".{target_item}" if target_item else '');
    return resolve_relative_path(target, self.loc.mod_path);
}

impl ModulePath.native_bundled_path -> (str | None) {
    import os;
    import from jaclang.compiler.frontend.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    mod_path = self.loc.mod_path if self.loc else None;
    if not self.in_native_context() {
        return None;
    }
    if mod_path and mod_path.endswith(".pyi") {
        return None;
    }
    base = self.dot_path_str;
    if not is_bundled_native_module(base) {
        return None;
    }
    base_dir = os.path.dirname(mod_path) if mod_path else os.getcwd();
    (_src, full_path) = resolve_native_module(base, base_dir);
    return full_path;
}

impl ModulePath.resolve_relative_path_list -> list[str] {
    parts = self.dot_path_str.split('.');
    if not parts {
        return [];
    }

    full_path = self.resolve_relative_path();

    paths: list[str] = [''] * len(parts);
    paths[-1] = full_path;

    full_basename = os.path.basename(full_path);
    cur_dir = os.path.dirname(full_path);
    if full_basename.startswith('__init__') {
        cur_dir = os.path.dirname(cur_dir);
    }
    for i in range(len(parts) - 2, -1, -1) {
        init_found = False;
        for init_name in ('__init__.jac', '__init__.py', '__init__.pyi') {
            init_path = os.path.join(cur_dir, init_name);
            if os.path.isfile(init_path) {
                paths[i] = init_path;
                init_found = True;
                break;
            }
        }
        if not init_found {
            paths[i] = cur_dir;
        }
        cur_dir = os.path.dirname(cur_dir);
    }
    return paths;
}

impl ModuleItem.postinit -> None {
    UniNode.postinit(self);
    self.abs_path = None;
}


impl ModuleItem.from_parent.getter -> Import {
    if (not self.parent or not isinstance(self.parent, Import)) {
        raise ValueError('Import parent not found. Not Possible.');
    }
    return self.parent;
}

impl ModuleItem.from_mod_path.getter -> ModulePath {
    if not self.from_parent.from_loc {
        raise ValueError('Module items should have module path. Not Possible.');
    }
    return self.from_parent.from_loc;
}

impl ModuleItem.binding_name.getter -> (Name | None) {
    if isinstance(self.name, Name) {
        return self.name;
    }

    if self.name.value in ('default', '*') {
        return self.alias;
    }
    return None;
}

impl ModuleItem.resolve_relative_path -> str {
    item_name = self.name.value if isinstance(self.name, Name) else None;

    if item_name is None {
        return self.from_mod_path.resolve_relative_path();
    }

    return self.from_mod_path.resolve_relative_path(target_item=item_name);
}

impl Archetype.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category={
            Tok.KW_OBJECT.value: SymbolType.OBJECT_ARCH,
            Tok.KW_NODE.value: SymbolType.NODE_ARCH,
            Tok.KW_EDGE.value: SymbolType.EDGE_ARCH,
            Tok.KW_WALKER.value: SymbolType.WALKER_ARCH
        }.get(
            self.arch_type.name, SymbolType.TYPE
        )
    );
    ArchSpec.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}


impl Archetype._get_impl_resolved_body -> list[UniNode] {
    """The nested ternary this replaced lowers natively now, but not here:
    `Archetype.body` is the `T` of the generic `AstImplNeedingNode[T]`, whose
    layout is type-erased, so the narrow can say "a list" and not what of.
    Both copies then unify at `list[jacval]` and the coercion to the declared
    `list[UniNode]` is refused. The typed local below is what pins the element
    type, so the flat form stays until a generic archetype's layout carries
    its argument.""";
    src = self.body.body if isinstance(self.body, ImplDef) else self.body;
    out: list[UniNode] = [];
    if isinstance(src, list) {
        out.extend(src);
    }
    return out;
}

impl Archetype.is_abstract.getter -> bool {
    body = self._get_impl_resolved_body();
    return `any((isinstance(i, Ability) and i.is_abstract) for i in body);
}

impl Archetype.arch_kind.getter -> (str | None) {
    kind_map: dict[SymbolType, str] = {
        SymbolType.NODE_ARCH: "node",
        SymbolType.EDGE_ARCH: "edge",
        SymbolType.WALKER_ARCH: "walker"
    };
    return kind_map.get(self.sym_category);
}

impl Archetype.get_has_vars -> list[HasVar] {
    body = self._get_impl_resolved_body();
    has_vars: list[HasVar] = [];
    for nd in body {
        if not isinstance(nd, ArchHas) {
            continue;
        }
        for has_ in nd.vars {
            if isinstance(has_, HasVar) {
                has_vars.append(has_);
            }
        }
    }
    return has_vars;
}

impl Archetype.get_methods -> list[Ability] {
    body = self._get_impl_resolved_body();
    methods: list[Ability] = [];
    for nd in body {
        if (isinstance(nd, Ability) and nd.is_method) {
            methods.append(nd);
        }
    }
    return methods;
}

impl ImplDef.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=('impl.' + '.'.join([x.sym_name for x in self.target])),
        name_spec=self.create_impl_name_node(),
        sym_category=SymbolType.IMPL
    );
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
}


impl ImplDef.create_impl_name_node -> Name {
    ret = Name(
        orig_src=self.target[-1].loc.orig_src,
        name=Tok.NAME.value,
        value=('impl.' + '.'.join([x.sym_name for x in self.target])),
        col_start=self.target[0].loc.col_start,
        col_end=self.target[-1].loc.col_end,
        line=self.target[0].loc.first_line,
        end_line=self.target[-1].loc.last_line,
        pos_start=self.target[0].loc.pos_start,
        pos_end=self.target[-1].loc.pos_end
    );
    ret.set_parent(self);
    return ret;
}

impl SemDef.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=('sem.' + '.'.join([x.sym_name for x in self.target])),
        name_spec=self.create_sem_name_node(),
        sym_category=SymbolType.SEM
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
}


impl SemDef.create_sem_name_node -> Name {
    ret = Name(
        orig_src=self.target[-1].loc.orig_src,
        name=Tok.NAME.value,
        value=('sem.' + '.'.join([x.sym_name for x in self.target])),
        col_start=self.target[0].loc.col_start,
        col_end=self.target[-1].loc.col_end,
        line=self.target[0].loc.first_line,
        end_line=self.target[-1].loc.last_line,
        pos_start=self.target[0].loc.pos_start,
        pos_end=self.target[-1].loc.pos_end
    );
    ret.set_parent(self);
    return ret;
}

impl Enum.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.ENUM_ARCH
    );
    ArchSpec.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
}


impl Ability.postinit -> None {
    UniNode.postinit(self);
    if (self.name_ref is None) {
        first_tok = self.kid[0]
            if (self.kid and isinstance(self.kid[0], Token))
            else None;
        if (first_tok is None) {
            raise ValueError('Cannot create synthetic name_ref without location info.');
        }
        if isinstance(self.signature, EventSignature)
            and (self.signature.event.name == Tok.KW_ENTRY) {
            event_type = "entry";
        } else {
            event_type = "exit";
        }
        synthetic_name = f"__ability_{event_type}_{first_tok.line_no}_{first_tok.c_start}__";
        synthetic_name_ref: NameAtom = Name(
            orig_src=first_tok.orig_src,
            name=Tok.NAME,
            value=synthetic_name,
            line=first_tok.line_no,
            end_line=first_tok.end_line,
            col_start=first_tok.c_start,
            col_end=first_tok.c_end,
            pos_start=first_tok.pos_start,
            pos_end=first_tok.pos_end,
            is_enum_stmt=False
        );
        name_spec_for_init: (Name | NameAtom) = synthetic_name_ref;
        self._role_set(NameRefRole, synthetic_name_ref);
    } else {
        name_spec_for_init = self.name_ref;
    }
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.py_resolve_name(),
        name_spec=name_spec_for_init,
        sym_category=SymbolType.ABILITY
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}


impl Ability.is_method.getter -> bool {
    return (self.method_owner is not None);
}

impl Ability.is_cls_method.getter -> bool {
    return (
        self.is_classmethod
        or (
            self.is_method
            and `any(
                (isinstance(dec, Name) and (dec.sym_name == 'classmethod'))
                for dec in (self.decorators or ())
            )
        )
    );
}

impl Ability.is_def.getter -> bool {
    return (not self.signature or isinstance(self.signature, FuncSignature));
}

impl Ability.method_owner.getter -> Archetype | Enum | None {
    found = (
        self.parent
            if (self.parent and isinstance(self.parent, (Archetype, Enum)))
            else None
    )
        or (
            self.parent.decl_link
                if (
                    self.parent
                    and isinstance(self.parent, ImplDef)
                    and isinstance(self.parent.decl_link, (Archetype, Enum))
                )
                else None
        );
    if (found is None) and (self.accessor_kind != "") {
        nodew = self.parent;
        while nodew is not None {
            if isinstance(nodew, (Archetype, Enum)) {
                return nodew;
            }
            nodew = nodew.parent;
        }
    }

    if found is None {
        nodew = self.parent;
        while isinstance(nodew, (IfStmt, ElseStmt, ModuleCode)) {
            nodew = nodew.parent;
        }
        if nodew is not self.parent and isinstance(nodew, (Archetype, Enum)) {
            mod = self.find_parent_of_type(Module);
            if mod is not None and mod.is_raised_from_py {
                return nodew;
            }
        }
    }
    return found;
}

impl Ability.is_genai_ability.getter -> bool {
    return isinstance(self.body, Expr);
}

impl Ability.py_resolve_name -> str {
    if (self.name_ref is None) {
        if isinstance(self.signature, EventSignature)
            and (self.signature.event.name == Tok.KW_ENTRY) {
            event_type = "entry";
        } else {
            event_type = "exit";
        }
        return f"__ability_{event_type}_{self.loc.first_line}_{self.loc.col_start}__";
    } elif isinstance(self.name_ref, Name) {
        return self.name_ref.value;
    } elif isinstance(self.name_ref, SpecialVarRef) {
        return self.name_ref.py_resolve_name();
    } else {
        raise NotImplementedError;
    }
}

impl Ability.event_trigger_type_names -> (list[str] | None) {
    if self.event_triggers is None {
        return None;
    }
    names: list[str] = [];
    for t in self.event_triggers {
        for part in t.mangle().split("|") {
            name = part.strip();
            if name.startswith("type[") and name.endswith("]") {
                name = name[5:-1];
            }
            if name and name not in names {
                names.append(name);
            }
        }
    }
    return names;
}

impl FuncSignature.postinit -> None {
    UniNode.postinit(self);
}


impl FuncSignature.get_parameters -> list[ParamVar] {
    params: list[ParamVar] = [];
    params.extend(self.posonly_params);
    if self.params is not None {
        params.extend(self.params);
    }
    if self.varargs is not None {
        params.append(self.varargs);
    }
    params.extend(self.kwonlyargs);
    if self.kwargs is not None {
        params.append(self.kwargs);
    }
    return params;
}

impl FuncSignature.is_static.getter -> bool {
    return (
        (isinstance(self.parent, Ability) and self.parent.is_static)
        or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_static
        )
    );
}

impl FuncSignature.is_in_py_class.getter -> bool {
    is_archi = self.find_parent_of_type(Archetype);
    is_class = (is_archi is not None) and (is_archi.arch_type.name == Tok.KW_CLASS);
    return (
        (
            isinstance(self.parent, Ability)
            and (self.parent.is_method is not None)
            and is_class
        )
        or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_method
            and is_class
        )
    );
}

impl EventSignature.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl ParamVar.postinit -> None {
    self.param_kind = ParamKind.NORMAL;
    UniNode.postinit(self);
    pv_spec: NameAtom = self.name;
    AstSymbolNode._init_symbol(
        self, sym_name=self.name.value, name_spec=pv_spec, sym_category=SymbolType.VAR
    );
}


impl ParamVar.is_vararg.getter -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_MUL.name)));
}

impl ParamVar.is_kwargs.getter -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_POW.name)));
}

impl ArchHas.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl HasVar.postinit -> None {
    UniNode.postinit(self);
    hv_spec: NameAtom = self.name;
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=hv_spec,
        sym_category=SymbolType.HAS_VAR
    );
}


impl TypedCtxBlock.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl OpenStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl IfStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ElseStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl ExprStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl TryStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl Except.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl FinallyStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl AwaitingClause.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl IterForStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl InForStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl WhileStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ForeverStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl WithStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ExprAsItem.postinit -> None {
    UniNode.postinit(self);
}


impl RaiseStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl AssertStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl CtrlStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DeleteStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DeleteStmt.leaf_targets -> list[Expr] {
    leaves: list[Expr] = [];
    pending: list[Expr] = `list(self.targets);
    pending.reverse();
    while pending {
        inner = DeleteStmt.unwrap_target(pending.pop());
        if isinstance(inner, (TupleVal, ListVal)) {
            elems = [
                el
                for el in inner.values
                if isinstance(el, Expr)
            ];
            elems.reverse();
            pending.extend(elems);
        } else {
            leaves.append(inner);
        }
    }
    return leaves;
}


impl DeleteStmt.unwrap_target(target: Expr) -> Expr {
    inner: Expr = target;
    while isinstance(inner, AtomUnit) and isinstance(inner.value, Expr) {
        inner = inner.value;
    }
    return inner;
}


impl DeleteStmt.is_location(target: Expr) -> bool {
    inner = DeleteStmt.unwrap_target(target);
    if isinstance(inner, Name) {
        return True;
    }
    return isinstance(inner, AtomTrailer)
        and (inner.is_attr or isinstance(inner.right, IndexSlice));
}


impl DeleteStmt.type_may_hold_graph(t: (TypeBase | None)) -> bool {
    import from jaclang.compiler.types.types { ClassType, UnionType }

    def never_graph(ty: any) -> bool {
        if isinstance(ty, UnionType) {
            return all(never_graph(m) for m in ty.types);
        }
        if not isinstance(ty, ClassType) {
            return False;
        }
        if ty.is_any_type()
            or ty.is_node_type()
            or ty.is_edge_type()
            or ty.is_walker_type()
            or not ty.is_builtin() {
            return False;
        }
        class_name = ty.shared.class_name;
        if class_name
            in (
                "int",
                "float",
                "complex",
                "str",
                "bytes",
                "bytearray",
                "bool",
                "None",
                "NoneType"
            ) {
            return True;
        }
        type_args = ty.private.type_args;
        if type_args is None or len(type_args) == 0 {
            return False;
        }
        if class_name in ("list", "tuple", "set", "frozenset") {
            return all(never_graph(a) for a in type_args);
        }
        if class_name == "dict" {
            return len(type_args) == 2 and never_graph(type_args[1]);
        }
        return False;
    }
    return not never_graph(t);
}


impl DeleteStmt.target_may_hold_graph(target: Expr) -> bool {
    return DeleteStmt.type_may_hold_graph(target.type);
}


impl ReportStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl ReturnStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl VisitStmt.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DisengageStmt.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl AwaitExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl CastExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl Assignment.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl ConcurrentExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl BinaryExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl CompareExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl BoolExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl LambdaExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}

impl LambdaExpr.captures.getter -> list[Symbol] {
    return self.get_enclosing_captures();
}

impl LambdaExpr.tail_return_expr -> Expr | None {
    """Implicit return: a braced body consisting of a single expression
    statement returns that expression's value. Any other body (multiple
    statements, or a non-expression statement) uses an explicit `return`.""";
    if isinstance(self.body, Expr) or not isinstance(self.body, list) {
        return None;
    }
    body: Sequence[CodeBlockStmt] = self.body;
    stmts = [
        s
        for s in body
        if not isinstance(s, Semi)
    ];
    if (len(stmts) == 1 and isinstance(stmts[0], ExprStmt)) {
        return stmts[0].expr;
    }
    if (
        len(stmts) == 1
        and isinstance(stmts[0], ReturnStmt)
        and stmts[0].is_implicit
        and stmts[0].expr is not None
    ) {
        return stmts[0].expr;
    }
    return None;
}


impl UnaryExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl IfElseExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl MultiString.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}

impl MultiString.lit_value.getter -> str | bytes {
    text_parts: list[str] = [];
    byte_parts: list[int] = [];
    saw_bytes = False;
    for s in self.strings {
        if isinstance(s, String) {
            part = s.lit_value;
            if isinstance(part, `bytes) {
                raw_bytes: bytes = part;
                saw_bytes = True;
                k = 0;
                while (k < len(raw_bytes)) {
                    byte_parts.append(raw_bytes[k]);
                    k += 1;
                }
            } else {
                raw_text: str = part;
                text_parts.append(raw_text);
            }
        }
    }
    if saw_bytes {
        if text_parts {
            raise ValueError('cannot concatenate bytes and str literals');
        }
        return bytes(byte_parts);
    }
    return ''.join(text_parts);
}


impl FString.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}


impl FormattedValue.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl ListVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl SetVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl TupleVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl DictVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl KVPair.postinit -> None {
    UniNode.postinit(self);
}


impl KWPair.postinit -> None {
    UniNode.postinit(self);
}


impl InnerCompr.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl ListCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl DictCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl AtomTrailer.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl AtomTrailer.as_attr_list.getter -> list[AstSymbolNode] {
    left = self.right if isinstance(self.right, AtomTrailer) else self.target;
    right = self.target if isinstance(self.right, AtomTrailer) else self.right;
    trag_list: list[AstSymbolNode] = [];
    if isinstance(right, AstSymbolNode) {
        trag_list.append(right);
    }
    while (isinstance(left, AtomTrailer) and left.is_attr) {
        if isinstance(left.right, AstSymbolNode) {
            trag_list.insert(0, left.right);
        }
        left = left.target;
    }
    if isinstance(left, AstSymbolNode) {
        trag_list.insert(0, left);
    }
    return trag_list;
}

impl AtomUnit.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl YieldExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl FuncCall.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl Slice.postinit -> None {
    UniNode.postinit(self);
}


impl IndexSlice.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl EdgeRefTrailer.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl EdgeOpRef.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl DisconnectOp.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl ConnectOp.postinit -> None {
    UniNode.postinit(self);
}


impl FilterCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl AssignCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl JsxElement.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.OBJECT_ARCH);
}


impl JsxElement.get_body_start_line -> (int | None) {
    if not self.kid {
        return None;
    }
    opening_tag = self.kid[0];
    if isinstance(opening_tag, JsxElement) {
        for k in opening_tag.kid {
            if (isinstance(k, Token) and (k.name == Tok.JSX_TAG_END) and k.loc) {
                return k.loc.last_line + 1;
            }
        }
    }
    return None;
}

impl JsxElement.get_body_end_line -> (int | None) {
    if not self.kid {
        return None;
    }
    closing_tag = self.kid[-1];
    if isinstance(closing_tag, JsxElement) {
        for k in closing_tag.kid {
            if (isinstance(k, Token) and (k.name == Tok.JSX_CLOSE_START) and k.loc) {
                return k.loc.first_line;
            }
        }
    }
    return None;
}

impl JsxElementName.postinit -> None {
    UniNode.postinit(self);
}


impl JsxAttribute.postinit -> None {
    UniNode.postinit(self);
}


impl JsxSpreadAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}


impl JsxNormalAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}


impl JsxChild.postinit -> None {
    UniNode.postinit(self);
}


impl JsxText.postinit -> None {
    JsxChild.postinit(self);
}


impl JsxText.get_normalized_text -> str {
    raw = self.value.value if isinstance(self.value, Token) else str(self.value);
    if not raw {
        return "";
    }
    lines = raw.replace('\r\n', '\n').replace('\r', '\n').split('\n');

    last_non_empty = -1;
    for i in range(len(lines)) {
        if lines[i].strip(' \t') != '' {
            last_non_empty = i;
        }
    }
    result = "";
    for i in range(len(lines)) {
        line = lines[i].replace('\t', ' ');
        is_first = i == 0;
        is_last = i == len(lines) - 1;
        if not is_first {
            line = line.lstrip(' ');
        }
        if not is_last {
            line = line.rstrip(' ');
        }
        if line {
            if last_non_empty >= 0 and i != last_non_empty {
                line += ' ';
            }
            result += line;
        }
    }
    return result;
}

impl JsxExpression.postinit -> None {
    JsxChild.postinit(self);
}


impl JsxSlot.postinit -> None {
    JsxChild.postinit(self);
}


impl JsxComment.postinit -> None {
    JsxChild.postinit(self);
}


impl MatchStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl MatchCase.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl SwitchStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl SwitchCase.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl MatchOr.postinit -> None {
    UniNode.postinit(self);
}


impl MatchAs.postinit -> None {
    UniNode.postinit(self);
}


impl MatchValue.postinit -> None {
    UniNode.postinit(self);
}


impl MatchSingleton.postinit -> None {
    UniNode.postinit(self);
}


impl MatchSequence.postinit -> None {
    UniNode.postinit(self);
}


impl MatchMapping.postinit -> None {
    UniNode.postinit(self);
}


impl MatchKVPair.postinit -> None {
    UniNode.postinit(self);
}


impl MatchStar.postinit -> None {
    UniNode.postinit(self);
}


impl MatchArch.postinit -> None {
    UniNode.postinit(self);
}


impl Token.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int
) -> None {
    self.orig_src = orig_src;
    self.name = name;
    self.value = value;
    self.line_no = line;
    self.end_line = end_line;
    self.c_start = col_start;
    self.c_end = col_end;
    self.pos_start = pos_start;
    self.pos_end = pos_end;
    self._is_synthetic = False;
    UniNode.postinit(self);
}

impl Token.__repr__ -> str {
    return f"Token({self.name}, {self.value}, {self.loc})";
}

impl Name.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int,
    is_enum_stmt: bool = False,
    is_kwesc: bool = False
) -> None {
    self.is_kwesc = is_kwesc;
    self.is_enum_stmt = is_enum_stmt;
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    self.name_of = self;
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._expr_ctx = ExprCtx.LOAD;
    Expr.postinit(self);
    AstSymbolNode._init_symbol(
        self, sym_name=value, name_spec=self, sym_category=SymbolType.VAR
    );
}

impl SpecialVarRef.init(var: Name, is_enum_stmt: bool = False) -> None {
    self.orig = var;
    Name.init(
        self,
        orig_src=var.orig_src,
        name=var.name,
        value=self.py_resolve_name(),
        line=var.line_no,
        end_line=var.end_line,
        col_start=var.c_start,
        col_end=var.c_end,
        pos_start=var.pos_start,
        pos_end=var.pos_end,
        is_enum_stmt=is_enum_stmt
    );
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.py_resolve_name(),
        name_spec=self,
        sym_category=SymbolType.VAR
    );
}

impl SpecialVarRef.py_resolve_name -> str {
    if (self.orig.name == Tok.KW_SELF) {
        return 'self';
    }
    if (self.orig.name == Tok.KW_PROPS) {
        return 'props';
    } elif (self.orig.name == Tok.KW_SUPER) {
        return 'super';
    } elif (self.orig.name == Tok.KW_ROOT) {
        return Con.ROOT.value;
    } elif (self.orig.name == Tok.KW_HERE) {
        return Con.HERE.value;
    } elif (self.orig.name == Tok.KW_VISITOR) {
        return Con.VISITOR.value;
    } elif (self.orig.name == Tok.KW_INIT) {
        return 'init';
    } elif (self.orig.name == Tok.KW_POST_INIT) {
        return '__post_init__';
    } else {
        raise NotImplementedError('ICE: Special var reference not implemented');
    }
}

impl Literal.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int
) -> None {
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    AstSymbolStubNode._init_stub(self, sym_type=self.SYMBOL_TYPE);
    Expr.postinit(self);
}

impl Literal.lit_value.getter -> int | str | float | bool | None | type | object {
    raise NotImplementedError;
}

impl BuiltinType.lit_value.getter -> type {
    if (self.value not in Literal.type_map) {
        raise TypeError(f"ICE: {self.value} is not a callable builtin");
    }
    tval = Literal.type_map[self.value];
    if isinstance(tval, type) {
        return tval;
    }
    raise TypeError(f"ICE: {self.value} is not a callable builtin");
}

impl Float.lit_value.getter -> float {
    return float(self.value);
}

impl Int.lit_value.getter -> int {
    return int(self.value, 0);
}

impl String.lit_value.getter -> str | bytes {
    if (self.parent and isinstance(self.parent, FString)) {
        fstring_parent: FString = self.parent;
        is_raw = False;
        if (fstring_parent.start and fstring_parent.start.value) {
            prefix = fstring_parent.start.value.lower();
            is_raw = 'r' in prefix;
        }
        if is_raw {
            return self.value;
        }
        return _decode_str_escapes(self.value);
    }
    return decode_string_literal(self.value);
}

impl Bool.lit_value.getter -> bool {
    return (self.value == 'True');
}

impl Null.lit_value.getter -> None {
    return None;
}

impl Ellipsis.lit_value.getter -> object {
    return ...;
}

impl EmptyToken.init(orig_src: (Source | None) = None) -> None {
    _src = orig_src;
    if _src is None {
        _src = Source('', '');
    }
    super.init(
        name='EmptyToken',
        orig_src=_src,
        value='',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl Semi.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int
) -> None {
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    CodeBlockStmt.postinit(self);
}

impl CommentToken.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int,
    kid: Sequence[UniNode]
) -> None {
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    self._link(kid, {});
    (first_tok, last_tok) = self.resolve_tok_range();
    self.loc = CodeLocInfo(first_tok, last_tok);
}

impl Source.init(source: str, mod_path: str) -> None {
    super.init(orig_src=self);
    self.value = source;
    self._hash = "";
    self.file_path = mod_path;
    self.comments = [];
    self.inline_suppressions = {};
}

impl Source.hash.getter -> str {
    if not self._hash {
        h = 0xCBF29CE484222325;
        for b in self.value.encode() {
            h = ((h ^ b) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF;
        }
        self._hash = f"{h:016x}";
    }
    return self._hash;
}

impl Source.code.getter -> str {
    return self.value;
}

impl PythonModuleAst.init(ast: object, orig_src: Source) -> None {
    super.init();
    self.ast = ast;
    self.orig_src = orig_src;
    self.file_path = orig_src.file_path;
}

impl UniNode.gen.getter -> CodeGenTarget {
    if (self._gen is None) {
        import from jaclang.compiler.frontend.codeinfo { CodeGenTarget as _CGT }
        self._gen = _CGT();
    }
    return self._gen;
}

impl UniNode.gen.setter(value: CodeGenTarget) {
    self._gen = value;
}

impl Expr.type_sym_tab.getter -> (UniScopeNode | None) {
    return self._type_sym_tab;
}

impl Expr.type_sym_tab.setter(type_sym_tab: UniScopeNode) {
    self._type_sym_tab = type_sym_tab;
}

impl FuncCall.callee_decl.getter -> (Ability | None) {
    found = [self->:CalleeDecl:->];
    return found[0] if found else None;
}

impl FuncCall.callee_decl.setter(callee_decl: (Ability | None)) {
    del [edge self->:CalleeDecl:->];
    if callee_decl is not None {
        self +>:CalleeDecl:+> callee_decl;
    }
}

impl Import.absorbed_mod.getter -> (Module | None) {
    found = [self->:Absorbs:->];
    return found[0] if found else None;
}

impl Import.absorbed_mod.setter(absorbed_mod: (Module | None)) {
    del [edge self->:Absorbs:->];
    if absorbed_mod is not None {
        self +>:Absorbs:+> absorbed_mod;
    }
}

impl NameAtom.sym.getter -> (Symbol | None) {
    found = [self->:SymOf:->];
    return found[0] if found else None;
}

impl NameAtom.sym.setter(sym: Symbol) {
    del [edge self->:SymOf:->];
    if sym is not None {
        self +>:SymOf:+> sym;
    }
}

impl NameAtom.expr_ctx.getter -> ExprCtx {
    return self._expr_ctx;
}

impl NameAtom.expr_ctx.setter(expr_ctx: ExprCtx) {
    self._expr_ctx = expr_ctx;
}

impl is_identifier_slot(nd: UniNode) -> bool {
    par = nd.parent;
    if isinstance(par, KWPair) {
        return par.key is nd;
    }
    if isinstance(par, AtomTrailer) {
        return par.is_attr and (par.right is nd);
    }
    if isinstance(par, (HasVar, ParamVar, Archetype, Enum)) {
        return par.name is nd;
    }
    if isinstance(par, Ability) {
        return par.name_ref is nd;
    }
    if isinstance(par, ModuleItem) {
        return (par.name is nd) or (par.alias is nd);
    }
    return False;
}

impl find_python_scope_node_of(nd: UniNode) -> (UniScopeNode | None) {
    while nd.parent {
        scope_parent = nd.parent;
        if isinstance(scope_parent, UniScopeNode)
            and UniScopeNode.is_python_scoping(scope_parent) {
            return scope_parent;
        }
        nd = scope_parent;
    }
    return None;
}

impl find_typed_decl_scope_of(nd: AstSymbolNode) -> UniScopeNode {
    if UniScopeNode.is_python_scoping(nd.sym_tab) {
        return nd.sym_tab;
    }
    py_scope = find_python_scope_node_of(nd);
    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        return py_scope;
    }
    return nd.sym_tab;
}

impl lookup_enclosing_binding(from_scope: UniScopeNode, name: str) -> (Symbol | None) {
    scope = find_python_scope_node_of(from_scope);
    while scope is not None {
        if isinstance(scope, Module) {
            sym = scope.names_in_scope.get(name);
            if sym is not None and sym.sym_type == SymbolType.MOD_VAR {
                return sym;
            }
            return None;
        }
        if isinstance(scope, (Ability, ImplDef, Test, LambdaExpr)) {
            sym = scope.names_in_scope.get(name);
            if sym is not None {
                return sym;
            }
        }
        scope = find_python_scope_node_of(scope);
    }
    return None;
}

impl record_cross_scope_rebind(py_scope: UniScopeNode, name: str, sym: Symbol) -> None {
    outer_tab = sym.parent_tab;
    if outer_tab is None or outer_tab is py_scope {
        return;
    }
    if not isinstance(py_scope, (Ability, ImplDef, Test)) {
        return;
    }
    if isinstance(py_scope, ImplDef) and py_scope.decl_link is outer_tab {
        return;
    }
    if isinstance(outer_tab, ImplDef) and outer_tab.decl_link is py_scope {
        return;
    }
    if isinstance(outer_tab, Module) {
        if sym.sym_type == SymbolType.MOD_VAR {
            py_scope.implicit_rebinds[name] = sym;
        }
        return;
    }
    if isinstance(outer_tab, (Ability, ImplDef, Test)) {
        py_scope.implicit_rebinds[name] = sym;
    }
}

impl rebind_or_def_insert(
    target: AstSymbolNode, py_scope: UniScopeNode, single_decl: str
) -> None {
    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        outer_sym = lookup_enclosing_binding(py_scope, target.sym_name);
        if outer_sym is not None {
            outer_sym.add_use(target.name_spec);
            py_scope.adopt_primary(outer_sym, target.sym_name);
            py_scope.implicit_rebinds[target.sym_name] = outer_sym;
            return;
        }
    }
    py_scope.def_insert(target, single_decl=single_decl);
}

impl def_insert_unpacking(
    nd: Expr, sym_tab: UniScopeNode, rebind_in_python_scope: bool = False
) -> None {
    if isinstance(nd, Name) {
        if rebind_in_python_scope {
            if ((existing := sym_tab.lookup(nd.sym_name, deep=False)) is not None) {
                existing.add_use(nd.name_spec);
                return;
            }
            py_scope = find_python_scope_node_of(nd);
            if py_scope is not None {
                if ((outer := py_scope.lookup(nd.sym_name, deep=False)) is not None) {
                    outer.add_use(nd.name_spec);
                    record_cross_scope_rebind(py_scope, nd.sym_name, outer);
                } else {
                    rebind_or_def_insert(nd, py_scope, single_decl='local var');
                }
                return;
            }
        }
        sym_tab.def_insert(nd, single_decl='iterator');
    } elif isinstance(nd, (TupleVal, ListVal)) {
        for target_var in nd.values {
            if isinstance(target_var, Expr) {
                def_insert_unpacking(target_var, sym_tab, rebind_in_python_scope);
            }
        }
    } elif (isinstance(nd, UnaryExpr) and (nd.op.name == Tok.STAR_MUL)) {
        def_insert_unpacking(nd.operand, sym_tab, rebind_in_python_scope);
    }
}

impl _ability_of_defn(defn_node: UniNode) -> (Ability | None) {
    if isinstance(defn_node, Ability) {
        return defn_node;
    }
    if isinstance(defn_node.parent, Ability) {
        return defn_node.parent;
    }
    return None;
}

impl ability_of_symbol(sym: (Symbol | None)) -> (Ability | None) {
    if sym is None or not sym.defn {
        return None;
    }
    decl = _ability_of_defn(sym.defn[0]);

    if decl is not None and str(decl.loc.mod_path).endswith(".pyi") {
        for alt in sym.defn {
            alt_decl = _ability_of_defn(alt);
            if alt_decl is not None
                and not str(alt_decl.loc.mod_path).endswith(".pyi") {
                return alt_decl;
            }
        }
    }
    return decl;
}

impl binding_kind_of_decl(decl: NameAtom) -> BindingKind {
    owner = decl.name_of;
    if isinstance(owner, (Archetype, Enum, TypeAlias)) {
        return BindingKind.BOTH;
    }
    if isinstance(owner, TypeParam) {
        return BindingKind.TYPE;
    }
    return BindingKind.VALUE;
}

impl import_chain_of(sym: Symbol) -> list[Symbol] {
    seen: set[int] = set();
    chain: list[Symbol] = [];
    cur: Symbol = sym;
    while True {
        if id(cur) in seen or not cur.defn {
            return chain;
        }
        seen.add(id(cur));
        chain.append(cur);
        decl = cur.decl;
        if not isinstance(decl.parent, ModuleItem) {
            return chain;
        }
        nxt = decl.sym;
        if nxt is None or nxt is cur {
            return chain;
        }
        cur = nxt;
    }
}

impl resolved_decl_of(sym: Symbol) -> (NameAtom | None) {
    for cur in import_chain_of(sym) {
        decl = cur.decl;
        if not isinstance(decl.parent, ModuleItem) {
            return decl;
        }
    }
    return None;
}

impl kind_has_runtime_binding(
    kind: BindingKind, decl: (NameAtom | None), space: CodeContext
) -> bool {
    if not kind.denotes_value() {
        return False;
    }
    if space != CodeContext.CLIENT {
        return True;
    }
    return decl is None or not isinstance(decl.name_of, TypeAlias);
}

impl has_runtime_binding(sym: Symbol, space: CodeContext) -> bool {
    return kind_has_runtime_binding(sym.binding_kind, resolved_decl_of(sym), space);
}

impl is_client_destined(nd: UniNode) -> bool {
    cur: (UniNode | None) = nd;
    while cur is not None {
        if isinstance(cur, ContextAwareNode) {
            return (cur.code_context == CodeContext.CLIENT) or cur.codespace_dual;
        }
        cur = cur.parent;
    }
    return False;
}

impl type_only_import_of(nd: NameAtom) -> (ModuleItem | None) {
    sym = nd.sym;
    if sym is None or not sym.imported or not sym.defn {
        return None;
    }
    found: (ModuleItem | None) = None;
    for d in sym.defn {
        if d is nd or not isinstance(d.parent, ModuleItem) {
            return None;
        }
        if not d.parent.from_parent.is_typed {
            return None;
        }
        found = d.parent;
    }
    return found;
}

impl in_type_position(nd: UniNode) -> bool {
    cur: UniNode = nd;
    parent = cur.parent;
    while parent is not None {
        if isinstance(parent, (SubTag, TypeAlias, TypeParam, IndexSlice)) {
            return True;
        }
        if isinstance(parent, CastExpr) and parent.cast_type is cur {
            return True;
        }
        if isinstance(parent, FuncSignature) and parent.return_type is cur {
            return True;
        }
        cur = parent;
        parent = cur.parent;
    }
    return False;
}

impl bind_assignment_targets(nd: Assignment) -> None {
    for i in nd.target {
        if isinstance(i, AstSymbolNode) {
            if isinstance(i, (ListVal, TupleVal)) {
                def_insert_unpacking(i, i.sym_tab, rebind_in_python_scope=True);
            } elif (
                (i.sym_name in i.sym_tab.names_in_scope)
                and ((sym := i.sym_tab.names_in_scope[i.sym_name]) is not None)
            ) {
                if sym.imported and isinstance(nd.value, Null) {
                    sym.add_defn(i.name_spec);
                }
                sym.add_use(i.name_spec);
                record_cross_scope_rebind(i.sym_tab, i.sym_name, sym);
            } elif (
                (nd.type_tag is None)
                and ((outer_has := i.sym_tab.lookup(i.sym_name, deep=True)) is not None)
                and outer_has.sym_type == SymbolType.HAS_VAR
                and isinstance(outer_has.parent_tab, Ability)
            ) {
                outer_has.add_use(i.name_spec);
            } elif (
                (nd.type_tag is None) and not UniScopeNode.is_python_scoping(i.sym_tab)
            ) {
                py_scope = find_python_scope_node_of(i);
                if py_scope is not None {
                    if (
                        (outer := py_scope.lookup(i.sym_name, deep=False)) is not None
                    ) {
                        if outer.imported and isinstance(nd.value, Null) {
                            outer.add_defn(i.name_spec);
                        }
                        outer.add_use(i.name_spec);
                        record_cross_scope_rebind(py_scope, i.sym_name, outer);
                    } else {
                        rebind_or_def_insert(i, py_scope, single_decl='local var');
                    }
                } else {
                    i.sym_tab.def_insert(i, single_decl='local var');
                }
            } elif (
                (nd.type_tag is None)
                and isinstance(i.sym_tab, (Ability, ImplDef, Test, LambdaExpr))
            ) {
                rebind_or_def_insert(i, i.sym_tab, single_decl='local var');
            } else {
                if isinstance(i.sym_tab, Enum) {
                    i.name_spec._sym_category = SymbolType.ENUM_MEMBER;
                }
                find_typed_decl_scope_of(i).def_insert(i, single_decl='local var');
            }
        }
    }
}

impl Expr.type.getter -> (TypeBase | None) {
    if self._type_cache_ok {
        return self._type_cache;
    }
    found = [self->:TypeOf:->];
    self._type_cache = found[0] if found else None;
    self._type_cache_ok = True;
    return self._type_cache;
}

impl Expr.type.setter(type: (TypeBase | None)) -> None {
    del [edge self->:TypeOf:->];
    if type is not None {
        self +>:TypeOf:+> type;
    }
    self._type_cache = type;
    self._type_cache_ok = True;
}

impl Expr.narrowed_type.getter -> (TypeBase | None) {
    found = [self->:NarrowedTypeOf:->];
    return found[0] if found else None;
}

impl Expr.narrowed_type.setter(narrowed_type: (TypeBase | None)) -> None {
    del [edge self->:NarrowedTypeOf:->];
    if narrowed_type is not None {
        self +>:NarrowedTypeOf:+> narrowed_type;
    }
}

impl AstTypedVarNode.type.getter -> (TypeBase | None) {
    found = [self->:TypeOf:->];
    return found[0] if found else None;
}

impl AstTypedVarNode.type.setter(type: (TypeBase | None)) -> None {
    del [edge self->:TypeOf:->];
    if type is not None {
        self +>:TypeOf:+> type;
    }
}

impl Ability.event_triggers.getter -> (list[TypeBase] | None) {
    return [self->:EventTriggerOf:->];
}

impl Ability.event_triggers.setter(event_triggers: (list[TypeBase] | None)) -> None {
    del [edge self->:EventTriggerOf:->];
    for t in (event_triggers or []) {
        self +>:EventTriggerOf:+> t;
    }
}
