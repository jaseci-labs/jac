# Expression-side lowering: visit_expr, expression/comprehension/lambda
# visitors, call/slice/await emission primitives, and the shared name/
# const/cell plumbing used by both expression and statement lowering.

# Split from compiler_codegen.jac (band-11 modularization): statement
# dispatch stays in compiler_codegen.jac and imports this module; this
# module only imports lower layers (no cycles).

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

# Record the first codegen diagnostic on the builder's unit.
def codegen_fail(g: cfg_builder, kind: str, message: str) {
    u = g.u;
    if u.diag is None {
        u.diag = lowering_diagnostic(kind=kind, message=message);
    }
}

def codegen_busy(g: cfg_builder) -> bool {
    return g.u.diag is not None;
}

# Class-body private name mangling (__x -> _C__x) for bytecode name tables.
def codegen_mangle(g: cfg_builder, name: str) -> str {
    return mangle_name(g.private, name);
}

# Fast locals for a compile unit. Module scope: comprehension iteration variables
# only. Function scope: parameters (definition order) then other locals (sorted).
def fast_varnames_from_sym(block: sym_block) -> list[str] {
    if block.block_type == "function" {
        out: list[str] = [];
        pi = 0;
        while pi < len(block.varnames) {
            out.append(block.varnames[pi]);
            pi = pi + 1;
        }
        li = 0;
        while li < len(block.local_varnames) {
            name = block.local_varnames[li];
            flags = sym_dict_get(block.symbols, name, 0);
            if sym_scope_of(flags) == SCOPE_LOCAL {
                found = False;
                fi = 0;
                while fi < len(out) {
                    if out[fi] == name {
                        found = True;
                    }
                    fi = fi + 1;
                }
                if not found {
                    out.append(name);
                }
            }
            li = li + 1;
        }
        return out;
    }
    names = sym_sorted_names(block.symbols);
    out: list[str] = [];
    ni = 0;
    while ni < len(names) {
        name = names[ni];
        flags = block.symbols[name];
        if block.block_type == "module" {
            if sym_flag_set(flags, DEF_COMP_ITER) {
                out.append(name);
            }
        } elif sym_scope_of(flags) == SCOPE_LOCAL {
            out.append(name);
        }
        ni = ni + 1;
    }
    return out;
}

def cellvars_from_sym(block: sym_block) -> list[str] {
    return sym_block_tuple_names(block.symbols, SCOPE_CELL);
}

def freevars_from_sym(block: sym_block) -> list[str] {
    return sym_block_tuple_names(block.symbols, SCOPE_FREE);
}

def varname_index(u: unverified_cfg, name: str) -> int {
    vi = 0;
    while vi < len(u.varnames) {
        if u.varnames[vi] == name {
            return vi;
        }
        vi = vi + 1;
    }
    return -1;
}

# Merged locals-plus index for MAKE_CELL / LOAD_DEREF / LOAD_FAST_BORROW (CPython 3.11+).
def localsplus_index_u(u: unverified_cfg, name: str) -> int {
    vi = varname_index(u, name);
    if vi >= 0 {
        return vi;
    }
    idx = len(u.varnames);
    ci = 0;
    while ci < len(u.cellvars) {
        cname = u.cellvars[ci];
        if varname_index(u, cname) < 0 {
            if cname == name {
                return idx;
            }
            idx = idx + 1;
        }
        ci = ci + 1;
    }
    fi = 0;
    while fi < len(u.freevars) {
        if u.freevars[fi] == name {
            return idx;
        }
        idx = idx + 1;
        fi = fi + 1;
    }
    return -1;
}

def localsplus_index(g: cfg_builder, name: str) -> int {
    return localsplus_index_u(g.u, name);
}

# CPython emits MAKE_CELL(s), optional COPY_FREE_VARS, then RESUME. Generators
# and coroutines prepend RETURN_GENERATOR; POP_TOP before RESUME (protect region
# starts at the following block).
def emit_function_prologue(
    g: cfg_builder, sym_fn: sym_block, firstlineno: int, is_suspendable: bool = False
) -> int {
    u = g.u;
    u.cellvars = cellvars_from_sym(sym_fn);
    u.freevars = freevars_from_sym(sym_fn);
    ploc = loc(0, firstlineno, 0, 0);
    ci = 0;
    while ci < len(u.cellvars) {
        lp = localsplus_index_u(u, u.cellvars[ci]);
        g.emit_op(OP_MAKE_CELL, lp, ploc);
        ci = ci + 1;
    }
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), ploc);
    }
    protect_start = -1;
    g.generator_protect_start = -1;
    if is_suspendable {
        g.emit_op(OP_RETURN_GENERATOR, 0, ploc);
        g.emit_op(OP_POP_TOP, 0, ploc);
        resume_blk = g.new_block();
        g.use(resume_blk);
        protect_start = resume_blk.id;
        g.generator_protect_start = protect_start;
    }
    g.emit_op(OP_RESUME, 0, ploc);
    return protect_start;
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

# GET_YIELD_FROM_ITER / GET_AWAITABLE + SEND loop shared by yield-from and await.
def emit_send_delegation_loop(
    g: cfg_builder,
    get_iter_op: int,
    get_iter_arg: int,
    resume_after_yield_arg: int,
    yloc: cloc
) {
    als = emit_await_send_loop_header(
        g, get_iter_op, get_iter_arg, resume_after_yield_arg, yloc
    );
    (ct, cj) = emit_await_send_loop_footer(g, als, yloc);
    emit_await_send_except_regions(g, als, ct, cj, 3, -1);
    g.use(als.end_send_blk);
}

# GET_AWAITABLE / GET_YIELD_FROM_ITER + SEND loop (footer deferred for async-with).

# Record the first codegen diagnostic on the builder's unit.
def codegen_fail(g: cfg_builder, kind: str, message: str) {
    u = g.u;
    if u.diag is None {
        u.diag = lowering_diagnostic(kind=kind, message=message);
    }
}

def codegen_busy(g: cfg_builder) -> bool {
    return g.u.diag is not None;
}

# Class-body private name mangling (__x -> _C__x) for bytecode name tables.
def codegen_mangle(g: cfg_builder, name: str) -> str {
    return mangle_name(g.private, name);
}

# Fast locals for a compile unit. Module scope: comprehension iteration variables
# only. Function scope: parameters (definition order) then other locals (sorted).
def fast_varnames_from_sym(block: sym_block) -> list[str] {
    if block.block_type == "function" {
        out: list[str] = [];
        pi = 0;
        while pi < len(block.varnames) {
            out.append(block.varnames[pi]);
            pi = pi + 1;
        }
        li = 0;
        while li < len(block.local_varnames) {
            name = block.local_varnames[li];
            flags = sym_dict_get(block.symbols, name, 0);
            if sym_scope_of(flags) == SCOPE_LOCAL {
                found = False;
                fi = 0;
                while fi < len(out) {
                    if out[fi] == name {
                        found = True;
                    }
                    fi = fi + 1;
                }
                if not found {
                    out.append(name);
                }
            }
            li = li + 1;
        }
        return out;
    }
    names = sym_sorted_names(block.symbols);
    out: list[str] = [];
    ni = 0;
    while ni < len(names) {
        name = names[ni];
        flags = block.symbols[name];
        if block.block_type == "module" {
            if sym_flag_set(flags, DEF_COMP_ITER) {
                out.append(name);
            }
        } elif sym_scope_of(flags) == SCOPE_LOCAL {
            out.append(name);
        }
        ni = ni + 1;
    }
    return out;
}

def cellvars_from_sym(block: sym_block) -> list[str] {
    return sym_block_tuple_names(block.symbols, SCOPE_CELL);
}

def freevars_from_sym(block: sym_block) -> list[str] {
    return sym_block_tuple_names(block.symbols, SCOPE_FREE);
}

def varname_index(u: unverified_cfg, name: str) -> int {
    vi = 0;
    while vi < len(u.varnames) {
        if u.varnames[vi] == name {
            return vi;
        }
        vi = vi + 1;
    }
    return -1;
}

# Merged locals-plus index for MAKE_CELL / LOAD_DEREF / LOAD_FAST_BORROW (CPython 3.11+).
def localsplus_index_u(u: unverified_cfg, name: str) -> int {
    vi = varname_index(u, name);
    if vi >= 0 {
        return vi;
    }
    idx = len(u.varnames);
    ci = 0;
    while ci < len(u.cellvars) {
        cname = u.cellvars[ci];
        if varname_index(u, cname) < 0 {
            if cname == name {
                return idx;
            }
            idx = idx + 1;
        }
        ci = ci + 1;
    }
    fi = 0;
    while fi < len(u.freevars) {
        if u.freevars[fi] == name {
            return idx;
        }
        idx = idx + 1;
        fi = fi + 1;
    }
    return -1;
}

def localsplus_index(g: cfg_builder, name: str) -> int {
    return localsplus_index_u(g.u, name);
}

# CPython emits MAKE_CELL(s), optional COPY_FREE_VARS, then RESUME. Generators
# and coroutines prepend RETURN_GENERATOR; POP_TOP before RESUME (protect region
# starts at the following block).
def emit_function_prologue(
    g: cfg_builder, sym_fn: sym_block, firstlineno: int, is_suspendable: bool = False
) -> int {
    u = g.u;
    u.cellvars = cellvars_from_sym(sym_fn);
    u.freevars = freevars_from_sym(sym_fn);
    ploc = loc(0, firstlineno, 0, 0);
    ci = 0;
    while ci < len(u.cellvars) {
        lp = localsplus_index_u(u, u.cellvars[ci]);
        g.emit_op(OP_MAKE_CELL, lp, ploc);
        ci = ci + 1;
    }
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), ploc);
    }
    protect_start = -1;
    g.generator_protect_start = -1;
    if is_suspendable {
        g.emit_op(OP_RETURN_GENERATOR, 0, ploc);
        g.emit_op(OP_POP_TOP, 0, ploc);
        resume_blk = g.new_block();
        g.use(resume_blk);
        protect_start = resume_blk.id;
        g.generator_protect_start = protect_start;
    }
    g.emit_op(OP_RESUME, 0, ploc);
    return protect_start;
}

