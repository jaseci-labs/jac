import os;
import jaclang.jac0core.unitree as uni;
import from threading { Event }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics { DiagnosticInfo, DIAGNOSTICS }
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.helpers { pascal_to_snake }
import type from jaclang.jac0core.program { JacProgram }
import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.cfront.c_common {
    BinKind,
    C_BINOPS,
    coord_of,
    c_tok,
    classify_c_constant,
    parse_c_int,
    parse_c_float,
    c_char_text,
    c_char_ord,
    c_string_inner,
    cast_scalar_target,
    expr_reeval_safe,
    has_loop_continue,
    is_simple_ref,
    switch_is_safe,
    jac_prim_zero,
    CLIT_INT,
    CLIT_FLOAT,
    CLIT_CHAR,
    CLIT_STRING
}
import from jaclang.compiler.cfront.c_types {
    elem_typename,
    typename,
    jac_prim,
    JacPrim,
    C_PRIM_MAP
}
import from jaclang.compiler.cfront.c_idioms {
    malloc_array_match,
    malloc_struct_type,
    realloc_ptr_arg,
    flatten_mult,
    sizeof_type
}
import from jaclang.compiler.cfront.enum_prepass {
    EnumVerdicts,
    EnumShape,
    build_enum_map
}
import from jaclang.compiler.cfront.c_common { eval_enumerators, jac_id, c_field }

glob _CONVERT_OVERRIDE: dict[str, str] = {
         "FileAST": "proc_file_ast",
         "ID": "proc_id"
     },
     C_UNSUPPORTED: str = "__c_unsupported__",
     C_OP_TOK: dict[str, tuple[BinKind, str, str]] = {
         "+": (BinKind.ARITH, Tok.PLUS, "+"),
         "-": (BinKind.ARITH, Tok.MINUS, "-"),
         "*": (BinKind.ARITH, Tok.STAR_MUL, "*"),
         "/": (BinKind.ARITH, Tok.DIV, "/"),
         "%": (BinKind.ARITH, Tok.MOD, "%"),
         "&": (BinKind.ARITH, Tok.BW_AND, "&"),
         "|": (BinKind.ARITH, Tok.BW_OR, "|"),
         "^": (BinKind.ARITH, Tok.BW_XOR, "^"),
         "<<": (BinKind.ARITH, Tok.LSHIFT, "<<"),
         ">>": (BinKind.ARITH, Tok.RSHIFT, ">>"),
         "==": (BinKind.COMPARE, Tok.EE, "=="),
         "!=": (BinKind.COMPARE, Tok.NE, "!="),
         "<": (BinKind.COMPARE, Tok.LT, "<"),
         "<=": (BinKind.COMPARE, Tok.LTE, "<="),
         ">": (BinKind.COMPARE, Tok.GT, ">"),
         ">=": (BinKind.COMPARE, Tok.GTE, ">="),
         "&&": (BinKind.BOOL, Tok.KW_AND, "and"),
         "||": (BinKind.BOOL, Tok.KW_OR, "or")
     },
     C_UNARY_TOK: dict[str, tuple[str, str]] = {
         "-": (Tok.MINUS, "-"),
         "+": (Tok.PLUS, "+"),
         "~": (Tok.BW_NOT, "~"),
         "!": (Tok.NOT, "not")
     },
     C_AUG_TOK: dict[str, str] = {
         "+=": Tok.ADD_EQ,
         "-=": Tok.SUB_EQ,
         "*=": Tok.MUL_EQ,
         "/=": Tok.DIV_EQ,
         "%=": Tok.MOD_EQ,
         "&=": Tok.BW_AND_EQ,
         "|=": Tok.BW_OR_EQ,
         "^=": Tok.BW_XOR_EQ,
         "<<=": Tok.LSHIFT_EQ,
         ">>=": Tok.RSHIFT_EQ
     };

