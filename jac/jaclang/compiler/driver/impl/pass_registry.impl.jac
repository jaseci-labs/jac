impl load_app_context_pass -> type[CompilerPass] {
    return AppContextPass;
}

impl load_graph_lowering_pass -> type[CompilerPass] {
    return GraphLoweringPass;
}

impl load_ast_validation_pass -> type[CompilerPass] {
    return ASTValidationPass;
}

impl load_absorb_imports_pass -> type[CompilerPass] {
    return AbsorbImportsPass;
}

impl load_sym_tab_build_pass -> type[CompilerPass] {
    return SymTabBuildPass;
}

impl load_decl_impl_match_pass -> type[CompilerPass] {
    return DeclImplMatchPass;
}

impl load_placement_apply_pass -> type[CompilerPass] {
    return PlacementApplyPass;
}

impl load_import_wiring_pass -> type[CompilerPass] {
    return ImportWiringPass;
}

impl load_package_boundary_pass -> type[CompilerPass] {
    return PackageBoundaryPass;
}

impl load_semantic_analysis_pass -> type[CompilerPass] {
    return SemanticAnalysisPass;
}

impl load_sem_def_match_pass -> type[CompilerPass] {
    return SemDefMatchPass;
}

impl load_cfg_build_pass -> type[CompilerPass] {
    return CFGBuildPass;
}

impl load_mtir_gen_pass -> type[CompilerPass] {
    return MTIRGenPass;
}

impl load_jsx_intrinsic_guard_pass -> type[CompilerPass] {
    return JsxIntrinsicGuardPass;
}

impl load_comptime_resolve_pass -> type[CompilerPass] {
    return ComptimeResolvePass;
}

impl load_region_infer_pass -> type[CompilerPass] {
    return RegionInferPass;
}

impl load_variant_agreement_pass -> type[CompilerPass] {
    return VariantAgreementPass;
}

impl load_type_check_pass -> type[CompilerPass] {
    return TypeCheckPass;
}

impl load_static_analysis_pass -> type[CompilerPass] {
    return StaticAnalysisPass;
}

impl load_flow_check_pass -> type[CompilerPass] {
    return FlowCheckPass;
}

impl load_access_check_pass -> type[CompilerPass] {
    return AccessCheckPass;
}

impl load_ownership_check_pass -> type[CompilerPass] {
    return OwnershipCheckPass;
}

impl load_placement_pass -> type[CompilerPass] {
    return PlacementPass;
}

impl load_portability_warn_pass -> type[CompilerPass] {
    return PortabilityWarnPass;
}

impl load_jac_lint_check_pass -> type[CompilerPass] {
    return JacLintCheckPass;
}

impl load_declaration_type_pass -> type[CompilerPass] {
    return DeclarationTypePass;
}

impl load_boundary_facts_pass -> type[CompilerPass] {
    return BoundaryFactsPass;
}

impl load_boundary_analysis_pass -> type[CompilerPass] {
    return BoundaryAnalysisPass;
}

impl load_endpoint_effect_pass -> type[CompilerPass] {
    return EndpointEffectPass;
}

impl load_esast_gen_pass -> type[CompilerPass] {
    return EsastGenPass;
}

impl load_layout_pass -> type[CompilerPass] {
    return LayoutPass;
}

impl load_rc_facts_pass -> type[CompilerPass] {
    return RcFactsPass;
}

impl load_native_import_facts_pass -> type[CompilerPass] {
    return NativeImportFactsPass;
}

impl load_jcir_gen_pass -> type[CompilerPass] {
    return JcirGenPass;
}

impl load_freeze_structure_pass -> type[CompilerPass] {
    return FreezeStructurePass;
}

impl load_jcir_bytecode_gen_pass -> type[CompilerPass] {
    return JcirBytecodeGenPass;
}

impl load_na_ir_gen_pass -> type[CompilerPass] {
    return NaIRGenPass;
}

impl load_native_compile_pass -> type[CompilerPass] {
    return NativeCompilePass;
}

impl load_comment_attach_pass -> type[CompilerPass] {
    return CommentAttachPass;
}

impl load_jac_auto_lint_pass -> type[CompilerPass] {
    return JacAutoLintPass;
}

impl load_doc_ir_gen_pass -> type[CompilerPass] {
    return DocIRGenPass;
}

impl load_jac_format_pass -> type[CompilerPass] {
    return JacFormatPass;
}

impl load_pyast_build_pass -> type[CompilerPass] {
    return PyastBuildPass;
}

impl load_grammar_extract_pass -> type[CompilerPass] {
    return GrammarExtractPass;
}

impl load_coalesce_bb_pass -> type[CompilerPass] {
    return CoalesceBBPass;
}

impl load_normalize_pass -> type[CompilerPass] {
    return NormalizePass;
}

impl load_unparse_pass -> type[CompilerPass] {
    return UnparsePass;
}
