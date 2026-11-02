obj PassStep {
    has name: str,
        contract: PassContract,
        load: Callable[[], type[CompilerPass]];
}

type PassSchedule = list[PassStep];

def load_app_context_pass -> type[CompilerPass];

def load_graph_lowering_pass -> type[CompilerPass];

def load_ast_validation_pass -> type[CompilerPass];

def load_absorb_imports_pass -> type[CompilerPass];

def load_sym_tab_build_pass -> type[CompilerPass];

def load_decl_impl_match_pass -> type[CompilerPass];

def load_placement_apply_pass -> type[CompilerPass];

def load_import_wiring_pass -> type[CompilerPass];

def load_package_boundary_pass -> type[CompilerPass];

def load_semantic_analysis_pass -> type[CompilerPass];

def load_sem_def_match_pass -> type[CompilerPass];

def load_cfg_build_pass -> type[CompilerPass];

def load_mtir_gen_pass -> type[CompilerPass];

def load_jsx_intrinsic_guard_pass -> type[CompilerPass];

def load_comptime_resolve_pass -> type[CompilerPass];

def load_region_infer_pass -> type[CompilerPass];

def load_variant_agreement_pass -> type[CompilerPass];

def load_type_check_pass -> type[CompilerPass];

def load_static_analysis_pass -> type[CompilerPass];

def load_flow_check_pass -> type[CompilerPass];

def load_access_check_pass -> type[CompilerPass];

def load_ownership_check_pass -> type[CompilerPass];

def load_placement_pass -> type[CompilerPass];

def load_portability_warn_pass -> type[CompilerPass];

def load_jac_lint_check_pass -> type[CompilerPass];

def load_declaration_type_pass -> type[CompilerPass];

def load_boundary_facts_pass -> type[CompilerPass];

def load_boundary_analysis_pass -> type[CompilerPass];

def load_endpoint_effect_pass -> type[CompilerPass];

def load_esast_gen_pass -> type[CompilerPass];

def load_layout_pass -> type[CompilerPass];

def load_rc_facts_pass -> type[CompilerPass];

def load_native_import_facts_pass -> type[CompilerPass];

def load_jcir_gen_pass -> type[CompilerPass];

def load_freeze_structure_pass -> type[CompilerPass];

def load_jcir_bytecode_gen_pass -> type[CompilerPass];

def load_na_ir_gen_pass -> type[CompilerPass];

def load_native_compile_pass -> type[CompilerPass];

def load_comment_attach_pass -> type[CompilerPass];

def load_jac_auto_lint_pass -> type[CompilerPass];

def load_doc_ir_gen_pass -> type[CompilerPass];

def load_jac_format_pass -> type[CompilerPass];

def load_pyast_build_pass -> type[CompilerPass];

def load_grammar_extract_pass -> type[CompilerPass];

def load_coalesce_bb_pass -> type[CompilerPass];

def load_normalize_pass -> type[CompilerPass];

def load_unparse_pass -> type[CompilerPass];

