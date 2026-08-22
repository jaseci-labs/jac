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

import from objects {
    PyObj,
    PyInt,
    PyStr,
    py_none,
    PyNoneType,
    PySlice,
    PyCode,
    PyTuple
}
import from opcode_meta {
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
import from ast_nodes {
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
import from compiler_ir {
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
    except_region,
    comp_handler,
}
import from compiler_symtable {
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
import from compiler_diagnostics { lowering_diagnostic }
import from flowgraph { verify_cfg, optimize_swap_range }
import from assembler { assemble }
import from compiler_emit {
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
    comp_lead_is_loopvar,
    comp_name_fast_index,
    comp_target_slots,
    compile_lambda_cfg,
    emit_anext_send_loop_footer,
    emit_anext_send_loop_header,
    emit_await_send_except_regions,
    emit_await_send_loop_footer,
    emit_await_send_loop_header,
    emit_branch_if_test_false,
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
    visit_dict_comp_async,
    visit_expr,
    visit_lambda,
    visit_list_comp,
    visit_list_comp_async,
    visit_set_comp,
    visit_set_comp_async,
    visit_store_target,
    visit_subscript_index,
    visit_test_expr,
}
import from codegen_util {
    fold_default_values,
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











# Suspendable functions: PEP 479 StopIteration handler at end of co_code.
def emit_generator_except_handler(g: cfg_builder, protect_start: int) {
    if protect_start < 0 {
        return;
    }
    noloc = no_loc();
    handler = g.new_block();
    g.use(handler);
    g.emit_op(OP_CALL_INTRINSIC_1, 3, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    if len(g.u.pending_pep479_regions) == 0 {
        g.u.except_regions.append(
            except_region(
                start_block=protect_start,
                end_block=handler.id,
                handler_block=handler.id,
                stack_depth=2,
                preserve_lasti=True
            )
        );
    }
    pi = 0;
    while pi < len(g.u.pending_pep479_regions) {
        ri = g.u.pending_pep479_regions[pi];
        g.u.except_regions[ri].handler_block = handler.id;
        if g.u.except_regions[ri].end_block < 0 {
            g.u.except_regions[ri].end_block = handler.id;
        }
        pi = pi + 1;
    }
}





# Inline footer before END_SEND (async-with except __aexit__ await).
def emit_await_send_loop_inline_footer(
    g: cfg_builder,
    get_iter_op: int,
    get_iter_arg: int,
    resume_after_yield_arg: int,
    yloc: cloc
) -> tuple[await_send_loop, basicblock, basicblock] {
    g.emit_op(get_iter_op, get_iter_arg, yloc);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, yloc);
    send_blk = g.new_block();
    yield_blk = g.new_block();
    after_resume_blk = g.new_block();
    cleanup_throw_blk = g.new_block();
    end_send_blk = g.new_block();
    g.use(send_blk);
    g.emit_jump(OP_SEND, end_send_blk.id, yloc);
    g.use(yield_blk);
    g.emit_op(OP_YIELD_VALUE, 1, yloc);
    g.use(after_resume_blk);
    g.emit_op(OP_RESUME, resume_after_yield_arg, yloc);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, send_blk.id, yloc);
    g.use(cleanup_throw_blk);
    g.emit_op(OP_CLEANUP_THROW, 0, yloc);
    g.use(end_send_blk);
    als = await_send_loop(
        send_blk=send_blk,
        yield_blk=yield_blk,
        after_resume_blk=after_resume_blk,
        end_send_blk=end_send_blk
    );
    return (als, cleanup_throw_blk, end_send_blk);
}




def emit_anext_send_except_regions(
    g: cfg_builder,
    als: anext_send_loop,
    store_blk: basicblock,
    cleanup_throw_blk: basicblock,
    cleanup_jump_blk: basicblock,
    async_for_handler: basicblock
) {
    g.u.except_regions.append(
        except_region(
            start_block=als.loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=async_for_handler.id,
            stack_depth=2,
            preserve_lasti=False
        )
    );
    # END_SEND through NOT_TAKEN only; loop body uses a separate PEP 479 region.
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=async_for_handler.id,
            stack_depth=2,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw_blk.id,
            end_block=cleanup_jump_blk.id,
            handler_block=async_for_handler.id,
            stack_depth=2,
            preserve_lasti=False
        )
    );
    `protect = g.generator_protect_start;
    if `protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=`protect,
                end_block=als.loop_hdr.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        g.u.except_regions.append(
            except_region(
                start_block=als.yield_blk.id,
                end_block=als.after_resume_blk.id,
                handler_block=cleanup_throw_blk.id,
                stack_depth=4,
                preserve_lasti=False
            )
        );
    }
}







def sym_class_child(parent: sym_block, class_name: str) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "class" and ch.name == class_name {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}

def sym_function_child(parent: sym_block, fn_name: str) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "function" and ch.name == fn_name {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}





def emit_name_store(g: cfg_builder, name: str, tloc: cloc) {
    name = codegen_mangle(g, name);
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_STORE_FAST, fi, tloc);
        return;
    }
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            g.emit_op(OP_STORE_DEREF, idx, tloc);
            return;
        }
        if scope == SCOPE_GLOBAL_EXPLICIT or scope == SCOPE_GLOBAL_IMPLICIT {
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
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_DELETE_FAST, fi, tloc);
        return;
    }
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            codegen_fail(
                g, "NotImplementedError", "delete of cell/free var not supported"
            );
            return;
        }
        if scope == SCOPE_GLOBAL_EXPLICIT or scope == SCOPE_GLOBAL_IMPLICIT {
            idx = g.u.add_name(name);
            g.emit_op(OP_DELETE_GLOBAL, idx, tloc);
            return;
        }
    }
    idx = g.u.add_name(name);
    g.emit_op(OP_DELETE_NAME, idx, tloc);
}

# Clear an except-as binding (STORE None + DELETE) before handler exit.
def emit_except_as_cleanup(g: cfg_builder, bind_name: str, cloc: cloc) {
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, cloc);
    emit_name_store(g, bind_name, cloc);
    emit_name_delete(g, bind_name, cloc);
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
    e: expr, filename: str, name: str, firstlineno: int
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name=name, qualname=name, firstlineno=firstlineno
    );
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk);
    g.emit_op(OP_RESUME, 0, loc(0, firstlineno, 0, 0));
    cleanup = visit_expr(g, e, false_shortcircuit_returns=True);
    if codegen_busy(g) {
        return u;
    }
    eloc = top_loc(e);
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



















# Emit comprehension cleanup handlers after the module RETURN_VALUE (dead code on
# the normal path; reached only via the exception table).
def emit_deferred_comp_handlers(g: cfg_builder) {
    emitted_groups: list[int] = [];
    emitted_blocks: list[int] = [];
    hi = 0;
    while hi < len(g.u.comp_handlers) {
        h = g.u.comp_handlers[hi];
        handler_blk = -1;
        gi = 0;
        while gi < len(emitted_groups) {
            if emitted_groups[gi] == h.group {
                handler_blk = emitted_blocks[gi];
                break;
            }
            gi = gi + 1;
        }
        if handler_blk < 0 {
            handler = g.new_block();
            handler_blk = handler.id;
            emitted_groups.append(h.group);
            emitted_blocks.append(handler_blk);
            g.use(handler);
            noloc = no_loc();
            g.emit_op(OP_SWAP, 2, noloc);
            g.emit_op(OP_POP_TOP, 0, noloc);
            if h.second_fast_index >= 0 {
                g.emit_op(OP_SWAP, 3, h.loc);
                g.emit_op(OP_STORE_FAST, h.second_fast_index, h.loc);
                g.emit_op(OP_STORE_FAST, h.fast_index, h.loc);
            } else {
                g.emit_op(OP_SWAP, h.swap_depth, h.loc);
                g.emit_op(OP_STORE_FAST, h.fast_index, h.loc);
            }
            g.emit_op(OP_RERAISE, 0, h.loc);
        }
        g.u.except_regions[h.region_index].handler_block = handler_blk;
        hi = hi + 1;
    }
}







# Module-level epilogue (LOAD_CONST None; RETURN_VALUE).
def emit_module_return(g: cfg_builder, lc: cloc) {
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, lc);
    g.emit_op(OP_RETURN_VALUE, 0, lc);
}


# Lower raise (exc/cause forms; bare re-raise in handler context).
def visit_raise_stmt(g: cfg_builder, r: Raise) -> stmt_cont {
    rloc = nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    if r.cause is not None {
        if r.exc is None {
            codegen_fail(g, "SyntaxError", "raise from without exception");
            return stmt_cont(loc=rloc);
        }
        visit_expr(g, r.exc);
        if codegen_busy(g) {
            return stmt_cont(loc=rloc);
        }
        visit_expr(g, r.cause);
        if codegen_busy(g) {
            return stmt_cont(loc=rloc);
        }
        g.emit_op(OP_RAISE_VARARGS, 2, rloc);
        return stmt_cont(loc=rloc, terminated=True);
    }
    if r.exc is not None {
        visit_expr(g, r.exc);
        if codegen_busy(g) {
            return stmt_cont(loc=rloc);
        }
        g.emit_op(OP_RAISE_VARARGS, 1, rloc);
        return stmt_cont(loc=rloc, terminated=True);
    }
    g.emit_op(OP_RAISE_VARARGS, 0, rloc);
    return stmt_cont(loc=rloc, terminated=True);
}


# Lower try/finally without except/else.
def visit_try_finally(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    nop_blk = g.new_block();
    try_entry = g.new_block();
    protect_end = g.new_block();
    after_protected = g.new_block();
    finally_except = g.new_block();
    unwind = g.new_block();
    g.use(nop_blk);
    g.emit_op(OP_NOP, 0, tloc);
    g.use(try_entry);
    protect_start = g.cur.id;
    try_follows = more_code_follows;
    if not try_follows and tail is not None and tail_idx < len(tail) {
        try_follows = True;
    }
    body_cont = visit_stmts(g, t.body, 0, True);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.use(protect_end);
    finally_cont = visit_stmts(g, t.finalbody);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.u.nested_try_finally_success_start = protect_end.id;
    g.use(after_protected);
    fallthrough_blk: basicblock | None = None;
    tail_end_blk: basicblock | None = None;
    tail_done = False;
    tail_terminated = False;
    if try_follows and tail is not None and tail_idx < len(tail) {
        tail_more = False;
        if tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        if codegen_busy(g) {
            return stmt_cont(loc=finally_cont.loc);
        }
        tail_done = True;
        tail_terminated = tail_cont.terminated;
        tail_end_blk = g.cur;
        if tail_cont.terminated {
            emit_module_return(g, tail_cont.loc);
        }
    } elif try_follows {
        fallthrough_blk = g.cur;
    } else {
        emit_module_return(g, finally_cont.loc);
    }
    g.u.nested_try_finally_success_end = after_protected.id;
    noloc = no_loc();
    g.use(finally_except);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    finally_except_cont = visit_stmts(g, t.finalbody);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.emit_op(OP_RERAISE, 0, finally_except_cont.loc);
    g.u.except_regions.append(
        except_region(
            start_block=protect_start,
            end_block=protect_end.id,
            handler_block=finally_except.id,
            stack_depth=1
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=finally_except.id,
            end_block=unwind.id,
            handler_block=unwind.id,
            stack_depth=3,
            preserve_lasti=True
        )
    );
    g.use(unwind);
    g.u.nested_try_finally_unwind_start = unwind.id;
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    if fallthrough_blk is not None {
        g.use(fallthrough_blk);
        return stmt_cont(loc=tloc, terminated=False);
    }
    if tail_done {
        if tail_end_blk is not None {
            g.use(tail_end_blk);
        }
        return stmt_cont(loc=tloc, next_si=len(tail), terminated=tail_terminated);
    }
    return stmt_cont(loc=tloc, terminated=True);
}

def append_try_unwind_region(g: cfg_builder, reg: except_region) {
    g.u.except_regions.append(reg);
    g.u.pending_try_unwind_regions.append(len(g.u.except_regions) - 1);
}

def bind_try_unwind_handlers(g: cfg_builder, unwind_block: int) {
    pi = 0;
    while pi < len(g.u.pending_try_unwind_regions) {
        ri = g.u.pending_try_unwind_regions[pi];
        g.u.except_regions[ri].handler_block = unwind_block;
        pi = pi + 1;
    }
}

# Emit the inline (normal-path) copy of a finally body followed by the module
# return / tail continuation. `with_nop` matches CPython's leading NOP that
# appears when the finally block is laid out after the handlers (terminated
# body path).
def emit_finally_inline_block(
    g: cfg_builder,
    finalbody: list[stmt],
    blk: basicblock,
    with_nop: bool,
    more_code_follows: bool,
    tail: list[stmt] | None,
    tail_idx: int,
    tloc: cloc
) {
    g.use(blk);
    if with_nop {
        g.emit_op(OP_NOP, 0, tloc);
    }
    fc = visit_stmts(g, finalbody);
    if codegen_busy(g) {
        return;
    }
    fin_follows = more_code_follows;
    if not fin_follows and tail is not None and tail_idx < len(tail) {
        fin_follows = True;
    }
    if fin_follows {
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tc = visit_stmt_tail(g, tail, tail_idx, tail_more);
        if codegen_busy(g) {
            return;
        }
        if not tc.terminated {
            emit_module_return(g, tc.loc);
        }
    } else {
        emit_module_return(g, fc.loc);
    }
}

# Lower flat try/except[/else]/finally by forward-nesting the finally around the
# try/except (CPython compiles them identically). Multiple handlers chained after
# one try, optional else and finally. Handlers may bind via `except E as e`;
# each bound handler gets its own as-cleanup unwind block.

# Coalesce spans that share handler/depth/lasti into maximal runs (CPython's
# exception-table builder merges contiguous same-target ranges; overlapping
# spans with identical handler metadata also fold into the covering range).
# Comparison is in LAYOUT position, not block id: deferred blocks are placed
# at first use, so id order does not match layout order.
def merge_except_spans(g: cfg_builder, spans: list[except_region]) -> list[except_region] {
    pos_of: dict[int, int] = {};
    bi = 0;
    while bi < len(g.u.blocks) {
        pos_of[g.u.blocks[bi].id] = bi;
        bi = bi + 1;
    }
    order: list[int] = [];
    i = 0;
    while i < len(spans) {
        order.append(i);
        i = i + 1;
    }
    ni = 0;
    while ni < len(order) {
        nj = ni + 1;
        while nj < len(order) {
            a = pos_of.get(spans[order[nj]].start_block, 0);
            b = pos_of.get(spans[order[ni]].start_block, 0);
            if a < b {
                tmp = order[ni];
                order[ni] = order[nj];
                order[nj] = tmp;
            }
            nj = nj + 1;
        }
        ni = ni + 1;
    }
    out: list[except_region] = [];
    oi = 0;
    while oi < len(order) {
        cur = spans[order[oi]];
        oi = oi + 1;
        while oi < len(order) {
            nxt = spans[order[oi]];
            if nxt.handler_block != cur.handler_block
                or nxt.stack_depth != cur.stack_depth
                or nxt.preserve_lasti != cur.preserve_lasti {
                break;
            }
            nxt_pos = pos_of.get(nxt.start_block, -1);
            cur_end_pos = pos_of.get(cur.end_block, -1);
            if nxt_pos < 0 or cur_end_pos < 0 or nxt_pos > cur_end_pos {
                break;
            }
            new_end = cur.end_block;
            if pos_of.get(nxt.end_block, -1) > cur_end_pos {
                new_end = nxt.end_block;
            }
            cur = except_region(
                start_block=cur.start_block,
                end_block=new_end,
                handler_block=cur.handler_block,
                stack_depth=cur.stack_depth,
                preserve_lasti=cur.preserve_lasti
            );
            oi = oi + 1;
        }
        out.append(cur);
    }
    return out;
}

def visit_try_except_finally(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    nh = len(t.handlers);
    noloc = no_loc();
    last_is_bare = t.handlers[nh - 1].type is None;

    nop_blk = g.new_block();
    try_body = g.new_block();
    g.use(nop_blk);
    g.emit_op(OP_NOP, 0, tloc);
    g.use(try_body);
    protect_start = g.cur.id;
    body_cont = visit_stmts(g, t.body, 0, True);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }

    protect_end = g.new_block();
    g.use(protect_end);
    normal_reaches_fin = not body_cont.terminated;
    has_else = t.orelse is not None and len(t.orelse) > 0;
    dead_blocks = -1;
    dead_regions = -1;
    dead_pending = -1;
    dead_ntf_ss = -1;
    dead_ntf_se = -1;
    dead_ntf_us = -1;
    dead_nte = -1;
    if has_else {
        if body_cont.terminated {
            # CPython still compiles a dead else after a terminated body: its
            # names and consts register first, then the unreachable code is
            # stripped by the flowgraph. Emit into throwaway blocks and drop
            # them so registration order matches without keeping the bytes.
            dead_blocks = len(g.u.blocks);
            dead_regions = len(g.u.except_regions);
            dead_pending = len(g.u.pending_try_unwind_regions);
            dead_ntf_ss = g.u.nested_try_finally_success_start;
            dead_ntf_se = g.u.nested_try_finally_success_end;
            dead_ntf_us = g.u.nested_try_finally_unwind_start;
            dead_nte = g.u.nested_try_except_end;
            g.use(g.new_block());
        }
        else_cont = visit_stmts(g, t.orelse, 0, True);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if dead_blocks >= 0 {
            g.u.blocks = g.u.blocks[0:dead_blocks];
            g.u.except_regions = g.u.except_regions[0:dead_regions];
            g.u.pending_try_unwind_regions =
                g.u.pending_try_unwind_regions[0:dead_pending];
            g.u.nested_try_finally_success_start = dead_ntf_ss;
            g.u.nested_try_finally_success_end = dead_ntf_se;
            g.u.nested_try_finally_unwind_start = dead_ntf_us;
            g.u.nested_try_except_end = dead_nte;
        } elif else_cont.terminated {
            normal_reaches_fin = False;
        }
    }

    # Deferred layout blocks; placed below in CPython's layout order.
    fin_inline = g.new_deferred_block();
    handler_entry = g.new_deferred_block();
    nt_blks: list[basicblock] = [];
    body_blks: list[basicblock] = [];
    epi_blks: list[basicblock] = [];
    next_blks: list[basicblock] = [];
    as_unwind_blks: list[basicblock] = [];
    binds: list[str | None] = [];
    hi = 0;
    while hi < nh {
        nt_blks.append(g.new_deferred_block());
        body_blks.append(g.new_deferred_block());
        epi_blks.append(g.new_deferred_block());
        as_unwind_blks.append(g.new_deferred_block());
        binds.append((t.handlers[hi] as ExceptHandler).name);
        if hi < nh - 1 {
            next_blks.append(g.new_deferred_block());
        }
        hi = hi + 1;
    }
    reraise_blk = g.new_deferred_block();
    inner_unwind = g.new_deferred_block();
    fin_except = g.new_deferred_block();
    outer_unwind = g.new_deferred_block();

    # Exception-table spans collected during emission, coalesced at the end.
    spans: list[except_region] = [];

    # try body -> first handler.
    if body_is_try_finally_only(t.body) {
        if g.u.nested_try_finally_success_start >= 0
            and g.u.nested_try_finally_success_end >= 0 {
            spans.append(
                except_region(
                    start_block=g.u.nested_try_finally_success_start,
                    end_block=g.u.nested_try_finally_success_end,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
        if g.u.nested_try_finally_unwind_start >= 0 {
            spans.append(
                except_region(
                    start_block=g.u.nested_try_finally_unwind_start,
                    end_block=handler_entry.id,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
    } elif body_is_try_except_only(t.body) and g.u.nested_try_except_end >= 0 {
        # The nested try/except owns [body start, its unwind]; this region
        # protects only what follows it so entries never overlap.
        spans.append(
            except_region(
                start_block=g.u.nested_try_except_end,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1
            )
        );
    } else {
        spans.append(
            except_region(
                start_block=protect_start,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1
            )
        );
    }

    fin_early = normal_reaches_fin;
    if has_else and normal_reaches_fin {
        # else clause -> exceptional finally handler directly (no active except
        # frame on that path).
        spans.append(
            except_region(
                start_block=protect_end.id,
                end_block=fin_inline.id,
                handler_block=fin_except.id,
                stack_depth=1
            )
        );
    }

    falls: list[bool] = [];
    nested_in: list[bool] = [];
    hi = 0;
    while hi < nh {
        falls.append(False);
        nested_in.append(False);
        hi = hi + 1;
    }

    if fin_early {
        g.use(fin_inline);
    }

    g.use(handler_entry);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    hi = 0;
    while hi < nh {
        h = t.handlers[hi] as ExceptHandler;
        hloc = try_handler_span(h);
        if hi > 0 {
            g.use(next_blks[hi - 1]);
        }
        if h.type is not None {
            visit_expr(g, h.type);
            if codegen_busy(g) {
                return stmt_cont(loc=tloc);
            }
            g.emit_op(OP_CHECK_EXC_MATCH, 0, hloc);
            if hi < nh - 1 {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, next_blks[hi].id, hloc);
            } else {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, reraise_blk.id, hloc);
            }
            if hi > 0 {
                # CPython keeps this NOT_TAKEN in its own uncovered block for
                # chained handlers; normalize_jumps skips the inline insert.
                g.use(nt_blks[hi]);
                g.emit_op(OP_NOT_TAKEN, 0, noloc);
            }
        }
        # Binding store belongs to the MATCH block (CPython splits the
        # exception-table body region AFTER the store, matching slice-3 flat
        # lowering). Unbound handlers keep POP_TOP at the top of the body
        # block, exactly as CPython's L5/L6 NOT_TAKEN / POP_TOP block pair.
        if binds[hi] is not None {
            emit_name_store(g, binds[hi] as str, hloc);
            g.use(body_blks[hi]);
        } else {
            g.use(body_blks[hi]);
            g.emit_op(OP_POP_TOP, 0, hloc);
        }
        # While emitting this handler body, advertise the inline success
        # epilogue (POP_EXCEPT [+ except-as cleanup] + jump to fin) and the
        # enclosing cleanup block so a nested try falling through finishes the
        # handler exactly the way CPython duplicates the epilogue per path.
        saved_ffin = g.handler_fallthrough_fin;
        saved_fbwd = g.handler_fallthrough_backward;
        saved_ffh = g.handler_fallthrough_fin_handler;
        saved_fbind = g.handler_fallthrough_bind;
        saved_feu = g.handler_enclosing_unwind;
        saved_fell = g.handler_fell_through;
        saved_nd = g.handler_nest_depth;
        g.handler_fallthrough_fin = fin_inline;
        g.handler_fallthrough_backward = fin_early;
        g.handler_fallthrough_fin_handler = fin_except.id;
        g.handler_fallthrough_bind = binds[hi];
        g.handler_enclosing_unwind = inner_unwind.id;
        g.handler_fell_through = False;
        g.handler_nest_depth = saved_nd + 1;
        hbody = visit_stmts(g, h.body);
        nested_fell = g.handler_fell_through;
        g.handler_fallthrough_fin = saved_ffin;
        g.handler_fallthrough_backward = saved_fbwd;
        g.handler_fallthrough_fin_handler = saved_ffh;
        g.handler_fallthrough_bind = saved_fbind;
        g.handler_enclosing_unwind = saved_feu;
        g.handler_fell_through = saved_fell;
        g.handler_nest_depth = saved_nd;
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if nested_fell {
            nested_in[hi] = True;
        }
        if not hbody.terminated {
            falls[hi] = True;
            g.use(epi_blks[hi]);
            g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
            if binds[hi] is not None {
                emit_except_as_cleanup(g, binds[hi] as str, hbody.loc);
            }
            if fin_early {
                g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, fin_inline.id, hbody.loc);
            } else {
                g.emit_jump(OP_JUMP_FORWARD, fin_inline.id, hbody.loc);
            }
        }
        if binds[hi] is not None {
            # Per-handler as-cleanup unwind: an exception raised inside a bound
            # handler's body clears the binding before re-raising (CPython emits
            # one such block per bound handler, laid out after its epilogue,
            # regardless of whether the body terminates).
            g.use(as_unwind_blks[hi]);
            emit_except_as_cleanup(g, binds[hi] as str, noloc);
            g.emit_op(OP_RERAISE, 1, noloc);
        }
        hi = hi + 1;
    }
    if not last_is_bare {
        g.use(reraise_blk);
        g.emit_op(OP_RERAISE, 0, try_handler_span(t.handlers[nh - 1]));
    }
    g.use(inner_unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);

    # Per-handler protected spans -> inner unwind (COPY 3 / POP_EXCEPT / RERAISE 1).
    hi = 0;
    while hi < nh {
        h = t.handlers[hi] as ExceptHandler;
        typed = h.type is not None;
        entry_id = handler_entry.id;
        if hi > 0 {
            entry_id = next_blks[hi - 1].id;
        }
        if nested_in[hi] {
            # Handler body = nested try that fell through: its own regions carve
            # out its span. Protect only the match code before it and the tail
            # from its unwind onward (which merges with the next handler's
            # match span, matching CPython's coalesced entries).
            inner_start = g.u.nested_try_except_start;
            if inner_start < 0 {
                inner_start = entry_id;
            }
            # Match portion -> shared unwind.
            spans.append(
                except_region(
                    start_block=entry_id,
                    end_block=inner_start,
                    handler_block=inner_unwind.id,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
            after_id = inner_unwind.id;
            if hi < nh - 1 {
                after_id = next_blks[hi].id;
            } else {
                if not last_is_bare {
                    after_id = reraise_blk.id;
                }
            }
            # Body portion -> as-cleanup unwind when bound (clears binding
            # before re-raise), shared unwind otherwise.
            body_handler = inner_unwind.id;
            if binds[hi] is not None {
                body_handler = as_unwind_blks[hi].id;
                spans.append(
                    except_region(
                        start_block=as_unwind_blks[hi].id,
                        end_block=after_id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
            spans.append(
                except_region(
                    start_block=g.u.nested_try_except_end,
                    end_block=after_id,
                    handler_block=body_handler,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
        } elif typed and falls[hi] {
            if binds[hi] is not None {
                # Bound handler: CPython splits at the body boundary - match
                # code unwinds via the shared COPY 3 / POP_EXCEPT / RERAISE 1
                # chain, body exceptions clear the binding first.
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=body_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                spans.append(
                    except_region(
                        start_block=body_blks[hi].id,
                        end_block=epi_blks[hi].id,
                        handler_block=as_unwind_blks[hi].id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            } elif hi == 0 {
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=epi_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            } else {
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=nt_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                spans.append(
                    except_region(
                        start_block=body_blks[hi].id,
                        end_block=epi_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
            # Exceptions while clearing the binding unwind via the shared chain
            # (coalesces with the following reraise span when present).
            if binds[hi] is not None {
                au_end = inner_unwind.id;
                if hi < nh - 1 {
                    au_end = next_blks[hi].id;
                } else {
                    if not last_is_bare {
                        au_end = reraise_blk.id;
                    }
                }
                spans.append(
                    except_region(
                        start_block=as_unwind_blks[hi].id,
                        end_block=au_end,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
        } else {
            end_id = inner_unwind.id;
            if hi < nh - 1 {
                end_id = next_blks[hi].id;
            } else {
                if not last_is_bare {
                    end_id = reraise_blk.id;
                }
            }
            if not typed {
                if falls[hi] {
                    end_id = epi_blks[hi].id;
                }
            }
            if binds[hi] is not None {
                # Terminated bound handler body (explicit raise/return): CPython
                # still splits - match portion via the shared chain, everything
                # from the body start through the as-cleanup block itself.
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=body_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                spans.append(
                    except_region(
                        start_block=body_blks[hi].id,
                        end_block=as_unwind_blks[hi].id,
                        handler_block=as_unwind_blks[hi].id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                # The as-cleanup block itself unwinds via the shared chain
                # (merges with the following reraise span when present).
                au_end = inner_unwind.id;
                if hi < nh - 1 {
                    au_end = next_blks[hi].id;
                } else {
                    if not last_is_bare {
                        au_end = reraise_blk.id;
                    }
                }
                spans.append(
                    except_region(
                        start_block=as_unwind_blks[hi].id,
                        end_block=au_end,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            } else {
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=end_id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
        }
        if falls[hi] {
            fe_end = fin_except.id;
            if hi < nh - 1 {
                fe_end = next_blks[hi].id;
            } else {
                if not last_is_bare {
                    fe_end = reraise_blk.id;
                } elif not fin_early {
                    # Bare last handler: no reraise block follows, so the span
                    # runs through the unwind chain into the late inline
                    # finally's leading NOP (merges with the inner-unwind span).
                    fe_end = fin_inline.id;
                }
            }
            if binds[hi] is not None {
                # The epilogue span ends where the as-cleanup block begins:
                # cleanup failures unwind via the fin handler from base depth.
                fe_end = as_unwind_blks[hi].id;
            }
            spans.append(
                except_region(
                    start_block=epi_blks[hi].id,
                    end_block=fe_end,
                    handler_block=fin_except.id,
                    stack_depth=1
                )
            );
        }
        hi = hi + 1;
    }
    if not last_is_bare {
        spans.append(
            except_region(
                start_block=reraise_blk.id,
                end_block=inner_unwind.id,
                handler_block=inner_unwind.id,
                stack_depth=3,
                preserve_lasti=True
            )
        );
    }

    # Inline finally copy on fall-through paths: placed before the handlers when
    # the normal path reaches it, otherwise after the unwind chain with the
    # single-predecessor leading NOP CPython emits there.
    any_reaches_fin = fin_early;
    fi = 0;
    while fi < nh {
        if falls[fi] or nested_in[fi] {
            any_reaches_fin = True;
        }
        fi = fi + 1;
    }
    if any_reaches_fin {
        late_preds = 0;
        if not fin_early {
            fi = 0;
            while fi < nh {
                if falls[fi] or nested_in[fi] {
                    late_preds = late_preds + 1;
                }
                fi = fi + 1;
            }
        }
    }
    # Inner unwind chain -> exceptional finally handler. With a late inline
    # copy the range ends at the copy's leading NOP (unprotected, like
    # CPython); otherwise it runs to the fin handler itself. Registered
    # even when no path reaches an inline copy - CPython keeps this entry
    # defensively (the COPY/POP_EXCEPT/RERAISE sequence can itself fault).
    iu_span_end = fin_except.id;
    if not fin_early and any_reaches_fin {
        iu_span_end = fin_inline.id;
    }
    spans.append(
        except_region(
            start_block=inner_unwind.id,
            end_block=iu_span_end,
            handler_block=fin_except.id,
            stack_depth=1
        )
    );
    if any_reaches_fin {
        emit_finally_inline_block(
            g,
            t.finalbody,
            fin_inline,
            not fin_early and late_preds == 1,
            more_code_follows,
            tail,
            tail_idx,
            tloc
        );
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
    }

    # Exceptional finally handler: run finalbody under PUSH_EXC_INFO, re-raise.
    g.use(fin_except);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    fe_cont = visit_stmts(g, t.finalbody);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.emit_op(OP_RERAISE, 0, fe_cont.loc);
    g.use(outer_unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    spans.append(
        except_region(
            start_block=fin_except.id,
            end_block=outer_unwind.id,
            handler_block=outer_unwind.id,
            stack_depth=3,
            preserve_lasti=True
        )
    );

    merged = merge_except_spans(g, spans);
    mi = 0;
    while mi < len(merged) {
        g.u.except_regions.append(merged[mi]);
        mi = mi + 1;
    }
    return stmt_cont(loc=tloc, terminated=True);
}

# Lower try/except (typed handlers; optional finally deferred).
def visit_try(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    if t.finalbody is not None and len(t.finalbody) > 0 {
        if t.handlers is not None and len(t.handlers) > 0 {
            return visit_try_except_finally(
                g, t, more_code_follows, tail, tail_idx, tail_join
            );
        }
        return visit_try_finally(g, t, more_code_follows, tail, tail_idx, tail_join);
    }
    if t.handlers is None or len(t.handlers) == 0 {
        codegen_fail(g, "NotImplementedError", "try without except");
        return stmt_cont(loc=tloc);
    }
    g.u.nested_try_except_end = -1;
    nop_blk = g.new_block();
    g.u.nested_try_except_start = nop_blk.id;
    try_body = g.new_block();
    g.use(nop_blk);
    g.emit_op(OP_NOP, 0, tloc);
    g.use(try_body);
    protect_start = g.cur.id;
    try_follows = more_code_follows;
    if not try_follows and tail is not None and tail_idx < len(tail) {
        try_follows = True;
    }
    body_cont = visit_stmts(g, t.body, 0, try_follows, tail, tail_idx, tail_join);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    protect_end = g.new_block();
    after_try_epilogue = g.new_block();
    g.use(protect_end);
    g.use(after_try_epilogue);
    normal_terminated = body_cont.terminated;
    if t.orelse is not None and len(t.orelse) > 0 and not body_cont.terminated {
        else_cont = visit_stmts(g, t.orelse, 0, try_follows, tail, tail_idx, tail_join);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if else_cont.terminated {
            normal_terminated = True;
        }
    }
    body_fini_region_start: int = -1;
    if try_follows or g.handler_fallthrough_fin is not None {
        if g.handler_fallthrough_fin is not None
            and not normal_terminated
            and not try_follows {
            # Nested inside an enclosing handler: finish it inline (CPython
            # duplicates the enclosing handler epilogue on each success path).
            g.handler_fell_through = True;
            body_fini_region_start = g.cur.id;
            g.emit_op(OP_POP_EXCEPT, 0, body_cont.loc);
            if g.handler_fallthrough_bind is not None {
                emit_except_as_cleanup(
                    g, g.handler_fallthrough_bind as str, body_cont.loc
                );
            }
            if g.handler_fallthrough_backward {
                g.emit_jump(
                    OP_JUMP_BACKWARD_NO_INTERRUPT,
                    g.handler_fallthrough_fin.id,
                    body_cont.loc
                );
            } else {
                g.emit_jump(OP_JUMP_FORWARD, g.handler_fallthrough_fin.id, body_cont.loc);
            }
        } elif try_follows {
            tail_more = False;
            if tail is not None and tail_idx + 1 < len(tail) {
                tail_more = exec_tail_emits_code(tail, tail_idx + 1);
            }
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            if not tail_cont.terminated and not normal_terminated {
                emit_module_return(g, tail_cont.loc);
            }
        }
    } else {
        if not normal_terminated {
            emit_module_return(g, body_cont.loc);
        }
    }
    handler_entry = g.new_block();
    handler_body_entries: list[basicblock] = [];
    handler_tails: list[tuple[basicblock, basicblock]] = [];
    as_unwind_tails: list[tuple[basicblock, basicblock]] = [];
    next_handlers: list[basicblock] = [];
    hi = 0;
    while hi < len(t.handlers) {
        handler_body_entries.append(g.new_block());
        handler_tails.append((g.new_block(), g.new_block()));
        as_unwind_tails.append((g.new_block(), g.new_block()));
        if hi < len(t.handlers) - 1 {
            next_handlers.append(g.new_block());
        }
        hi = hi + 1;
    }
    reraise_blk = g.new_block();
    if body_is_try_finally_only(t.body) {
        if g.u.nested_try_finally_success_start >= 0
            and g.u.nested_try_finally_success_end >= 0 {
            g.u.except_regions.append(
                except_region(
                    start_block=g.u.nested_try_finally_success_start,
                    end_block=g.u.nested_try_finally_success_end,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
        if g.u.nested_try_finally_unwind_start >= 0 {
            g.u.except_regions.append(
                except_region(
                    start_block=g.u.nested_try_finally_unwind_start,
                    end_block=handler_entry.id,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
    } elif body_is_try_except_only(t.body) and g.u.nested_try_except_end >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=g.u.nested_try_except_end,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1
            )
        );
    } else {
        g.u.except_regions.append(
            except_region(
                start_block=protect_start,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1 + g.handler_nest_depth
            )
        );
    }
    noloc = no_loc();
    g.use(handler_entry);
    handler_region_start = handler_entry.id;
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    if body_fini_region_start >= 0 {
        # Inline enclosing-handler epilogue after the body: protected by the
        # enclosing finally handler (CPython: the POP_EXCEPT + jump-to-finally
        # range maps to the fin handler at base depth).
        g.u.except_regions.append(
            except_region(
                start_block=body_fini_region_start,
                end_block=handler_entry.id,
                handler_block=g.handler_fallthrough_fin_handler,
                stack_depth=1
            )
        );
    }
    hloc = try_handler_span(t.handlers[0]);
    need_reraise_except_region = False;
    merged_handler_unwind_start = -1;
    except_as_unwind_start = -1;
    nested_fini_starts: list[int] = [];
    nested_fini_ends: list[int] = [];
    hi = 0;
    while hi < len(t.handlers) {
        h = t.handlers[hi];
        if hi > 0 {
            g.use(next_handlers[hi - 1]);
            handler_region_start = g.cur.id;
        }
        hloc = try_handler_span(h);
        if h.type is None {
            # bare except: always matches, no CHECK_EXC_MATCH / POP_JUMP.
        } else {
            visit_expr(g, h.type);
            if codegen_busy(g) {
                return stmt_cont(loc=tloc);
            }
            g.emit_op(OP_CHECK_EXC_MATCH, 0, hloc);
            if hi < len(t.handlers) - 1 {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, next_handlers[hi].id, hloc);
            } else {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, reraise_blk.id, hloc);
            }
        }
        bind_name = h.name;
        if bind_name is not None {
            emit_name_store(g, bind_name, hloc);
        } else {
            g.emit_op(OP_POP_TOP, 0, hloc);
        }
        handler_body_start = handler_body_entries[hi].id;
        g.use(handler_body_entries[hi]);
        hbody = visit_stmts(g, h.body);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        handler_region_end = handler_tails[hi][0];
        handler_success = handler_tails[hi][1];
        g.use(handler_region_end);
        if not hbody.terminated {
            need_reraise_except_region = True;
            g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
            if bind_name is not None {
                emit_except_as_cleanup(g, bind_name, hbody.loc);
            }
            g.use(handler_success);
            if g.handler_fallthrough_fin is not None and not try_follows {
                # Nested in an enclosing handler: emit its epilogue inline
                # (second POP_EXCEPT + jump to finally) instead of returning.
                g.handler_fell_through = True;
                g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
                if g.handler_fallthrough_bind is not None {
                    emit_except_as_cleanup(
                        g, g.handler_fallthrough_bind as str, hbody.loc
                    );
                }
                if g.handler_fallthrough_backward {
                    g.emit_jump(
                        OP_JUMP_BACKWARD_NO_INTERRUPT,
                        g.handler_fallthrough_fin.id,
                        hbody.loc
                    );
                } else {
                    g.emit_jump(
                        OP_JUMP_FORWARD, g.handler_fallthrough_fin.id, hbody.loc
                    );
                }
            } else {
                emit_module_return(g, hbody.loc);
            }
        } else {
            if merged_handler_unwind_start < 0 {
                merged_handler_unwind_start = handler_region_start;
            }
        }
        if bind_name is not None {
            append_try_unwind_region(
                g,
                except_region(
                    start_block=handler_region_start,
                    end_block=handler_body_start,
                    handler_block=-1,
                    stack_depth=3 + g.handler_nest_depth,
                    preserve_lasti=True
                )
            );
            as_unwind = as_unwind_tails[hi][0];
            g.use(as_unwind);
            except_as_unwind_start = as_unwind.id;
            emit_except_as_cleanup(g, bind_name, hbody.loc);
            g.emit_op(OP_RERAISE, 1, hbody.loc);
            as_unwind_end = as_unwind_tails[hi][1];
            g.u.except_regions.append(
                except_region(
                    start_block=handler_body_start,
                    end_block=handler_region_end.id,
                    handler_block=as_unwind.id,
                    stack_depth=3 + g.handler_nest_depth,
                    preserve_lasti=True
                )
            );
        } else {
            if not hbody.terminated {
                if g.handler_fallthrough_fin is not None {
                    # Nested in an enclosing handler: CPython protects the match
                    # code AND the handler body with our own unwind (an
                    # exception in the body re-enters our cleanup path only up
                    # to the first POP_EXCEPT), then splits: the first
                    # POP_EXCEPT maps to the ENCLOSING try's cleanup and the
                    # inline epilogue maps to the fin handler.
                    append_try_unwind_region(
                        g,
                        except_region(
                            start_block=handler_region_start,
                            end_block=handler_region_end.id,
                            handler_block=-1,
                            stack_depth=3 + g.handler_nest_depth,
                            preserve_lasti=True
                        )
                    );
                    g.u.except_regions.append(
                        except_region(
                            start_block=handler_region_end.id,
                            end_block=handler_success.id,
                            handler_block=g.handler_enclosing_unwind,
                            stack_depth=3,
                            preserve_lasti=True
                        )
                    );
                    nested_fini_starts.append(handler_success.id);
                    if hi < len(t.handlers) - 1 {
                        nested_fini_ends.append(next_handlers[hi].id);
                    } else {
                        nested_fini_ends.append(-1);
                    }
                } else {
                    append_try_unwind_region(
                        g,
                        except_region(
                            start_block=handler_region_start,
                            end_block=handler_region_end.id,
                            handler_block=-1,
                            stack_depth=3 + g.handler_nest_depth,
                            preserve_lasti=True
                        )
                    );
                }
            }
        }
        hi = hi + 1;
    }
    last_is_bare = t.handlers[len(t.handlers) - 1].type is None;
    if not last_is_bare {
        g.use(reraise_blk);
        g.emit_op(OP_RERAISE, 0, hloc);
    }
    reraise_end = g.new_block();
    unwind_blk = g.new_block();
    nfi = 0;
    while nfi < len(nested_fini_starts) {
        fini_end = nested_fini_ends[nfi];
        if fini_end < 0 {
            # Last handler: the fin-protected epilogue ends at the no-match
            # reraise block (CPython L8..L9), not at the empty block after it.
            fini_end = reraise_blk.id;
        }
        g.u.except_regions.append(
            except_region(
                start_block=nested_fini_starts[nfi],
                end_block=fini_end,
                handler_block=g.handler_fallthrough_fin_handler,
                stack_depth=1
            )
        );
        nfi = nfi + 1;
    }
    if need_reraise_except_region {
        if except_as_unwind_start >= 0 {
            append_try_unwind_region(
                g,
                except_region(
                    start_block=except_as_unwind_start,
                    end_block=unwind_blk.id,
                    handler_block=-1,
                    stack_depth=3 + g.handler_nest_depth,
                    preserve_lasti=True
                )
            );
        } elif not last_is_bare {
            append_try_unwind_region(
                g,
                except_region(
                    start_block=reraise_blk.id,
                    end_block=reraise_end.id,
                    handler_block=-1,
                    stack_depth=3 + g.handler_nest_depth,
                    preserve_lasti=True
                )
            );
        }
    } else {
        append_try_unwind_region(
            g,
            except_region(
                start_block=merged_handler_unwind_start,
                end_block=unwind_blk.id,
                handler_block=-1,
                stack_depth=3 + g.handler_nest_depth,
                preserve_lasti=True
            )
        );
    }
    bind_try_unwind_handlers(g, unwind_blk.id);
    g.use(unwind_blk);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    # Publish this statement's last block for an enclosing try whose body is
    # exactly this try/except, so its body span starts after our regions.
    g.u.nested_try_except_end = unwind_blk.id;
    return stmt_cont(loc=tloc, terminated=True);
}

# Lower with (single item, optional_vars required).
def visit_with(
    g: cfg_builder,
    w: With,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    wloc = stmt_loc(w);
    if len(w.items) < 1 {
        codegen_fail(g, "SyntaxError", "with requires at least one item");
        return stmt_cont(loc=wloc);
    }
    noloc = no_loc();
    n = len(w.items);
    # --- enters: for each item, emit context-manager setup + bind target ---
    store_ids: list[int] = [];
    ei = 0;
    while ei < n {
        it = w.items[ei];
        cl = expr_loc(it.context_expr);
        visit_expr(g, it.context_expr);
        if codegen_busy(g) {
            return stmt_cont(loc=wloc);
        }
        g.emit_op(OP_COPY, 1, cl);
        g.emit_op(OP_LOAD_SPECIAL, 1, cl);
        g.emit_op(OP_SWAP, 2, cl);
        g.emit_op(OP_SWAP, 3, cl);
        g.emit_op(OP_LOAD_SPECIAL, 0, cl);
        g.emit_op(OP_CALL, 0, cl);
        if codegen_busy(g) {
            return stmt_cont(loc=wloc);
        }
        bind_blk = g.new_block();
        g.use(bind_blk);
        if it.optional_vars is None {
            g.emit_op(OP_POP_TOP, 0, cl);
        } else {
            visit_store_target_tos(g, it.optional_vars);
            if codegen_busy(g) {
                return stmt_cont(loc=wloc);
            }
        }
        store_ids.append(g.cur.id);
        ei = ei + 1;
    }
    # --- body ---
    with_body = g.new_block();
    g.use(with_body);
    with_follows = more_code_follows;
    if not with_follows and tail is not None and tail_idx < len(tail) {
        with_follows = True;
    }
    body_cont = visit_stmts(g, w.body, 0, with_follows, tail, tail_idx, tail_join);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    # --- inline __exit__ calls, innermost first (xs[k] is frame n-1-k) ---
    none_idx = g.u.add_const(py_none());
    xs: list[basicblock] = [];
    k = 0;
    while k < n {
        xblk = g.new_block();
        g.use(xblk);
        g.emit_op(OP_LOAD_CONST, none_idx, wloc);
        g.emit_op(OP_LOAD_CONST, none_idx, wloc);
        g.emit_op(OP_LOAD_CONST, none_idx, wloc);
        g.emit_op(OP_CALL, 3, wloc);
        g.emit_op(OP_POP_TOP, 0, wloc);
        xs.append(xblk);
        k = k + 1;
    }
    # normal-path continuation (after outermost inline exit)
    if with_follows {
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if not tail_cont.terminated {
            emit_module_return(g, tail_cont.loc);
        }
    } else {
        emit_module_return(g, body_cont.loc);
    }
    # --- cleanup handlers, innermost first (ws/ends/uns[k] is frame n-1-k) ---
    ws: list[basicblock] = [];
    ends: list[basicblock] = [];
    uns: list[basicblock] = [];
    k = 0;
    while k < n {
        i_frame = n - 1 - k;
        with_except = g.new_block();
        g.use(with_except);
        g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
        g.emit_op(OP_WITH_EXCEPT_START, 0, noloc);
        g.emit_op(OP_TO_BOOL, 0, noloc);
        suppressed = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_TRUE, suppressed.id, noloc);
        g.emit_op(OP_RERAISE, 2, noloc);
        g.use(suppressed);
        g.emit_op(OP_POP_TOP, 0, noloc);
        cleanup_end = g.new_block();
        g.use(cleanup_end);
        g.emit_op(OP_POP_EXCEPT, 0, noloc);
        g.emit_op(OP_POP_TOP, 0, noloc);
        g.emit_op(OP_POP_TOP, 0, noloc);
        g.emit_op(OP_POP_TOP, 0, noloc);
        if i_frame > 0 {
            # fall back to the enclosing frame's inline __exit__ (xs[k+1] = X_{i-1})
            g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, xs[k + 1].id, wloc);
        } else {
            emit_module_return(g, wloc);
        }
        unwind = g.new_block();
        g.use(unwind);
        g.emit_op(OP_COPY, 3, noloc);
        g.emit_op(OP_POP_EXCEPT, 0, noloc);
        g.emit_op(OP_RERAISE, 1, noloc);
        ws.append(with_except);
        ends.append(cleanup_end);
        uns.append(unwind);
        k = k + 1;
    }
    # --- exception regions (carved so the assembler emits them verbatim) ---
    i = 0;
    while i < n {
        s_i = store_ids[i];
        x_i = xs[n - 1 - i];
        w_i = ws[n - 1 - i];
        e_i = ends[n - 1 - i];
        u_i = uns[n - 1 - i];
        if i == n - 1 {
            # innermost: protected body
            g.u.except_regions.append(
                except_region(
                    start_block=s_i,
                    end_block=x_i.id,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
        } else {
            s_next = store_ids[i + 1];
            x_next = xs[n - 2 - i];
            e_next = ends[n - 2 - i];
            # enter of the next-inner item
            g.u.except_regions.append(
                except_region(
                    start_block=s_i,
                    end_block=s_next,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
            # inline __exit__ of the next-inner frame
            g.u.except_regions.append(
                except_region(
                    start_block=x_next.id,
                    end_block=x_i.id,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
            # cleanup tail + unwind of the next-inner frame
            g.u.except_regions.append(
                except_region(
                    start_block=e_next.id,
                    end_block=w_i.id,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
        }
        # this frame's own cleanup handler
        g.u.except_regions.append(
            except_region(
                start_block=w_i.id,
                end_block=e_i.id,
                handler_block=u_i.id,
                stack_depth=6 + 2 * i,
                preserve_lasti=True
            )
        );
        i = i + 1;
    }
    return stmt_cont(loc=wloc, terminated=True);
}

# Lower async with (single item, optional_vars required).
def visit_async_with(
    g: cfg_builder,
    w: AsyncWith,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    wloc = stmt_loc(w);
    if len(w.items) != 1 {
        codegen_fail(g, "NotImplementedError", "multiple with items not supported");
        return stmt_cont(loc=wloc);
    }
    item = w.items[0];
    cloc = expr_loc(item.context_expr);
    visit_expr(g, item.context_expr);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    g.emit_op(OP_COPY, 1, cloc);
    g.emit_op(OP_LOAD_SPECIAL, 3, cloc);
    g.emit_op(OP_SWAP, 2, cloc);
    g.emit_op(OP_SWAP, 3, cloc);
    g.emit_op(OP_LOAD_SPECIAL, 2, cloc);
    g.emit_op(OP_CALL, 0, cloc);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    enter_als = emit_await_send_loop_header(g, OP_GET_AWAITABLE, 1, 3, cloc);
    bind_blk = g.new_block();
    g.use(bind_blk);
    if item.optional_vars is None {
        g.emit_op(OP_POP_TOP, 0, cloc);
    } else {
        visit_store_target_tos(g, item.optional_vars);
        if codegen_busy(g) {
            return stmt_cont(loc=wloc);
        }
    }
    protect_start = bind_blk.id;
    with_body = g.new_block();
    g.use(with_body);
    with_follows = more_code_follows;
    if not with_follows and tail is not None and tail_idx < len(tail) {
        with_follows = True;
    }
    body_cont = visit_stmts(g, w.body, 0, with_follows, tail, tail_idx, tail_join);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    protect_end = g.new_block();
    g.use(protect_end);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, wloc);
    g.emit_op(OP_LOAD_CONST, none_idx, wloc);
    g.emit_op(OP_LOAD_CONST, none_idx, wloc);
    g.emit_op(OP_CALL, 3, wloc);
    exit_als = emit_await_send_loop_header(g, OP_GET_AWAITABLE, 2, 3, wloc);
    g.emit_op(OP_POP_TOP, 0, wloc);
    if with_follows {
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        if tail is not None and tail_idx < len(tail) {
            ts = tail[tail_idx];
            if isinstance(ts, Return) {
                visit_return_stmt(g, ts as Return, False, True);
            } else {
                tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
                if codegen_busy(g) {
                    return stmt_cont(loc=body_cont.loc);
                }
                if not tail_cont.terminated {
                    emit_module_return(g, tail_cont.loc);
                }
            }
        } else {
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            if not tail_cont.terminated {
                emit_module_return(g, tail_cont.loc);
            }
        }
    } else {
        emit_module_return(g, body_cont.loc);
    }
    (enter_ct, enter_cj) = emit_await_send_loop_footer(g, enter_als, cloc);
    emit_await_send_except_regions(
        g, enter_als, enter_ct, enter_cj, 5, -1, -1, bind_blk.id, 2, True
    );
    (exit_ct, exit_cj) = emit_await_send_loop_footer(g, exit_als, wloc);
    emit_await_send_except_regions(
        g, exit_als, exit_ct, exit_cj, 3, -1, protect_end.id, enter_cj.id, 2, True
    );
    g.u.except_regions.append(
        except_region(
            start_block=exit_ct.id,
            end_block=exit_cj.id,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    with_except = g.new_block();
    noloc = no_loc();
    g.use(with_except);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    g.emit_op(OP_WITH_EXCEPT_START, 0, noloc);
    (except_als, except_ct, except_cj) = emit_await_send_loop_inline_footer(
        g, OP_GET_AWAITABLE, 2, 3, noloc
    );
    g.use(except_als.end_send_blk);
    g.emit_op(OP_END_SEND, 0, noloc);
    g.emit_op(OP_TO_BOOL, 0, noloc);
    not_taken_blk = g.new_block();
    reraise_blk = g.new_block();
    suppressed = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_TRUE, suppressed.id, noloc);
    g.use(not_taken_blk);
    g.emit_op(OP_NOT_TAKEN, 0, noloc);
    g.use(reraise_blk);
    g.emit_op(OP_RERAISE, 2, noloc);
    g.use(suppressed);
    g.emit_op(OP_POP_TOP, 0, noloc);
    cleanup_end = g.new_block();
    g.use(cleanup_end);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_POP_TOP, 0, noloc);
    g.emit_op(OP_POP_TOP, 0, noloc);
    g.emit_op(OP_POP_TOP, 0, noloc);
    if with_follows and tail is not None and tail_idx < len(tail) {
        ts = tail[tail_idx];
        if isinstance(ts, Return) {
            visit_return_stmt(g, ts as Return, True);
        } else {
            emit_module_return(g, wloc);
        }
    } else {
        emit_module_return(g, wloc);
    }
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_end.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    unwind = g.new_block();
    g.u.except_regions.append(
        except_region(
            start_block=except_als.yield_blk.id,
            end_block=except_als.after_resume_blk.id,
            handler_block=except_ct.id,
            stack_depth=8,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=except_als.after_resume_blk.id,
            end_block=not_taken_blk.id,
            handler_block=unwind.id,
            stack_depth=6,
            preserve_lasti=True
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=protect_start,
            end_block=protect_end.id,
            handler_block=with_except.id,
            stack_depth=4,
            preserve_lasti=True
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=with_except.id,
            end_block=except_als.yield_blk.id,
            handler_block=unwind.id,
            stack_depth=6,
            preserve_lasti=True
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=reraise_blk.id,
            end_block=cleanup_end.id,
            handler_block=unwind.id,
            stack_depth=6,
            preserve_lasti=True
        )
    );
    g.use(unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    if with_follows {
        return stmt_cont(loc=wloc, next_si=len(tail), terminated=True);
    }
    return stmt_cont(loc=wloc, terminated=True);
}

# Lower assert (test + optional message).
def visit_assert_stmt(g: cfg_builder, a: Assert) -> stmt_cont {
    aloc = nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    test_loc = expr_loc(a.`test);
    visit_test_expr(g, a.`test, test_loc);
    if codegen_busy(g) {
        return stmt_cont(loc=aloc);
    }
    ok = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_TRUE, ok.id, test_loc);
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
    tail_join: basicblock | None = None
) -> stmt_cont {
    if len(stmts) == 0 or from_idx >= len(stmts) {
        return stmt_cont(loc=loc(1, 1, 0, 0));
    }
    last = stmt_loc(stmts[from_idx]);
    terminated = False;
    si = from_idx;
    while si < len(stmts) {
        follow = more_follows_after;
        if not follow {
            follow = exec_tail_emits_code(stmts, si + 1);
        }
        if not follow and tail is not None {
            follow = exec_tail_emits_code(tail, tail_idx);
        }
        cont = visit_stmt(g, stmts[si], follow, tail, tail_idx, tail_join);
        last = cont.loc;
        if cont.terminated {
            terminated = True;
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

# Lower a statement suffix once at the current block.
def visit_stmt_tail(
    g: cfg_builder, tail: list[stmt], from_idx: int, more_follows_after: bool = False
) -> stmt_cont {
    return visit_stmts(g, tail, from_idx, more_follows_after);
}

# Emit tail suffix and finish the module when CPython duplicates it per branch.
def emit_tail_and_finish(
    g: cfg_builder, tail: list[stmt], tail_idx: int, end_loc: cloc
) -> stmt_cont {
    tail_cont = visit_stmt_tail(g, tail, tail_idx);
    if codegen_busy(g) {
        return tail_cont;
    }
    emit_module_return(g, tail_cont.loc);
    return stmt_cont(loc=end_loc, next_si=len(tail), terminated=True);
}

obj match_pat_ctx {
    has stores: list[str],
        on_top: int,
        cleanup_blocks: list[basicblock],
        max_cleanup: int,
        allow_irrefutable: bool;
}


def match_subject_use_load_fast(g: cfg_builder, m: Match) -> bool {
    has_default = 0;
    if len(m.cases) > 1 {
        if match_pattern_wildcard(m.cases[len(m.cases) - 1].pattern) {
            has_default = 1;
        }
    }
    if len(m.cases) - has_default > 1 {
        return True;
    }
    ci = 0;
    while ci < len(m.cases) {
        raw = m.cases[ci].pattern;
        if isinstance(raw, MatchOr) and len((raw as MatchOr).patterns) > 1 {
            # Multi-alternative OR copies the subject per alternative, so it must
            # be owned (LOAD_FAST), not borrowed.
            return True;
        }
        p = match_pattern_unwrap_or(raw);
        if isinstance(p, MatchSequence) or isinstance(p, MatchMapping) {
            return True;
        }
        ci = ci + 1;
    }
    return False;
}

def match_emit_subject(g: cfg_builder, m: Match) {
    subj = m.subject;
    if isinstance(subj, Name) {
        n = subj as Name;
        tloc = nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset);
        name = codegen_mangle(g, n.id);
        fi = fast_local_index(g, name);
        if fi >= 0 {
            if match_subject_use_load_fast(g, m) {
                g.emit_op(OP_LOAD_FAST, fi, tloc);
            } else {
                g.emit_op(OP_LOAD_FAST_BORROW, fi, tloc);
            }
            return;
        }
    }
    visit_expr(g, subj);
}

obj match_case_start {
    has ctx: match_pat_ctx,
        next_arm: basicblock;
}

# Exact maximum fail-pop depth for a pattern entered with `on_top` extra stack
# items and `nstores` deferred capture names. Mirrors emit_match_pattern's
# on_top/stores accounting so cleanup blocks can be pre-allocated in layout order
# (block id order == layout order is assumed by the flowgraph). Returns
# (max_pops, nstores_after); max_pops is -1 when the pattern never jumps to fail.
def match_fail_levels(p: pattern, on_top: int, nstores: int) -> tuple[int, int] {
    p = match_pattern_unwrap_or(p);
    if isinstance(p, MatchValue) or isinstance(p, MatchSingleton) {
        return (on_top + nstores, nstores);
    }
    if isinstance(p, MatchAs) {
        ma = p as MatchAs;
        if ma.pattern is None {
            ns = nstores;
            if ma.name is not None {
                ns = nstores + 1;
            }
            return (-1, ns);
        }
        sub = match_fail_levels(ma.pattern, on_top + 1, nstores);
        ns2 = sub[1];
        if ma.name is not None {
            ns2 = ns2 + 1;
        }
        return (sub[0], ns2);
    }
    if isinstance(p, MatchSequence) {
        ms = p as MatchSequence;
        patterns = ms.patterns;
        size = len(patterns);
        star = -1;
        only_wildcard = True;
        pi = 0;
        while pi < size {
            pat = patterns[pi];
            if isinstance(pat, MatchStar) {
                star = pi;
                mst = pat as MatchStar;
                if mst.name is not None {
                    only_wildcard = False;
                }
            } elif not match_pattern_wildcard(pat) {
                only_wildcard = False;
            }
            pi = pi + 1;
        }
        d1 = (on_top + 1) + nstores;
        if star >= 0 {
            return (d1, nstores);
        }
        if only_wildcard or match_sequence_all_captures(patterns) {
            return (d1, nstores);
        }
        maxf = d1;
        cur = on_top + size;
        ns = nstores;
        pi = 0;
        while pi < size {
            cur = cur - 1;
            sub = match_fail_levels(patterns[pi], cur, ns);
            if sub[0] > maxf {
                maxf = sub[0];
            }
            ns = sub[1];
            pi = pi + 1;
        }
        return (maxf, ns);
    }
    if isinstance(p, MatchMapping) {
        mm = p as MatchMapping;
        mm_keys: list[expr] = mm.keys if mm.keys is not None else [];
        mm_patterns: list[pattern] = mm.patterns if mm.patterns is not None else [];
        size = len(mm_keys);
        d1 = (on_top + 1) + nstores;
        if size == 0 and mm.rest is None {
            return (d1, nstores);
        }
        maxf = d1;
        f2 = (on_top + 3) + nstores;
        if f2 > maxf {
            maxf = f2;
        }
        cur = on_top + size + 2;
        ns = nstores;
        pi = 0;
        while pi < size {
            cur = cur - 1;
            sub = match_fail_levels(mm_patterns[pi], cur, ns);
            if sub[0] > maxf {
                maxf = sub[0];
            }
            ns = sub[1];
            pi = pi + 1;
        }
        if mm.rest is not None {
            ns = ns + 1;
        }
        return (maxf, ns);
    }
    if isinstance(p, MatchClass) {
        mc = p as MatchClass;
        mc_patterns: list[pattern] = mc.patterns if mc.patterns is not None else [];
        mc_kwd: list[pattern] = mc.kwd_patterns if mc.kwd_patterns is not None else [];
        nargs = len(mc_patterns);
        nattrs = len(mc_kwd);
        total = nargs + nattrs;
        maxf = (on_top + 1) + nstores;
        cur = on_top + total;
        ns = nstores;
        i = 0;
        while i < total {
            cur = cur - 1;
            sp: pattern = mc_patterns[i] if i < nargs else mc_kwd[i - nargs];
            if not match_pattern_wildcard(sp) {
                sub = match_fail_levels(sp, cur, ns);
                if sub[0] > maxf {
                    maxf = sub[0];
                }
                ns = sub[1];
            }
            i = i + 1;
        }
        return (maxf, ns);
    }
    return (on_top + nstores, nstores);
}

def match_arm_cleanup_levels(p: pattern) -> int {
    res = match_fail_levels(p, 0, 0);
    if res[0] < 0 {
        return 0;
    }
    return res[0];
}

# Allocate `levels` cleanup blocks + next_arm so their block ids ascend in the
# exact layout order needed for fail-pop fallthrough chaining: the block reached
# by an N-deep fail pops N items across N contiguous blocks that fall through to
# next_arm. cleanup_blocks[i] is the target for a fail that must pop i+1 items.
def match_begin_case(g: cfg_builder, levels: int) -> match_case_start {
    # Deferred blocks: laid out at use() (CPython USE_LABEL) so the fail-pop chain
    # and next_arm land after the arm body, and after any deferred blocks a MatchOr
    # alternative emits. Placement order (not allocation order) is authoritative.
    cleanup: list[basicblock] = [];
    i = 0;
    while i < levels {
        blk = g.new_deferred_block();
        blk.exit_inline_ok = True;
        cleanup.append(blk);
        i = i + 1;
    }
    next_arm = g.new_deferred_block();
    next_arm.exit_inline_ok = True;
    ctx = match_pat_ctx(
        stores=[],
        on_top=0,
        cleanup_blocks=cleanup,
        max_cleanup=0,
        allow_irrefutable=False
    );
    return match_case_start(ctx=ctx, next_arm=next_arm);
}

def match_ensure_cleanup_blocks(g: cfg_builder, ctx: match_pat_ctx, n: int) {
    while len(ctx.cleanup_blocks) < n {
        blk = g.new_deferred_block();
        ctx.cleanup_blocks.append(blk);
    }
}

def match_jump_to_fail(
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, jump_op: int, loc: cloc
) {
    pops = ctx.on_top + len(ctx.stores);
    if pops > ctx.max_cleanup {
        ctx.max_cleanup = pops;
    }
    if pops == 0 {
        g.emit_jump(jump_op, next_arm.id, loc);
        return;
    }
    match_ensure_cleanup_blocks(g, ctx, pops);
    g.emit_jump(jump_op, ctx.cleanup_blocks[pops - 1].id, loc);
}

def match_emit_reset_fail_pop(
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, loc: cloc
) {
    idx = ctx.max_cleanup - 1;
    while idx >= 0 {
        g.use(ctx.cleanup_blocks[idx]);
        g.emit_op(OP_POP_TOP, 0, loc);
        idx = idx - 1;
    }
    g.use(next_arm);
    ctx.max_cleanup = 0;
}

def match_pattern_rotate(g: cfg_builder, loc: cloc, count: int) {
    while count > 1 {
        g.emit_op(OP_SWAP, count, loc);
        count = count - 1;
    }
}

def match_pattern_helper_store_name(
    g: cfg_builder, name: str | None, ctx: match_pat_ctx, loc: cloc
) -> bool {
    if name is None {
        g.emit_op(OP_POP_TOP, 0, loc);
        return True;
    }
    si = 0;
    while si < len(ctx.stores) {
        if ctx.stores[si] == name {
            codegen_fail(g, "SyntaxError", "multiple assignments to name in pattern");
            return False;
        }
        si = si + 1;
    }
    rot = ctx.on_top + len(ctx.stores) + 1;
    match_pattern_rotate(g, loc, rot);
    ctx.stores.append(name);
    return True;
}

def match_emit_case_stores(g: cfg_builder, ctx: match_pat_ctx, loc: cloc) {
    # Emit separate stores in capture order; optimize_swap_range folds adjacent
    # STORE_FAST pairs into STORE_FAST_STORE_FAST (and reorders via static swaps)
    # to match CPython's post-optimizer shape.
    n = len(ctx.stores);
    si = 0;
    while si < n {
        emit_name_store(g, ctx.stores[si], loc);
        si = si + 1;
    }
}

def emit_match_pattern_sub(
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    allow = ctx.allow_irrefutable;
    ctx.allow_irrefutable = True;
    ok = emit_match_pattern(g, p, ctx, next_arm, ploc);
    ctx.allow_irrefutable = allow;
    return ok;
}

def emit_match_pattern_value(
    g: cfg_builder, mv: MatchValue, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    visit_expr(g, mv.value);
    if codegen_busy(g) {
        return False;
    }
    oparg = compare_filter_oparg(CMP_EQ);
    g.emit_op(OP_COMPARE_OP, oparg, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    return True;
}

def emit_match_pattern_singleton(
    g: cfg_builder,
    ms: MatchSingleton,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    if ms.value is None {
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NOT_NONE, ploc);
        return True;
    }
    idx = g.u.add_const(ms.value);
    g.emit_op(OP_LOAD_CONST, idx, ploc);
    g.emit_op(OP_IS_OP, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    return True;
}

def emit_match_pattern_as(
    g: cfg_builder, ma: MatchAs, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    if ma.pattern is None {
        if not ctx.allow_irrefutable {
            if ma.name is not None {
                codegen_fail(
                    g,
                    "SyntaxError",
                    "name capture makes remaining patterns unreachable"
                );
                return False;
            }
            codegen_fail(
                g, "SyntaxError", "wildcard makes remaining patterns unreachable"
            );
            return False;
        }
        return match_pattern_helper_store_name(g, ma.name, ctx, ploc);
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_COPY, 1, ploc);
    if not emit_match_pattern(g, ma.pattern, ctx, next_arm, ploc) {
        return False;
    }
    ctx.on_top = ctx.on_top - 1;
    return match_pattern_helper_store_name(g, ma.name, ctx, ploc);
}

def match_sequence_all_captures(patterns: list[pattern]) -> bool {
    if len(patterns) == 0 {
        return False;
    }
    pi = 0;
    while pi < len(patterns) {
        p = match_pattern_unwrap_or(patterns[pi]);
        if not isinstance(p, MatchAs) {
            return False;
        }
        ma = p as MatchAs;
        if ma.pattern is not None or ma.name is None or ma.name == "_" {
            return False;
        }
        pi = pi + 1;
    }
    return True;
}

def match_emit_sequence_capture_stores(
    g: cfg_builder, patterns: list[pattern], ploc: cloc
) {
    n = len(patterns);
    if n == 2 {
        na = codegen_mangle(g, (match_pattern_unwrap_or(patterns[0]) as MatchAs).name);
        nb = codegen_mangle(g, (match_pattern_unwrap_or(patterns[1]) as MatchAs).name);
        fa = fast_local_index(g, na);
        fb = fast_local_index(g, nb);
        if fa >= 0 and fb >= 0 {
            pair = fa * 16 + fb;
            g.emit_op(OP_STORE_FAST_STORE_FAST, pair, ploc);
            return;
        }
    }
    pi = n - 1;
    while pi >= 0 {
        ma = match_pattern_unwrap_or(patterns[pi]) as MatchAs;
        emit_name_store(g, ma.name, ploc);
        pi = pi - 1;
    }
}

def match_star_capture_name(
    patterns: list[pattern], idx: int, star_idx: int
) -> str | None {
    if idx == star_idx {
        return (patterns[idx] as MatchStar).name;
    }
    return (match_pattern_unwrap_or(patterns[idx]) as MatchAs).name;
}

def match_seq_star_all_captures(patterns: list[pattern], star_idx: int) -> bool {
    if len(patterns) == 0 {
        return False;
    }
    pi = 0;
    while pi < len(patterns) {
        if pi == star_idx {
            mst = patterns[pi] as MatchStar;
            if mst.name is None or mst.name == "_" {
                return False;
            }
        } else {
            p = match_pattern_unwrap_or(patterns[pi]);
            if not isinstance(p, MatchAs) {
                return False;
            }
            ma = p as MatchAs;
            if ma.pattern is not None or ma.name is None or ma.name == "_" {
                return False;
            }
        }
        pi = pi + 1;
    }
    return True;
}

def match_emit_star_capture_stores(
    g: cfg_builder, patterns: list[pattern], star_idx: int, ploc: cloc
) {
    n = len(patterns);
    if n == 2 {
        na = codegen_mangle(g, match_star_capture_name(patterns, 0, star_idx));
        nb = codegen_mangle(g, match_star_capture_name(patterns, 1, star_idx));
        fa = fast_local_index(g, na);
        fb = fast_local_index(g, nb);
        if fa >= 0 and fb >= 0 {
            g.emit_op(OP_STORE_FAST_STORE_FAST, fa * 16 + fb, ploc);
            return;
        }
    }
    # UNPACK_EX leaves element[0] on top, so bind forward; opt_superinstructions
    # fuses the first adjacent STORE_FAST pair (matching CPython's left-to-right
    # STORE_FAST_STORE_FAST peephole, e.g. `[a,*mid,b]` -> (a,mid) + b).
    pi = 0;
    while pi < n {
        emit_name_store(g, match_star_capture_name(patterns, pi, star_idx), ploc);
        pi = pi + 1;
    }
}

# CPython pattern_helper_sequence_subscr: used when the star element is a bare
# wildcard (`*_`). The tail is dropped, so the fixed elements are read off the
# subject by index (nonnegative before the star, len-relative after it) rather
# than unpacked. The subject stays on the stack and is popped at the end.
def emit_match_sequence_subscr(
    g: cfg_builder,
    patterns: list[pattern],
    star_idx: int,
    next_arm: basicblock,
    ctx: match_pat_ctx,
    ploc: cloc
) -> bool {
    size = len(patterns);
    pi = 0;
    while pi < size {
        if pi == star_idx {
            pi = pi + 1;
            continue;
        }
        pat = patterns[pi];
        if match_pattern_wildcard(pat) {
            pi = pi + 1;
            continue;
        }
        g.emit_op(OP_COPY, 1, ploc);
        if pi < star_idx {
            idx_const = g.u.add_const(PyInt(t="int", val=pi));
            g.emit_op(OP_LOAD_CONST, idx_const, ploc);
        } else {
            g.emit_op(OP_GET_LEN, 0, ploc);
            neg_const = g.u.add_const(PyInt(t="int", val=size - pi));
            g.emit_op(OP_LOAD_CONST, neg_const, ploc);
            g.emit_op(OP_BINARY_OP, NB_SUBTRACT, ploc);
        }
        g.emit_op(OP_BINARY_OP, NB_SUBSCR, ploc);
        # The element value sits on top with the subject preserved below. A plain
        # capture stores it immediately (CPython emits a bare STORE_FAST here, no
        # rotate); nested sub-patterns fall back to the general on-stack path.
        up = match_pattern_unwrap_or(pat);
        if isinstance(up, MatchAs) and (up as MatchAs).pattern is None {
            emit_name_store(g, (up as MatchAs).name, ploc);
        } else {
            ctx.on_top = ctx.on_top + 1;
            if not emit_match_pattern_sub(g, pat, ctx, next_arm, ploc) {
                return False;
            }
            ctx.on_top = ctx.on_top - 1;
        }
        pi = pi + 1;
    }
    ctx.on_top = ctx.on_top - 1;
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}

def emit_match_pattern_sequence(
    g: cfg_builder,
    ms: MatchSequence,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    patterns = ms.patterns;
    size = len(patterns);
    star = -1;
    star_wild = 0;
    only_wildcard = 1;
    pi = 0;
    while pi < size {
        pat = patterns[pi];
        if isinstance(pat, MatchStar) {
            if star >= 0 {
                codegen_fail(
                    g, "SyntaxError", "multiple starred names in sequence pattern"
                );
                return False;
            }
            star = pi;
            mst = pat as MatchStar;
            if mst.name is None {
                star_wild = 1;
                only_wildcard = only_wildcard and 1;
            } else {
                only_wildcard = 0;
            }
            pi = pi + 1;
            continue;
        }
        if match_pattern_wildcard(pat) {
            only_wildcard = only_wildcard and 1;
        } else {
            only_wildcard = 0;
        }
        pi = pi + 1;
    }
    if star >= 0 {
        n_before = star;
        n_after = size - star - 1;
        n_fixed = n_before + n_after;
        ctx.on_top = ctx.on_top + 1;
        g.emit_op(OP_MATCH_SEQUENCE, 0, ploc);
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
        # CPython only checks the length when there is at least one fixed
        # element around the star; `[*rest]` skips the length guard entirely.
        if n_fixed > 0 {
            g.emit_op(OP_GET_LEN, 0, ploc);
            nfx_idx = g.u.add_const(PyInt(t="int", val=n_fixed));
            g.emit_op(OP_LOAD_CONST, nfx_idx, ploc);
            g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GE), ploc);
            match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
        }
        if only_wildcard {
            ctx.on_top = ctx.on_top - 1;
            g.emit_op(OP_POP_TOP, 0, ploc);
            return True;
        }
        if star_wild {
            # `[a, *_]`: the star swallows the tail without binding, so CPython
            # subscripts the fixed elements off the subject instead of unpacking.
            return emit_match_sequence_subscr(g, patterns, star, next_arm, ctx, ploc);
        }
        # Capture star: split the subject with UNPACK_EX (n_before | n_after<<8).
        ctx.on_top = ctx.on_top - 1;
        g.emit_op(OP_UNPACK_EX, n_before + n_after * 256, ploc);
        if match_seq_star_all_captures(patterns, star) {
            match_emit_star_capture_stores(g, patterns, star, ploc);
            return True;
        }
        ctx.on_top = ctx.on_top + size;
        pi = 0;
        while pi < size {
            ctx.on_top = ctx.on_top - 1;
            if pi == star {
                mst2 = patterns[pi] as MatchStar;
                if not match_pattern_helper_store_name(g, mst2.name, ctx, ploc) {
                    return False;
                }
            } else {
                if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
                    return False;
                }
            }
            pi = pi + 1;
        }
        return True;
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_MATCH_SEQUENCE, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    g.emit_op(OP_GET_LEN, 0, ploc);
    # CPython interns the length const (ADDOP_LOAD_CONST_NEW) and the optimizer
    # folds it to LOAD_SMALL_INT while keeping it in the pool, so later consts
    # (e.g. a following class pattern's attr-name tuple) keep CPython's indices.
    seq_sz_idx = g.u.add_const(PyInt(t="int", val=size));
    g.emit_op(OP_LOAD_CONST, seq_sz_idx, ploc);
    oparg = compare_oparg(CMP_EQ);
    g.emit_op(OP_COMPARE_OP, oparg, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    ctx.on_top = ctx.on_top - 1;
    if only_wildcard {
        g.emit_op(OP_POP_TOP, 0, ploc);
        return True;
    }
    if match_sequence_all_captures(patterns) {
        g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
        match_emit_sequence_capture_stores(g, patterns, ploc);
        return True;
    }
    g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
    ctx.on_top = ctx.on_top + size;
    pi = 0;
    while pi < size {
        ctx.on_top = ctx.on_top - 1;
        if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
            return False;
        }
        pi = pi + 1;
    }
    return True;
}

# CPython codegen_pattern_class. Emits the class-check, then unpacks the
# attribute tuple and matches sub-patterns. Positional patterns first, then
# keyword patterns (attr names carried in a const tuple for MATCH_CLASS).
def emit_match_pattern_class(
    g: cfg_builder, mc: MatchClass, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    cls_patterns: list[pattern] = mc.patterns if mc.patterns is not None else [];
    kwd_attrs: list[str] = mc.kwd_attrs if mc.kwd_attrs is not None else [];
    kwd_patterns: list[pattern] = mc.kwd_patterns
        if mc.kwd_patterns is not None
        else [];
    nargs = len(cls_patterns);
    nattrs = len(kwd_attrs);
    if nattrs != len(kwd_patterns) {
        codegen_fail(
            g,
            "SyntaxError",
            "kwd_attrs / kwd_patterns length mismatch in class pattern"
        );
        return False;
    }
    ai = 0;
    while ai < nattrs {
        aj = ai + 1;
        while aj < nattrs {
            if kwd_attrs[ai] == kwd_attrs[aj] {
                codegen_fail(
                    g,
                    "SyntaxError",
                    "attribute name repeated in class pattern: " + kwd_attrs[ai]
                );
                return False;
            }
            aj = aj + 1;
        }
        ai = ai + 1;
    }
    visit_expr(g, mc.cls);
    if codegen_busy(g) {
        return False;
    }
    attr_items: list[PyObj] = [];
    ki = 0;
    while ki < nattrs {
        attr_items.append(PyStr(t="str", val=kwd_attrs[ki]));
        ki = ki + 1;
    }
    names_idx = g.u.add_const(PyTuple(t="tuple", items=attr_items));
    g.emit_op(OP_LOAD_CONST, names_idx, ploc);
    g.emit_op(OP_MATCH_CLASS, nargs, ploc);
    g.emit_op(OP_COPY, 1, ploc);
    ctx.on_top = ctx.on_top + 1;
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NONE, ploc);
    total = nargs + nattrs;
    g.emit_op(OP_UNPACK_SEQUENCE, total, ploc);
    ctx.on_top = ctx.on_top + total - 1;
    i = 0;
    while i < total {
        ctx.on_top = ctx.on_top - 1;
        sp: pattern = cls_patterns[i] if i < nargs else kwd_patterns[i - nargs];
        if match_pattern_wildcard(sp) {
            g.emit_op(OP_POP_TOP, 0, ploc);
        } elif not emit_match_pattern_sub(g, sp, ctx, next_arm, ploc) {
            return False;
        }
        i = i + 1;
    }
    return True;
}

# CPython codegen_pattern_mapping. MATCH_MAPPING + length check, MATCH_KEYS
# against a key tuple, then sub-patterns on the values; **rest binds remaining
# items via the CPython dict-copy/delete idiom.
def emit_match_pattern_mapping(
    g: cfg_builder,
    mm: MatchMapping,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    keys: list[expr] = mm.keys if mm.keys is not None else [];
    patterns: list[pattern] = mm.patterns if mm.patterns is not None else [];
    size = len(keys);
    if size != len(patterns) {
        codegen_fail(
            g, "SyntaxError", "keys / patterns length mismatch in mapping pattern"
        );
        return False;
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_MATCH_MAPPING, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    if size == 0 and mm.rest is None {
        ctx.on_top = ctx.on_top - 1;
        g.emit_op(OP_POP_TOP, 0, ploc);
        return True;
    }
    if size > 0 {
        g.emit_op(OP_GET_LEN, 0, ploc);
        # CPython emits LOAD_CONST(size) (ADDOP_LOAD_CONST_NEW); rewrite_small_ints
        # folds it to LOAD_SMALL_INT but keeps the const in the pool, so later
        # consts (the key tuple) keep CPython's indices.
        sz_idx = g.u.add_const(PyInt(t="int", val=size));
        g.emit_op(OP_LOAD_CONST, sz_idx, ploc);
        g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GE), ploc);
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    }
    all_const = True;
    seen: list[PyObj] = [];
    ki = 0;
    while ki < size {
        key = keys[ki];
        if isinstance(key, Constant) {
            kv = (key as Constant).value;
            hk = kv.tp_hashkey();
            si = 0;
            while si < len(seen) {
                if seen[si].tp_hashkey() == hk {
                    codegen_fail(
                        g, "SyntaxError", "mapping pattern checks duplicate key"
                    );
                    return False;
                }
                si = si + 1;
            }
            seen.append(kv);
        } elif isinstance(key, Attribute) {
            all_const = False;
        } else {
            codegen_fail(
                g,
                "SyntaxError",
                "mapping pattern keys may only match literals and attribute lookups"
            );
            return False;
        }
        ki = ki + 1;
    }
    if all_const {
        key_items: list[PyObj] = [];
        ki = 0;
        while ki < size {
            key_items.append((keys[ki] as Constant).value);
            ki = ki + 1;
        }
        keys_idx = g.u.add_const(PyTuple(t="tuple", items=key_items));
        g.emit_op(OP_LOAD_CONST, keys_idx, ploc);
    } else {
        ki = 0;
        while ki < size {
            visit_expr(g, keys[ki]);
            if codegen_busy(g) {
                return False;
            }
            ki = ki + 1;
        }
        g.emit_op(OP_BUILD_TUPLE, size, ploc);
    }
    g.emit_op(OP_MATCH_KEYS, 0, ploc);
    ctx.on_top = ctx.on_top + 2;
    g.emit_op(OP_COPY, 1, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NONE, ploc);
    g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
    ctx.on_top = ctx.on_top + size - 1;
    pi = 0;
    while pi < size {
        ctx.on_top = ctx.on_top - 1;
        if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
            return False;
        }
        pi = pi + 1;
    }
    ctx.on_top = ctx.on_top - 2;
    if mm.rest is not None {
        g.emit_op(OP_BUILD_MAP, 0, ploc);
        g.emit_op(OP_SWAP, 3, ploc);
        g.emit_op(OP_DICT_UPDATE, 2, ploc);
        g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
        sz = size;
        while sz > 0 {
            g.emit_op(OP_COPY, 1 + sz, ploc);
            g.emit_op(OP_SWAP, 2, ploc);
            g.emit_op(OP_DELETE_SUBSCR, 0, ploc);
            sz = sz - 1;
        }
        return match_pattern_helper_store_name(g, mm.rest, ctx, ploc);
    }
    g.emit_op(OP_POP_TOP, 0, ploc);
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}

# Lower a multi-alternative MatchOr (CPython codegen_pattern_or). Each alternative
# copies the subject, tests it, and on success jumps to a shared `end`. On failure
# it falls to the next alternative (subject preserved underneath); the last
# alternative's failure pops the surviving subject and jumps to next_arm. `end`
# and the per-alternative entries are deferred blocks so they lay out after the
# preceding alternative bodies (allocation order != layout order). Captures inside
# alternatives (name permutation across arms) need a sequence/display subject to
# oracle-verify and are gated off until that slice lands.
def emit_match_pattern_or(
    g: cfg_builder, mo: MatchOr, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    end = g.new_deferred_block();
    end.exit_inline_ok = True;
    size = len(mo.patterns);
    outer_allow = ctx.allow_irrefutable;
    i = 0;
    while i < size {
        alt = mo.patterns[i];
        is_last = i == size - 1;
        alt_fail = g.new_deferred_block();
        g.emit_op(OP_COPY, 1, ploc);
        alt_ctx = match_pat_ctx(
            stores=[],
            on_top=0,
            cleanup_blocks=[],
            max_cleanup=0,
            allow_irrefutable=is_last and outer_allow
        );
        if not emit_match_pattern(g, alt, alt_ctx, alt_fail, ploc) {
            return False;
        }
        if codegen_busy(g) {
            return False;
        }
        if len(alt_ctx.stores) != 0 {
            codegen_fail(
                g, "NotImplementedError", "capture inside match-or alternative"
            );
            return False;
        }
        g.emit_jump(OP_JUMP_FORWARD, end.id, ploc);
        g.use(alt_fail);
        if is_last {
            # Total failure: pop the subject copy that survived every alternative,
            # then continue to the arm's fail target.
            g.emit_op(OP_POP_TOP, 0, ploc);
            g.emit_jump(OP_JUMP_FORWARD, next_arm.id, ploc);
        }
        i = i + 1;
    }
    g.use(end);
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}

def emit_match_pattern(
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        if len(mo.patterns) > 1 {
            return emit_match_pattern_or(g, mo, ctx, next_arm, ploc);
        }
    }
    p = match_pattern_unwrap_or(p);
    if isinstance(p, MatchValue) {
        return emit_match_pattern_value(g, p as MatchValue, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchSingleton) {
        return emit_match_pattern_singleton(
            g, p as MatchSingleton, ctx, next_arm, ploc
        );
    }
    if isinstance(p, MatchAs) {
        return emit_match_pattern_as(g, p as MatchAs, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchSequence) {
        return emit_match_pattern_sequence(g, p as MatchSequence, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchClass) {
        return emit_match_pattern_class(g, p as MatchClass, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchMapping) {
        return emit_match_pattern_mapping(g, p as MatchMapping, ctx, next_arm, ploc);
    }
    codegen_fail(g, "NotImplementedError", "unsupported match pattern");
    return False;
}

# Lower match (CPython codegen_match_inner shape; slice 1–3 patterns + guards).
def visit_match(
    g: cfg_builder,
    m: Match,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    mloc = stmt_loc(m);
    if len(m.cases) == 0 {
        return stmt_cont(loc=mloc);
    }
    match_emit_subject(g, m);
    if codegen_busy(g) {
        return stmt_cont(loc=mloc);
    }
    has_default = 0;
    if len(m.cases) > 1 {
        last_pat = m.cases[len(m.cases) - 1].pattern;
        if match_pattern_wildcard(last_pat) {
            has_default = 1;
        }
    }
    join_blk = tail_join;
    owns_join = False;
    if more_code_follows {
        if join_blk is None {
            join_blk = g.new_deferred_block();
            join_blk.exit_inline_ok = True;
            owns_join = True;
        }
    }
    match_end = join_blk;
    owns_match_end = False;
    if match_end is None {
        match_end = g.new_deferred_block();
        match_end.exit_inline_ok = True;
        owns_match_end = True;
    }
    body_follows = more_code_follows;
    if not body_follows and tail is not None and tail_idx < len(tail) {
        body_follows = True;
    }
    loop_end = len(m.cases) - has_default;
    terminated = False;
    ci = 0;
    while ci < loop_end {
        arm = m.cases[ci];
        ploc = match_pattern_loc(arm.pattern);
        start = match_begin_case(g, match_arm_cleanup_levels(arm.pattern));
        ctx = start.ctx;
        next_arm = start.next_arm;
        if ci != loop_end - 1 {
            g.emit_op(OP_COPY, 1, ploc);
        }
        ctx.allow_irrefutable = arm.guard is not None or ci == loop_end - 1;
        opt_lo = len(g.cur.instrs);
        if not emit_match_pattern(g, arm.pattern, ctx, next_arm, ploc) {
            return stmt_cont(loc=mloc);
        }
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        match_emit_case_stores(g, ctx, ploc);
        # Fold the arm's naive rotate (SWAP) + separate stores into CPython's
        # optimized shape (swaptimize + static swaps + STORE_FAST_STORE_FAST).
        optimize_swap_range(g.cur, opt_lo);
        if arm.guard is not None {
            gloc = expr_loc(arm.guard);
            visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            g.emit_jump(OP_POP_JUMP_IF_FALSE, next_arm.id, gloc);
        }
        if ci != loop_end - 1 {
            g.emit_op(OP_POP_TOP, 0, ploc);
        }
        body_cont = visit_stmts(g, arm.body, 0, body_follows, tail, tail_idx, join_blk);
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        if body_cont.terminated {
            terminated = True;
        } else {
            g.emit_jump(OP_JUMP_FORWARD, match_end.id, ploc);
        }
        match_emit_reset_fail_pop(g, ctx, next_arm, ploc);
        ci = ci + 1;
    }
    if has_default {
        arm = m.cases[len(m.cases) - 1];
        ploc = match_pattern_loc(arm.pattern);
        if len(m.cases) == 1 {
            g.emit_op(OP_POP_TOP, 0, ploc);
        } else {
            g.emit_op(OP_NOP, 0, ploc);
        }
        if arm.guard is not None {
            gloc = expr_loc(arm.guard);
            visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            g.emit_jump(OP_POP_JUMP_IF_FALSE, match_end.id, gloc);
        }
        body_cont = visit_stmts(g, arm.body, 0, body_follows, tail, tail_idx, join_blk);
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        if body_cont.terminated {
            terminated = True;
        }
    }
    if owns_match_end {
        g.use(match_end);
        if not more_code_follows and not terminated {
            emit_module_return(g, mloc);
            terminated = True;
        }
    }
    if owns_join and join_blk is not None {
        g.use(join_blk);
        tail_more = exec_tail_emits_code(tail, tail_idx);
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(
            loc=tail_cont.loc,
            next_si=len(tail),
            terminated=terminated or tail_cont.terminated
        );
    }
    return stmt_cont(loc=mloc, terminated=terminated);
}




def visit_if(
    g: cfg_builder,
    i: If,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    tail_join: basicblock | None = None
) -> stmt_cont {
    iloc = nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    test_loc = expr_loc(i.`test);
    kind = visit_test_expr(g, i.`test, test_loc, True);
    if codegen_busy(g) {
        return stmt_cont(loc=iloc);
    }
    false_blk = g.new_block();
    has_else = len(i.orelse) > 0;
    if more_code_follows {
        tail_more = exec_tail_emits_code(tail, tail_idx);
        if has_else {
            if tail_more {
                join = g.new_block();
                emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
                body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx);
                if codegen_busy(g) {
                    return stmt_cont(loc=body_cont.loc);
                }
                if not body_cont.terminated {
                    g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
                }
                g.use(false_blk);
                else_cont = visit_stmts(g, i.orelse, 0, False, tail, tail_idx);
                if codegen_busy(g) {
                    return stmt_cont(loc=else_cont.loc);
                }
                g.use(join);
                tail_cont = visit_stmt_tail(
                    g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1)
                );
                return stmt_cont(
                    loc=tail_cont.loc,
                    next_si=len(tail),
                    terminated=tail_cont.terminated
                );
            }
            # tail_more is False but more_code_follows is True: the real
            # continuation is in the CALLER's own statement list, not in `tail`
            # (which is empty/exhausted here). This branch is only reached from
            # visit_stmts-style callers -- the compile_fn_cfg/module driver
            # always has more_code_follows == tail_more, so it never lands here.
            # Converge both branches at `join` and return next_si=-1 so the
            # caller emits its following statements. Using emit_tail_and_finish
            # here would append a module return AND return next_si=len(tail)=0,
            # resetting the caller's index -> infinite loop on
            # `if c: return; if d: ... else: ...; <more>`.
            join = g.new_block();
            emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
            body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            if not body_cont.terminated {
                g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
            }
            g.use(false_blk);
            else_cont = visit_stmts(g, i.orelse, 0, False, tail, tail_idx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            g.use(join);
            return stmt_cont(loc=iloc);
        }
        join = tail_join;
        owns_tail = False;
        if join is None {
            join = g.new_block();
            owns_tail = True;
        }
        emit_branch_if_test_false(g, kind, join.id, test_loc);
        body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx, join);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if owns_tail {
            g.use(join);
            if tail_more {
                tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
                return stmt_cont(
                    loc=tail_cont.loc,
                    next_si=len(tail),
                    terminated=tail_cont.terminated
                );
            }
            # No code in `tail` to duplicate: the real continuation lives in the
            # caller's own statement list (e.g. visit_stmts over a loop body).
            # Fall through at `join` and let the caller emit its following
            # statements. Returning next_si=len(tail)=0 here would reset the
            # caller's index to 0 -> infinite loop (hangs `while: if c: break; more`).
            return stmt_cont(loc=body_cont.loc);
        }
        return stmt_cont(loc=body_cont.loc);
    }
    # more_code_follows == False: nothing follows this if in the current
    # statement list. Two sub-cases, distinguished by `tail`:
    #
    # (a) tail is None -- a loop body (or other back-edge context): the
    #     continuation is the loop's JUMP_BACKWARD, not a return. Fall through and
    #     let the enclosing loop emit the back-edge; never synthesize a return.
    #
    # (b) tail is not None -- the function/module/compound tail: CPython
    #     DUPLICATES the implicit `return None` into each falling-through branch
    #     (verified: `if a in xs: r=1` emits a return after the true body AND at
    #     the false label). Preserve that duplication, but skip the return after a
    #     branch that already terminates (return/raise/continue) -- emitting one
    #     there is dead code after a terminator ("Invalid CFG").
    if tail is None {
        emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
        body_cont = visit_stmts(g, i.body);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if has_else {
            join = None;
            if not body_cont.terminated {
                join = g.new_block();
                g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
            }
            g.use(false_blk);
            else_cont = visit_stmts(g, i.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            if join is not None {
                g.use(join);
                return stmt_cont(loc=iloc, terminated=False);
            }
            return stmt_cont(loc=iloc, terminated=else_cont.terminated);
        }
        g.use(false_blk);
        return stmt_cont(loc=iloc, terminated=False);
    }
    emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
    body_cont = visit_stmts(g, i.body);
    if codegen_busy(g) {
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        emit_module_return(g, body_cont.loc);
    }
    g.use(false_blk);
    if has_else {
        else_cont = visit_stmts(g, i.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        if not else_cont.terminated {
            emit_module_return(g, else_cont.loc);
        }
    } else {
        emit_module_return(g, test_loc);
    }
    return stmt_cont(loc=iloc, terminated=True);
}

def visit_while(
    g: cfg_builder, w: While, more_code_follows: bool, tail: list[stmt], tail_idx: int
) -> stmt_cont {
    wloc = nloc(w.lineno, w.end_lineno, w.col_offset, w.end_col_offset);
    test_loc = expr_loc(w.`test);
    head = g.new_block();
    g.use(head);
    kind = visit_test_expr(g, w.`test, test_loc, True);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    has_break = loop_body_has_break(w.body);
    if more_code_follows {
        exit_blk = g.new_block();
        emit_branch_if_test_false(g, kind, exit_blk.id, test_loc);
        break_blk = g.new_block();
        g.push_loop(head, break_blk, has_break);
        body_cont = visit_stmts(g, w.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
        }
        g.pop_loop();
        tail_more = exec_tail_emits_code(tail, tail_idx);
        if has_break {
            g.use(break_blk);
            g.emit_op(OP_NOP, 0, wloc);
            if tail_more {
                g.emit_jump(OP_JUMP_FORWARD, exit_blk.id, wloc);
            } else {
                br_cont = emit_tail_and_finish(g, tail, tail_idx, wloc);
                if codegen_busy(g) {
                    return br_cont;
                }
            }
        }
        g.use(exit_blk);
        else_terminated = False;
        if len(w.orelse) > 0 {
            else_cont = visit_stmts(g, w.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            else_terminated = else_cont.terminated;
        }
        if has_break and not tail_more {
            return stmt_cont(loc=wloc, next_si=len(tail), terminated=True);
        }
        if else_terminated and not has_break {
            # Normal loop exit runs the else, which terminates; with no break
            # there is no path to the trailing statements, so they are
            # unreachable. CPython drops them (DCE); emitting them here would be
            # dead code after a terminator ("Invalid CFG").
            return stmt_cont(loc=wloc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    if len(g.loop_stack) > 0 {
        after_body = g.new_block();
        emit_branch_if_test_false(g, kind, after_body.id, test_loc);
        if has_break {
            break_blk = g.new_block();
            g.push_loop(head, break_blk, True);
        } else {
            g.push_loop(head, after_body, False);
        }
        body_cont = visit_stmts(g, w.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
        }
        g.pop_loop();
        if has_break {
            g.use(break_blk);
            g.emit_jump(OP_JUMP_BACKWARD, after_body.id, wloc);
        }
        g.use(after_body);
        return stmt_cont(loc=wloc, terminated=False);
    }
    emit_branch_if_test_false(g, kind, 0, test_loc);
    pop_false_ins = g.cur.instrs[len(g.cur.instrs) - 1];
    g.push_loop(head, head, False);
    body_cont = visit_stmts(g, w.body);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
    }
    g.pop_loop();
    exit_blk = g.new_block();
    pop_false_ins.target_block = exit_blk.id;
    g.use(exit_blk);
    if len(w.orelse) > 0 {
        else_cont = visit_stmts(g, w.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, test_loc);
    }
    return stmt_cont(loc=wloc, terminated=True);
}


def visit_for(
    g: cfg_builder, f: For, more_code_follows: bool, tail: list[stmt], tail_idx: int
) -> stmt_cont {
    floc = nloc(f.lineno, f.end_lineno, f.col_offset, f.end_col_offset);
    iter_loc = expr_loc(f.iter);
    visit_expr(g, f.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_ITER, 0, iter_loc);
    loop_hdr = g.new_block();
    g.use(loop_hdr);
    after = g.new_block();
    has_break = loop_body_has_break(f.body);
    if more_code_follows {
        break_blk = g.new_block();
        g.push_loop(loop_hdr, break_blk, has_break);
        g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
        store = visit_store_target_tos(g, f.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_cont = visit_stmts(g, f.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
        }
        g.pop_loop();
        tail_more = exec_tail_emits_code(tail, tail_idx);
        if has_break {
            g.use(break_blk);
            g.emit_op(OP_POP_TOP, 0, iter_loc);
            if tail_more {
                g.emit_jump(OP_JUMP_FORWARD, after.id, iter_loc);
            } else {
                br_cont = emit_tail_and_finish(g, tail, tail_idx, floc);
                if codegen_busy(g) {
                    return br_cont;
                }
            }
        }
        g.use(after);
        g.emit_op(OP_END_FOR, 0, iter_loc);
        g.emit_op(OP_POP_ITER, 0, iter_loc);
        else_terminated = False;
        if len(f.orelse) > 0 {
            else_cont = visit_stmts(g, f.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            else_terminated = else_cont.terminated;
        }
        if has_break and not tail_more {
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        if else_terminated and not has_break {
            # Normal loop exit runs the else, which terminates; with no break
            # there is no path to the trailing statements, so they are
            # unreachable. CPython drops them (DCE); emitting them here would be
            # dead code after a terminator ("Invalid CFG").
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    break_blk = after;
    needs_break_stub = has_break;
    if needs_break_stub {
        break_blk = g.new_block();
    }
    g.push_loop(loop_hdr, break_blk, needs_break_stub);
    g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
    store = visit_store_target_tos(g, f.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_cont = visit_stmts(g, f.body);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
    }
    g.pop_loop();
    if needs_break_stub {
        g.use(break_blk);
        g.emit_op(OP_POP_TOP, 0, iter_loc);
        emit_module_return(g, iter_loc);
    }
    g.use(after);
    g.emit_op(OP_END_FOR, 0, iter_loc);
    g.emit_op(OP_POP_ITER, 0, iter_loc);
    if len(f.orelse) > 0 {
        else_cont = visit_stmts(g, f.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, iter_loc);
    }
    return stmt_cont(loc=floc, terminated=True);
}

def visit_async_for(
    g: cfg_builder,
    af: AsyncFor,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int
) -> stmt_cont {
    floc = nloc(af.lineno, af.end_lineno, af.col_offset, af.end_col_offset);
    iter_loc = expr_loc(af.iter);
    visit_expr(g, af.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    loop_hdr = g.new_block();
    has_break = loop_body_has_break(af.body);
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);
    if more_code_follows {
        store_blk = g.new_block();
        g.use(store_blk);
        g.emit_op(OP_NOT_TAKEN, 0, iter_loc);
        break_tgt = loop_hdr;
        if has_break {
            break_tgt = g.new_block();
        }
        g.push_loop(loop_hdr, break_tgt, has_break);
        store = visit_store_target_tos(g, af.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_cont = visit_stmts(g, af.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
        }
        g.pop_loop();
        (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
        end_async_handler = g.new_block();
        emit_anext_send_except_regions(
            g, als, store_blk, cleanup_throw, cleanup_jump, end_async_handler
        );
        g.u.except_regions.append(
            except_region(
                start_block=store_blk.id,
                end_block=cleanup_throw.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        tail_more = exec_tail_emits_code(tail, tail_idx);
        after = g.new_block();
        if has_break {
            g.use(break_tgt);
            g.emit_op(OP_POP_TOP, 0, iter_loc);
            if tail_more {
                g.emit_jump(OP_JUMP_FORWARD, after.id, iter_loc);
            } else {
                br_cont = emit_tail_and_finish(g, tail, tail_idx, floc);
                if codegen_busy(g) {
                    return br_cont;
                }
            }
        }
        g.use(end_async_handler);
        g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);
        g.async_for_end_async_block = end_async_handler.id;
        g.u.except_regions.append(
            except_region(
                start_block=end_async_handler.id,
                end_block=-1,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        g.use(after);
        if len(af.orelse) > 0 {
            else_cont = visit_stmts(g, af.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
        }
        if has_break and not tail_more {
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    needs_break_stub = has_break;
    store_blk = g.new_block();
    g.use(store_blk);
    g.emit_op(OP_NOT_TAKEN, 0, iter_loc);
    break_tgt = loop_hdr;
    if needs_break_stub {
        break_tgt = g.new_block();
    }
    g.push_loop(loop_hdr, break_tgt, needs_break_stub);
    store = visit_store_target_tos(g, af.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_cont = visit_stmts(g, af.body);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
    }
    g.pop_loop();
    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    emit_anext_send_except_regions(
        g, als, store_blk, cleanup_throw, cleanup_jump, end_async_handler
    );
    g.u.except_regions.append(
        except_region(
            start_block=store_blk.id,
            end_block=cleanup_throw.id,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if needs_break_stub {
        g.use(break_tgt);
        g.emit_op(OP_POP_TOP, 0, iter_loc);
        emit_module_return(g, iter_loc);
    }
    after = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);
    g.async_for_end_async_block = end_async_handler.id;
    g.u.except_regions.append(
        except_region(
            start_block=end_async_handler.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    g.use(after);
    if len(af.orelse) > 0 {
        else_cont = visit_stmts(g, af.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, iter_loc);
    }
    return stmt_cont(loc=floc, terminated=True);
}


# CPython's import prefix keeps int 0 in co_consts even though level uses
# LOAD_SMALL_INT (same dead-small-int slot as literal folding).
def ensure_import_prefix_consts(g: cfg_builder) {
    # Same dead-small-int rule: 0 is kept only at const index 0 (pool empty).
    if len(g.u.consts) == 0 {
        g.u.add_const(PyInt(t="int", val=0));
        g.u.dead_small_int_const = True;
    }
}

# LOAD_SMALL_INT level, LOAD_CONST fromlist, IMPORT_NAME modname (CPython import).
def emit_import_name_call(
    g: cfg_builder, modname: str, level: int, fromlist: PyObj | None, iloc: cloc
) {
    ensure_import_prefix_consts(g);
    emit_folded_int(g, level, iloc);
    if fromlist is None {
        none_idx = g.u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, none_idx, iloc);
    } else {
        fl_idx = g.u.add_const(fromlist);
        g.emit_op(OP_LOAD_CONST, fl_idx, iloc);
    }
    midx = g.u.add_name(modname);
    g.emit_op(OP_IMPORT_NAME, midx, iloc);
}

def visit_import(g: cfg_builder, imp: Import) -> stmt_cont {
    iloc = nloc(imp.lineno, imp.end_lineno, imp.col_offset, imp.end_col_offset);
    ni = 0;
    while ni < len(imp.names) {
        a = imp.names[ni];
        emit_import_name_call(g, a.name, 0, None, iloc);
        emit_name_store(g, import_bind_name(a), iloc);
        ni = ni + 1;
    }
    return stmt_cont(loc=iloc);
}

def visit_import_from(g: cfg_builder, imp: ImportFrom) -> stmt_cont {
    iloc = nloc(imp.lineno, imp.end_lineno, imp.col_offset, imp.end_col_offset);
    level = 0;
    if imp.level is not None {
        level = imp.level;
    }
    modname = "";
    if imp.module is not None {
        modname = imp.module;
    }
    names: list[PyObj] = [];
    ni = 0;
    while ni < len(imp.names) {
        names.append(PyStr(t="str", val=imp.names[ni].name));
        ni = ni + 1;
    }
    fromlist = PyTuple(t="tuple", items=names);
    emit_import_name_call(g, modname, level, fromlist, iloc);
    ni = 0;
    while ni < len(imp.names) {
        a = imp.names[ni];
        fidx = g.u.add_name(a.name);
        g.emit_op(OP_IMPORT_FROM, fidx, iloc);
        emit_name_store(g, import_bind_name(a), iloc);
        ni = ni + 1;
    }
    g.emit_op(OP_POP_TOP, 0, iloc);
    return stmt_cont(loc=iloc);
}

# Lower one statement into the builder's current block.
def visit_stmt(
    g: cfg_builder,
    s: stmt,
    more_code_follows: bool = False,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
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
    # PEP 649 (3.14): function-local annotations are never evaluated at run
    # time -- the host oracle emits only the assignment side (bare annotation
    # emits nothing). Module/class scopes instead emit a deferred __annotate__
    # code object plus __conditional_annotations__ bookkeeping; until that
    # slice lands, fail loudly rather than emit silently-wrong bytes.
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        if g.sym_top is None or g.sym_top.block_type != "function" {
            codegen_fail(
                g,
                "NotImplementedError",
                "module/class-scope annotation (__annotate__) not yet supported"
            );
            return stmt_cont(loc=stmt_loc(s));
        }
        if an.value is None {
            return stmt_cont(loc=stmt_loc(s));
        }
        visit_expr(g, an.value);
        if codegen_busy(g) {
            return stmt_cont(loc=stmt_loc(s));
        }
        emit = visit_store_target_tos(g, an.target);
        return stmt_cont(loc=emit.loc);
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
            g.emit_op(OP_POP_TOP, 0, eloc);
            after = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, after.id, eloc);
            emit_compare_cleanup(g, cmp_cleanup, cloc_call);
            if len(call_effective_keywords(ca)) > 0 {
                emit_call_keyword_values(g, ca, cloc_call);
            }
            emit_call_instruction(g, ca, cloc_call);
            g.emit_op(OP_POP_TOP, 0, eloc);
            g.use(after);
        } elif cmp_cleanup is not None {
            g.emit_op(OP_POP_TOP, 0, eloc);
            after = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, after.id, eloc);
            emit_compare_cleanup(g, cmp_cleanup, eloc);
            g.emit_op(OP_POP_TOP, 0, eloc);
            g.use(after);
        } else {
            g.emit_op(OP_POP_TOP, 0, eloc);
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
        t = tail;
        if t is None {
            t = [];
        }
        return visit_if(g, s as If, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, While) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_while(g, s as While, more_code_follows, t, tail_idx);
    }
    if isinstance(s, For) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_for(g, s as For, more_code_follows, t, tail_idx);
    }
    if isinstance(s, AsyncFor) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_async_for(g, s as AsyncFor, more_code_follows, t, tail_idx);
    }
    if isinstance(s, Break) {
        b = s as Break;
        bloc = stmt_loc(b);
        frame = g.current_loop();
        if frame is None {
            codegen_fail(g, "SyntaxError", "'break' outside loop");
            return stmt_cont(loc=bloc);
        }
        if frame.break_is_stub {
            g.emit_jump(OP_JUMP_FORWARD, frame.break_blk.id, bloc);
        } else {
            emit_module_return(g, bloc);
        }
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
        g.emit_jump(OP_JUMP_BACKWARD, frame.continue_blk.id, cloc_stmt);
        return stmt_cont(loc=cloc_stmt, terminated=True);
    }
    if isinstance(s, Return) {
        visit_return_stmt(g, s as Return);
        return stmt_cont(loc=stmt_loc(s), terminated=True);
    }
    if isinstance(s, FunctionDef) {
        return visit_function_def(g, s as FunctionDef);
    }
    if isinstance(s, AsyncFunctionDef) {
        return visit_async_function_def(g, s as AsyncFunctionDef);
    }
    if isinstance(s, ClassDef) {
        return visit_class_def(g, s as ClassDef);
    }
    if isinstance(s, Import) {
        return visit_import(g, s as Import);
    }
    if isinstance(s, ImportFrom) {
        return visit_import_from(g, s as ImportFrom);
    }
    if isinstance(s, Try) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_try(g, s as Try, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, Raise) {
        return visit_raise_stmt(g, s as Raise);
    }
    if isinstance(s, With) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_with(g, s as With, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, AsyncWith) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_async_with(
            g, s as AsyncWith, more_code_follows, t, tail_idx, tail_join
        );
    }
    if isinstance(s, Match) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_match(g, s as Match, more_code_follows, t, tail_idx, tail_join);
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
    rloc = nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    if r.value is not None {
        if isinstance(r.value, Name) {
            n = r.value as Name;
            name = codegen_mangle(g, n.id);
            fi = fast_local_index(g, name);
            if fi >= 0 {
                if check_fast {
                    g.emit_op(OP_LOAD_FAST_CHECK, fi, rloc);
                } elif borrow_fast {
                    g.emit_op(OP_LOAD_FAST_BORROW, fi, rloc);
                } else {
                    g.emit_op(OP_LOAD_FAST, fi, rloc);
                }
                g.emit_op(OP_RETURN_VALUE, 0, rloc);
                return;
            }
        }
        visit_expr(g, r.value);
        g.emit_op(OP_RETURN_VALUE, 0, rloc);
        return;
    }
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, rloc);
    g.emit_op(OP_RETURN_VALUE, 0, rloc);
}


def sym_class_qualname(
    cd: ClassDef, sym_cls: sym_block, enclosing_private: str | None
) -> str {
    if sym_cls.nested and enclosing_private is not None {
        return enclosing_private + "." + cd.name;
    }
    return cd.name;
}

# LOAD_BUILD_CLASS call: name const is already on stack; push bases and keywords.
def emit_class_build_call(g: cfg_builder, cd: ClassDef, cloc: cloc) {
    bases = class_effective_bases(cd);
    kws = class_effective_keywords(cd);
    bi = 0;
    while bi < len(bases) {
        visit_expr(g, bases[bi], False, False);
        if codegen_busy(g) {
            return;
        }
        bi = bi + 1;
    }
    if len(kws) == 0 {
        g.emit_op(OP_CALL, 2 + len(bases), cloc);
        return;
    }
    ki = 0;
    while ki < len(kws) {
        kw = kws[ki];
        if kw.arg is None {
            codegen_fail(
                g, "NotImplementedError", "keyword argument unpacking not supported"
            );
            return;
        }
        visit_expr(g, kw.value, False, False);
        if codegen_busy(g) {
            return;
        }
        ki = ki + 1;
    }
    names: list[PyObj] = [];
    ki = 0;
    while ki < len(kws) {
        names.append(PyStr(t="str", val=kws[ki].arg));
        ki = ki + 1;
    }
    tup = PyTuple(t="tuple", items=names);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, cloc);
    g.emit_op(OP_CALL_KW, 2 + len(bases) + len(kws), cloc);
}

# Class body boilerplate through __firstlineno__ (CPython compile_class).
def class_body_has_function(cd: ClassDef) -> bool {
    bi = 0;
    while bi < len(cd.body) {
        s = cd.body[bi];
        if isinstance(s, FunctionDef) or isinstance(s, AsyncFunctionDef) {
            return True;
        }
        bi = bi + 1;
    }
    return False;
}

def emit_class_body_prologue(g: cfg_builder, cd: ClassDef, class_qname: str) {
    cloc = nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    ploc = loc(0, cd.lineno, 0, 0);
    if len(g.u.cellvars) > 0 {
        ci = 0;
        while ci < len(g.u.cellvars) {
            lp = localsplus_index_u(g.u, g.u.cellvars[ci]);
            g.emit_op(OP_MAKE_CELL, lp, ploc);
            ci = ci + 1;
        }
    }
    g.emit_op(OP_RESUME, 0, ploc);
    nidx = g.u.add_name("__name__");
    g.emit_op(OP_LOAD_NAME, nidx, cloc);
    midx = g.u.add_name("__module__");
    g.emit_op(OP_STORE_NAME, midx, cloc);
    qidx = g.u.add_const(PyStr(t="str", val=class_qname));
    g.emit_op(OP_LOAD_CONST, qidx, cloc);
    qnidx = g.u.add_name("__qualname__");
    g.emit_op(OP_STORE_NAME, qnidx, cloc);
    emit_folded_int(g, cd.lineno, cloc);
    flidx = g.u.add_name("__firstlineno__");
    g.emit_op(OP_STORE_NAME, flidx, cloc);
    if len(g.u.cellvars) > 0 {
        g.emit_op(OP_LOAD_LOCALS, 0, cloc);
        cd_lp = localsplus_index_u(g.u, "__classdict__");
        g.emit_op(OP_STORE_DEREF, cd_lp, cloc);
    }
}

# __static_attributes__, optional __classdictcell__, and implicit RETURN_VALUE None.
def emit_class_body_epilogue(g: cfg_builder, last: cloc) {
    tup = PyTuple(t="tuple", items=[]);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, last);
    saidx = g.u.add_name("__static_attributes__");
    g.emit_op(OP_STORE_NAME, saidx, last);
    if len(g.u.cellvars) > 0 {
        cd_lp = localsplus_index_u(g.u, "__classdict__");
        g.emit_op(OP_LOAD_FAST_BORROW, cd_lp, last);
        cdidx = g.u.add_name("__classdictcell__");
        g.emit_op(OP_STORE_NAME, cdidx, last);
    }
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, last);
    g.emit_op(OP_RETURN_VALUE, 0, last);
}

# Lower `class name: ...` at module/class scope into nested PyCode + LOAD_BUILD_CLASS.
def visit_class_def(g: cfg_builder, cd: ClassDef) -> stmt_cont {
    cloc = nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "class definition without symtable");
        return stmt_cont(loc=cloc);
    }
    sym_cls = sym_class_child(g.sym_top, cd.name);
    if sym_cls is None {
        codegen_fail(g, "SystemError", "missing symtable for class " + cd.name);
        return stmt_cont(loc=cloc);
    }
    u_cls = compile_class_cfg(cd, g.u.filename, sym_cls, g.private);
    if u_cls.diag is not None {
        g.u.diag = u_cls.diag;
        return stmt_cont(loc=cloc);
    }
    cfg_cls = verify_cfg(u_cls);
    if cfg_cls.diag is not None {
        g.u.diag = cfg_cls.diag;
        return stmt_cont(loc=cloc);
    }
    co = assemble(cfg_cls);
    g.u.nested_code_emitted = True;
    g.emit_op(OP_LOAD_BUILD_CLASS, 0, cloc);
    g.emit_op(OP_PUSH_NULL, 0, cloc);
    cidx = g.u.add_const(co);
    g.emit_op(OP_LOAD_CONST, cidx, cloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, cloc);
    name_idx = g.u.add_const(PyStr(t="str", val=cd.name));
    g.emit_op(OP_LOAD_CONST, name_idx, cloc);
    emit_class_build_call(g, cd, cloc);
    if codegen_busy(g) {
        return stmt_cont(loc=cloc);
    }
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        fi = fast_local_index(g, cd.name);
        if fi < 0 {
            codegen_fail(
                g, "SystemError", "missing fast local for nested class " + cd.name
            );
            return stmt_cont(loc=cloc);
        }
        g.emit_op(OP_STORE_FAST, fi, cloc);
    } else {
        nidx = g.u.add_name(cd.name);
        g.emit_op(OP_STORE_NAME, nidx, cloc);
    }
    return stmt_cont(loc=cloc);
}

# Build unverified_cfg for a class body (nested code object before assembly).
def compile_class_cfg(
    cd: ClassDef,
    filename: str,
    sym_cls: sym_block,
    enclosing_private: str | None = None
) -> unverified_cfg {
    class_qname = sym_class_qualname(cd, sym_cls, enclosing_private);
    u = unverified_cfg(
        filename=filename, name=cd.name, qualname=class_qname, firstlineno=cd.lineno
    );
    if sym_cls.nested {
        u.flags = CO_NESTED;
    }
    if class_body_has_function(cd) {
        u.cellvars = ["__classdict__"];
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_cls, cd.name);
    emit_class_body_prologue(g, cd, class_qname);
    last = loc(0, cd.lineno, 0, 0);
    bi = 0;
    while bi < len(cd.body) {
        s = cd.body[bi];
        cont = visit_stmt(g, s, exec_tail_emits_code(cd.body, bi + 1), cd.body, bi + 1);
        last = cont.loc;
        if codegen_busy(g) {
            return u;
        }
        if cont.next_si >= 0 {
            bi = cont.next_si;
        } else {
            bi = bi + 1;
        }
    }
    emit_class_body_epilogue(g, last);
    return u;
}

# Lower `def name(...): ...` at module/class scope into nested PyCode + MAKE_FUNCTION.
def visit_function_def(g: cfg_builder, fd: FunctionDef) -> stmt_cont {
    floc = function_def_loc(fd);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "function definition without symtable");
        return stmt_cont(loc=floc);
    }
    sym_fn = sym_function_child(g.sym_top, fd.name);
    if sym_fn is None {
        codegen_fail(g, "SystemError", "missing symtable for function " + fd.name);
        return stmt_cont(loc=floc);
    }
    decorators = fd.decorator_list;
    if decorators is None {
        decorators = [];
    }
    u_fn = compile_fn_cfg(
        fd.name, fd.args, fd.body, fd.lineno, g.u.filename, sym_fn, g.private
    );
    if u_fn.diag is not None {
        g.u.diag = u_fn.diag;
        return stmt_cont(loc=floc);
    }
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return stmt_cont(loc=floc);
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    di = 0;
    while di < len(decorators) {
        visit_expr(g, decorators[di]);
        di = di + 1;
    }
    emit_make_function_with_closure(g, sym_fn, co, floc, fd.args);
    ri = len(decorators) - 1;
    while ri >= 0 {
        dec = decorators[ri];
        g.emit_op(OP_CALL, 0, expr_loc(dec));
        ri = ri - 1;
    }
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        fi = fast_local_index(g, fd.name);
        if fi < 0 {
            codegen_fail(
                g, "SystemError", "missing fast local for nested function " + fd.name
            );
            return stmt_cont(loc=floc);
        }
        g.emit_op(OP_STORE_FAST, fi, floc);
    } else {
        nidx = g.u.add_name(fd.name);
        g.emit_op(OP_STORE_NAME, nidx, floc);
    }
    return stmt_cont(loc=floc);
}

# Lower `async def name(...): ...` at module/class scope into nested PyCode + MAKE_FUNCTION.
def visit_async_function_def(g: cfg_builder, afd: AsyncFunctionDef) -> stmt_cont {
    floc = async_function_def_loc(afd);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "function definition without symtable");
        return stmt_cont(loc=floc);
    }
    sym_fn = sym_function_child(g.sym_top, afd.name);
    if sym_fn is None {
        codegen_fail(g, "SystemError", "missing symtable for function " + afd.name);
        return stmt_cont(loc=floc);
    }
    decorators = afd.decorator_list;
    if decorators is None {
        decorators = [];
    }
    u_fn = compile_fn_cfg(
        afd.name, afd.args, afd.body, afd.lineno, g.u.filename, sym_fn, g.private
    );
    if u_fn.diag is not None {
        g.u.diag = u_fn.diag;
        return stmt_cont(loc=floc);
    }
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return stmt_cont(loc=floc);
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    di = 0;
    while di < len(decorators) {
        visit_expr(g, decorators[di]);
        di = di + 1;
    }
    emit_make_function_with_closure(g, sym_fn, co, floc, afd.args);
    ri = len(decorators) - 1;
    while ri >= 0 {
        dec = decorators[ri];
        g.emit_op(OP_CALL, 0, expr_loc(dec));
        ri = ri - 1;
    }
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        fi = fast_local_index(g, afd.name);
        if fi < 0 {
            codegen_fail(
                g, "SystemError", "missing fast local for nested function " + afd.name
            );
            return stmt_cont(loc=floc);
        }
        g.emit_op(OP_STORE_FAST, fi, floc);
    } else {
        nidx = g.u.add_name(afd.name);
        g.emit_op(OP_STORE_NAME, nidx, floc);
    }
    return stmt_cont(loc=floc);
}



# Build unverified_cfg for a function/async body (nested code object before assembly).
def compile_fn_cfg(
    name: str,
    args: arguments,
    body: list[stmt],
    lineno: int,
    filename: str,
    sym_fn: sym_block,
    private: str | None = None
) -> unverified_cfg {
    (argcount, posonly, kwonly) = function_argcounts(args);
    u = unverified_cfg(filename=filename, name=name, qualname=name, firstlineno=lineno);
    u.argcount = argcount;
    u.posonlyargcount = posonly;
    u.kwonlyargcount = kwonly;
    is_suspendable = sym_fn.generator or sym_fn.coroutine;
    u.flags = function_code_flags(args);
    if sym_fn.generator and sym_fn.coroutine {
        u.flags = u.flags | CO_ASYNC_GENERATOR;
    } elif sym_fn.generator {
        u.flags = u.flags | CO_GENERATOR;
    } elif sym_fn.coroutine {
        u.flags = u.flags | CO_COROUTINE;
    }
    u.varnames = fast_varnames_from_sym(sym_fn);
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_fn, private);
    protect_start = emit_function_prologue(g, sym_fn, lineno, is_suspendable);
    last = loc(0, lineno, 0, 0);
    terminated = False;
    bi = 0;
    while bi < len(body) {
        s = body[bi];
        cont = visit_stmt(g, s, exec_tail_emits_code(body, bi + 1), body, bi + 1);
        last = cont.loc;
        if cont.terminated {
            terminated = True;
        }
        if codegen_busy(g) {
            return u;
        }
        if cont.next_si >= 0 {
            bi = cont.next_si;
        } else {
            bi = bi + 1;
        }
    }
    if not terminated {
        none_idx = u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, none_idx, last);
        g.emit_op(OP_RETURN_VALUE, 0, last);
    }
    emit_deferred_comp_handlers(g);
    if is_suspendable {
        emit_generator_except_handler(g, protect_start);
    }
    return u;
}

# Build unverified_cfg for a `def` body (nested code object before assembly).
def compile_function_cfg(
    fd: FunctionDef, filename: str, sym_fn: sym_block, private: str | None = None
) -> unverified_cfg {
    return compile_fn_cfg(
        fd.name, fd.args, fd.body, fd.lineno, filename, sym_fn, private
    );
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
    sym_top: sym_block | None = None
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name=name, qualname=name, firstlineno=firstlineno
    );
    if sym_top is not None {
        u.varnames = fast_varnames_from_sym(sym_top);
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_top);
    g.emit_op(OP_RESUME, 0, loc(0, firstlineno, 0, 0));
    last = loc(0, firstlineno, 0, 0);
    terminated = False;
    si = 0;
    while si < len(body) {
        s = body[si];
        cont = visit_stmt(g, s, exec_tail_emits_code(body, si + 1), body, si + 1);
        last = cont.loc;
        if cont.terminated {
            terminated = True;
        }
        if codegen_busy(g) {
            return u;
        }
        if cont.next_si >= 0 {
            si = cont.next_si;
        } else {
            si = si + 1;
        }
    }
    if terminated {
        return u;
    }
    none_idx = u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, last);
    g.emit_op(OP_RETURN_VALUE, 0, last);
    emit_deferred_comp_handlers(g);
    return u;
}
