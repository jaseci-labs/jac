import from jaclang.runtime.object_model { field }
import from jaclang.compiler.frontend.unitree {
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
    ability_of_symbol,
    resolved_decl_of
}
import from jaclang.compiler.frontend.constant {
    CodeContext,
    SymbolType,
    Tokens as Tok
}
import from jaclang.compiler.frontend.codeinfo {
    BoundaryTypeInfo,
    InteropBinding,
    InteropContext
}
import from jaclang.compiler.passes.uni_pass { UniPass }
import type from jaclang.compiler.driver.program { JacProgram }

walker BoundaryAnalysisPass(UniPass) {
    has prog: JacProgram | None = None;
    static has HOST_PASS: bool = True;
    has _func_defs: dict[(str, tuple[(InteropContext, Ability)])] = field(
        default_factory=`dict
    ),
        _imported_native_funcs: dict[(str, tuple[(str, InteropContext)])] = field(
            default_factory=`dict
        ),
        _imported_native_modules: dict[(str, tuple[(str, InteropContext)])] = field(
            default_factory=`dict
        );

    def before_pass -> None;
    def _resolved_native_decl(name_node: (UniNode | None)) -> (Ability | None);
    def _signature_of_decl(
        decl: (Ability | None)
    ) -> tuple[(str, list[str], list[str])];

    def _get_context(nd: UniNode) -> InteropContext;
    def _extract_type_name(expr: (UniNode | None)) -> str;
    def _in_native_module -> bool;
    def _native_source_module_of(mod: (Module | None)) -> (str | None);
    def _register_native_absorb(nd: Import) -> None;
    can enter_import with Import entry;
    def _register_sv_import(
        nd: Import, module_name: str, caller_ctx: InteropContext
    ) -> None;

    def _register_na_client_import(nd: Import) -> None;
    def _register_client_bridged_import(nd: Import) -> None;
    def _provider_module_of(nd: Import) -> (Module | None);
    def _record_app_edge(nd: Import) -> None;
    def _bridge_targets(mod: Module) -> list[tuple[(str, str)]];
    def _check_app_cycle(nd: Import, consumer_app: str, provider_app: str) -> None;
    def _find_ability(mod: Module, target: str) -> (Ability | None);
    def _parsed_provider_of(nd: Import) -> (Module | None);
    def _reject_owned_type_import(nd: Import, item: ModuleItem, kind: str) -> None;
    def _check_provider_pub(nd: Import, item: ModuleItem) -> None;
    def _extract_walker_has_fields(
        walker_nd: (Archetype | None)
    ) -> tuple[list[str], list[str]];

    def _find_archetype(nd: UniNode, target: str) -> (Archetype | Enum | None);
    def _parse_imported_archetype(
        type_name: str, search_mods: list[Module]
    ) -> (Archetype | Enum | None);

    can enter_atom_trailer with AtomTrailer entry;
    can enter_ability with Ability entry;
    can enter_func_call with FuncCall entry;
    def _extract_subscript_inner(expr: (UniNode | None)) -> str;
    def _extract_all_subscript_types(expr: (UniNode | None)) -> list[str];
    def _extract_all_type_names(expr: (UniNode | None)) -> list[str];
    def _collect_boundary_type(type_name: str, source_mod: (Module | None)) -> None;
    def _literal_default(expr: (UniNode | None)) -> tuple[(bool, any)];
    def after_pass -> None;
    def _record_access_levels(manifest: any) -> None;
}

glob _type_parse_memo: dict[str, tuple[float, Module | None]] = {};

def _parse_module_for_types(file_path: str) -> (Module | None);