# GET_YIELD_FROM_ITER / GET_AWAITABLE + SEND loop shared by yield-from and await.
def emit_send_delegation_loop(
    g: cfg_builder,
    get_iter_op: int,
    get_iter_arg: int,
    resume_after_yield_arg: int,
    yloc: cloc
) {
    als = emit_await_send_loop_header(
        g, get_iter_op, get_iter_arg, resume_after_yield_arg, yloc
    );
    (ct, cj) = emit_await_send_loop_footer(g, als, yloc);
    emit_await_send_except_regions(g, als, ct, cj, 3, -1);
    g.use(als.end_send_blk);
}

# GET_AWAITABLE / GET_YIELD_FROM_ITER + SEND loop (footer deferred for async-with).
obj await_send_loop {
    has send_blk: basicblock,
        yield_blk: basicblock,
        after_resume_blk: basicblock,
        end_send_blk: basicblock;
}

def emit_await_send_loop_header(
    g: cfg_builder,
    get_iter_op: int,
    get_iter_arg: int,
    resume_after_yield_arg: int,
    yloc: cloc,
    emit_end_send: bool = True
) -> await_send_loop {
    g.emit_op(get_iter_op, get_iter_arg, yloc);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, yloc);
    send_blk = g.new_block();
    yield_blk = g.new_block();
    after_resume_blk = g.new_block();
    end_send_blk = g.new_block();
    g.use(send_blk);
    g.emit_jump(OP_SEND, end_send_blk.id, yloc);
    g.use(yield_blk);
    g.emit_op(OP_YIELD_VALUE, 1, yloc);
    g.use(after_resume_blk);
    g.emit_op(OP_RESUME, resume_after_yield_arg, yloc);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, send_blk.id, yloc);
    g.use(end_send_blk);
    if emit_end_send {
        g.emit_op(OP_END_SEND, 0, yloc);
    }
    return await_send_loop(
        send_blk=send_blk,
        yield_blk=yield_blk,
        after_resume_blk=after_resume_blk,
        end_send_blk=end_send_blk
    );
}

def emit_await_send_loop_footer(
    g: cfg_builder, als: await_send_loop, yloc: cloc
) -> tuple[basicblock, basicblock] {
    cleanup_throw_blk = g.new_block();
    cleanup_jump_blk = g.new_block();
    g.use(cleanup_throw_blk);
    g.emit_op(OP_CLEANUP_THROW, 0, yloc);
    g.use(cleanup_jump_blk);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, als.end_send_blk.id, yloc);
    return (cleanup_throw_blk, cleanup_jump_blk);
}

def emit_await_send_except_regions(
    g: cfg_builder,
    als: await_send_loop,
    cleanup_throw_blk: basicblock,
    cleanup_jump_blk: basicblock,
    cleanup_stack_depth: int,
    after_resume_handler: int,
    pep479_start: int = -1,
    pep479_end: int = -1,
    after_resume_stack_depth: int = 2,
    after_resume_preserve_lasti: bool = True
) {
    `protect = g.generator_protect_start;
    if `protect < 0 {
        return;
    }
    if pep479_start >= 0 {
        `protect = pep479_start;
    }
    pep479_end_blk = cleanup_jump_blk.id;
    if pep479_end >= 0 {
        pep479_end_blk = pep479_end;
    }
    g.u.except_regions.append(
        except_region(
            start_block=`protect,
            end_block=als.yield_blk.id,
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
            stack_depth=cleanup_stack_depth,
            preserve_lasti=False
        )
    );
    ar_handler = after_resume_handler;
    if ar_handler < 0 {
        ar_handler = -1;
    }
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=pep479_end_blk,
            handler_block=ar_handler,
            stack_depth=after_resume_stack_depth,
            preserve_lasti=after_resume_preserve_lasti
        )
    );
    if after_resume_handler < 0 {
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    }
}

# GET_ANEXT + SEND loop blocks for async-for (footer emitted after the loop body).
obj anext_send_loop {
    has loop_hdr: basicblock,
        send_blk: basicblock,
        yield_blk: basicblock,
        after_resume_blk: basicblock,
        end_send_blk: basicblock;
}

# Loop header: GET_ANEXT, LOAD_CONST None, SEND/YIELD/RESUME/END_SEND.
def emit_anext_send_loop_header(
    g: cfg_builder, loop_hdr: basicblock, resume_after_yield_arg: int, yloc: cloc
) -> anext_send_loop {
    g.use(loop_hdr);
    g.emit_op(OP_GET_ANEXT, 0, yloc);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, yloc);
    send_blk = g.new_block();
    yield_blk = g.new_block();
    after_resume_blk = g.new_block();
    end_send_blk = g.new_block();
    g.use(send_blk);
    g.emit_jump(OP_SEND, end_send_blk.id, yloc);
    g.use(yield_blk);
    g.emit_op(OP_YIELD_VALUE, 1, yloc);
    g.use(after_resume_blk);
    g.emit_op(OP_RESUME, resume_after_yield_arg, yloc);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, send_blk.id, yloc);
    g.use(end_send_blk);
    g.emit_op(OP_END_SEND, 0, yloc);
    return anext_send_loop(
        loop_hdr=loop_hdr,
        send_blk=send_blk,
        yield_blk=yield_blk,
        after_resume_blk=after_resume_blk,
        end_send_blk=end_send_blk
    );
}

# CLEANUP_THROW footer for async-for (laid out after the loop body's JUMP_BACK).
def emit_anext_send_loop_footer(
    g: cfg_builder, als: anext_send_loop, yloc: cloc
) -> tuple[basicblock, basicblock] {
    cleanup_throw_blk = g.new_block();
    cleanup_jump_blk = g.new_block();
    g.use(cleanup_throw_blk);
    g.emit_op(OP_CLEANUP_THROW, 0, yloc);
    g.use(cleanup_jump_blk);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, als.end_send_blk.id, yloc);
    return (cleanup_throw_blk, cleanup_jump_blk);
}

# Compile default expressions in the enclosing scope; leaves defaults tuple on stack.
def emit_function_defaults(g: cfg_builder, defaults: list[expr], tloc: cloc) -> bool {
    if len(defaults) == 0 {
        return True;
    }
    folded = fold_default_values(defaults);
    if folded is not None {
        tup = PyTuple(t="tuple", items=folded);
        idx = g.u.add_const(tup);
        g.emit_op(OP_LOAD_CONST, idx, tloc);
        return True;
    }
    di = 0;
    while di < len(defaults) {
        visit_expr(g, defaults[di]);
        if codegen_busy(g) {
            return False;
        }
        di = di + 1;
    }
    g.emit_op(OP_BUILD_TUPLE, len(defaults), tloc);
    return True;
}

# Compile kw-only default expressions; leaves kwdefaults dict on stack.
def emit_function_kwdefaults(g: cfg_builder, args: arguments, tloc: cloc) -> bool {
    pair_count = 0;
    ki = 0;
    while ki < len(args.kwonlyargs) {
        kd: expr | None = None;
        if ki < len(args.kw_defaults) {
            kd = args.kw_defaults[ki];
        }
        if kd is not None {
            a = args.kwonlyargs[ki] as arg;
            key_idx = g.u.add_const(PyStr(t="str", val=a.arg));
            g.emit_op(OP_LOAD_CONST, key_idx, tloc);
            visit_expr(g, kd);
            if codegen_busy(g) {
                return False;
            }
            pair_count = pair_count + 1;
        }
        ki = ki + 1;
    }
    if pair_count > 0 {
        g.emit_op(OP_BUILD_MAP, pair_count, tloc);
    }
    return True;
}

# Nested code on stack; defaults/kwdefaults/closure + SET_FUNCTION_ATTRIBUTE when needed.
def emit_make_function_with_closure(
    g: cfg_builder,
    sym_fn: sym_block,
    co: PyCode,
    tloc: cloc,
    args: arguments | None = None
) {
    has_defaults = args is not None and len(args.defaults) > 0;
    has_kwdefaults = args is not None and args_have_kw_defaults(args);
    cidx = g.u.add_const(co);
    if has_defaults {
        if not emit_function_defaults(g, args.defaults, tloc) {
            return;
        }
    }
    if has_kwdefaults {
        if not emit_function_kwdefaults(g, args, tloc) {
            return;
        }
    }
    child_free = freevars_from_sym(sym_fn);
    if len(child_free) > 0 {
        fi = 0;
        while fi < len(child_free) {
            lp = localsplus_index(g, child_free[fi]);
            g.emit_op(OP_LOAD_FAST_BORROW, lp, tloc);
            fi = fi + 1;
        }
        g.emit_op(OP_BUILD_TUPLE, len(child_free), tloc);
    }
    g.emit_op(OP_LOAD_CONST, cidx, tloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, tloc);
    if len(child_free) > 0 {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, tloc);
    }
    if has_kwdefaults {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 2, tloc);
    }
    if has_defaults {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, tloc);
    }
}

def sym_function_child_at(
    parent: sym_block, fn_name: str, lineno: int, col_offset: int
) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "function"
            and ch.name == fn_name
            and ch.lineno == lineno
            and ch.col_offset == col_offset {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}

def unit_fail(u: unverified_cfg, kind: str, message: str) {
    if u.diag is None {
        u.diag = lowering_diagnostic(kind=kind, message=message);
    }
}

