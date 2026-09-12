# Compiler codegen for the P4 back track (PLAN.md P0.10).
#
# Walks a hand-built (later: parser-produced) ast_nodes.jac tree and emits IR
# into a unverified_cfg. Dispatch is locked to na-legal ordered isinstance
# if-chains (PLAN.md dispatch decision). Covers the expression slice only:
# Constant, Name, BinOp, UnaryOp, Call, plus the eval/module wrapper.
#
# Location assignment matches CPython 3.14 exactly (verified per-instruction via
# code.co_positions()): RESUME -> (0, firstlineno, 0, 0); RETURN_VALUE -> the
# top-level expression's span; PUSH_NULL -> the callable's span; every other
# instruction -> its owning AST node's span.
#
# Product module: imports compiler_ir + opcode_meta + ast_nodes only. No host
# tokenize/ast/compile/marshal.

import from jaclang.runtime.python.objects {
    PyObj,
    PyInt,
    PyStr,
    py_none,
    PyNoneType,
    PySlice,
    PyCode,
    PyTuple
}
# Statement-dispatch handler registry (leaf module; see compiler_dispatch.jac).
import from jaclang.compiler.backends.py.jacpython.compiler_dispatch { stmt_handlers }
import from jaclang.runtime.python.opcode_meta {
    is_scope_exit_opcode,
    is_unconditional_jump_opcode,
    OP_RESUME,
    OP_RETURN_GENERATOR,
    OP_RETURN_VALUE,
    OP_YIELD_VALUE,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_END_ASYNC_FOR,
    OP_SEND,
    OP_END_SEND,
    OP_CLEANUP_THROW,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_CALL_INTRINSIC_1,
    OP_LOAD_CONST,
    OP_LOAD_SMALL_INT,
    OP_LOAD_NAME,
    OP_LOAD_GLOBAL,
    OP_LOAD_BUILD_CLASS,
    OP_MAKE_FUNCTION,
    OP_MAKE_CELL,
    OP_COPY_FREE_VARS,
    OP_LOAD_DEREF,
    OP_STORE_DEREF,
    OP_BUILD_TUPLE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_BINARY_OP,
    CO_OPTIMIZED,
    CO_NEWLOCALS,
    CO_NESTED,
    CO_GENERATOR,
    CO_COROUTINE,
    CO_ASYNC_GENERATOR,
    CO_VARARGS,
    CO_VARKEYWORDS,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNARY_NOT,
    OP_PUSH_NULL,
    OP_CALL,
    OP_CALL_KW,
    OP_LOAD_LOCALS,
    OP_COMPARE_OP,
    OP_IS_OP,
    OP_CONTAINS_OP,
    OP_POP_TOP,
    OP_IMPORT_NAME,
    OP_IMPORT_FROM,
    OP_STORE_NAME,
    OP_STORE_GLOBAL,
    OP_STORE_ATTR,
    OP_STORE_SUBSCR,
    OP_STORE_SLICE,
    OP_BINARY_SLICE,
    OP_BUILD_SLICE,
    OP_LOAD_ATTR,
    OP_DELETE_NAME,
    OP_DELETE_GLOBAL,
    OP_DELETE_ATTR,
    OP_DELETE_SUBSCR,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_NONE,
    OP_JUMP_FORWARD,
    OP_JUMP_BACKWARD,
    OP_COPY,
    OP_SWAP,
    OP_GET_LEN,
    OP_MATCH_SEQUENCE,
    OP_MATCH_MAPPING,
    OP_MATCH_KEYS,
    OP_MATCH_CLASS,
    OP_DICT_UPDATE,
    OP_TO_BOOL,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_GET_ITER,
    OP_FOR_ITER,
    OP_END_FOR,
    OP_POP_ITER,
    OP_BUILD_LIST,
    OP_LIST_APPEND,
    OP_LIST_EXTEND,
    OP_BUILD_SET,
    OP_SET_ADD,
    OP_SET_UPDATE,
    OP_BUILD_MAP,
    OP_MAP_ADD,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_AND_CLEAR,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_DELETE_DEREF,
    OP_STORE_FAST_STORE_FAST,
    OP_STORE_FAST_LOAD_FAST,
    OP_UNPACK_SEQUENCE,
    OP_UNPACK_EX,
    OP_PUSH_EXC_INFO,
    OP_POP_EXCEPT,
    OP_CHECK_EXC_MATCH,
    OP_RERAISE,
    OP_RAISE_VARARGS,
    OP_LOAD_SPECIAL,
    OP_WITH_EXCEPT_START,
    OP_LOAD_COMMON_CONSTANT,
    NB_ADD,
    NB_SUBTRACT,
    NB_MULTIPLY,
    NB_TRUE_DIVIDE,
    NB_FLOOR_DIVIDE,
    NB_REMAINDER,
    NB_POWER,
    NB_LSHIFT,
    NB_RSHIFT,
    NB_OR,
    NB_XOR,
    NB_AND,
    NB_MATRIX_MULTIPLY,
    NB_SUBSCR,
    NB_INPLACE_ADD,
    NB_INPLACE_SUBTRACT,
    NB_INPLACE_MULTIPLY,
    NB_INPLACE_TRUE_DIVIDE,
    NB_INPLACE_FLOOR_DIVIDE,
    NB_INPLACE_REMAINDER,
    NB_INPLACE_POWER,
    NB_INPLACE_LSHIFT,
    NB_INPLACE_RSHIFT,
    NB_INPLACE_OR,
    NB_INPLACE_XOR,
    NB_INPLACE_AND,
    NB_INPLACE_MATRIX_MULTIPLY,
    CMP_LT,
    CMP_LE,
    CMP_EQ,
    CMP_NE,
    CMP_GT,
    CMP_GE,
    compare_oparg,
    compare_filter_oparg,
}
import from jaclang.compiler.frontend.python.ast_nodes {
    ast_node,
    expr,
    stmt,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    Assign,
    Expr,
    Pass,
    Return,
    AugAssign,
    AnnAssign,
    Delete,
    Attribute,
    Subscript,
    Slice,
    Load,
    Store,
    Lt,
    Gt,
    Eq,
    NotEq,
    LtE,
    GtE,
    Is,
    IsNot,
    In,
    NotIn,
    Add,
    Sub,
    Mult,
    Div,
    Mod,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    FloorDiv,
    MatMult,
    USub,
    UAdd,
    Invert,
    Not,
    BoolOp,
    And,
    Or,
    NamedExpr,
    Lambda,
    IfExp,
    Dict,
    Set,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    comprehension,
    Await,
    Yield,
    YieldFrom,
    FormattedValue,
    JoinedStr,
    Interpolation,
    TemplateStr,
    Starred,
    List,
    Tuple,
    FunctionDef,
    AsyncFunctionDef,
    keyword,
    arguments,
    ClassDef,
    TypeAlias,
    For,
    AsyncFor,
    While,
    If,
    With,
    AsyncWith,
    Match,
    match_case,
    pattern,
    MatchValue,
    MatchSingleton,
    MatchAs,
    MatchOr,
    MatchSequence,
    MatchMapping,
    MatchClass,
    MatchStar,
    Raise,
    Try,
    TryStar,
    ExceptHandler,
    Assert,
    Import,
    ImportFrom,
    alias,
    Global,
    Nonlocal,
    Break,
    Continue,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    cloc,
    unverified_cfg,
    basicblock,
    cinstr,
    loc,
    no_loc,
    mk_instr,
    mk_jump,
    cfg_builder,
    stmt_cont,
    new_cfg_builder,
    loop_frame,
    break_site,
    control_unwind,
    except_region,
    comp_handler,
}
import from jaclang.compiler.frontend.python.compiler_symtable {
    sym_block,
    sym_dict_get,
    sym_flag_set,
    sym_scope_of,
    sym_sorted_names,
    mangle_name,
    DEF_COMP_ITER,
    SCOPE_GLOBAL_EXPLICIT,
    SCOPE_GLOBAL_IMPLICIT,
    SCOPE_LOCAL,
    SCOPE_CELL,
    SCOPE_FREE,
    sym_block_tuple_names,
}
import from jaclang.compiler.frontend.python.compiler_diagnostics {
    lowering_diagnostic
}
import from jaclang.compiler.backends.py.jacpython.flowgraph {
    verify_cfg,
    optimize_swap_range
}
import from jaclang.compiler.backends.py.jacpython.assembler { assemble }
import from jaclang.compiler.backends.py.jacpython.compiler_context {
    current_compile_flags
}
import from jaclang.compiler.backends.py.jacpython.compiler_emit {
    emit_suspendable_prologue,
    emit_generator_except_handler,
    flush_pending_await_footers,
    cellvars_from_sym,
    codegen_busy,
    codegen_fail,
    codegen_mangle,
    comp_append_handler,
    comp_emit_bind_target,
    comp_emit_cleanup,
    comp_emit_filters,
    comp_emit_setup,
    comp_emit_single_elt,
    comp_finish_loop,
    comp_lead_loopvar_slot,
    comp_name_fast_index,
    comp_target_slots,
    compile_lambda_cfg,
    emit_anext_send_loop_footer,
    emit_anext_send_loop_header,
    emit_await_send_except_regions,
    emit_await_send_loop_footer,
    emit_await_send_loop_header,
    emit_return_unwind,
    emit_control_unwind,
    finish_control_unwind,
    emit_branch_if_test_false,
    emit_branch_if_test_true,
    emit_call_instruction,
    emit_call_keyword_values,
    emit_cmp_link,
    emit_folded_int,
    emit_function_defaults,
    emit_function_kwdefaults,
    emit_function_prologue,
    emit_make_function_with_closure,
    emit_name_load,
    emit_send_delegation_loop,
    emit_slice_bound,
    emit_slice_load,
    emit_starred_list_build,
    fast_local_index,
    fast_varnames_from_sym,
    freevars_from_sym,
    is_none_identity_test,
    localsplus_index,
    localsplus_index_u,
    name_load_opcode,
    register_int_literal_const,
    sym_function_child_at,
    try_emit_fast_local_pair_load,
    unit_fail,
    varname_index,
    visit_boolop,
    visit_comp_dict_kv,
    visit_comp_elt,
    visit_compare,
    visit_dict_comp,
    visit_expr,
    visit_lambda,
    visit_list_comp,
    visit_set_comp,
    visit_subscript_index,
    visit_test_expr,
}
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    body_docstring,
    args_have_kw_defaults,
    function_argcounts,
    function_code_flags,
    ast_node_name,
    nloc,
    function_def_loc,
    async_function_def_loc,
    binop_id,
    inplace_binop_id,
    expr_loc,
    fold_slice_const,
    unary_opcode,
    ast_cmp_kind,
    cmpop_oparg,
    cmpop_filter_oparg,
    try_fold_binop,
    call_func_loc,
    call_effective_args,
    call_effective_keywords,
    top_loc,
    stmt_loc,
    seq_target_elts,
    is_seq_literal,
    display_has_starred,
    display_all_constant,
    display_const_items,
    starred_target_index,
    exec_tail_emits_code,
    comp_name_bound,
    comp_bound_names_from_target,
    comp_leftmost_leaf,
    comp_dict_map_loc,
    try_handler_span,
    body_is_try_finally_only,
    body_is_try_except_only,
    match_pattern_loc,
    match_pattern_unwrap_or,
    match_pattern_wildcard,
    loop_body_has_break,
    import_bind_name,
    class_effective_bases,
    class_effective_keywords
}
import from jaclang.compiler.backends.py.jacpython.compiler_annotations {
    ann_scope_plan,
    collect_ann_plan,
    emit_module_annotation_setup,
    finish_module_annotations,
    visit_ann_assign,
}