glob APP_CONTEXT_STEP: PassStep = PassStep(
         name='AppContextPass', contract=PassContract(), load=load_app_context_pass
     ),
     GRAPH_LOWERING_STEP: PassStep = PassStep(
         name='GraphLoweringPass',
         contract=PassContract(kernel_safe=True),
         load=load_graph_lowering_pass
     ),
     AST_VALIDATION_STEP: PassStep = PassStep(
         name='ASTValidationPass',
         contract=PassContract(kernel_safe=True),
         load=load_ast_validation_pass
     ),
     ABSORB_IMPORTS_STEP: PassStep = PassStep(
         name='AbsorbImportsPass',
         contract=PassContract(),
         load=load_absorb_imports_pass
     ),
     SYM_TAB_BUILD_STEP: PassStep = PassStep(
         name='SymTabBuildPass',
         contract=PassContract(
             provides=(
                 AnalysisFact.SYM_OF,
                 AnalysisFact.DEFINES,
                 AnalysisFact.IN_SCOPE,
                 AnalysisFact.SCOPE_CHILD,

             ),
             kernel_safe=True
         ),
         load=load_sym_tab_build_pass
     ),
     DECL_IMPL_MATCH_STEP: PassStep = PassStep(
         name='DeclImplMatchPass',
         contract=PassContract(
             requires=(AnalysisFact.SYM_OF, ),
             provides=(AnalysisFact.IMPL_OF, ),
             kernel_safe=True
         ),
         load=load_decl_impl_match_pass
     ),
     PLACEMENT_APPLY_STEP: PassStep = PassStep(
         name='PlacementApplyPass',
         contract=PassContract(
             requires=(AnalysisFact.SYM_OF, ),
             provides=(
                 AnalysisFact.PLACED_IN,
                 AnalysisFact.DECIDED_CODESPACE,
                 AnalysisFact.CODESPACE_PULL,

             )
         ),
         load=load_placement_apply_pass
     ),
     IMPORT_WIRING_STEP: PassStep = PassStep(
         name='ImportWiringPass',
         contract=PassContract(requires=(AnalysisFact.SYM_OF, )),
         load=load_import_wiring_pass
     ),
     PACKAGE_BOUNDARY_STEP: PassStep = PassStep(
         name='PackageBoundaryPass',
         contract=PassContract(requires=(AnalysisFact.SYM_OF, )),
         load=load_package_boundary_pass
     ),
     SEMANTIC_ANALYSIS_STEP: PassStep = PassStep(
         name='SemanticAnalysisPass',
         contract=PassContract(kernel_safe=True),
         load=load_semantic_analysis_pass
     ),
     SEM_DEF_MATCH_STEP: PassStep = PassStep(
         name='SemDefMatchPass',
         contract=PassContract(kernel_safe=True),
         load=load_sem_def_match_pass
     ),
     CFG_BUILD_STEP: PassStep = PassStep(
         name='CFGBuildPass',
         contract=PassContract(
             provides=(
                 AnalysisFact.CFG_SUCC,
                 AnalysisFact.CFG_TRUE,
                 AnalysisFact.CFG_FALSE,
                 AnalysisFact.CFG_EXIT,

             ),
             kernel_safe=True
         ),
         load=load_cfg_build_pass
     ),
     MTIR_GEN_STEP: PassStep = PassStep(
         name='MTIRGenPass', contract=PassContract(), load=load_mtir_gen_pass
     ),
     JSX_INTRINSIC_GUARD_STEP: PassStep = PassStep(
         name='JsxIntrinsicGuardPass',
         contract=PassContract(kernel_safe=True),
         load=load_jsx_intrinsic_guard_pass
     ),
     COMPTIME_RESOLVE_STEP: PassStep = PassStep(
         name='ComptimeResolvePass',
         contract=PassContract(provides=(AnalysisFact.COMPTIME, )),
         load=load_comptime_resolve_pass
     ),
     REGION_INFER_STEP: PassStep = PassStep(
         name='RegionInferPass',
         contract=PassContract(provides=(AnalysisFact.REGION_INFER, )),
         load=load_region_infer_pass
     ),
     VARIANT_AGREEMENT_STEP: PassStep = PassStep(
         name='VariantAgreementPass',
         contract=PassContract(provides=(AnalysisFact.VARIANT_AGREEMENT, )),
         load=load_variant_agreement_pass
     ),
     TYPE_CHECK_STEP: PassStep = PassStep(
         name='TypeCheckPass',
         contract=PassContract(provides=(AnalysisFact.TYPE_OF, )),
         load=load_type_check_pass
     ),
     STATIC_ANALYSIS_STEP: PassStep = PassStep(
         name='StaticAnalysisPass',
         contract=PassContract(provides=(AnalysisFact.STATIC_CHECKS, )),
         load=load_static_analysis_pass
     ),
     FLOW_CHECK_STEP: PassStep = PassStep(
         name='FlowCheckPass',
         contract=PassContract(
             requires=(AnalysisFact.CFG_SUCC, ), provides=(AnalysisFact.FLOW_CHECKS, )
         ),
         load=load_flow_check_pass
     ),
     ACCESS_CHECK_STEP: PassStep = PassStep(
         name='AccessCheckPass',
         contract=PassContract(provides=(AnalysisFact.ACCESS_CHECKS, )),
         load=load_access_check_pass
     ),
     OWNERSHIP_CHECK_STEP: PassStep = PassStep(
         name='OwnershipCheckPass',
         contract=PassContract(
             requires=(AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF, ),
             provides=(AnalysisFact.OWNERSHIP, )
         ),
         load=load_ownership_check_pass
     ),
     PLACEMENT_STEP: PassStep = PassStep(
         name='PlacementPass',
         contract=PassContract(
             requires=(AnalysisFact.TYPE_OF, ),
             provides=(AnalysisFact.CAPABILITY, AnalysisFact.CLIENT_CAPABILITY, )
         ),
         load=load_placement_pass
     ),
     PORTABILITY_WARN_STEP: PassStep = PassStep(
         name='PortabilityWarnPass',
         contract=PassContract(provides=(AnalysisFact.PORTABILITY, )),
         load=load_portability_warn_pass
     ),
     JAC_LINT_CHECK_STEP: PassStep = PassStep(
         name='JacLintCheckPass', contract=PassContract(), load=load_jac_lint_check_pass
     ),
     DECLARATION_TYPE_STEP: PassStep = PassStep(
         name='DeclarationTypePass',
         contract=PassContract(provides=(AnalysisFact.DECL_TYPES, )),
         load=load_declaration_type_pass
     ),
     BOUNDARY_FACTS_STEP: PassStep = PassStep(
         name='BoundaryFactsPass',
         contract=PassContract(),
         load=load_boundary_facts_pass
     ),
     BOUNDARY_ANALYSIS_STEP: PassStep = PassStep(
         name='BoundaryAnalysisPass',
         contract=PassContract(),
         load=load_boundary_analysis_pass
     ),
     ENDPOINT_EFFECT_STEP: PassStep = PassStep(
         name='EndpointEffectPass',
         contract=PassContract(),
         load=load_endpoint_effect_pass
     ),
     ESAST_GEN_STEP: PassStep = PassStep(
         name='EsastGenPass', contract=PassContract(), load=load_esast_gen_pass
     ),
     LAYOUT_STEP: PassStep = PassStep(
         name='LayoutPass', contract=PassContract(), load=load_layout_pass
     ),
     RC_FACTS_STEP: PassStep = PassStep(
         name='RcFactsPass',
         contract=PassContract(
             requires=(AnalysisFact.CFG_SUCC, ), provides=(AnalysisFact.RC_FACTS, )
         ),
         load=load_rc_facts_pass
     ),
     NATIVE_IMPORT_FACTS_STEP: PassStep = PassStep(
         name='NativeImportFactsPass',
         contract=PassContract(),
         load=load_native_import_facts_pass
     ),
     JCIR_GEN_STEP: PassStep = PassStep(
         name='JcirGenPass', contract=PassContract(), load=load_jcir_gen_pass
     ),
     FREEZE_STRUCTURE_STEP: PassStep = PassStep(
         name='FreezeStructurePass',
         contract=PassContract(provides=(AnalysisFact.FROZEN, )),
         load=load_freeze_structure_pass
     ),
     JCIR_BYTECODE_GEN_STEP: PassStep = PassStep(
         name='JcirBytecodeGenPass',
         contract=PassContract(),
         load=load_jcir_bytecode_gen_pass
     ),
     NA_IR_GEN_STEP: PassStep = PassStep(
         name='NaIRGenPass',
         contract=PassContract(
             requires=(
                 AnalysisFact.TYPE_OF,
                 AnalysisFact.CFG_SUCC,
                 AnalysisFact.OWNERSHIP,
                 AnalysisFact.CAPABILITY,
                 AnalysisFact.RC_FACTS,

             )
         ),
         load=load_na_ir_gen_pass
     ),
     NATIVE_COMPILE_STEP: PassStep = PassStep(
         name='NativeCompilePass',
         contract=PassContract(),
         load=load_native_compile_pass
     ),
     COMMENT_ATTACH_STEP: PassStep = PassStep(
         name='CommentAttachPass',
         contract=PassContract(),
         load=load_comment_attach_pass
     ),
     JAC_AUTO_LINT_STEP: PassStep = PassStep(
         name='JacAutoLintPass', contract=PassContract(), load=load_jac_auto_lint_pass
     ),
     DOC_IR_GEN_STEP: PassStep = PassStep(
         name='DocIRGenPass', contract=PassContract(), load=load_doc_ir_gen_pass
     ),
     JAC_FORMAT_STEP: PassStep = PassStep(
         name='JacFormatPass', contract=PassContract(), load=load_jac_format_pass
     ),
     PYAST_BUILD_STEP: PassStep = PassStep(
         name='PyastBuildPass', contract=PassContract(), load=load_pyast_build_pass
     ),
     GRAMMAR_EXTRACT_STEP: PassStep = PassStep(
         name='GrammarExtractPass',
         contract=PassContract(),
         load=load_grammar_extract_pass
     ),
     COALESCE_BB_STEP: PassStep = PassStep(
         name='CoalesceBBPass', contract=PassContract(), load=load_coalesce_bb_pass
     ),
     NORMALIZE_STEP: PassStep = PassStep(
         name='NormalizePass', contract=PassContract(), load=load_normalize_pass
     ),
     UNPARSE_STEP: PassStep = PassStep(
         name='UnparsePass', contract=PassContract(), load=load_unparse_pass
     );