def emit_name_load(
    g: cfg_builder, name: str, tloc: cloc, for_call: bool = False
) -> bool {
    # Returns True when a separate PUSH_NULL is required before CALL (LOAD_NAME
    # and fast locals). LOAD_GLOBAL folds NULL into the oparg low bit (CPython 3.14).
    name = codegen_mangle(g, name);
    fi = fast_local_index(g, name);
    if fi >= 0 {
        # Inside a comprehension body the loop target's borrowed copy is left on
        # the stack by STORE_FAST_LOAD_FAST at bind time; the first evaluated
        # reference to it consumes that copy (emits nothing). Every later
        # reference loads its own borrow.
        if fi == g.u.comp_pending_borrow {
            g.u.comp_pending_borrow = -1;
            return True;
        }
        # Inside a comprehension body, coalesce with an immediately preceding
        # borrow load into LOAD_FAST_BORROW_LOAD_FAST_BORROW, keeping the first
        # load's position (CPython's superinstruction peephole).
        if g.u.comp_depth > 0 and len(g.cur.instrs) > 0 {
            prev = g.cur.instrs[len(g.cur.instrs) - 1];
            if prev.opcode == OP_LOAD_FAST_BORROW {
                prev.opcode = OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW;
                prev.oparg = prev.oparg * 16 + fi;
                return True;
            }
        }
        if g.u.comp_depth > 0 {
            # Comprehension bodies keep their hand-emitted borrow shapes; the
            # flowgraph strength-reduction passes are inert on them (they only
            # transform owned LOAD_FAST). See flowgraph.optimize_load_fast.
            g.emit_op(OP_LOAD_FAST_BORROW, fi, tloc);
        } else {
            # Emit an owned load. flowgraph.insert_superinstructions fuses adjacent
            # owned pairs and flowgraph.optimize_load_fast downgrades every load
            # whose borrow it can prove safe -- matching CPython, which emits owned
            # loads and strength-reduces them after the CFG is built.
            g.emit_op(OP_LOAD_FAST, fi, tloc);
        }
        return True;
    }
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            g.emit_op(OP_LOAD_DEREF, idx, tloc);
            return True;
        }
    }
    opc = name_load_opcode(g, name);
    idx = g.u.add_name(name);
    if opc == OP_LOAD_GLOBAL {
        # CPython encodes LOAD_GLOBAL's oparg as (name_index << 1) | push_null,
        # where the low bit requests the extra NULL for a following CALL. The VM
        # decodes name_index = arg >> 1, so the shift is required for every
        # LOAD_GLOBAL, not just the call form (idx==0 masked this before).
        if for_call {
            g.emit_op(opc, (idx << 1) | 1, tloc);
            return False;
        }
        g.emit_op(opc, idx << 1, tloc);
        return True;
    }
    g.emit_op(opc, idx, tloc);
    return True;
}

# Name load opcode from symtable facts. Module scope uses LOAD_NAME for globals
# and LOAD_FAST when the name is a comprehension / local slot in varnames.
def name_load_opcode(g: cfg_builder, name: str) -> int {
    name = codegen_mangle(g, name);
    if fast_local_index(g, name) >= 0 {
        return OP_LOAD_FAST;
    }
    if g.sym_top is None or g.sym_top.block_type == "module" {
        return OP_LOAD_NAME;
    }
    flags = sym_dict_get(g.sym_top.symbols, name, 0);
    scope = sym_scope_of(flags);
    if scope == SCOPE_GLOBAL_EXPLICIT or scope == SCOPE_GLOBAL_IMPLICIT {
        return OP_LOAD_GLOBAL;
    }
    return OP_LOAD_NAME;
}

# Emit the subscript key (index or constant slice) onto the stack.
# register_small_int: CPython keeps small-index literals in co_consts for
# BINARY_OP[] loads but not for STORE_SUBSCR stores (byte-exact parity).
# Emit one slice bound: the expression, or LOAD_CONST None when the bound is
# omitted (CPython fills missing lower/upper/step with None).
def emit_slice_bound(g: cfg_builder, e: expr | None, lc: cloc) {
    if e is None {
        idx = g.u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, idx, lc);
        return;
    }
    visit_expr(g, e);
}

# Push a non-constant slice's operands and the fused/build opcode for a LOAD.
# CPython 3.14: a 2-element slice (no step) uses BINARY_SLICE (lower, upper on
# stack, receiver below); a 3-element slice uses BUILD_SLICE 3 + BINARY_OP []].
# Constant slices are folded by the caller (fold_slice_const) and never reach here.
def emit_slice_load(g: cfg_builder, sl: Slice, lc: cloc) {
    if sl.step is not None {
        emit_slice_bound(g, sl.lower, lc);
        emit_slice_bound(g, sl.upper, lc);
        visit_expr(g, sl.step);
        g.emit_op(OP_BUILD_SLICE, 3, lc);
        g.emit_op(OP_BINARY_OP, NB_SUBSCR, lc);
        return;
    }
    emit_slice_bound(g, sl.lower, lc);
    emit_slice_bound(g, sl.upper, lc);
    g.emit_op(OP_BINARY_SLICE, 0, lc);
}

def visit_subscript_index(
    g: cfg_builder, key: expr, lc: cloc, register_small_int: bool = False
) {
    if isinstance(key, Slice) {
        folded = fold_slice_const(key as Slice);
        if folded is not None {
            idx = g.u.add_const(folded);
            g.emit_op(OP_LOAD_CONST, idx, lc);
            return;
        }
    }
    if isinstance(key, Constant) {
        cv = (key as Constant).value;
        if isinstance(cv, PyInt) {
            kloc = expr_loc(key);
            if register_small_int {
                g.u.add_const((key as Constant).value);
            }
            emit_folded_int(g, (cv as PyInt).val, kloc);
            return;
        }
    }
    visit_expr(g, key);
}

# Emit the single comparison opcode for one cmpop link. Identity/membership ops
# lower to IS_OP / CONTAINS_OP (negation folded into oparg 1) and always yield a
# bool, so bool_context only affects the COMPARE_OP oparg. Returns False when the
# op node is not a recognized cmpop (caller reports NotImplementedError).
def emit_cmp_link(g: cfg_builder, op: PyObj, lc: cloc, bool_context: bool) -> bool {
    if isinstance(op, Is) {
        g.emit_op(OP_IS_OP, 0, lc);
        return True;
    }
    if isinstance(op, IsNot) {
        g.emit_op(OP_IS_OP, 1, lc);
        return True;
    }
    if isinstance(op, In) {
        g.emit_op(OP_CONTAINS_OP, 0, lc);
        return True;
    }
    if isinstance(op, NotIn) {
        g.emit_op(OP_CONTAINS_OP, 1, lc);
        return True;
    }
    kind = ast_cmp_kind(op);
    if kind < 0 {
        return False;
    }
    if bool_context {
        g.emit_op(OP_COMPARE_OP, compare_filter_oparg(kind), lc);
    } else {
        g.emit_op(OP_COMPARE_OP, compare_oparg(kind), lc);
    }
    return True;
}

# CPython folds `x is None` / `x is not None` in bool (test/filter) context into
# POP_JUMP_IF_NONE / POP_JUMP_IF_NOT_NONE, dropping the LOAD_CONST None + IS_OP.
# That jump peephole is a separate slice; until it lands, identity tests against
# the None literal in bool context must fail loudly rather than emit
# non-conformant IS_OP bytecode. Value-context `x is None` (plain IS_OP) is fine.
def is_none_identity_test(op: PyObj, comparand: expr) -> bool {
    if not isinstance(op, Is) and not isinstance(op, IsNot) {
        return False;
    }
    if not isinstance(comparand, Constant) {
        return False;
    }
    return isinstance((comparand as Constant).value, PyNoneType);
}

# Chained-compare lowering (compile.c): keep the middle operand on the stack
# across links; short-circuit on the first false with SWAP/POP cleanup.
# false_shortcircuit_returns: only the eval-mode top-level expression may return
# from the module on a false chain link. use_join: fall through to a shared join
# block (BoolOp rhs); otherwise return the cleanup block for suffix duplication.
def visit_compare(
    g: cfg_builder, c: Compare, false_shortcircuit_returns: bool, use_join: bool = True
) -> basicblock | None {
    n = len(c.ops);
    cloc_cmp = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    visit_expr(g, c.left, false_shortcircuit_returns=false_shortcircuit_returns);
    cleanup: basicblock | None = None;
    if n > 1 {
        cleanup = g.new_block();
    }
    ei = 0;
    while ei < n {
        visit_expr(g, c.comparators[ei]);
        if n > 1 and ei == 0 {
            g.emit_op(OP_SWAP, 2, cloc_cmp);
            g.emit_op(OP_COPY, 2, cloc_cmp);
        }
        if not emit_cmp_link(g, c.ops[ei], cloc_cmp, False) {
            codegen_fail(g, "NotImplementedError", "unsupported comparison operator");
            return None;
        }
        if ei < n - 1 {
            g.emit_op(OP_COPY, 1, cloc_cmp);
            g.emit_op(OP_TO_BOOL, 0, cloc_cmp);
            if cleanup is not None {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, cleanup.id, cloc_cmp);
            }
            g.emit_op(OP_POP_TOP, 0, cloc_cmp);
        }
        ei = ei + 1;
    }
    if cleanup is not None {
        if false_shortcircuit_returns {
            main_blk = g.cur;
            g.use(cleanup);
            g.emit_op(OP_SWAP, 2, cloc_cmp);
            g.emit_op(OP_POP_TOP, 0, cloc_cmp);
            g.emit_op(OP_RETURN_VALUE, 0, cloc_cmp);
            g.use(main_blk);
            return None;
        }
        if use_join {
            join = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, join.id, cloc_cmp);
            g.use(cleanup);
            g.emit_op(OP_SWAP, 2, cloc_cmp);
            g.emit_op(OP_POP_TOP, 0, cloc_cmp);
            g.use(join);
            return None;
        }
        return cleanup;
    }
    return None;
}

# Emit a folded literal: LOAD_SMALL_INT for 0..255, else LOAD_CONST.
def emit_folded_int(g: cfg_builder, v: int, lc: cloc) {
    if v >= 0 and v <= 255 {
        g.emit_op(OP_LOAD_SMALL_INT, v, lc);
        return;
    }
    idx = g.u.add_const(PyInt(t="int", val=v));
    g.emit_op(OP_LOAD_CONST, idx, lc);
}

