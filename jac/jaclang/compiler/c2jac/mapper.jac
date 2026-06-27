"""pycparser C-AST → CPython ast mapper (Python-AST path).

Covers P1a (scalar expressions, control flow), P1b (structs), P1c (arrays).
Dispatch-miss fallback emits __c2jac_unsupported__ / __c2jac_unsupported_expr__
surrogates that are syntactically valid Jac, satisfying §8.2.

DIRECT_IR nodes (For, Enum, Enumerator, EnumeratorList) are replaced by
placeholder call expressions keyed on a slot_id; the driver splices in the real
uni nodes after PyastBuildPass runs.

This module is the node dispatcher + `ast`-node builder. The three cross-cutting
*analyses* it used to inline now live in focused sibling modules — each pure (no
`CMapper` state, no node-building), so they read and test on their own:
  - c_types.jac    — C type-name resolution (the type model)
  - c_idioms.jac   — malloc/realloc pointer-idiom structural recognizers (§7)
  - c_dataflow.jac — list-bound MUST-dataflow across control flow (§9.5)
The handlers call those to *decide*, then emit the Jac form and stamp the Tier
verdict here.

`CMapper` itself is declared here (state + the full method roster as signatures)
and its bodies live in the `mapper.impl/` annex, grouped by the kind of construct
each handler lowers — so the dispatcher no longer shares a file with every handler
it dispatches to:
  - core.impl.jac         — dispatch, coord/slot/stamp, surrogate & direct-IR
                            placeholders, Tier-verdict stamping (the machinery)
  - control_flow.impl.jac — if / while / do-while / switch / ternary / for and
                            the §9.5 list-bound joins across branches & back-edges
  - declarations.impl.jac — file/func/var/array decls, assignment, structs,
                            typedefs, enums, and the C-type annotation helpers
  - expressions.impl.jac  — binary/unary ops, ids, constants, refs, init lists,
                            casts, and the malloc/realloc idiom recognizers (§7)
"""

import ast as ast3;
import from pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }
import from jaclang.compiler.c2jac.c_common {
    C_BINOPS,
    C_AUGOPS,
    parse_c_int,
    parse_c_float,
    coord_of,
    classify_c_constant,
    c_char_text,
    c_string_inner,
    expr_reeval_safe,
    has_loop_continue,
    switch_is_safe,
    section_terminates,
    is_simple_ref,
    cast_scalar_target,
    CLIT_INT,
    CLIT_FLOAT,
    CLIT_CHAR,
    CLIT_STRING,
    UNSUPPORTED_STMT,
    UNSUPPORTED_EXPR
}
import from jaclang.compiler.c2jac.c_types {
    C_PRIM_MAP,
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
# The direct-IR placeholder protocol (emit here, splice in the driver) is owned by
# c2jac.directir — see that module for why the py-ast round-trip is safe and how
# leaks are made impossible. We only need the sentinel name to emit a placeholder.
import from jaclang.compiler.c2jac.directir { SLOT_SENTINEL }

obj CMapper {
    has tags: TagTable,
        slot_map: dict[int, object],  # slot_id -> c_node
        _next_slot: int,
        _lineno: int,
        _list_bound: set[str],  # names known to back a Jac list (§7.5 realloc-elide)
        _func_depth: int;  # >0 while building a function body (function-local scope)

    def init(tags: TagTable) {
        self.tags = tags;
        self.slot_map = {};
        self._next_slot = 0;
        self._lineno = 1;
        self._list_bound = set();
        self._func_depth = 0;
    }

    # ------------------------------------------------------------------ #
    # Core machinery        → mapper.impl/core.impl.jac
    # ------------------------------------------------------------------ #
    def _loc(c_node: object) -> tuple[int, int];
    def _stamp(py_node: object, c_node: object, *, text: str = "") -> object;
    def _stamp_manual(
        py_node: object, line: int, col: int, *, text: str = ""
    ) -> object;

    def _alloc_slot(c_node: object) -> int;
    def _surrogate_stmt(c_node: object) -> object;
    def _surrogate_expr(c_node: object) -> object;
    def _mark_tier_b(c_node: object, reason: str);
    def _mark_tier_a(c_node: object, idiom: Idiom, reason: str = "");
    def _mark_tier_b_idiom(c_node: object, idiom: Idiom, reason: str);
    def _directir_placeholder(c_node: object) -> object;
    def conv(c_node: object, *, stmt: bool = True) -> object;
    def _inc_dec_stmt(nd: object) -> object | None;
    def conv_stmt(c_node: object) -> object;
    def conv_expr(c_node: object) -> object;
    def _to_store(py_node: object) -> object;
    # ------------------------------------------------------------------ #
    # Control-flow handlers → mapper.impl/control_flow.impl.jac
    # ------------------------------------------------------------------ #
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
    # ------------------------------------------------------------------ #
    # Declarations & types  → mapper.impl/declarations.impl.jac
    # ------------------------------------------------------------------ #
    def c_FileAST(nd: object) -> object;
    def c_Compound(nd: object) -> list[object];
    def c_FuncDef(nd: object) -> object;
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
    # ------------------------------------------------------------------ #
    # Expression handlers   → mapper.impl/expressions.impl.jac
    # ------------------------------------------------------------------ #
    def c_BinaryOp(nd: object) -> object;
    def c_UnaryOp(nd: object) -> object;
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
