import os;
import from typing { cast }
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
    C_PRIM_MAP,
    is_char_ptr,
    walk_to_typedecl,
    TypeKind
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
import from jaclang.compiler.cfront.fidelity { fidelity_band, band_quarantines }
import from jaclang.jac0core.constant { VALUE_ARCH_DECORATOR }

obj CLiftSite {
    has code: str,
        msg: str,
        line: int,
        band: str,
        function: str | None = None,
        quarantined: bool = False;
}

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
        _var_types: dict[str, JacPrim] by postinit,
        _func_depth: int by postinit,
        _func_name: str | None by postinit,
        _func_contam: list[CLiftSite] by postinit,
        _sites: list[CLiftSite] by postinit,
        _quarantined: list[str] by postinit,
        _module_globals: set[str] by postinit,
        _func_global_writes: set[str] by postinit,
        _struct_fields: dict[str, list[tuple[str, object]]] by postinit;

    def postinit -> None;
    def _build_member_owner_map -> dict[str, str];
    def _collect_enum_nodes(nd: c_ast.Node, out: list) -> None;
    def transform(ir_in: uni.CModuleAst) -> uni.Module;
    def nu(nd: uni.UniNode) -> uni.UniNode;
    def convert(
        nd: c_ast.Node, *, stmt: bool = False
    ) -> uni.UniNode | list[uni.UniNode];

    def conv_expr(nd: c_ast.Node) -> uni.Expr;
    def emit_c_diag(
        c_node: c_ast.Node, num: int, anchor: uni.UniNode | None = None, **kw: object
    ) -> None;

    def c_diags -> list[tuple[str, str, int]];
    def c_sites -> list[CLiftSite];
    def quarantined_functions -> list[str];
    def _quarantine_raise(
        c_node: c_ast.Node, fname: str, sites: list[CLiftSite]
    ) -> uni.RaiseStmt;

    def _coord(c_node: c_ast.Node) -> tuple[int, int];
    def _name(c_node: c_ast.Node, value: str) -> uni.Name;
    def _ident(c_node: c_ast.Node, value: str) -> uni.Name;
    def _op_tok(c_node: c_ast.Node, tok: str, value: str) -> uni.Token;
    def _surrogate_expr(c_node: c_ast.Node) -> uni.FuncCall;
    def _surrogate_stmt(c_node: c_ast.Node) -> uni.UniNode;
    def _scope_bind(assign: uni.Assignment) -> uni.UniNode;
    def _collect_module_globals(ext: list) -> set[str];
    def _global_stmt(c_node: c_ast.Node, names: list[str]) -> uni.GlobalStmt;
    def proc_file_ast(nd: c_ast.Node) -> uni.Module;
    def proc_compound(nd: c_ast.Node) -> list[uni.CodeBlockStmt];
    def proc_func_def(nd: c_ast.Node) -> uni.Ability;
    def proc_decl(nd: c_ast.Node) -> object;
    def proc_return(nd: c_ast.Node) -> uni.ReturnStmt;
    def proc_binary_op(nd: c_ast.Node) -> object;
    def proc_id(nd: c_ast.Node) -> uni.UniNode;
    def proc_constant(nd: c_ast.Node) -> uni.Literal;
    def _lit(cls: type, tok: str, text: str, line: int, col: int) -> uni.Literal;
    def proc_func_call(nd: c_ast.Node) -> object;
    def _realloc_elide(nd: c_ast.Node) -> uni.Expr | None;
    def _malloc_array(nd: c_ast.Node) -> object | None;
    def _elem_default(c_node: c_ast.Node, tname: str) -> uni.Expr;
    def _range_compr(
        c_node: c_ast.Node, elem_default: uni.Expr, count: uni.Expr
    ) -> uni.ListCompr;

    def _product_expr(c_node: c_ast.Node, factors: list) -> object;
    def _pass_semi(c_node: c_ast.Node) -> uni.Semi;
    def _stmts_from(c_node: c_ast.Node) -> list[uni.UniNode];
    def _block(c_node: c_ast.Node) -> list[uni.CodeBlockStmt];
    def proc_if(nd: c_ast.Node) -> object;
    def proc_while(nd: c_ast.Node) -> object;
    def _inc_dec_stmt(nd: c_ast.Node) -> uni.Assignment | None;
    def _conv_stmts(items: list) -> list[uni.CodeBlockStmt];
    def _for_promotable(nd: c_ast.Node) -> bool;
    def _for_clause_stmts(clause_node: c_ast.Node) -> list[uni.CodeBlockStmt];
    def _splice_for_continues(
        stmts: list[uni.CodeBlockStmt], step_c: c_ast.Node
    ) -> list[uni.CodeBlockStmt];

    def proc_for(nd: c_ast.Node) -> object;
    def _bool_true(c_node: c_ast.Node) -> uni.Literal;
    def _is_surrogate(expr: c_ast.Node) -> bool;
    def proc_break(nd: c_ast.Node) -> uni.CtrlStmt;
    def proc_continue(nd: c_ast.Node) -> uni.CtrlStmt;
    def _break_stmt(c_node: c_ast.Node) -> uni.CtrlStmt;
    def proc_do_while(nd: c_ast.Node) -> object;
    def proc_switch(nd: c_ast.Node) -> object;
    def _switch_test(nd: c_ast.Node, cond_cnode: c_ast.Node, vals: list) -> uni.Expr;
    def _switch_branch_body(
        nd: c_ast.Node, stmts: list | None
    ) -> list[uni.CodeBlockStmt];

    def proc_empty_statement(nd: c_ast.Node) -> uni.Semi;
    def proc_ternary_op(nd: c_ast.Node) -> object;
    def _scalar_prim(type_node: c_ast.Node) -> JacPrim | None;
    def _record_scalar_type(name: str, type_node: c_ast.Node) -> None;
    def _expr_prim(c_node: c_ast.Node) -> JacPrim | None;
    def _is_str_cursor(c_node: c_ast.Node) -> bool;
    def _index_expr(
        c_node: c_ast.Node, base: uni.Expr, idx: uni.Expr
    ) -> uni.AtomTrailer;

    def _slice_from(
        c_node: c_ast.Node, base: uni.Expr, start: uni.Expr
    ) -> uni.AtomTrailer;

    def _ord_call(c_node: c_ast.Node, ch: uni.Expr) -> uni.FuncCall;
    def _str_char_at(
        c_node: c_ast.Node, base_c: c_ast.Node, idx_c: c_ast.Node | None
    ) -> object;

    def _str_deref(c_node: c_ast.Node, ptr_c: c_ast.Node) -> object;
    def _str_advance_assign(
        c_node: c_ast.Node, name: str, forward: bool
    ) -> uni.Assignment | None;

    def proc_unary_op(nd: c_ast.Node) -> object;
    def _pre_incdec_walrus(nd: c_ast.Node) -> uni.AtomUnit | None;
    def proc_assignment(nd: c_ast.Node) -> object;
    def proc_struct_ref(nd: c_ast.Node) -> object;
    def proc_array_ref(nd: c_ast.Node) -> object;
    def _struct_field(mem: c_ast.Node) -> uni.ArchHas | None;
    def _struct_archetype(
        snode: c_ast.Node, name: str, origin: c_ast.Node
    ) -> uni.Archetype;

    def proc_struct(nd: c_ast.Node) -> uni.Archetype;
    def proc_typedef(nd: c_ast.Node) -> object;
    def proc_enum(nd: c_ast.Node) -> uni.UniNode | list[uni.UniNode];
    def _enum_var_decl(nd: c_ast.Node, en: c_ast.Node) -> list[uni.UniNode];
    def _enum_as_enum(nd: c_ast.Node, name_map: dict[str, int]) -> uni.Enum;
    def _enum_as_consts(
        nd: c_ast.Node, name_map: dict[str, int]
    ) -> list[uni.GlobalVars];

    def _list_ann(c_node: c_ast.Node, elem_name: str) -> uni.AtomTrailer;
    def _elem_zero_lit(c_node: c_ast.Node, elem_name: str) -> uni.Literal;
    def _decl_array(nd: c_ast.Node) -> object;
    def proc_array_decl(nd: c_ast.Node) -> object;
    def proc_init_list(nd: c_ast.Node) -> object;
    def proc_named_initializer(nd: c_ast.Node) -> object;
    def _desig_name(d: c_ast.Node) -> str;
    def _kw_pair(c_node: c_ast.Node, key: str, value: uni.Expr) -> uni.KWPair;
    def _needs_typed_init(c_type: c_ast.Node) -> bool;
    def _init_value(c_init: c_ast.Node, c_type: c_ast.Node) -> uni.Expr | None;
    def _typed_init(c_init: c_ast.Node, c_type: c_ast.Node) -> uni.Expr | None;
    def _array_init_from_list(
        c_init: c_ast.Node, elem_type: c_ast.Node
    ) -> uni.ListVal | None;

    def _struct_init_from_list(
        c_init: c_ast.Node, type_name: str
    ) -> uni.FuncCall | None;

    def _field_index(type_name: str, field: str) -> int | None;
    def proc_expr_list(nd: c_ast.Node) -> object;
    def proc_cast(nd: c_ast.Node) -> object;
}