# Register literal int operands in co_consts without emitting (CPython dead
# small-int slot + out-of-range LOAD_CONST operands). Used by Constant visit
# and by peephole-folded BinOp so folded exprs keep the same const pool.
def register_int_literal_const(g: cfg_builder, e: expr, register_int_const: bool) {
    if not register_int_const {
        return;
    }
    if not isinstance(e, Constant) {
        return;
    }
    c = e as Constant;
    if not isinstance(c.value, PyInt) {
        return;
    }
    v = (c.value as PyInt).val;
    in_class_body = g.sym_top is not None and g.sym_top.block_type == "class";
    if in_class_body {
        return;
    }
    if v >= 0 and v <= 255 {
        # CPython keeps the dead small-int slot ONLY when it lands at const
        # index 0 (pool empty). Once a code object / string / other const has
        # been added, small ints are pure LOAD_SMALL_INT with no pool entry.
        if len(g.u.consts) == 0 {
            g.u.add_const(c.value);
            g.u.dead_small_int_const = True;
        }
    } else {
        g.u.add_const(c.value);
    }
}

# BoolOp lowering (compile.c): short-circuit and/or chains with COPY/TO_BOOL.
# Returns the false-exit block when false_shortcircuit_returns so the caller
# can place its RETURN after the true-path suffix (CPython block layout).
def visit_boolop(
    g: cfg_builder, b: BoolOp, false_shortcircuit_returns: bool
) -> basicblock | None {
    bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
    n = len(b.values);
    if n < 2 {
        codegen_fail(g, "NotImplementedError", "BoolOp requires at least two values");
        return None;
    }
    is_and = isinstance(b.op, And);
    is_or = isinstance(b.op, Or);
    if not is_and and not is_or {
        codegen_fail(g, "NotImplementedError", "unsupported boolean operator");
        return None;
    }
    jump_op = OP_POP_JUMP_IF_FALSE;
    if is_or {
        jump_op = OP_POP_JUMP_IF_TRUE;
    }
    join: basicblock | None = None;
    if not false_shortcircuit_returns {
        join = g.new_block();
    }
    false_exit: basicblock | None = None;
    vi = 0;
    while vi < n - 1 {
        visit_expr(g, b.values[vi]);
        if false_shortcircuit_returns and false_exit is None {
            false_exit = g.new_block();
        }
        g.emit_op(OP_COPY, 1, bl);
        g.emit_op(OP_TO_BOOL, 0, bl);
        if false_shortcircuit_returns {
            false_target = false_exit.id;
        } else {
            false_target = join.id;
        }
        g.emit_jump(jump_op, false_target, bl);
        g.emit_op(OP_POP_TOP, 0, bl);
        vi = vi + 1;
    }
    visit_expr(g, b.values[n - 1]);
    if join is not None {
        g.emit_jump(OP_JUMP_FORWARD, join.id, bl);
        g.use(join);
        return None;
    }
    if false_shortcircuit_returns {
        return false_exit;
    }
    return None;
}

# Visit one expression. Returns a chained-compare cleanup block when the caller
# must duplicate its suffix (CALL / STORE), else None.
def visit_expr(
    g: cfg_builder,
    e: expr,
    false_shortcircuit_returns: bool = False,
    compare_use_join: bool = True,
    register_int_const: bool = True
) -> basicblock | None {
    if codegen_busy(g) {
        return None;
    }
    if isinstance(e, Constant) {
        c = e as Constant;
        cloc = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
        if isinstance(c.value, PyInt) {
            v = (c.value as PyInt).val;
            register_int_literal_const(g, e, register_int_const);
            emit_folded_int(g, v, cloc);
            return None;
        }
        idx = g.u.add_const(c.value);
        g.emit_op(OP_LOAD_CONST, idx, cloc);
        return None;
    }
    if isinstance(e, Name) {
        n = e as Name;
        emit_name_load(
            g, n.id, nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset)
        );
        return None;
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
        folded = try_fold_binop(b.left, b.op, b.right);
        if folded is not None and isinstance(folded, PyInt) {
            register_int_literal_const(g, b.left, register_int_const);
            register_int_literal_const(g, b.right, register_int_const);
            emit_folded_int(g, (folded as PyInt).val, bl);
            return None;
        }
        opid = binop_id(b.op);
        if opid < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported binary operator");
            return None;
        }
        if try_emit_fast_local_pair_load(g, b.left, b.right, bl) {
            g.emit_op(OP_BINARY_OP, opid, bl);
            return None;
        }
        visit_expr(g, b.left);
        visit_expr(g, b.right);
        g.emit_op(OP_BINARY_OP, opid, bl);
        return None;
    }
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        visit_expr(g, un.operand);
        opc = unary_opcode(un.op);
        if opc < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported unary operator");
            return None;
        }
        g.emit_op(
            opc, 0, nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset)
        );
        return None;
    }
    if isinstance(e, Compare) {
        return visit_compare(
            g, e as Compare, false_shortcircuit_returns, compare_use_join
        );
    }
    if isinstance(e, BoolOp) {
        return visit_boolop(g, e as BoolOp, false_shortcircuit_returns);
    }
    if isinstance(e, IfExp) {
        # Conditional expression `body if test else orelse`. Branch+join form,
        # leaving the selected value on the stack (CPython's embedded shape):
        #   <test>; POP_JUMP_IF_FALSE else; <body>; JUMP_FORWARD join;
        #   else: <orelse>; join:
        # At a statement tail CPython instead duplicates the suffix into both
        # arms (no join); that tail-duplication is a separate slice, so a
        # top-level `x = a if c else b` compiles correctly but is not byte-exact.
        ie = e as IfExp;
        ieloc = nloc(ie.lineno, ie.end_lineno, ie.col_offset, ie.end_col_offset);
        test_loc = expr_loc(ie.`test);
        else_blk = g.new_block();
        join_blk = g.new_block();
        kind = visit_test_expr(g, ie.`test, test_loc, True);
        if codegen_busy(g) {
            return None;
        }
        emit_branch_if_test_false(g, kind, else_blk.id, test_loc);
        visit_expr(g, ie.body);
        if codegen_busy(g) {
            return None;
        }
        g.emit_jump(OP_JUMP_FORWARD, join_blk.id, ieloc);
        g.use(else_blk);
        visit_expr(g, ie.orelse);
        if codegen_busy(g) {
            return None;
        }
        g.use(join_blk);
        return None;
    }
    if isinstance(e, Call) {
        ca = e as Call;
        floc = call_func_loc(ca.func);
        if isinstance(ca.func, Name) {
            nf = ca.func as Name;
            nloc_fn = nloc(nf.lineno, nf.end_lineno, nf.col_offset, nf.end_col_offset);
            needs_null = emit_name_load(g, nf.id, nloc_fn, True);
            if needs_null {
                g.emit_op(OP_PUSH_NULL, 0, floc);
            }
        } elif isinstance(ca.func, Attribute) {
            attr = ca.func as Attribute;
            aloc = expr_loc(attr);
            visit_expr(g, attr.value);
            idx = g.u.add_name(codegen_mangle(g, attr.attr));
            g.emit_op(OP_LOAD_ATTR, (idx << 1) | 1, aloc);
        } else {
            visit_expr(g, ca.func);
            g.emit_op(OP_PUSH_NULL, 0, floc);
        }
        cmp_cleanup: basicblock | None = None;
        call_args = call_effective_args(ca);
        ai = 0;
        while ai < len(call_args) {
            arg_cleanup = visit_expr(
                g, call_args[ai], False, False, not g.u.nested_code_emitted
            );
            if arg_cleanup is not None {
                cmp_cleanup = arg_cleanup;
            }
            ai = ai + 1;
        }
        cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
        kws = call_effective_keywords(ca);
        if len(kws) > 0 {
            emit_call_keyword_values(
                g, ca, cloc_call, False, not g.u.nested_code_emitted
            );
            if codegen_busy(g) {
                return cmp_cleanup;
            }
        }
        emit_call_instruction(g, ca, cloc_call);
        return cmp_cleanup;
    }
    if isinstance(e, Attribute) {
        a = e as Attribute;
        aloc = expr_loc(a);
        visit_expr(g, a.value);
        idx = g.u.add_name(codegen_mangle(g, a.attr));
        g.emit_op(OP_LOAD_ATTR, idx * 2, aloc);
        return None;
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        sloc = expr_loc(s);
        visit_expr(g, s.value);
        if isinstance(s.slice, Slice) {
            sl = s.slice as Slice;
            folded = fold_slice_const(sl);
            if folded is not None {
                idx = g.u.add_const(folded);
                g.emit_op(OP_LOAD_CONST, idx, sloc);
                g.emit_op(OP_BINARY_OP, NB_SUBSCR, sloc);
                return None;
            }
            emit_slice_load(g, sl, sloc);
            return None;
        }
        visit_subscript_index(g, s.slice, sloc, True);
        g.emit_op(OP_BINARY_OP, NB_SUBSCR, sloc);
        return None;
    }
    if isinstance(e, ListComp) {
        visit_list_comp(g, e as ListComp);
        return None;
    }
    if isinstance(e, SetComp) {
        visit_set_comp(g, e as SetComp);
        return None;
    }
    if isinstance(e, DictComp) {
        visit_dict_comp(g, e as DictComp);
        return None;
    }
    if isinstance(e, Lambda) {
        visit_lambda(g, e as Lambda);
        return None;
    }
    if isinstance(e, Yield) {
        y = e as Yield;
        yloc = nloc(y.lineno, y.end_lineno, y.col_offset, y.end_col_offset);
        if y.value is not None {
            visit_expr(g, y.value);
        } else {
            none_idx = g.u.add_const(py_none());
            g.emit_op(OP_LOAD_CONST, none_idx, yloc);
        }
        # In an async generator, each yielded value is wrapped by
        # INTRINSIC_ASYNC_GEN_WRAP (4) before YIELD_VALUE.
        if (g.u.flags & CO_ASYNC_GENERATOR) != 0 {
            g.emit_op(OP_CALL_INTRINSIC_1, 4, yloc);
        }
        g.emit_op(OP_YIELD_VALUE, 0, yloc);
        g.emit_op(OP_RESUME, 5, yloc);
        return None;
    }
    if isinstance(e, YieldFrom) {
        yf = e as YieldFrom;
        yloc = nloc(yf.lineno, yf.end_lineno, yf.col_offset, yf.end_col_offset);
        visit_expr(g, yf.value);
        if codegen_busy(g) {
            return None;
        }
        emit_send_delegation_loop(g, OP_GET_YIELD_FROM_ITER, 0, 2, yloc);
        return None;
    }
    if isinstance(e, Await) {
        a = e as Await;
        aloc = nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
        visit_expr(g, a.value);
        if codegen_busy(g) {
            return None;
        }
        emit_send_delegation_loop(g, OP_GET_AWAITABLE, 0, 3, aloc);
        return None;
    }
    if isinstance(e, Tuple) {
        tup = e as Tuple;
        telts = tup.elts if tup.elts is not None else [];
        dloc = nloc(tup.lineno, tup.end_lineno, tup.col_offset, tup.end_col_offset);
        if display_has_starred(telts) {
            emit_starred_list_build(g, telts, dloc);
            if codegen_busy(g) {
                return None;
            }
            # INTRINSIC_LIST_TO_TUPLE == 6
            g.emit_op(OP_CALL_INTRINSIC_1, 6, dloc);
            return None;
        }
        if display_all_constant(telts) {
            cidx = g.u.add_const(PyTuple(t="tuple", items=display_const_items(telts)));
            g.emit_op(OP_LOAD_CONST, cidx, dloc);
            return None;
        }
        di = 0;
        while di < len(telts) {
            visit_expr(g, telts[di]);
            di = di + 1;
        }
        if codegen_busy(g) {
            return None;
        }
        g.emit_op(OP_BUILD_TUPLE, len(telts), dloc);
        return None;
    }
    if isinstance(e, List) {
        lst = e as List;
        lelts = lst.elts if lst.elts is not None else [];
        dloc = nloc(lst.lineno, lst.end_lineno, lst.col_offset, lst.end_col_offset);
        if display_has_starred(lelts) {
            emit_starred_list_build(g, lelts, dloc);
            return None;
        }
        if len(lelts) > 0 and display_all_constant(lelts) {
            # CPython packs an all-constant list as an empty list extended by a
            # folded const tuple: BUILD_LIST 0; LOAD_CONST (tuple); LIST_EXTEND 1.
            g.emit_op(OP_BUILD_LIST, 0, dloc);
            cidx = g.u.add_const(PyTuple(t="tuple", items=display_const_items(lelts)));
            g.emit_op(OP_LOAD_CONST, cidx, dloc);
            g.emit_op(OP_LIST_EXTEND, 1, dloc);
            return None;
        }
        di = 0;
        while di < len(lelts) {
            visit_expr(g, lelts[di]);
            di = di + 1;
        }
        if codegen_busy(g) {
            return None;
        }
        g.emit_op(OP_BUILD_LIST, len(lelts), dloc);
        return None;
    }
    if isinstance(e, Set) {
        st = e as Set;
        selts = st.elts if st.elts is not None else [];
        dloc = nloc(st.lineno, st.end_lineno, st.col_offset, st.end_col_offset);
        if display_has_starred(selts) {
            g.emit_op(OP_BUILD_SET, 0, dloc);
            si = 0;
            while si < len(selts) {
                sel = selts[si];
                if isinstance(sel, Starred) {
                    visit_expr(g, (sel as Starred).value);
                    if codegen_busy(g) {
                        return None;
                    }
                    g.emit_op(OP_SET_UPDATE, 1, dloc);
                } else {
                    visit_expr(g, sel);
                    if codegen_busy(g) {
                        return None;
                    }
                    g.emit_op(OP_SET_ADD, 1, dloc);
                }
                si = si + 1;
            }
            return None;
        }
        si = 0;
        while si < len(selts) {
            visit_expr(g, selts[si]);
            si = si + 1;
        }
        if codegen_busy(g) {
            return None;
        }
        g.emit_op(OP_BUILD_SET, len(selts), dloc);
        return None;
    }
    if isinstance(e, Dict) {
        dd = e as Dict;
        dkeys = dd.keys if dd.keys is not None else [];
        dvals = dd.values if dd.values is not None else [];
        dloc = nloc(dd.lineno, dd.end_lineno, dd.col_offset, dd.end_col_offset);
        has_star = False;
        si2 = 0;
        while si2 < len(dkeys) {
            if dkeys[si2] is None {
                has_star = True;
            }
            si2 = si2 + 1;
        }
        if not has_star {
            di = 0;
            while di < len(dkeys) {
                visit_expr(g, dkeys[di]);
                visit_expr(g, dvals[di]);
                di = di + 1;
            }
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_BUILD_MAP, len(dkeys), dloc);
            return None;
        }
        # dict-merge display: `{**a, 'k': v, ...}`. Walk left-to-right,
        # accumulating consecutive literal k:v pairs into `n`. When a `**x`
        # (key None) is reached, flush any pending pairs as BUILD_MAP n (which
        # DICT_UPDATEs onto the running base once one exists), then merge x with
        # DICT_UPDATE 1. Mirrors CPython 3.14 codegen_dict.
        n = 0;
        have_dict = False;
        di = 0;
        while di < len(dkeys) {
            k = dkeys[di];
            if k is None {
                if n > 0 or (not have_dict) {
                    g.emit_op(OP_BUILD_MAP, n, dloc);
                    if have_dict {
                        g.emit_op(OP_DICT_UPDATE, 1, dloc);
                    }
                    have_dict = True;
                    n = 0;
                }
                visit_expr(g, dvals[di]);
                g.emit_op(OP_DICT_UPDATE, 1, dloc);
            } else {
                visit_expr(g, k);
                visit_expr(g, dvals[di]);
                n = n + 1;
            }
            di = di + 1;
        }
        if n > 0 or (not have_dict) {
            g.emit_op(OP_BUILD_MAP, n, dloc);
            if have_dict {
                g.emit_op(OP_DICT_UPDATE, 1, dloc);
            }
        }
        if codegen_busy(g) {
            return None;
        }
        return None;
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported expression: " + ast_node_name(e as ast_node)
    );
    return None;
}

