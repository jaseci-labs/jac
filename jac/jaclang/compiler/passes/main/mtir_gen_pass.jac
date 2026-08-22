import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    Assignment,
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
    Module,
    MultiString,
    Name,
    NameAtom,
    String,
    Symbol,
    UniNode,
    UniScopeNode,
    VisitStmt
}
import from jaclang.jac0core.mtp {
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

import from jaclang.jac0core.passes.transform { Transform }

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
         'tuple',
         'i8',
         'u8',
         'i16',
         'u16',
         'i32',
         'u32',
         'i64',
         'u64',
         'f32',
         'f64'
     ];

obj MTIRGenPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None,
        _class_info_cache: dict[int, ClassInfo] = {};

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _is_primitive_type(type_expr: Expr | None) -> bool;
    def _parse_type_expr(
        type_expr: Expr | None, scope: UniScopeNode
    ) -> ClassInfo | str | tuple | None;

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

    def _traversal_candidate_archetypes(expr: Expr, scope: UniScopeNode) -> tuple;
    def _register_archetype_light(nd: Archetype) -> None;
}
