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

walker MTIRGenPass {
    has ctx: CompileContext,
        module: Module,
        _class_info_cache: dict[int, ClassInfo] = {};

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