# Push keyword-argument values, then the names tuple (bottom -> top: vals…, names).
def emit_call_keyword_values(
    g: cfg_builder,
    ca: Call,
    cloc_call: cloc,
    comp_mode: bool = False,
    register_int_const: bool = True
) {
    kws = call_effective_keywords(ca);
    ki = 0;
    while ki < len(kws) {
        kw = kws[ki];
        if kw.arg is None {
            codegen_fail(
                g, "NotImplementedError", "keyword argument unpacking not supported"
            );
            return;
        }
        if comp_mode {
            visit_comp_elt(g, kw.value, [], False);
        } else {
            visit_expr(g, kw.value, False, False, register_int_const);
        }
        if codegen_busy(g) {
            return;
        }
        ki = ki + 1;
    }
    if len(kws) == 0 {
        return;
    }
    names: list[PyObj] = [];
    ki = 0;
    while ki < len(kws) {
        names.append(PyStr(t="str", val=kws[ki].arg));
        ki = ki + 1;
    }
    tup = PyTuple(t="tuple", items=names);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, cloc_call);
}

# Positional and keyword values must already be on the stack (names tuple last for CALL_KW).
def emit_call_instruction(g: cfg_builder, ca: Call, cloc_call: cloc) {
    args = call_effective_args(ca);
    kws = call_effective_keywords(ca);
    if len(kws) > 0 {
        ki = 0;
        while ki < len(kws) {
            if kws[ki].arg is None {
                codegen_fail(
                    g, "NotImplementedError", "keyword argument unpacking not supported"
                );
                return;
            }
            ki = ki + 1;
        }
        g.emit_op(OP_CALL_KW, len(args) + len(kws), cloc_call);
    } else {
        g.emit_op(OP_CALL, len(args), cloc_call);
    }
}

# Build a list on the stack from a display element list containing starred
# entries: BUILD_LIST 0, then LIST_EXTEND for each *starred and LIST_APPEND for
# each plain element. Shared by starred list and starred tuple displays.
def emit_starred_list_build(g: cfg_builder, elts: list[expr], dloc: cloc) -> None {
    g.emit_op(OP_BUILD_LIST, 0, dloc);
    i = 0;
    while i < len(elts) {
        el = elts[i];
        if isinstance(el, Starred) {
            visit_expr(g, (el as Starred).value);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_LIST_EXTEND, 1, dloc);
        } else {
            visit_expr(g, el);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_LIST_APPEND, 1, dloc);
        }
        i = i + 1;
    }
    return None;
}

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
            return visit_store_seq_literal(g, telts, velts, expr_loc(t));
        }
    }
    visit_expr(g, value);
    return visit_store_target_tos(g, t);
}

def fast_local_index(g: cfg_builder, name: str) -> int {
    vi = 0;
    while vi < len(g.u.varnames) {
        if g.u.varnames[vi] == name {
            return vi;
        }
        vi = vi + 1;
    }
    return -1;
}

# CPython 3.14 fuses two fast-local loads for binops (e.g. `return x + y`).
def try_emit_fast_local_pair_load(
    g: cfg_builder, left: expr, right: expr, tloc: cloc
) -> bool {
    # Outside a comprehension, let the two operands emit owned LOAD_FAST loads
    # individually: flowgraph.insert_superinstructions fuses them and
    # optimize_load_fast picks the correct owned/borrow fused variant. Only
    # comprehension bodies (which keep hand-emitted borrow shapes) fuse here.
    if g.u.comp_depth == 0 {
        return False;
    }
    if not isinstance(left, Name) or not isinstance(right, Name) {
        return False;
    }
    lfi = fast_local_index(g, (left as Name).id);
    rfi = fast_local_index(g, (right as Name).id);
    if lfi < 0 or rfi < 0 {
        return False;
    }
    # A pending comprehension borrow means one operand consumes the copy already
    # on the stack (emits nothing), so the two loads cannot fuse into a pair.
    if lfi == g.u.comp_pending_borrow or rfi == g.u.comp_pending_borrow {
        return False;
    }
    pair_arg = lfi * 16 + rfi;
    g.emit_op(OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW, pair_arg, tloc);
    return True;
}

