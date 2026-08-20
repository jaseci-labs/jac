import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    Bool,
    BuiltinType,
    DictVal,
    Enum,
    Float,
    FuncCall,
    FuncSignature,
    HasVar,
    Import,
    IndexSlice,
    Int,
    KVPair,
    LambdaExpr,
    ListVal,
    Module,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    NameAtom,
    Null,
    ParamVar,
    Slice,
    String,
    Token,
    TupleVal,
    UnaryExpr,
    UniNode,
    ability_of_symbol
}
import from jaclang.jac0core.constant { CodeContext, SymbolType, Tokens as Tok }
import from jaclang.jac0core.codeinfo {
    BoundaryTypeInfo,
    InteropBinding,
    InteropContext
}
import from jaclang.jac0core.passes.uni_pass { UniPass }

class BoundaryAnalysisPass(UniPass) {
    has _func_defs: dict[(str, tuple[(InteropContext, Ability)])],
        _imported_native_funcs: dict[(str, tuple[(str, InteropContext)])],
        _imported_native_modules: dict[(str, tuple[(str, InteropContext)])];

    def before_pass(self: BoundaryAnalysisPass) -> None;
    def _resolved_native_decl(
        self: BoundaryAnalysisPass, name_node: (UniNode | None)
    ) -> (Ability | None);

    def _na_target_decl(
        self: BoundaryAnalysisPass, source_mod: (Module | None), name: str
    ) -> (UniNode | None);

    def _signature_of_decl(
        self: BoundaryAnalysisPass, decl: (Ability | None)
    ) -> tuple[(str, list[str], list[str])];

    def _get_context(self: BoundaryAnalysisPass, nd: UniNode) -> InteropContext;
    def _extract_type_name(self: BoundaryAnalysisPass, expr: (UniNode | None)) -> str;
    def _in_native_module(self: BoundaryAnalysisPass) -> bool;
    def _native_source_module_of(
        self: BoundaryAnalysisPass, mod: (Module | None)
    ) -> (str | None);

    def _register_native_absorb(self: BoundaryAnalysisPass, nd: Import) -> None;
    def enter_import(self: BoundaryAnalysisPass, nd: Import) -> None;
    def _register_sv_import(
        self: BoundaryAnalysisPass,
        nd: Import,
        module_name: str,
        caller_ctx: InteropContext
    ) -> None;

    def _register_na_client_import(self: BoundaryAnalysisPass, nd: Import) -> None;
    def _register_client_bridged_import(
        self: BoundaryAnalysisPass, nd: Import
    ) -> None;

    def _collect_abilities(
        self: BoundaryAnalysisPass, nd: UniNode, out: dict[(str, Ability)]
    ) -> None;

    def _collect_pub_walkers(
        self: BoundaryAnalysisPass, nd: UniNode, out: dict[(str, Archetype)]
    ) -> None;

    def _extract_walker_has_fields(
        self: BoundaryAnalysisPass, walker_nd: (Archetype | None)
    ) -> tuple[list[str], list[str]];

    def _find_archetype(
        self: BoundaryAnalysisPass, nd: UniNode, target: str
    ) -> (Archetype | Enum | None);

    def enter_ability(self: BoundaryAnalysisPass, nd: Ability) -> None;
    def enter_func_call(self: BoundaryAnalysisPass, nd: FuncCall) -> None;
    def _extract_subscript_inner(
        self: BoundaryAnalysisPass, expr: (UniNode | None)
    ) -> str;

    def _extract_all_subscript_types(
        self: BoundaryAnalysisPass, expr: (UniNode | None)
    ) -> list[str];

    def _extract_all_type_names(
        self: BoundaryAnalysisPass, expr: (UniNode | None)
    ) -> list[str];

    def _collect_boundary_type(
        self: BoundaryAnalysisPass, type_name: str, source_mod: (Module | None)
    ) -> None;

    def _literal_default(
        self: BoundaryAnalysisPass, expr: (UniNode | None)
    ) -> tuple[(bool, any)];

    def after_pass(self: BoundaryAnalysisPass) -> None;
    def _record_access_levels(self: BoundaryAnalysisPass, manifest: any) -> None;
}
