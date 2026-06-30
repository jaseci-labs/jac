import ast as ast3;
import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.c_common {
    C_BINOPS,
    C_AUGOPS,
    parse_c_int,
    parse_c_float,
    coord_of,
    classify_c_constant,
    c_char_text,
    c_char_ord,
    c_string_inner,
    expr_reeval_safe,
    has_loop_continue,
    switch_is_safe,
    section_terminates,
    is_simple_ref,
    is_null_ptr_constant,
    cast_scalar_target,
    CLIT_INT,
    CLIT_FLOAT,
    CLIT_CHAR,
    CLIT_STRING,
    UNSUPPORTED_STMT,
    UNSUPPORTED_EXPR,
    jac_prim_zero
}
import from jaclang.compiler.c2jac.c_types {
    C_PRIM_MAP,
    elem_typename,
    jac_prim,
    typename,
    user_type_name
}
import from jaclang.compiler.c2jac.c_idioms {
    flatten_mult,
    sizeof_type,
    malloc_array_match,
    malloc_struct_type,
    realloc_of_list_bound
}
import from jaclang.compiler.c2jac.c_dataflow { lb_merge, collect_lb_kills }

import from jaclang.compiler.c2jac.directir { SLOT_SENTINEL }

obj CMapper {
    has tags: TagTable,
        slot_map: dict[int, object],
        _next_slot: int,
        _lineno: int,
        _list_bound: set[str],
        _var_types: dict[str, str],
        _func_depth: int,
        _ret_is_ptr: bool;

    def init(tags: TagTable) {
        self.tags = tags;
        self.slot_map = {};
        self._next_slot = 0;
        self._lineno = 1;
        self._list_bound = set();
        self._var_types = {};
        self._func_depth = 0;
        self._ret_is_ptr = False;
    }

    def _loc(c_node: object) -> tuple[int, int];
    def _stamp(py_node: object, c_node: object, *, text: str = "") -> object;
    def _stamp_manual(
        py_node: object, line: int, col: int, *, text: str = ""
    ) -> object;

    def _alloc_slot(c_node: object) -> int;
    def _tag(c_node: object, tier: Tier, idiom: Idiom, reason: str);
    def _surrogate(c_node: object, name: str) -> object;
    def _surrogate_stmt(c_node: object) -> object;
    def _surrogate_expr(c_node: object) -> object;
    def _mark_tier_b(c_node: object, reason: str);
    def _mark_tier_a(c_node: object, idiom: Idiom, reason: str = "");
    def _mark_tier_b_idiom(c_node: object, idiom: Idiom, reason: str);
    def _earn_tier_a(c_node: object);
    def _directir_placeholder(c_node: object) -> object;
    def conv(c_node: object, *, stmt: bool = True) -> object;
    def _inc_dec_stmt(nd: object) -> object | None;
    def conv_stmt(c_node: object) -> object;
    def conv_expr(c_node: object) -> object;
    def _to_store(py_node: object) -> object;
    def c_If(nd: object) -> object;
    def c_While(nd: object) -> object;
    def c_DoWhile(nd: object) -> object;
    def c_Switch(nd: object) -> object;
    def _switch_test(cond_cnode: object, vals: list, line: int, col: int) -> object;
    def _switch_branch_body(stmts: list | None) -> list[object];
    def c_TernaryOp(nd: object) -> object;
    def _stmts_from(nd: object) -> list[object];
    def c_Return(nd: object) -> object;
    def c_Break(nd: object) -> object;
    def c_Continue(nd: object) -> object;
    def c_EmptyStatement(nd: object) -> object;
    def c_For(nd: object) -> object;
    def _for_promotable(nd: object) -> bool;
    def _for_init_stmts(init_node: object) -> list[object];
    def _for_step_stmts(step_node: object) -> list[object];
    def _is_surrogate_expr(n: object) -> bool;
    def c_FileAST(nd: object) -> object;
    def c_Compound(nd: object) -> list[object];
    def c_FuncDef(nd: object) -> object;
    def _body_inspects_varargs(nd: object) -> bool;
    def c_Decl(nd: object) -> object;
    def _all_quals(nd: object) -> set;
    def _decl_struct_var(nd: object) -> object;
    def _zero_default(inner: object) -> object;
    def c_Assignment(nd: object) -> object;
    def c_Struct(nd: object) -> object;
    def _struct_field(mem: object) -> object | None;
    def c_Typedef(nd: object) -> object;
    def _decl_array(nd: object) -> object;
    def c_ArrayDecl(nd: object) -> object;
    def c_Enum(nd: object) -> object;
    def c_Enumerator(nd: object) -> object;
    def c_EnumeratorList(nd: object) -> object;
    def _type_ann(decl: object) -> object;
    def _type_ann_from_type(t: object) -> object;
    def _ret_ann(funcdecl: object) -> object;
    def _list_ann_of(tname: str) -> object;
    def c_BinaryOp(nd: object) -> object;
    def _record_scalar_type(name: str, type_node: object);
    def _scalar_prim(type_node: object) -> str | None;
    def _expr_prim(c_node: object) -> str | None;
    def _binop_operand(operand: object, sibling: object) -> object;
    def c_UnaryOp(nd: object) -> object;
    def _pre_incdec_walrus(nd: object) -> object | None;
    def c_ID(nd: object) -> object;
    def c_Constant(nd: object) -> object;
    def c_StructRef(nd: object) -> object;
    def c_ArrayRef(nd: object) -> object;
    def c_InitList(nd: object) -> object;
    def c_NamedInitializer(nd: object) -> object;
    def _desig_name(d: object) -> str;
    def c_ExprList(nd: object) -> object;
    def c_Cast(nd: object) -> object;
    def c_FuncCall(nd: object) -> object;
    def _realloc_elide(nd: object) -> object | None;
    def _elem_default(tname: str) -> object;
    def _product_expr(factors: list) -> object;
    def _malloc_array(nd: object) -> object | None;
}