def comp_target_slots(g: cfg_builder, target: expr) -> list[int] | None {
    if isinstance(target, Name) {
        fi = fast_local_index(g, (target as Name).id);
        if fi < 0 {
            return None;
        }
        return [fi];
    }
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) != 2 {
            return None;
        }
        if not isinstance(elts[0], Name) or not isinstance(elts[1], Name) {
            return None;
        }
        fi0 = fast_local_index(g, (elts[0] as Name).id);
        fi1 = fast_local_index(g, (elts[1] as Name).id);
        if fi0 < 0 or fi1 < 0 {
            return None;
        }
        return [fi0, fi1];
    }
    return None;
}

# True when the comprehension's first evaluated body expression begins with the
# single loop variable -- the case CPython fuses into STORE_FAST_LOAD_FAST.
def comp_lead_is_loopvar(
    g: cfg_builder,
    gen: comprehension,
    body_first: expr,
    bound_names: list[str],
    slots: list[int]
) -> bool {
    if len(slots) != 1 {
        return False;
    }
    first: expr = body_first;
    if len(gen.ifs) > 0 {
        first = gen.ifs[0];
    }
    leaf = comp_leftmost_leaf(first);
    if not isinstance(leaf, Name) {
        return False;
    }
    nid = (leaf as Name).id;
    if not comp_name_bound(nid, bound_names) {
        return False;
    }
    return fast_local_index(g, nid) == slots[0];
}

def comp_name_fast_index(g: cfg_builder, e: expr, bound_names: list[str]) -> int {
    if not isinstance(e, Name) {
        return -1;
    }
    nid = (e as Name).id;
    if not comp_name_bound(nid, bound_names) {
        return -1;
    }
    return fast_local_index(g, nid);
}

def comp_append_handler(
    g: cfg_builder,
    start_blk: int,
    protect_end: int,
    stack_depth: int,
    fast_index: int,
    cloc_comp: cloc,
    handler_group: int,
    second_fast_index: int = -1,
    swap_depth: int = 2
) {
    reg = except_region(
        start_block=start_blk,
        end_block=protect_end,
        handler_block=-1,
        stack_depth=stack_depth
    );
    g.u.except_regions.append(reg);
    g.u.comp_handlers.append(
        comp_handler(
            region_index=len(g.u.except_regions) - 1,
            fast_index=fast_index,
            second_fast_index=second_fast_index,
            swap_depth=swap_depth,
            loc=cloc_comp,
            group=handler_group
        )
    );
}

# Lower a comprehension element expression. The innermost loop target is already
# on the stack from STORE_FAST_LOAD_FAST; references to bound names must not load.
def visit_comp_elt(
    g: cfg_builder, e: expr, bound_names: list[str], filter_compare: bool = False
) {
    if isinstance(e, Name) {
        # Loop-var and ordinary name loads both go through emit_name_load, which
        # consumes the STORE_FAST_LOAD_FAST borrow for the first loop-var
        # reference and emits LOAD_FAST_BORROW for the rest.
        visit_expr(g, e);
        return;
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        cloc_cmp = expr_loc(c);
        visit_comp_elt(g, c.left, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        ci = 0;
        while ci < len(c.comparators) {
            if filter_compare and is_none_identity_test(c.ops[ci], c.comparators[ci]) {
                codegen_fail(
                    g, "NotImplementedError", "is-None jump peephole not supported"
                );
                return;
            }
            visit_comp_elt(g, c.comparators[ci], bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            if not emit_cmp_link(g, c.ops[ci], cloc_cmp, filter_compare) {
                codegen_fail(
                    g, "NotImplementedError", "unsupported comparison operator"
                );
                return;
            }
            ci = ci + 1;
        }
        return;
    }
    if isinstance(e, Call) {
        ca = e as Call;
        floc = call_func_loc(ca.func);
        visit_comp_elt(g, ca.func, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        g.emit_op(OP_PUSH_NULL, 0, floc);
        call_args = call_effective_args(ca);
        ai = 0;
        while ai < len(call_args) {
            visit_comp_elt(g, call_args[ai], bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            ai = ai + 1;
        }
        cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
        kws = call_effective_keywords(ca);
        if len(kws) > 0 {
            emit_call_keyword_values(g, ca, cloc_call, True);
            if codegen_busy(g) {
                return;
            }
        }
        emit_call_instruction(g, ca, cloc_call);
        return;
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
        opid = binop_id(b.op);
        if opid < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported binary operator");
            return;
        }
        # Operands emit LOAD_FAST_BORROW individually; adjacent borrow loads are
        # coalesced into LOAD_FAST_BORROW_LOAD_FAST_BORROW by emit_name_load's
        # in-comprehension fuse (CPython's superinstruction peephole).
        visit_comp_elt(g, b.left, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        visit_comp_elt(g, b.right, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        g.emit_op(OP_BINARY_OP, opid, bl);
        return;
    }
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        ul = nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
        visit_comp_elt(g, un.operand, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        opc = unary_opcode(un.op);
        if opc < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported unary operator");
            return;
        }
        g.emit_op(opc, 0, ul);
        return;
    }
    visit_expr(g, e);
}

# Bind the comprehension loop target. When `lead` is true the first evaluated
# reference in the body is the (single) loop var, so CPython fuses the store with
# that first load into STORE_FAST_LOAD_FAST, leaving a borrowed copy on the stack
# that emit_name_load consumes for that reference (comp_pending_borrow). Otherwise
# a plain STORE_FAST binds it and every reference loads its own borrow.
def comp_emit_bind_target(
    g: cfg_builder, target: expr, slots: list[int], lead: bool = False
) {
    tloc = expr_loc(target);
    g.u.comp_pending_borrow = -1;
    if len(slots) == 1 {
        if lead {
            pair_arg = slots[0] * 16 + slots[0];
            g.emit_op(OP_STORE_FAST_LOAD_FAST, pair_arg, tloc);
            g.u.comp_pending_borrow = slots[0];
        } else {
            g.emit_op(OP_STORE_FAST, slots[0], tloc);
        }
        return;
    }
    unpack_loc = tloc;
    store_loc = tloc;
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) > 0 {
            store_loc = expr_loc(elts[0]);
        }
    }
    g.emit_op(OP_UNPACK_SEQUENCE, len(slots), unpack_loc);
    pair_arg = slots[0] * 16 + slots[1];
    g.emit_op(OP_STORE_FAST_STORE_FAST, pair_arg, store_loc);
}

def comp_emit_filters(
    g: cfg_builder,
    ifs: list[expr],
    bound_names: list[str],
    loop_hdr: basicblock,
    stack_depth: int,
    cloc_comp: cloc,
    fast_index: int,
    region_start: int,
    handler_group: int,
    filter_jump_loc: cloc,
    second_fast_index: int = -1,
    swap_depth: int = 2
) -> tuple[basicblock | None, int] {
    element_entry: basicblock | None = None;
    ii = 0;
    while ii < len(ifs) {
        ife = ifs[ii];
        visit_comp_elt(g, ife, bound_names, True);
        if codegen_busy(g) {
            return (element_entry, region_start);
        }
        filter_post = g.new_block();
        comp_append_handler(
            g,
            region_start,
            filter_post.id,
            stack_depth,
            fast_index,
            cloc_comp,
            handler_group,
            second_fast_index,
            swap_depth
        );
        g.use(filter_post);
        pass_blk = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_TRUE, pass_blk.id, filter_jump_loc);
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
        g.use(pass_blk);
        region_start = pass_blk.id;
        element_entry = pass_blk;
        ii = ii + 1;
    }
    return (element_entry, region_start);
}

def comp_finish_loop(
    g: cfg_builder,
    loop_hdr: basicblock,
    for_iter_idx: int,
    region_start: int,
    iter_loc: cloc,
    stack_depth: int,
    slots: list[int],
    cloc_comp: cloc,
    handler_group: int,
    second_fast: int,
    swap_depth: int
) {
    after = g.new_block();
    loop_hdr.instrs[for_iter_idx].target_block = after.id;
    g.use(after);
    g.emit_op(OP_END_FOR, 0, iter_loc);
    g.emit_op(OP_POP_ITER, 0, iter_loc);
    protect_end = g.new_block();
    comp_append_handler(
        g,
        region_start,
        protect_end.id,
        stack_depth,
        slots[0],
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
    g.use(protect_end);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);
}

def comp_emit_single_elt(
    g: cfg_builder,
    elt: expr,
    bound_names: list[str],
    add_op: int,
    elt_loc: cloc,
    has_filters: bool,
    filter_jump_loc: cloc | None = None
) {
    emit_loc = elt_loc;
    if has_filters and filter_jump_loc is not None {
        emit_loc = filter_jump_loc;
    }
    if has_filters
        and len(bound_names) == 1
        and isinstance(elt, Name)
        and (elt as Name).id == bound_names[0] {
        fi = fast_local_index(g, (elt as Name).id);
        g.emit_op(OP_LOAD_FAST_BORROW, fi, emit_loc);
        g.emit_op(add_op, 2, emit_loc);
        return;
    }
    visit_comp_elt(g, elt, bound_names);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(add_op, 2, emit_loc);
}

def visit_comp_dict_kv(
    g: cfg_builder, dc: DictComp, bound_names: list[str], has_filters: bool = False
) {
    # Key then value in evaluation order; the first loop-var reference (usually
    # the key) consumes the STORE_FAST_LOAD_FAST borrow via emit_name_load, and
    # adjacent loop-var value loads fuse into LOAD_FAST_BORROW_LOAD_FAST_BORROW.
    map_loc = comp_dict_map_loc(dc);
    visit_comp_elt(g, dc.key, bound_names);
    if codegen_busy(g) {
        return;
    }
    visit_comp_elt(g, dc.value, bound_names);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_MAP_ADD, 2, map_loc);
}