def emit_name_store(g: cfg_builder, name: str, tloc: cloc) {
    name = codegen_mangle(g, name);
    # Cell/free scope FIRST (see emit_name_load in compiler_emit): a
    # STORE_FAST into a cellvar's converted localsplus slot would replace the
    # cell object itself. CPython emits STORE_DEREF for CO_FAST_CELL params --
    # namedtuple rebinds field_names/typename and broke with "free variable is
    # not set" without this.
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            g.emit_op(OP_STORE_DEREF, idx, tloc);
            return;
        }
    }
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_STORE_FAST, fi, tloc);
        return;
    }
    if g.sym_top is not None {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_GLOBAL_EXPLICIT
            or (scope == SCOPE_GLOBAL_IMPLICIT and g.sym_top.block_type != "module") {
            idx = g.u.add_name(name);
            g.emit_op(OP_STORE_GLOBAL, idx, tloc);
            return;
        }
    }
    idx = g.u.add_name(name);
    g.emit_op(OP_STORE_NAME, idx, tloc);
}

def emit_name_delete(g: cfg_builder, name: str, tloc: cloc) {
    name = codegen_mangle(g, name);
    # Cell/free scope FIRST (see emit_name_load in compiler_emit): CPython
    # emits DELETE_DEREF for cell/free names, never DELETE_FAST.
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            g.emit_op(OP_DELETE_DEREF, idx, tloc);
            return;
        }
    }
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_DELETE_FAST, fi, tloc);
        return;
    }
    if g.sym_top is not None {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_GLOBAL_EXPLICIT
            or (scope == SCOPE_GLOBAL_IMPLICIT and g.sym_top.block_type != "module") {
            idx = g.u.add_name(name);
            g.emit_op(OP_DELETE_GLOBAL, idx, tloc);
            return;
        }
    }
    idx = g.u.add_name(name);
    g.emit_op(OP_DELETE_NAME, idx, tloc);
}


