import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    Bool,
    BuiltinType,
    EdgeOpRef,
    EdgeRefTrailer,
    Enum,
    EventSignature,
    Expr,
    FilterCompr,
    Float,
    FuncCall,
    FuncSignature,
    Int,
    KWPair,
    ListVal,
    Module,
    MultiString,
    Name,
    NameAtom,
    String,
    Symbol,
    Token,
    TupleVal,
    UniNode,
    UniScopeNode,
    VisitStmt
}
import from jaclang.compiler.driver.mtp {
    ClassInfo,
    EnumInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
    mk_tuple,
    type_to_str
}

import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

glob PRIMITIVE_TYPES: list[str] = [
         'int',
         'float',
         'str',
         'bool',
         'None',
         'bytes',
         'list',
         'dict',
         'set',
         'tuple'
     ]
         + JAC_TYPE_REGISTRY.sized_scalar_names();

walker MTIRGenPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None,
        _class_info_cache: dict[int, ClassInfo] = {};

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _is_primitive_type(type_expr: Expr | None) -> bool;
    def _doc_text(doc: String | None) -> str | None;
    def _parse_type_expr(
        type_expr: Expr | None, scope: UniScopeNode
    ) -> ClassInfo | EnumInfo | str | tuple[object, ...] | None;

    def _extract_type_symbol(
        type_expr: Expr | None, scope: UniScopeNode
    ) -> Symbol | None;

    def _extract_enum_info(symbol: Symbol) -> EnumInfo;
    def _extract_class_info(symbol: Symbol) -> ClassInfo | None;
    def _extract_function_info(nd: Ability) -> FunctionInfo;
    def _extract_method_info(nd: Ability, by_call: bool = False) -> MethodInfo;
    def _get_scope_str(nd: UniScopeNode) -> str;
    def _extract_tools_from_expr(
        expr: Expr, scope: UniScopeNode
    ) -> list[FunctionInfo];

    def _process_ability(nd: Ability) -> None;
    def _collect_routing_archetypes(ir_in: Module) -> list[Archetype];
    def _archetype_from_event(ab: Ability | None) -> Archetype | None;
    def _archetype_of_type_expr(
        type_expr: Expr, scope: UniScopeNode
    ) -> Archetype | None;

    def _traversal_candidate_archetypes(
        expr: Expr, scope: UniScopeNode
    ) -> tuple[list[Archetype], bool];

    def _register_archetype_light(nd: Archetype) -> None;
}