def comp_emit_cleanup(
    g: cfg_builder, slots: list[int], cloc_comp: cloc, swap_depth: int
) {
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);
    if len(slots) == 2 {
        g.emit_op(OP_STORE_FAST, slots[1], cloc_comp);
        g.emit_op(OP_STORE_FAST, slots[0], cloc_comp);
        return;
    }
    g.emit_op(OP_STORE_FAST, slots[0], cloc_comp);
}

def comp_emit_setup(
    g: cfg_builder,
    gen: comprehension,
    slots: list[int],
    build_op: int,
    cloc_comp: cloc,
    iter_loc: cloc
) -> tuple[int, basicblock, int] {
    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        loop_hdr = g.new_block();
        return (-1, loop_hdr, -1);
    }
    g.emit_op(OP_GET_ITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
        g.emit_op(OP_SWAP, swap_depth, cloc_comp);
    } else {
        g.emit_op(OP_SWAP, swap_depth, cloc_comp);
    }
    comp_body = g.new_block();
    g.use(comp_body);
    start_blk = g.cur.id;
    g.emit_op(build_op, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);
    loop_hdr = g.new_block();
    g.use(loop_hdr);
    for_iter_idx = len(loop_hdr.instrs);
    g.emit_jump(OP_FOR_ITER, 0, iter_loc);
    return (start_blk, loop_hdr, for_iter_idx);
}

# Inline async list comprehension `[elt async for target in aiter]` inside an
# `async def`. The comprehension's implicit function is inlined (PEP 709): the
# loop uses GET_AITER / GET_ANEXT / SEND / END_ASYNC_FOR (mirroring statement
# async-for) in place of GET_ITER / FOR_ITER, while the list-build / append /
# loop-var save-restore scaffolding matches the sync inline listcomp. Single
# generator only.
def visit_list_comp_async(
    g: cfg_builder,
    lc: ListComp,
    gen: comprehension,
    bound_names: list[str],
    slots: list[int]
) {
    cloc_comp = expr_loc(lc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(lc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    `protect = g.generator_protect_start;

    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
    }

    # --- setup: evaluate iterable, GET_AITER, clear+save loop-var slot(s) ---
    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);

    # --- comp body block: BUILD_LIST, SWAP (protected list-build) ---
    comp_body = g.new_block();
    g.use(comp_body);
    g.emit_op(OP_BUILD_LIST, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);

    # --- async loop header: GET_ANEXT/LOAD_CONST/SEND/YIELD/RESUME/END_SEND ---
    loop_hdr = g.new_block();
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);

    # --- store/append block (kept separate: it is an exception-region edge) ---
    store_blk = g.new_block();
    g.use(store_blk);
    g.u.comp_depth = g.u.comp_depth + 1;
    comp_emit_bind_target(
        g, gen.target, slots, comp_lead_is_loopvar(g, gen, lc.elt, bound_names, slots)
    );
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    comp_emit_single_elt(g, lc.elt, bound_names, OP_LIST_APPEND, elt_loc, False);
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    g.u.comp_depth = g.u.comp_depth - 1;

    # --- footer: CLEANUP_THROW / JUMP_BACKWARD_NO_INTERRUPT + END_ASYNC_FOR ---
    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);

    # --- after loop: restore outer loop-var, leaving the built list on TOS ---
    after = g.new_block();
    g.use(after);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);

    # ---------------- exception regions (non-overlapping, CPython order) -------
    # Comprehension save/restore handler (SWAP/POP + restore loop-var + RERAISE),
    # covering the three ranges not owned by the async-loop handlers.
    comp_append_handler(
        g, comp_body.id, loop_hdr.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    # async loop: GET_ANEXT..SEND -> END_ASYNC_FOR
    g.u.except_regions.append(
        except_region(
            start_block=loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    # YIELD_VALUE -> CLEANUP_THROW
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup_throw.id,
            stack_depth=6,
            preserve_lasti=False
        )
    );
    # RESUME..END_SEND -> END_ASYNC_FOR
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, store_blk.id, cleanup_throw.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    # CLEANUP_THROW -> END_ASYNC_FOR
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw.id,
            end_block=cleanup_jump.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, end_async_handler.id, after.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    # PEP 479 wrap: tail (after loop through RETURN_VALUE) and head (setup before
    # BUILD_LIST). Handlers/ends resolved by emit_generator_except_handler.
    g.u.except_regions.append(
        except_region(
            start_block=after.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if `protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=`protect,
                end_block=comp_body.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    }
}

# Inline async set comprehension `{elt async for target in aiter}` inside an
# `async def`. Same shape as visit_list_comp_async with BUILD_SET/SET_ADD.
def visit_set_comp_async(
    g: cfg_builder,
    sc: SetComp,
    gen: comprehension,
    bound_names: list[str],
    slots: list[int]
) {
    cloc_comp = expr_loc(sc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(sc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    `protect = g.generator_protect_start;

    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
    }

    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);

    comp_body = g.new_block();
    g.use(comp_body);
    g.emit_op(OP_BUILD_SET, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);

    loop_hdr = g.new_block();
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);

    store_blk = g.new_block();
    g.use(store_blk);
    g.u.comp_depth = g.u.comp_depth + 1;
    comp_emit_bind_target(
        g, gen.target, slots, comp_lead_is_loopvar(g, gen, sc.elt, bound_names, slots)
    );
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    comp_emit_single_elt(g, sc.elt, bound_names, OP_SET_ADD, elt_loc, False);
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    g.u.comp_depth = g.u.comp_depth - 1;

    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);

    after = g.new_block();
    g.use(after);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);

    comp_append_handler(
        g, comp_body.id, loop_hdr.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup_throw.id,
            stack_depth=6,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, store_blk.id, cleanup_throw.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw.id,
            end_block=cleanup_jump.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, end_async_handler.id, after.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=after.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if `protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=`protect,
                end_block=comp_body.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    }
}