# Non-constant slice STORE (value already on the stack, container just pushed).
# 2-element: STORE_SLICE (fused). 3-element: BUILD_SLICE 3 + STORE_SUBSCR.
def emit_slice_store(g: cfg_builder, sl: Slice, lc: cloc) {
    if sl.step is not None {
        emit_slice_bound(g, sl.lower, lc);
        emit_slice_bound(g, sl.upper, lc);
        visit_expr(g, sl.step);
        g.emit_op(OP_BUILD_SLICE, 3, lc);
        g.emit_op(OP_STORE_SUBSCR, 0, lc);
        return;
    }
    emit_slice_bound(g, sl.lower, lc);
    emit_slice_bound(g, sl.upper, lc);
    g.emit_op(OP_STORE_SLICE, 0, lc);
}

# Non-constant slice DELETE (container just pushed). CPython has no fused
# delete-slice: both 2- and 3-element forms use BUILD_SLICE (2 or 3) + DELETE_SUBSCR.
def emit_slice_delete(g: cfg_builder, sl: Slice, lc: cloc) {
    emit_slice_bound(g, sl.lower, lc);
    emit_slice_bound(g, sl.upper, lc);
    n = 2;
    if sl.step is not None {
        visit_expr(g, sl.step);
        n = 3;
    }
    g.emit_op(OP_BUILD_SLICE, n, lc);
    g.emit_op(OP_DELETE_SUBSCR, 0, lc);
}


def emit_compare_cleanup(g: cfg_builder, cleanup: basicblock, lc: cloc) {
    g.use(cleanup);
    g.emit_op(OP_SWAP, 2, lc);
    g.emit_op(OP_POP_TOP, 0, lc);
}


# Build a unverified_cfg for an eval-mode expression. Emits RESUME (module/eval
# scope: lineno 0), the expression, then RETURN_VALUE carrying the expression's
# span. addNone is false for eval (no trailing None push).
def compile_eval(
    e: expr,
    filename: str,
    name: str,
    firstlineno: int,
    sym_top: sym_block | None = None
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name=name, qualname=name, firstlineno=firstlineno
    );
    if sym_top is not None {
        u.varnames = fast_varnames_from_sym(sym_top);
        u.cellvars.extend(cellvars_from_sym(sym_top));
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_top);
    protect_start = emit_source_resume(g, sym_top, firstlineno);
    cleanup = visit_expr(g, e, false_shortcircuit_returns=True);
    if codegen_busy(g) {
        u.flush_late_consts();
        return u;
    }
    # CPython attributes the eval epilogue RETURN_VALUE to the location of the
    # LAST EMITTED instruction, not the root expression span. The two coincide
    # for most roots (the final op carries the root span) but diverge for
    # f-strings: FORMAT_SIMPLE / FORMAT_WITH_SPEC / BUILD_STRING carry inner
    # FormattedValue / JoinedStr spans.
    ins_list = g.cur.instrs;
    if len(ins_list) > 0 {
        eloc = (ins_list[len(ins_list) - 1] as cinstr).loc;
    } else {
        eloc = top_loc(e);
    }
    g.emit_op(OP_RETURN_VALUE, 0, eloc);
    if cleanup is not None {
        if isinstance(e, Call) {
            ca = e as Call;
            cloc_call = nloc(
                ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset
            );
            emit_compare_cleanup(g, cleanup, cloc_call);
            if len(call_effective_keywords(ca)) > 0 {
                emit_call_keyword_values(g, ca, cloc_call);
            }
            emit_call_instruction(g, ca, cloc_call);
            g.emit_op(OP_RETURN_VALUE, 0, eloc);
        } else {
            g.use(cleanup);
            g.emit_op(OP_RETURN_VALUE, 0, eloc);
        }
    }
    finish_source_scope(g, protect_start);
    u.flush_late_consts();
    return u;
}

# ---------------- exec mode (statements, PLAN.md P0.12 band 2) ----------------
#
# visit_stmt lowers the straight-line statement set (Assign / Expr / Pass) into
# the current block. Returns the source location carried by the last instruction
# it emitted -- CPython's implicit module return (LOAD_CONST None; RETURN_VALUE)
# is generated with NO_LOCATION and inherits the preceding instruction's
# location, so compile_exec uses this return value for the epilogue. A statement
# that emits no instructions (Pass) returns its own location so the epilogue
# still lands on the statement's span (matches CPython's location fixup).

# Store `value` into a target. CPython elides the sequence round-trip when both
# sides are same-arity sequence literals with no starred target: evaluate the
# RHS elements in order, reorder (SWAP for n<=3, BUILD_TUPLE+UNPACK_SEQUENCE for
# n>=4), then store each target left-to-right.
def visit_store_target(g: cfg_builder, t: expr, value: expr) -> stmt_cont {
    if is_seq_literal(t) and is_seq_literal(value) {
        telts = seq_target_elts(t);
        velts = seq_target_elts(value);
        if len(telts) == len(velts)
            and starred_target_index(telts) < 0
            and starred_target_index(velts) < 0 {
            return visit_store_seq_literal(
                g, telts, velts, expr_loc(t), expr_loc(value)
            );
        }
    }
    visit_expr(g, value);
    return visit_store_target_tos(g, t);
}