obj CastBuildPass(Transform[uni.CModuleAst, uni.Module]) {
    has ir_in: uni.CModuleAst,
        prog: JacProgram,
        cancel_token: Event | None = None,
        lenient_c: bool = False,
        orig_src: uni.Source by postinit,
        enum_verdicts: EnumVerdicts by postinit,
        _list_bound: set[str] by postinit,
        _enum_member_owner: dict[str, str] by postinit,
        _var_types: dict[str, object] by postinit,
        _func_depth: int by postinit;

    def postinit -> None;
    def _build_member_owner_map -> dict[str, str];
    def _collect_enum_nodes(nd: object, out: list) -> None;
    def transform(ir_in: uni.CModuleAst) -> uni.Module;
    def nu(nd: uni.UniNode) -> uni.UniNode;
    def convert(nd: object, *, stmt: bool = False) -> object;
    def conv_expr(nd: object) -> object;
    def emit_c_diag(
        c_node: object, num: int, anchor: uni.UniNode | None = None, **kw: object
    ) -> None;

    def c_diags -> list[tuple[str, str, int]];
    def _coord(c_node: object) -> tuple[int, int];
    def _name(c_node: object, value: str) -> uni.Name;
    def _ident(c_node: object, value: str) -> uni.Name;
    def _op_tok(c_node: object, tok: str, value: str) -> uni.Token;
    def _surrogate_expr(c_node: object) -> uni.FuncCall;
    def _surrogate_stmt(c_node: object) -> uni.UniNode;
    def _scope_bind(assign: uni.Assignment) -> uni.UniNode;
    def proc_file_ast(nd: object) -> uni.Module;
    def proc_compound(nd: object) -> list[uni.UniNode];
    def proc_func_def(nd: object) -> uni.Ability;
    def proc_decl(nd: object) -> object;
    def proc_return(nd: object) -> uni.ReturnStmt;
    def proc_binary_op(nd: object) -> object;
    def proc_id(nd: object) -> uni.UniNode;
    def proc_constant(nd: object) -> uni.Literal;
    def _lit(cls: type, tok: str, text: str, line: int, col: int) -> uni.Literal;
    def proc_func_call(nd: object) -> object;
    def _realloc_elide(nd: object) -> uni.Expr | None;
    def _malloc_array(nd: object) -> object | None;
    def _elem_default(c_node: object, tname: str) -> uni.Expr;
    def _range_compr(
        c_node: object, elem_default: uni.Expr, count: uni.Expr
    ) -> uni.ListCompr;

    def _product_expr(c_node: object, factors: list) -> object;
    def _pass_semi(c_node: object) -> uni.Semi;
    def _stmts_from(c_node: object) -> list[uni.UniNode];
    def _block(c_node: object) -> list[uni.UniNode];
    def proc_if(nd: object) -> object;
    def proc_while(nd: object) -> object;
    def _inc_dec_stmt(nd: object) -> uni.Assignment | None;
    def _conv_stmts(items: list) -> list[uni.UniNode];
    def _for_promotable(nd: object) -> bool;
    def _for_clause_stmts(clause_node: object) -> list[uni.UniNode];
    def proc_for(nd: object) -> object;
    def _bool_true(c_node: object) -> uni.Literal;
    def _is_surrogate(expr: object) -> bool;
    def proc_break(nd: object) -> uni.CtrlStmt;
    def proc_continue(nd: object) -> uni.CtrlStmt;
    def _break_stmt(c_node: object) -> uni.CtrlStmt;
    def proc_do_while(nd: object) -> object;
    def proc_switch(nd: object) -> object;
    def _switch_test(nd: object, cond_cnode: object, vals: list) -> uni.Expr;
    def _switch_branch_body(nd: object, stmts: list | None) -> list[uni.UniNode];
    def proc_empty_statement(nd: object) -> uni.Semi;
    def proc_ternary_op(nd: object) -> object;
    def _scalar_prim(type_node: object) -> JacPrim | None;
    def _record_scalar_type(name: str, type_node: object) -> None;
    def _expr_prim(c_node: object) -> JacPrim | None;
    def proc_unary_op(nd: object) -> object;
    def _pre_incdec_walrus(nd: object) -> uni.AtomUnit | None;
    def proc_assignment(nd: object) -> object;
    def proc_struct_ref(nd: object) -> object;
    def proc_array_ref(nd: object) -> object;
    def _struct_field(mem: object) -> uni.ArchHas | None;
    def _struct_archetype(snode: object, name: str, origin: object) -> uni.Archetype;
    def proc_struct(nd: object) -> uni.Archetype;
    def proc_typedef(nd: object) -> object;
    def proc_enum(nd: object) -> object;
    def _enum_var_decl(nd: object, en: object) -> list[uni.UniNode];
    def _enum_as_enum(nd: object, name_map: dict[str, int]) -> uni.Enum;
    def _enum_as_consts(nd: object, name_map: dict[str, int]) -> list[uni.GlobalVars];
    def _list_ann(c_node: object, elem_name: str) -> uni.AtomTrailer;
    def _elem_zero_lit(c_node: object, elem_name: str) -> uni.Literal;
    def _decl_array(nd: object) -> object;
    def proc_array_decl(nd: object) -> object;
    def proc_init_list(nd: object) -> object;
    def proc_named_initializer(nd: object) -> object;
    def _desig_name(d: object) -> str;
    def proc_expr_list(nd: object) -> object;
    def proc_cast(nd: object) -> object;
}
