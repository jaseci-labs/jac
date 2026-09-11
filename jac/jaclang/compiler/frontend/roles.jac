import type from jaclang.compiler.frontend.unitree {
    AstImplNeedingNode,
    ImplDef,
    UniNode
}

edge Role {}

edge Kid: UniNode --> UniNode {}

edge ImplOf: AstImplNeedingNode --> ImplDef {}

edge AccessRole(Role) {}

edge AccessorsRole(Role) {}

edge AliasRole(Role) {}

edge ArchTagInfoRole(Role) {}

edge ArchTypeRole(Role) {}

edge ArgPatternsRole(Role) {}

edge AssignmentsRole(Role) {}

edge AssignsRole(Role) {}

edge AttributesRole(Role) {}

edge AugOpRole(Role) {}

edge AwaitingBodyRole(Role) {}

edge BaseClassesRole(Role) {}

edge BodyRole(Role) {}

edge BoundRole(Role) {}

edge CasesRole(Role) {}

edge CastTypeRole(Role) {}

edge CauseRole(Role) {}

edge ChainRole(Role) {}

edge ChildrenRole(Role) {}

edge ClibDeclsRole(Role) {}

edge CodeRole(Role) {}

edge CollectionRole(Role) {}

edge ComparesRole(Role) {}

edge ComprRole(Role) {}

edge ConditionRole(Role) {}

edge ConditionalRole(Role) {}

edge ConnAssignRole(Role) {}

edge ConnTypeRole(Role) {}

edge CountByRole(Role) {}

edge CtrlRole(Role) {}

edge DecoratorsRole(Role) {}

edge DefaultValRole(Role) {}

edge DescriptionRole(Role) {}

edge DocRole(Role) {}

edge DynamicTagRole(Role) {}

edge EdgeSpecRole(Role) {}

edge ElseBodyRole(Role) {}

edge ElseValueRole(Role) {}

edge EndRole(Role) {}

edge ErrorMsgRole(Role) {}

edge EventRole(Role) {}

edge ExTypeRole(Role) {}

edge ExceptsRole(Role) {}

edge ExprRole(Role) {}

edge ExprsRole(Role) {}

edge FTypeRole(Role) {}

edge FilterCondRole(Role) {}

edge FinallyBodyRole(Role) {}

edge FormatPartRole(Role) {}

edge FormatSpecRole(Role) {}

edge FromLocRole(Role) {}

edge FromTargetRole(Role) {}

edge GuardRole(Role) {}

edge HintRole(Role) {}

edge InsertLocRole(Role) {}

edge ItemsRole(Role) {}

edge IterRole(Role) {}

edge KeyRole(Role) {}

edge KeywordsRole(Role) {}

edge KvPairRole(Role) {}

edge KvPairsRole(Role) {}

edge KwPatternsRole(Role) {}

edge KwargsRole(Role) {}

edge KwonlyargsRole(Role) {}

edge LeftRole(Role) {}

edge MainRole(Role) {}

edge NameRole(Role) {}

edge NameRefRole(Role) {}

edge OpRole(Role) {}

edge OperandRole(Role) {}

edge OpsRole(Role) {}

edge OutExprRole(Role) {}

edge ParamsRole(Role) {}

edge PartsRole(Role) {}

edge PathRole(Role) {}

edge PatternRole(Role) {}

edge PatternsRole(Role) {}

edge PosonlyParamsRole(Role) {}

edge ReturnTypeRole(Role) {}

edge RightRole(Role) {}

edge RightsRole(Role) {}

edge SignatureRole(Role) {}

edge SlicesRole(Role) {}

edge SpecRole(Role) {}

edge SrcEndpointRole(Role) {}

edge StartRole(Role) {}

edge StepRole(Role) {}

edge StopRole(Role) {}

edge StringsRole(Role) {}

edge TargetRole(Role) {}

edge TgtEndpointRole(Role) {}

edge TokRole(Role) {}

edge TypeCtxRole(Role) {}

edge TypeParamsRole(Role) {}

edge TypeTagRole(Role) {}

edge UnpackRole(Role) {}

edge ValueRole(Role) {}

edge ValueTypeRole(Role) {}

edge ValuesRole(Role) {}

edge VarargsRole(Role) {}

edge VarsRole(Role) {}