# Store value already on the stack into an assignment target (name / attribute /
# subscript). CPython stack layout before STORE_ATTR / STORE_SUBSCR: value below
# owner (and index for subscript), with owner/index on TOS.
def visit_store_target_tos(g: cfg_builder, t: expr) -> stmt_cont {
    if codegen_busy(g) {
        return stmt_cont(loc=expr_loc(t));
    }
    if isinstance(t, Name) {
        n = t as Name;
        tloc = expr_loc(n);
        emit_name_store(g, n.id, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(g, a.value);
        idx = g.u.add_name(codegen_mangle(g, a.attr));
        tloc = expr_loc(a);
        g.emit_op(OP_STORE_ATTR, idx, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        sloc = expr_loc(s);
        visit_expr(g, s.value);
        if isinstance(s.slice, Slice) {
            sl = s.slice as Slice;
            folded = fold_slice_const(sl);
            if folded is not None {
                idx = g.u.add_const(folded);
                g.emit_op(OP_LOAD_CONST, idx, sloc);
                g.emit_op(OP_STORE_SUBSCR, 0, sloc);
                return stmt_cont(loc=sloc);
            }
            emit_slice_store(g, sl, sloc);
            return stmt_cont(loc=sloc);
        }
        visit_subscript_index(g, s.slice, sloc);
        g.emit_op(OP_STORE_SUBSCR, 0, sloc);
        return stmt_cont(loc=sloc);
    }
    if isinstance(t, Tuple) or isinstance(t, List) {
        last_loc = emit_unpack_stores(g, seq_target_elts(t), expr_loc(t));
        return stmt_cont(loc=last_loc);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported assignment target: " + ast_node_name(t as ast_node)
    );
    return stmt_cont(loc=expr_loc(t));
}


# With the sequence value on TOS, emit UNPACK_SEQUENCE (no star) or UNPACK_EX
# (starred), then store each element target left-to-right. Nested Tuple/List
# targets recurse; a Starred target stores the captured list into its .value.
def emit_unpack_stores(g: cfg_builder, elts: list[expr], tloc: cloc) -> cloc {
    star = starred_target_index(elts);
    n = len(elts);
    if star < 0 {
        g.emit_op(OP_UNPACK_SEQUENCE, n, tloc);
    } else {
        before = star;
        after = n - star - 1;
        g.emit_op(OP_UNPACK_EX, before + after * 256, tloc);
    }
    last_loc = tloc;
    i = 0;
    while i < n {
        el = elts[i];
        if isinstance(el, Starred) {
            se = visit_store_target_tos(g, (el as Starred).value);
        } else {
            se = visit_store_target_tos(g, el);
        }
        last_loc = se.loc;
        i = i + 1;
    }
    return last_loc;
}


def visit_store_seq_literal(
    g: cfg_builder, telts: list[expr], velts: list[expr], tloc: cloc, vloc: cloc
) -> stmt_cont {
    n = len(velts);
    i = 0;
    while i < n {
        visit_expr(g, velts[i]);
        i = i + 1;
    }
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    if n == 1 {
        return visit_store_target_tos(g, telts[0]);
    }
    if n <= 3 {
        # SWAP carries the target span; BUILD_TUPLE carries the RHS span.
        g.emit_op(OP_SWAP, n, tloc);
    } else {
        g.emit_op(OP_BUILD_TUPLE, n, vloc);
        g.emit_op(OP_UNPACK_SEQUENCE, n, tloc);
    }
    last_loc = tloc;
    i = 0;
    while i < n {
        se = visit_store_target_tos(g, telts[i]);
        last_loc = se.loc;
        i = i + 1;
    }
    return stmt_cont(loc=last_loc);
}

# Delete one target (name / attribute / subscript).
def visit_delete_target(g: cfg_builder, t: expr) -> stmt_cont {
    if codegen_busy(g) {
        return stmt_cont(loc=expr_loc(t));
    }
    if isinstance(t, (Tuple, List)) {
        last = expr_loc(t);
        for item in t.elts {
            last = visit_delete_target(g, item).loc;
        }
        return stmt_cont(loc=last);
    }
    if isinstance(t, Name) {
        n = t as Name;
        tloc = expr_loc(n);
        # emit_name_delete picks DELETE_FAST / DELETE_GLOBAL / DELETE_NAME from
        # the symtable scope (and rejects cell/free deletion).
        emit_name_delete(g, n.id, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(g, a.value);
        idx = g.u.add_name(codegen_mangle(g, a.attr));
        tloc = expr_loc(a);
        g.emit_op(OP_DELETE_ATTR, idx, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        tloc = expr_loc(s);
        visit_expr(g, s.value);
        if isinstance(s.slice, Slice) {
            sl = s.slice as Slice;
            folded = fold_slice_const(sl);
            if folded is not None {
                idx = g.u.add_const(folded);
                g.emit_op(OP_LOAD_CONST, idx, tloc);
                g.emit_op(OP_DELETE_SUBSCR, 0, tloc);
                return stmt_cont(loc=tloc);
            }
            emit_slice_delete(g, sl, tloc);
            return stmt_cont(loc=tloc);
        }
        visit_subscript_index(g, s.slice, tloc);
        g.emit_op(OP_DELETE_SUBSCR, 0, tloc);
        return stmt_cont(loc=tloc);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported deletion target: " + ast_node_name(t as ast_node)
    );
    return stmt_cont(loc=expr_loc(t));
}


# Module-level epilogue (LOAD_CONST None; RETURN_VALUE).
def emit_module_return(g: cfg_builder, lc: cloc) {
    if g.cur.instrs {
        last = g.cur.instrs[-1].opcode;
        if is_scope_exit_opcode(last) or is_unconditional_jump_opcode(last) {
            return;
        }
    }
    if g.fallthrough_target is not None {
        g.fallthrough_target.fallthrough_used = True;
        g.emit_jump(OP_JUMP_FORWARD, g.fallthrough_target.id, lc);
        return;
    }
    none_idx = g.u.stage_late_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, lc);
    g.emit_op(OP_RETURN_VALUE, 0, lc);
}

# Natural exit for a unit-final loop whose body contains try/except: lay out
# before handler machinery when break/continue ends the protected span.
def emit_unit_loop_exit_epilogue(g: cfg_builder, lc: cloc, with_end_for: bool) {
    if with_end_for {
        g.emit_op(OP_END_FOR, 0, lc);
        g.emit_op(OP_POP_ITER, 0, lc);
    }
    emit_module_return(g, lc);
}


# Lower assert (test + optional message).
def visit_assert_stmt(g: cfg_builder, a: Assert) -> stmt_cont {
    aloc = nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    import from jaclang.compiler.backends.py.jacpython.compiler_context {
        current_optimization_level
    }
    if current_optimization_level() > 0 {
        return stmt_cont(loc=aloc);
    }
    test_loc = expr_loc(a.`test);
    kind = visit_test_expr(g, a.`test, test_loc);
    if codegen_busy(g) {
        return stmt_cont(loc=aloc);
    }
    # Message expressions can create their own blocks (for comprehensions,
    # conditionals and short-circuit operators). Place success after all of them.
    ok = g.new_deferred_block();
    emit_branch_if_test_true(g, kind, ok.id, test_loc);
    g.emit_op(OP_LOAD_COMMON_CONSTANT, 0, aloc);
    if a.msg is not None {
        visit_expr(g, a.msg);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        g.emit_op(OP_CALL, 0, aloc);
    }
    g.emit_op(OP_RAISE_VARARGS, 1, aloc);
    g.use(ok);
    return stmt_cont(loc=aloc);
}

# Lower statements [from_idx..] in order. When tail/tail_idx are set, the suffix
# starting at tail_idx is the enclosing construct's continuation. tail_join is an
# optional shared join block for nested if/loop tails owned by an outer visitor.
def visit_stmts(
    g: cfg_builder,
    stmts: list[stmt],
    from_idx: int = 0,
    more_follows_after: bool = False,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    if len(stmts) == 0 or from_idx >= len(stmts) {
        return stmt_cont(loc=loc(1, 1, 0, 0));
    }
    last = stmt_loc(stmts[from_idx]);
    terminated = False;
    si = from_idx;
    while si < len(stmts) {
        follow = more_follows_after;
        local_more = exec_tail_emits_code(stmts, si + 1);
        if not follow {
            follow = local_more;
        }
        if not follow and tail is not None {
            follow = exec_tail_emits_code(tail, tail_idx);
        }
        # A shared outer join may only be adopted by the statement that owns
        # this list's continuation (the last code-emitting one). When more
        # statements follow here, the child's false edge must converge on a
        # join holding THIS remainder: adopting the outer join makes the
        # remainder land in the current (terminated) block -- "Invalid CFG,
        # instructions after terminator" for `if: if: return; raise` shapes.
        join_arg = tail_join;
        # Tail-consuming visitors (if/with/try) treat (tail, tail_idx) as
        # "everything that follows". When this list has its own remainder,
        # that remainder IS the continuation: hand the child this list's
        # suffix so a consumed tail covers exactly the following statements
        # instead of swallowing them as unreachable after the outer tail.
        child_tail = tail;
        child_idx = tail_idx;
        if local_more {
            join_arg = None;
            child_tail = stmts;
            child_idx = si + 1;
        }
        cont = visit_stmt(
            g, stmts[si], follow, child_tail, child_idx, join_arg, ann_ctx
        );
        last = cont.loc;
        if cont.terminated {
            # Statements after an unconditional terminator (return/break/
            # continue/raise) are unreachable: CPython compiles them and drops
            # the blocks (flowgraph remove_unreachable). Stop here so their
            # instructions never reach the layout.
            return stmt_cont(loc=last, terminated=True);
        }
        if codegen_busy(g) {
            return stmt_cont(loc=last, terminated=terminated);
        }
        if cont.next_si >= 0 {
            si = cont.next_si;
        } else {
            si = si + 1;
        }
    }
    return stmt_cont(loc=last, terminated=terminated);
}

# Lower a statement suffix once at the current block. When prefix_terminated
# is set, the owning construct's body ended unconditionally (return/break/etc.);
# the suffix is unreachable on that path and must not emit live bytes here.
def visit_stmt_tail(
    g: cfg_builder,
    tail: list[stmt],
    from_idx: int,
    more_follows_after: bool = False,
    ann_ctx: ann_scope_plan | None = None,
    prefix_terminated: bool = False
) -> stmt_cont {
    if prefix_terminated {
        if from_idx < len(tail) {
            return stmt_cont(
                loc=stmt_loc(tail[from_idx]), next_si=len(tail), terminated=True
            );
        }
        return stmt_cont(loc=loc(1, 1, 0, 0), next_si=len(tail), terminated=True);
    }
    return visit_stmts(g, tail, from_idx, more_follows_after, None, 0, None, ann_ctx);
}

# Emit tail suffix and finish the module when CPython duplicates it per branch.
def emit_tail_and_finish(
    g: cfg_builder,
    tail: list[stmt],
    tail_idx: int,
    end_loc: cloc,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    tail_cont = visit_stmt_tail(g, tail, tail_idx, False, ann_ctx);
    if codegen_busy(g) {
        return tail_cont;
    }
    emit_module_return(g, tail_cont.loc);
    return stmt_cont(loc=end_loc, next_si=len(tail), terminated=True);
}


# Lower one statement into the builder's current block.
def finish_expression(g: cfg_builder, lc: cloc) {
    if g.u.interactive {
        g.emit_op(OP_CALL_INTRINSIC_1, 1, lc);
    }
    g.emit_op(OP_POP_TOP, 0, lc);
}

def visit_stmt(
    g: cfg_builder,
    s: stmt,
    more_code_follows: bool = False,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    if codegen_busy(g) {
        return stmt_cont(loc=stmt_loc(s));
    }
    if isinstance(s, Assign) {
        asgn = s as Assign;
        last = stmt_loc(s);
        copy_loc = nloc(
            asgn.lineno, asgn.end_lineno, asgn.col_offset, asgn.end_col_offset
        );
        # Same-arity, no-star sequence-literal elision: CPython avoids the
        # build/unpack round-trip by evaluating the RHS elements and reordering
        # in place (SWAP for n<=3, BUILD_TUPLE+UNPACK_SEQUENCE for n>=4).
        if len(asgn.targets) == 1
            and is_seq_literal(asgn.targets[0])
            and is_seq_literal(asgn.value) {
            telts = seq_target_elts(asgn.targets[0]);
            velts = seq_target_elts(asgn.value);
            if len(telts) == len(velts)
                and starred_target_index(telts) < 0
                and starred_target_index(velts) < 0 {
                emit = visit_store_seq_literal(
                    g, telts, velts, expr_loc(asgn.targets[0]), expr_loc(asgn.value)
                );
                return stmt_cont(loc=emit.loc);
            }
        }
        if len(asgn.targets) == 1 and isinstance(asgn.value, Name) {
            vn = asgn.value as Name;
            vfi = fast_local_index(g, codegen_mangle(g, vn.id));
            if vfi >= 0 {
                vloc = expr_loc(vn);
                g.emit_op(OP_LOAD_FAST, vfi, vloc);
                emit = visit_store_target_tos(g, asgn.targets[0]);
                return stmt_cont(loc=emit.loc);
            }
        }
        cmp_cleanup = visit_expr(g, asgn.value, False, False);
        if cmp_cleanup is not None and more_code_follows {
            join = g.new_block();
            cmp_loc = expr_loc(asgn.value);
            g.emit_jump(OP_JUMP_FORWARD, join.id, cmp_loc);
            emit_compare_cleanup(g, cmp_cleanup, cmp_loc);
            g.use(join);
            ti = 0;
            while ti < len(asgn.targets) {
                if ti < len(asgn.targets) - 1 {
                    g.emit_op(OP_COPY, 1, copy_loc);
                }
                emit = visit_store_target_tos(g, asgn.targets[ti]);
                last = emit.loc;
                ti = ti + 1;
            }
            return stmt_cont(loc=last);
        }
        ti = 0;
        while ti < len(asgn.targets) {
            if ti < len(asgn.targets) - 1 {
                g.emit_op(OP_COPY, 1, copy_loc);
            }
            emit = visit_store_target_tos(g, asgn.targets[ti]);
            last = emit.loc;
            ti = ti + 1;
        }
        if cmp_cleanup is not None {
            none_idx = g.u.add_const(py_none());
            g.emit_op(OP_LOAD_CONST, none_idx, last);
            g.emit_op(OP_RETURN_VALUE, 0, last);
            emit_compare_cleanup(g, cmp_cleanup, expr_loc(asgn.value));
            ti = 0;
            while ti < len(asgn.targets) {
                if ti < len(asgn.targets) - 1 {
                    g.emit_op(OP_COPY, 1, copy_loc);
                }
                emit = visit_store_target_tos(g, asgn.targets[ti]);
                last = emit.loc;
                ti = ti + 1;
            }
            g.emit_op(OP_LOAD_CONST, none_idx, last);
            g.emit_op(OP_RETURN_VALUE, 0, last);
            return stmt_cont(loc=last, terminated=True);
        }
        return stmt_cont(loc=last);
    }
    # PEP 649 (3.14): AnnAssign lowering lives in compiler_annotations.jac --
    # function-local annotations reduce to the assignment side, module scope
    # defers into the __annotate__ machinery, class scope still traps.
    if isinstance(s, AnnAssign) {
        return visit_ann_assign(g, s as AnnAssign, ann_ctx);
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        opid = inplace_binop_id(aa.op);
        aloc = nloc(aa.lineno, aa.end_lineno, aa.col_offset, aa.end_col_offset);
        if opid < 0 {
            codegen_fail(
                g, "NotImplementedError", "unsupported augmented assignment operator"
            );
            return stmt_cont(loc=stmt_loc(s));
        }
        if isinstance(aa.target, Name) {
            n = aa.target as Name;
            visit_expr(g, n);
            visit_expr(g, aa.value);
            g.emit_op(OP_BINARY_OP, opid, aloc);
            tloc = expr_loc(n);
            emit_name_store(g, n.id, tloc);
            return stmt_cont(loc=tloc);
        }
        if isinstance(aa.target, Attribute) {
            attr = aa.target as Attribute;
            tloc = expr_loc(attr);
            visit_expr(g, attr.value);
            g.emit_op(OP_COPY, 1, tloc);
            idx = g.u.add_name(codegen_mangle(g, attr.attr));
            g.emit_op(OP_LOAD_ATTR, idx * 2, tloc);
            visit_expr(g, aa.value);
            g.emit_op(OP_BINARY_OP, opid, aloc);
            g.emit_op(OP_SWAP, 2, tloc);
            g.emit_op(OP_STORE_ATTR, idx, tloc);
            return stmt_cont(loc=tloc);
        }
        if isinstance(aa.target, Subscript) {
            sub = aa.target as Subscript;
            sloc = expr_loc(sub);
            visit_expr(g, sub.value);
            visit_subscript_index(g, sub.slice, sloc, True);
            g.emit_op(OP_COPY, 2, sloc);
            g.emit_op(OP_COPY, 2, sloc);
            g.emit_op(OP_BINARY_OP, NB_SUBSCR, sloc);
            visit_expr(g, aa.value, register_int_const=False);
            g.emit_op(OP_BINARY_OP, opid, aloc);
            g.emit_op(OP_SWAP, 3, sloc);
            g.emit_op(OP_SWAP, 2, sloc);
            g.emit_op(OP_STORE_SUBSCR, 0, sloc);
            return stmt_cont(loc=sloc);
        }
        codegen_fail(
            g,
            "NotImplementedError",
            "unsupported augmented assignment target: "
                + ast_node_name(aa.target as ast_node)
        );
        return stmt_cont(loc=stmt_loc(s));
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        last = stmt_loc(s);
        ti = 0;
        while ti < len(d.targets) {
            emit = visit_delete_target(g, d.targets[ti]);
            last = emit.loc;
            ti = ti + 1;
        }
        return stmt_cont(loc=last);
    }
    if isinstance(s, Expr) {
        x = s as Expr;
        cmp_cleanup = visit_expr(g, x.value, False, False);
        eloc = nloc(x.lineno, x.end_lineno, x.col_offset, x.end_col_offset);
        if cmp_cleanup is not None and isinstance(x.value, Call) {
            ca = x.value as Call;
            cloc_call = nloc(
                ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset
            );
            finish_expression(g, eloc);
            after = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, after.id, eloc);
            emit_compare_cleanup(g, cmp_cleanup, cloc_call);
            if len(call_effective_keywords(ca)) > 0 {
                emit_call_keyword_values(g, ca, cloc_call);
            }
            emit_call_instruction(g, ca, cloc_call);
            finish_expression(g, eloc);
            g.use(after);
        } elif cmp_cleanup is not None {
            finish_expression(g, eloc);
            after = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, after.id, eloc);
            emit_compare_cleanup(g, cmp_cleanup, eloc);
            finish_expression(g, eloc);
            g.use(after);
        } else {
            finish_expression(g, eloc);
        }
        return stmt_cont(loc=eloc);
    }
    if isinstance(s, Pass) {
        ploc = stmt_loc(s);
        if more_code_follows {
            g.emit_op(OP_NOP, 0, ploc);
        }
        return stmt_cont(loc=ploc);
    }
    if isinstance(s, Global) or isinstance(s, Nonlocal) {
        # global / nonlocal are scope declarations resolved entirely in the
        # symtable (they retarget name loads/stores to STORE_GLOBAL / STORE_DEREF).
        # They emit no bytecode of their own.
        return stmt_cont(loc=stmt_loc(s));
    }
    if isinstance(s, If) {
        # tail stays None in loop-body contexts: the continuation is the
        # enclosing loop's back edge / the caller's own statement list.
        return stmt_handlers["visit_if"](
            g, s as If, more_code_follows, tail, tail_idx, tail_join, ann_ctx
        );
    }
    if isinstance(s, While) {
        # tail stays None in loop-body contexts: the continuation is the
        # enclosing loop's back edge / the caller's own statement list.
        return stmt_handlers["visit_while"](
            g, s as While, more_code_follows, tail, tail_idx, ann_ctx
        );
    }
    if isinstance(s, For) {
        # tail stays None in loop-body contexts: the continuation is the
        # enclosing loop's back edge / the caller's own statement list.
        return stmt_handlers["visit_for"](
            g, s as For, more_code_follows, tail, tail_idx, ann_ctx
        );
    }
    if isinstance(s, AsyncFor) {
        # tail stays None in loop-body contexts: the continuation is the
        # enclosing loop's back edge / the caller's own statement list.
        return stmt_handlers["visit_async_for"](
            g, s as AsyncFor, more_code_follows, tail, tail_idx, ann_ctx
        );
    }
    if isinstance(s, Break) {
        b = s as Break;
        bloc = stmt_loc(b);
        frame = g.current_loop();
        if frame is None {
            codegen_fail(g, "SyntaxError", "'break' outside loop");
            return stmt_cont(loc=bloc);
        }
        unwind_end = emit_control_unwind(g, bloc, False, frame.cleanup_depth);
        if unwind_end.terminated {
            finish_control_unwind(g, unwind_end);
            return stmt_cont(loc=bloc, terminated=True);
        }
        if frame.break_is_stub {
            # CPython codegen_break: unwind the loop (POP_TOP for the FOR
            # family, nothing for WHILE), then jump to the loop's exit anchor.
            if frame.pops_iter {
                g.emit_op(OP_POP_TOP, 0, bloc);
            }
            site_idx = len(g.cur.instrs);
            g.emit_jump(OP_JUMP_FORWARD, frame.break_blk.id, bloc);
            frame.break_sites.append(
                break_site(blk=g.cur, instr_idx=site_idx, loc=bloc)
            );
        } else {
            emit_module_return(g, bloc);
        }
        finish_control_unwind(g, unwind_end);
        return stmt_cont(loc=bloc, terminated=True);
    }
    if isinstance(s, Continue) {
        c = s as Continue;
        cloc_stmt = stmt_loc(c);
        frame = g.current_loop();
        if frame is None {
            codegen_fail(g, "SyntaxError", "'continue' not properly in loop");
            return stmt_cont(loc=cloc_stmt);
        }
        unwind_end = emit_control_unwind(g, cloc_stmt, False, frame.cleanup_depth);
        if not unwind_end.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, frame.continue_blk.id, cloc_stmt);
        }
        finish_control_unwind(g, unwind_end);
        return stmt_cont(loc=cloc_stmt, terminated=True);
    }
    if isinstance(s, Return) {
        visit_return_stmt(g, s as Return);
        return stmt_cont(loc=stmt_loc(s), terminated=True);
    }
    if isinstance(s, FunctionDef) {
        return stmt_handlers["visit_function_def"](g, s as FunctionDef);
    }
    if isinstance(s, AsyncFunctionDef) {
        return stmt_handlers["visit_async_function_def"](g, s as AsyncFunctionDef);
    }
    if isinstance(s, ClassDef) {
        return stmt_handlers["visit_class_def"](g, s as ClassDef);
    }
    if isinstance(s, TypeAlias) {
        return stmt_handlers["visit_type_alias"](g, s as TypeAlias);
    }
    if isinstance(s, Import) {
        return stmt_handlers["visit_import"](g, s as Import);
    }
    if isinstance(s, ImportFrom) {
        return stmt_handlers["visit_import_from"](g, s as ImportFrom);
    }
    if isinstance(s, Try) {
        t = tail;
        if t is None {
            t = [];
        }
        return stmt_handlers["visit_try"](
            g, s as Try, more_code_follows, t, tail_idx, tail_join, ann_ctx
        );
    }
    if isinstance(s, TryStar) {
        t = tail;
        if t is None {
            t = [];
        }
        return stmt_handlers["visit_try_star"](
            g, s as TryStar, more_code_follows, t, tail_idx, tail_join, ann_ctx
        );
    }
    if isinstance(s, Raise) {
        return stmt_handlers["visit_raise_stmt"](g, s as Raise);
    }
    if isinstance(s, With) {
        t = tail;
        if t is None {
            t = [];
        }
        return stmt_handlers["visit_with"](
            g, s as With, more_code_follows, t, tail_idx, tail_join, ann_ctx
        );
    }
    if isinstance(s, AsyncWith) {
        t = tail;
        if t is None {
            t = [];
        }
        return stmt_handlers["visit_async_with"](
            g, s as AsyncWith, more_code_follows, t, tail_idx, tail_join, ann_ctx
        );
    }
    if isinstance(s, Match) {
        t = tail;
        if t is None {
            t = [];
        }
        return stmt_handlers["visit_match"](
            g, s as Match, more_code_follows, t, tail_idx, tail_join, ann_ctx
        );
    }
    if isinstance(s, Assert) {
        return visit_assert_stmt(g, s as Assert);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported statement: " + ast_node_name(s as ast_node)
    );
    return stmt_cont(loc=stmt_loc(s));
}