# Inline async dict comprehension `{k: v async for target in aiter}` inside an
# `async def`. Same shape as visit_list_comp_async with BUILD_MAP/MAP_ADD.
def visit_dict_comp_async(
    g: cfg_builder,
    dc: DictComp,
    gen: comprehension,
    bound_names: list[str],
    slots: list[int]
) {
    cloc_comp = expr_loc(dc);
    iter_loc = expr_loc(gen.iter);
    map_loc = comp_dict_map_loc(dc);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    `protect = g.generator_protect_start;

    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
    }

    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);

    comp_body = g.new_block();
    g.use(comp_body);
    g.emit_op(OP_BUILD_MAP, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);

    loop_hdr = g.new_block();
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);

    store_blk = g.new_block();
    g.use(store_blk);
    g.u.comp_depth = g.u.comp_depth + 1;
    comp_emit_bind_target(
        g, gen.target, slots, comp_lead_is_loopvar(g, gen, dc.key, bound_names, slots)
    );
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    visit_comp_dict_kv(g, dc, bound_names, False);
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, map_loc);
    g.u.comp_depth = g.u.comp_depth - 1;

    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);

    after = g.new_block();
    g.use(after);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);

    comp_append_handler(
        g, comp_body.id, loop_hdr.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup_throw.id,
            stack_depth=6,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, store_blk.id, cleanup_throw.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw.id,
            end_block=cleanup_jump.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, end_async_handler.id, after.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=after.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if `protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=`protect,
                end_block=comp_body.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    }
}

# Inline list comprehension (module-level / expression context).
def visit_list_comp(g: cfg_builder, lc: ListComp) {
    if len(lc.generators) == 0 {
        codegen_fail(g, "NotImplementedError", "empty list comprehension");
        return;
    }
    gen = lc.generators[0];
    bound_names = comp_bound_names_from_target(gen.target);
    slots = comp_target_slots(g, gen.target);
    if bound_names is None or slots is None {
        codegen_fail(g, "NotImplementedError", "unsupported list comprehension target");
        return;
    }
    if gen.is_async == 1 {
        if len(lc.generators) != 1 {
            codegen_fail(
                g,
                "NotImplementedError",
                "async list comprehension with multiple generators"
            );
            return;
        }
        visit_list_comp_async(g, lc, gen, bound_names, slots);
        return;
    }
    cloc_comp = expr_loc(lc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(lc.elt);
    filter_jump_loc = expr_loc(lc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    setup = comp_emit_setup(g, gen, slots, OP_BUILD_LIST, cloc_comp, iter_loc);
    if codegen_busy(g) {
        return;
    }
    g.u.comp_depth = g.u.comp_depth + 1;
    start_blk = setup[0];
    loop_hdr = setup[1];
    for_iter_idx = setup[2];
    swap_depth = 2;
    stack_depth = 3;
    second_fast = -1;
    if len(slots) == 2 {
        swap_depth = 3;
        stack_depth = 4;
        second_fast = slots[1];
    }
    comp_emit_bind_target(
        g, gen.target, slots, comp_lead_is_loopvar(g, gen, lc.elt, bound_names, slots)
    );
    if codegen_busy(g) {
        return;
    }
    filt = comp_emit_filters(
        g,
        gen.ifs,
        bound_names,
        loop_hdr,
        stack_depth,
        cloc_comp,
        slots[0],
        start_blk,
        handler_group,
        filter_jump_loc,
        second_fast,
        swap_depth
    );
    if codegen_busy(g) {
        return;
    }
    region_start = filt[1];
    comp_emit_single_elt(
        g,
        lc.elt,
        bound_names,
        OP_LIST_APPEND,
        elt_loc,
        len(gen.ifs) > 0,
        filter_jump_loc
    );
    if codegen_busy(g) {
        return;
    }
    if len(gen.ifs) > 0 {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
    } else {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    }
    g.u.comp_depth = g.u.comp_depth - 1;
    comp_finish_loop(
        g,
        loop_hdr,
        for_iter_idx,
        region_start,
        iter_loc,
        stack_depth,
        slots,
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
}

# Inline set comprehension.
def visit_set_comp(g: cfg_builder, sc: SetComp) {
    if len(sc.generators) == 0 {
        codegen_fail(g, "NotImplementedError", "empty set comprehension");
        return;
    }
    gen = sc.generators[0];
    bound_names = comp_bound_names_from_target(gen.target);
    slots = comp_target_slots(g, gen.target);
    if bound_names is None or slots is None {
        codegen_fail(g, "NotImplementedError", "unsupported set comprehension target");
        return;
    }
    if gen.is_async == 1 {
        if len(sc.generators) != 1 {
            codegen_fail(
                g,
                "NotImplementedError",
                "async set comprehension with multiple generators"
            );
            return;
        }
        visit_set_comp_async(g, sc, gen, bound_names, slots);
        return;
    }
    cloc_comp = expr_loc(sc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(sc.elt);
    filter_jump_loc = expr_loc(sc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    setup = comp_emit_setup(g, gen, slots, OP_BUILD_SET, cloc_comp, iter_loc);
    if codegen_busy(g) {
        return;
    }
    g.u.comp_depth = g.u.comp_depth + 1;
    start_blk = setup[0];
    loop_hdr = setup[1];
    for_iter_idx = setup[2];
    swap_depth = 2;
    stack_depth = 3;
    second_fast = -1;
    if len(slots) == 2 {
        swap_depth = 3;
        stack_depth = 4;
        second_fast = slots[1];
    }
    comp_emit_bind_target(
        g, gen.target, slots, comp_lead_is_loopvar(g, gen, sc.elt, bound_names, slots)
    );
    if codegen_busy(g) {
        return;
    }
    filt = comp_emit_filters(
        g,
        gen.ifs,
        bound_names,
        loop_hdr,
        stack_depth,
        cloc_comp,
        slots[0],
        start_blk,
        handler_group,
        filter_jump_loc,
        second_fast,
        swap_depth
    );
    if codegen_busy(g) {
        return;
    }
    region_start = filt[1];
    comp_emit_single_elt(
        g, sc.elt, bound_names, OP_SET_ADD, elt_loc, len(gen.ifs) > 0, filter_jump_loc
    );
    if codegen_busy(g) {
        return;
    }
    if len(gen.ifs) > 0 {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
    } else {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    }
    g.u.comp_depth = g.u.comp_depth - 1;
    comp_finish_loop(
        g,
        loop_hdr,
        for_iter_idx,
        region_start,
        iter_loc,
        stack_depth,
        slots,
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
}

# Inline dict comprehension.
def visit_dict_comp(g: cfg_builder, dc: DictComp) {
    if len(dc.generators) == 0 {
        codegen_fail(g, "NotImplementedError", "empty dict comprehension");
        return;
    }
    gen = dc.generators[0];
    bound_names = comp_bound_names_from_target(gen.target);
    slots = comp_target_slots(g, gen.target);
    if bound_names is None or slots is None {
        codegen_fail(g, "NotImplementedError", "unsupported dict comprehension target");
        return;
    }
    if gen.is_async == 1 {
        if len(dc.generators) != 1 {
            codegen_fail(
                g,
                "NotImplementedError",
                "async dict comprehension with multiple generators"
            );
            return;
        }
        visit_dict_comp_async(g, dc, gen, bound_names, slots);
        return;
    }
    cloc_comp = expr_loc(dc);
    iter_loc = expr_loc(gen.iter);
    filter_jump_loc = comp_dict_map_loc(dc);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    setup = comp_emit_setup(g, gen, slots, OP_BUILD_MAP, cloc_comp, iter_loc);
    if codegen_busy(g) {
        return;
    }
    g.u.comp_depth = g.u.comp_depth + 1;
    start_blk = setup[0];
    loop_hdr = setup[1];
    for_iter_idx = setup[2];
    swap_depth = 2;
    stack_depth = 3;
    second_fast = -1;
    if len(slots) == 2 {
        swap_depth = 3;
        stack_depth = 4;
        second_fast = slots[1];
    }
    comp_emit_bind_target(
        g, gen.target, slots, comp_lead_is_loopvar(g, gen, dc.key, bound_names, slots)
    );
    if codegen_busy(g) {
        return;
    }
    filt = comp_emit_filters(
        g,
        gen.ifs,
        bound_names,
        loop_hdr,
        stack_depth,
        cloc_comp,
        slots[0],
        start_blk,
        handler_group,
        filter_jump_loc,
        second_fast,
        swap_depth
    );
    if codegen_busy(g) {
        return;
    }
    region_start = filt[1];
    visit_comp_dict_kv(g, dc, bound_names, len(gen.ifs) > 0);
    if codegen_busy(g) {
        return;
    }
    if len(gen.ifs) > 0 {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
    } else {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, comp_dict_map_loc(dc));
    }
    g.u.comp_depth = g.u.comp_depth - 1;
    comp_finish_loop(
        g,
        loop_hdr,
        for_iter_idx,
        region_start,
        iter_loc,
        stack_depth,
        slots,
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
}

# Lower an if/while test (CPython bool context): single Compare uses COMPARE_OP
# with bool oparg; other expressions use TO_BOOL after visit_expr.
# visit_test_expr return kinds. NORMAL leaves a bool on the stack, consumed by a
# POP_JUMP_IF_FALSE. IS_NONE / IS_NOT_NONE leave the bare operand on the stack;
# the caller must consume it with POP_JUMP_IF_NOT_NONE / POP_JUMP_IF_NONE (the
# CPython `x is None` jump peephole), via emit_branch_if_test_false.
glob TEST_NORMAL: int = 0,
     TEST_IS_NONE: int = 1,
     TEST_IS_NOT_NONE: int = 2;

def visit_test_expr(
    g: cfg_builder, e: expr, test_loc: cloc, allow_none_peephole: bool = False
) -> int {
    if isinstance(e, Compare) {
        c = e as Compare;
        if len(c.ops) == 1 {
            cloc_cmp = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
            if is_none_identity_test(c.ops[0], c.comparators[0]) {
                if allow_none_peephole {
                    # Emit only the left operand; the branch site folds the
                    # identity + jump into POP_JUMP_IF_NONE / _NOT_NONE.
                    visit_expr(g, c.left);
                    # CPython compiles the None comparand's LOAD_CONST (adding
                    # None to co_consts) before the peephole removes the load, so
                    # None still occupies its const-pool slot. Register it here to
                    # match co_consts ordering (and suppress a spurious dead
                    # small-int slot at index 0).
                    g.u.add_const(py_none());
                    if isinstance(c.ops[0], Is) {
                        return TEST_IS_NONE;
                    }
                    return TEST_IS_NOT_NONE;
                }
                codegen_fail(
                    g, "NotImplementedError", "is-None jump peephole not supported"
                );
                return TEST_NORMAL;
            }
            visit_expr(g, c.left);
            visit_expr(g, c.comparators[0]);
            if not emit_cmp_link(g, c.ops[0], cloc_cmp, True) {
                codegen_fail(
                    g, "NotImplementedError", "unsupported comparison operator"
                );
                return TEST_NORMAL;
            }
            return TEST_NORMAL;
        }
    }
    visit_expr(g, e);
    g.emit_op(OP_TO_BOOL, 0, test_loc);
    return TEST_NORMAL;
}

# Emit the conditional branch taken when a visit_test_expr result is FALSE. For
# the None-identity kinds this is the CPython jump peephole:
#   `x is None`     -> POP_JUMP_IF_NOT_NONE  (branch away when x is NOT None)
#   `x is not None` -> POP_JUMP_IF_NONE      (branch away when x IS None)
def emit_branch_if_test_false(g: cfg_builder, kind: int, target_id: int, loc: cloc) {
    if kind == TEST_IS_NONE {
        g.emit_jump(OP_POP_JUMP_IF_NOT_NONE, target_id, loc);
        return;
    }
    if kind == TEST_IS_NOT_NONE {
        g.emit_jump(OP_POP_JUMP_IF_NONE, target_id, loc);
        return;
    }
    g.emit_jump(OP_POP_JUMP_IF_FALSE, target_id, loc);
}

# Lower `lambda ...: expr` into nested PyCode + MAKE_FUNCTION (value on stack).
def visit_lambda(g: cfg_builder, lam: Lambda) {
    lloc = nloc(lam.lineno, lam.end_lineno, lam.col_offset, lam.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "lambda without symtable");
        return;
    }
    sym_fn = sym_function_child_at(g.sym_top, "lambda", lam.lineno, lam.col_offset);
    if sym_fn is None {
        codegen_fail(g, "SystemError", "missing symtable for lambda");
        return;
    }
    u_fn = compile_lambda_cfg(lam, g.u.filename, sym_fn, g.private);
    if u_fn.diag is not None {
        g.u.diag = u_fn.diag;
        return;
    }
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return;
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    emit_make_function_with_closure(g, sym_fn, co, lloc, lam.args);
}

# Build unverified_cfg for a lambda body (expression + RETURN_VALUE).
def compile_lambda_cfg(
    lam: Lambda, filename: str, sym_fn: sym_block, private: str | None = None
) -> unverified_cfg {
    (argcount, posonly, kwonly) = function_argcounts(lam.args);
    u = unverified_cfg(
        filename=filename, name="<lambda>", qualname="<lambda>", firstlineno=lam.lineno
    );
    u.argcount = argcount;
    u.posonlyargcount = posonly;
    u.kwonlyargcount = kwonly;
    u.flags = function_code_flags(lam.args);
    u.varnames = fast_varnames_from_sym(sym_fn);
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_fn, private);
    emit_function_prologue(g, sym_fn, lam.lineno);
    bloc = expr_loc(lam.body);
    visit_expr(g, lam.body);
    if codegen_busy(g) {
        return u;
    }
    g.emit_op(OP_RETURN_VALUE, 0, bloc);
    return u;
}
