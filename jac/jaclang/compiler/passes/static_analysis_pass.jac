import builtins;

glob BUILTIN_NAMES: set[str] = set(dir(builtins)),
     DEPRECATED_TYPING_ALIASES: dict[str, str] = {
         'Dict': 'dict',
         'FrozenSet': 'frozenset',
         'List': 'list',
         'Set': 'set',
         'Tuple': 'tuple',
         'Type': 'type'
     };

def is_bootstrap_compiled_module(mod_path: str) -> bool;

def is_ambient_provider_module(mod_path: str) -> bool;

walker UnusedSymbolWalker(ScopeWalker) {
    has analysis: StaticAnalysisPass;

    can check_scope with UniScopeNode entry;
}

walker StaticAnalysisPass(CompilerPass) {
    static has contract: PassContract = PassContract(
        provides=(AnalysisFact.STATIC_CHECKS, )
    );

    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _check_unused_symbols(scope: UniScopeNode) -> None;
    def _check_undefined_names(mod: Module) -> None;
    def _literal_case_suggestion(name: str) -> (str | None);
    def _enclosing_class_member(name_nd: Name) -> (str | None);
    def _osp_shape_position(name_nd: Name) -> (str | None);
    def _native_type_position(name_nd: Name) -> (str | None);
    def _check_unreachable_code(mod: Module) -> None;
    def _check_semantic_patterns(mod: Module) -> None;
    def _check_typing_import_refusals(mod: Module) -> None;
    def _check_redundant_imports(mod: Module) -> None;
    def _check_client_imports(mod: Module) -> None;
    def _check_placement_warnings(mod: Module) -> None;
}