# Emit a Return statement and finish the compile unit (no module epilogue).
def visit_return_stmt(
    g: cfg_builder, r: Return, check_fast: bool = False, borrow_fast: bool = False
) {
    # CPython 3.14 return locations (codegen_return): value-expression
    # instructions carry their own spans; RETURN_VALUE carries the statement
    # span -- except for Constant values, where the folded NOP/LOAD_CONST pair
    # pins BOTH the load and RETURN_VALUE to the value's span. Fast-local loads
    # keep the Name node's own span.
    rloc = nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    has_fblocks = len(g.cleanup_stack) > 0;
    unwind_end = control_unwind();
    if r.value is not None {
        visit_expr(g, r.value);
        ret_loc = rloc;
        if isinstance(r.value, Constant) {
            ret_loc = expr_loc(r.value);
        }
        if has_fblocks {
            unwind_end = emit_return_unwind(g, rloc);
        }
        if not unwind_end.terminated {
            g.emit_op(OP_RETURN_VALUE, 0, ret_loc);
        }
        finish_control_unwind(g, unwind_end);
        return;
    }
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, rloc);
    if has_fblocks {
        unwind_end = emit_return_unwind(g, rloc);
    }
    if not unwind_end.terminated {
        g.emit_op(OP_RETURN_VALUE, 0, rloc);
    }
    finish_control_unwind(g, unwind_end);
}


# Build a unverified_cfg for an exec-mode module body. Emits RESUME (module scope:
# lineno 0), each statement, then the implicit LOAD_CONST None; RETURN_VALUE
# epilogue. The epilogue carries the last-emitted instruction's location (or the
# last statement's location when it emitted nothing, e.g. Pass), matching
# CPython's NO_LOCATION inheritance at the end of _PyCodegen_AddReturnAtEnd.
def compile_exec(
    body: list[stmt],
    filename: str,
    name: str,
    firstlineno: int,
    sym_top: sym_block | None = None,
    interactive: bool = False
) -> unverified_cfg {
    # PEP 649: module-scope annotated assignments defer into the __annotate__
    # machinery. The plan is collected up front because the setup bytes emit
    # at scope entry while the nested code object builds at end of unit.
    ann_plan = collect_ann_plan(body);
    if ann_plan.any_annotation {
        u_cell = ["__conditional_annotations__"];
        u = unverified_cfg(
            filename=filename,
            name=name,
            qualname=name,
            firstlineno=firstlineno,
            cellvars=u_cell
        );
    } else {
        u = unverified_cfg(
            filename=filename, name=name, qualname=name, firstlineno=firstlineno
        );
    }
    u.interactive = interactive;
    if sym_top is not None {
        u.varnames = fast_varnames_from_sym(sym_top);
        u.cellvars.extend(cellvars_from_sym(sym_top));
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_top);
    ploc0 = loc(0, firstlineno, 0, 0);
    if ann_plan.any_annotation {
        g.emit_op(
            OP_MAKE_CELL, localsplus_index_u(u, "__conditional_annotations__"), no_loc()
        );
    }
    protect_start = emit_source_resume(g, sym_top, firstlineno);
    if ann_plan.any_annotation {
        sloc = ann_plan.head_loc;
        if sloc is None {
            sloc = ploc0;
        }
        emit_module_annotation_setup(g, ann_plan, sloc);
    }
    last = loc(0, firstlineno, 0, 0);
    terminated = False;
    si = 0;
    doc = body_docstring(body) if not interactive else None;
    if doc is not None {
        import from jaclang.compiler.backends.py.jacpython.compiler_context {
            current_optimization_level
        }
        if current_optimization_level() < 2 {
            last = expr_loc((body[0] as Expr).value);
            g.emit_op(OP_LOAD_CONST, u.add_const(doc), last);
            emit_name_store(g, "__doc__", last);
        }
        si = 1;
    }
    while si < len(body) {
        s = body[si];
        cont = visit_stmt(
            g, s, exec_tail_emits_code(body, si + 1), body, si + 1, None, ann_plan
        );
        last = cont.loc;
        if cont.terminated {
            # CPython compiles the remaining statements and then drops them as
            # unreachable blocks (flowgraph remove_unreachable). Visiting them
            # here would append live bytes after a terminator, so stop now.
            # The implicit-return None const is still interned by CPython's
            # (dead) epilogue emission; remove_unused_consts keeps it only at
            # index 0, exactly like the host. Deferred comp cleanup handlers
            # are emitted here too -- CPython lays them out after the (dead)
            # epilogue regardless of how the body ended.
            if len(ann_plan.entries) > 0 {
                finish_module_annotations(g, ann_plan);
                if codegen_busy(g) {
                    u.flush_late_consts();
                    return u;
                }
            }
            u.add_const(py_none());
            finish_source_scope(g, protect_start);
            u.flush_late_consts();
            return u;
        }
        if codegen_busy(g) {
            u.flush_late_consts();
            return u;
        }
        if cont.next_si >= 0 {
            si = cont.next_si;
        } else {
            si = si + 1;
        }
    }
    if len(ann_plan.entries) > 0 {
        finish_module_annotations(g, ann_plan);
        if codegen_busy(g) {
            u.flush_late_consts();
            return u;
        }
    }
    if terminated {
        # Dead implicit-return None const, interned like CPython's unreachable
        # epilogue; kept by remove_unused_consts only at index 0.
        u.add_const(py_none());
        finish_source_scope(g, protect_start);
        u.flush_late_consts();
        return u;
    }
    none_idx = u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, last);
    g.emit_op(OP_RETURN_VALUE, 0, last);
    finish_source_scope(g, protect_start);
    u.flush_late_consts();
    return u;
}

# Statement dispatch for compound statements goes through the handler slots
# in compiler_dispatch (a leaf module), not through imports of the split-out
# sibling modules: those siblings import shared lowering helpers (visit_stmts,
# emit_name_store, ...) from THIS module, so a static edge in either direction
# would close an import cycle. Each sibling registers its visitors at module
# load; entry drivers (product_compile, compiler_slice) import the siblings so
# registration runs before the first compile. See compiler_dispatch.jac.

# Module and eval code keep mapping locals, even when they produce a coroutine.
# Scope analysis runs before optimization, so elided awaits still set CO_COROUTINE.
def emit_source_resume(
    g: cfg_builder, scope: sym_block | None, firstlineno: int
) -> int {
    protect_start = -1;
    if scope is not None and scope.coroutine and current_compile_flags() & 0x2000 {
        g.u.flags |= CO_COROUTINE;
        protect_start = emit_suspendable_prologue(g, firstlineno, False);
    }
    g.emit_op(OP_RESUME, 0, loc(0, firstlineno, 0, 0));
    return protect_start;
}

def finish_source_scope(g: cfg_builder, protect_start: int) {
    flush_pending_await_footers(g);
    stmt_handlers["deferred_comp_handlers"](g);
    emit_generator_except_handler(g, protect_start);
}
