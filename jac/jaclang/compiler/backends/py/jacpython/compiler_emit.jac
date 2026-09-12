import from jaclang.compiler.backends.py.jacpython.compiler_dispatch { stmt_handlers }
# Expression-side lowering: visit_expr, expression/comprehension/lambda
# visitors, call/slice/await emission primitives, and the shared name/
# const/cell plumbing used by both expression and statement lowering.

# Split from compiler_codegen.jac (band-11 modularization): statement
# dispatch stays in compiler_codegen.jac and imports this module; this
# module only imports lower layers (no cycles).

import from jaclang.runtime.python.objects {
    PyFloat,
    PyComplex,
    PyObj,
    PyBool,
    PyInt,
    PyStr,
    py_none,
    PyNoneType,
    PySlice,
    PyCode,
    PyTuple,
    PySet,
    is_error
}
import from jaclang.runtime.python.opcode_meta {
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
    OP_LOAD_FROM_DICT_OR_GLOBALS,
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
    OP_CALL_FUNCTION_EX,
    OP_LOAD_LOCALS,
    OP_LOAD_FROM_DICT_OR_DEREF,
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
    OP_LOAD_SUPER_ATTR,
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
    OP_DICT_MERGE,
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
    OP_CONVERT_VALUE,
    OP_FORMAT_SIMPLE,
    OP_FORMAT_WITH_SPEC,
    OP_BUILD_STRING,
    OP_BUILD_TEMPLATE,
    OP_BUILD_INTERPOLATION,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_AND_CLEAR,
    OP_STORE_FAST,
    OP_STORE_FAST_MAYBE_NULL,
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
    except_region,
    with_unwind_rec,
    cleanup_frame,
    control_unwind,
    await_footer_job,
    try_await_frame,
    comp_handler,
}
import from jaclang.compiler.frontend.python.compiler_symtable {
    sym_block,
    sym_dict_get,
    sym_flag_set,
    sym_scope_of,
    sym_sorted_names,
    mangle_name,
    sym_mangle_name,
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
    optimize_swap_range,
    build_layout_pos,
    layout_pos
}
import from jaclang.compiler.backends.py.jacpython.assembler { assemble }
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    fold_default_leaf_values,
    args_have_kw_defaults,
    nested_code_qualname,
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
    return sym_mangle_name(g.private, g.sym_top, name)
        if g.sym_top is not None
        else mangle_name(g.private, name);
}

# Fast locals for a compile unit. Module scope: comprehension iteration variables
# only. Function scope: parameters (definition order) then other locals (sorted).
def inline_storage_names(
    block: sym_block, cells_only: bool = False, owner: sym_block | None = None
) -> list[str] {
    if owner is None {
        owner = block;
    }
    occupied = sym_block_tuple_names(owner.symbols, SCOPE_FREE)
        + owner.class_free_names;
    if not cells_only {
        if owner.block_type == "function" {
            occupied.extend(sym_block_tuple_names(owner.symbols, SCOPE_LOCAL));
        }
    }
    names: list[str] = [];
    for child in block.children {
        if child.inlined {
            for (name, alias) in child.inline_aliases.items() {
                if alias not in occupied
                    and alias not in names
                    and (
                        not cells_only
                        or sym_scope_of(child.symbols[name]) == SCOPE_CELL
                    ) {
                    names.append(alias);
                }
            }
            for name in inline_storage_names(child, cells_only, owner) {
                if name not in names {
                    names.append(name);
                }
            }
        }
    }
    return names;
}

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
        return out
            + [
                name
                for name in inline_storage_names(block)
                if name not in out
            ];
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
    return out + inline_storage_names(block);
}

def cellvars_from_sym(block: sym_block) -> list[str] {
    names = sym_block_tuple_names(block.symbols, SCOPE_CELL);
    return names
        + [
            name
            for name in inline_storage_names(block, True)
            if name not in names
        ];
}

def freevars_from_sym(block: sym_block) -> list[str] {
    names = sym_block_tuple_names(block.symbols, SCOPE_FREE);
    return sorted(set(names + block.class_free_names));
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
    return localsplus_index_u(g.u, g.scope_names.get(name, name));
}

# CPython emits MAKE_CELL(s), optional COPY_FREE_VARS, then RESUME. Generators
# and coroutines prepend RETURN_GENERATOR; POP_TOP before RESUME (protect region
# starts at the following block). Nested-scope locations (CPython 3.14):
# MAKE_CELL / COPY_FREE_VARS carry NO_LOCATION; RETURN_GENERATOR / POP_TOP sit
# on the def line with no columns (NO_COLUMNS linetable form); only RESUME
# carries a full location -- the def line, full-width zero columns.
# (Module scope differs: its RESUME uses lineno 0; see compile_exec.)
def def_line_no_columns(firstlineno: int) -> cloc {
    return loc(firstlineno, firstlineno, -1, -1);
}

def emit_function_prologue(
    g: cfg_builder, sym_fn: sym_block, firstlineno: int, is_suspendable: bool = False
) -> int {
    u = g.u;
    u.cellvars = cellvars_from_sym(sym_fn);
    u.freevars = freevars_from_sym(sym_fn);
    noloc = no_loc();
    # CPython flowgraph order: COPY_FREE_VARS precedes the MAKE_CELLs
    # (matches the annotation-format / generic-parameter scopes).
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), noloc);
    }
    initial_cells = sym_block_tuple_names(sym_fn.symbols, SCOPE_CELL);
    ci = 0;
    while ci < len(initial_cells) {
        lp = localsplus_index_u(u, initial_cells[ci]);
        g.emit_op(OP_MAKE_CELL, lp, noloc);
        ci = ci + 1;
    }
    protect_start = -1;
    g.generator_protect_start = -1;
    if is_suspendable {
        protect_start = emit_suspendable_prologue(g, firstlineno);
    }
    g.emit_op(OP_RESUME, 0, loc(firstlineno, firstlineno, 0, 0));
    return protect_start;
}

# Shared by functions and source scopes with top-level await. The caller
# emits RESUME with its own source location after establishing suspension.
def emit_suspendable_prologue(
    g: cfg_builder, firstlineno: int, wrap_stopiteration: bool = True
) -> int {
    suspend_loc = def_line_no_columns(firstlineno);
    g.emit_op(OP_RETURN_GENERATOR, 0, suspend_loc);
    g.emit_op(OP_POP_TOP, 0, suspend_loc);
    resume_blk = g.new_block();
    g.use(resume_blk);
    # Top-level coroutine code preserves escaping StopIteration unchanged.
    g.generator_protect_start = resume_blk.id if wrap_stopiteration else -1;
    return g.generator_protect_start;
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
) -> int {
    als = emit_await_send_loop_header(
        g, get_iter_op, get_iter_arg, resume_after_yield_arg, yloc
    );
    # Keep delegated cleanup inside its lexical protection. The normal edge
    # skips the cold handler; a thrown exception restores the complete operand
    # prefix (including call arguments and enclosing exception state).
    cleanup = g.new_deferred_block();
    continuation = g.new_deferred_block();
    g.use(als.end_send_blk);
    g.emit_jump(OP_JUMP_FORWARD, continuation.id, yloc);
    g.use(cleanup);
    g.emit_op(OP_CLEANUP_THROW, 0, yloc);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, als.end_send_blk.id, yloc);
    g.use(continuation);
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup.id,
            stack_depth=0,
            depth_from_block=als.yield_blk.id,
            depth_offset=1
        )
    );
    return als.end_send_blk.id;
}

# Place every still-queued await CLEANUP_THROW footer after all warm code
# (unit end, before the deferred comp / generator-except handlers). CPython
# keeps these cold blocks after the body's final RETURN, in queue order.
def flush_pending_await_footers(g: cfg_builder) {
    fi = 0;
    while fi < len(g.pending_await_footers) {
        pf = g.pending_await_footers[fi] as await_footer_job;
        g.use(pf.ct);
        g.emit_op(OP_CLEANUP_THROW, 0, pf.loc);
        g.use(pf.cj);
        g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, pf.end_send.id, pf.loc);
        if pf.emit_ct_row {
            g.u.except_regions.append(
                except_region(
                    start_block=pf.ct.id,
                    end_block=pf.cj.id,
                    handler_block=-1,
                    stack_depth=2,
                    preserve_lasti=True
                )
            );
            g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        }
        fi = fi + 1;
    }
    g.pending_await_footers = [];
    g.open_gen_tails = [];
}

# Trim every open generator-tail row at a new await's yield window: the row
# up to the window becomes that await's generator region (the A row CPython
# closes/reopens per window), and the window's own B row plus the await's
# post-resume rows cover everything after. Without the trim the stale row
# would win find_handler's first match and misroute the yield window.
# Returns True when an open row already starts at start_blk (the caller then
# skips its own A row: the trimmed tail IS that row).
def split_open_gen_tails(g: cfg_builder, y_blk: int, start_blk: int) -> bool {
    pos = build_layout_pos(g.u);
    y_pos = layout_pos(pos, y_blk);
    if y_pos < 0 {
        return False;
    }
    start_pos = layout_pos(pos, start_blk);
    covered = False;
    ti = 0;
    while ti < len(g.open_gen_tails) {
        ri = g.open_gen_tails[ti];
        reg = g.u.except_regions[ri];
        if layout_pos(pos, reg.start_block) < y_pos
            and y_pos < layout_pos(pos, reg.end_block) {
            reg.end_block = y_blk;
        }
        if layout_pos(pos, reg.start_block) == start_pos {
            covered = True;
        }
        ti = ti + 1;
    }
    return covered;
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
    # Defer layout until each label's first use (CPython USE_LABEL). Eager
    # add_block here placed yield/send fragments ahead of following loop
    # bodies (yield from then for in the same outer loop) and broke stackdepth.
    send_blk = g.new_deferred_block();
    yield_blk = g.new_deferred_block();
    after_resume_blk = g.new_deferred_block();
    end_send_blk = g.new_deferred_block();
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
    cleanup_throw_blk = g.new_deferred_block();
    cleanup_jump_blk = g.new_deferred_block();
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
    after_resume_preserve_lasti: bool = True,
    from_delegation: bool = False
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
    frame: try_await_frame | None = None;
    if from_delegation and len(g.open_try_frames) > 0 {
        frame = g.open_try_frames[len(g.open_try_frames) - 1];
    }
    # Generator-protect region A. CPython closes it at each construct
    # boundary and reopens at the previous await's after-resume: the row
    # starts at the barrier (function entry until the first boundary), and
    # inside a try body it is trimmed to end at the try's opening NOP --
    # the try's own split span covers the body up to the yield window.
    a_start = `protect;
    if g.await_region_barrier > a_start {
        a_start = g.await_region_barrier;
    }
    # Trim open generator-tail rows around this await's yield window first.
    # a_covered: an open row already starts at a_start (its trimmed span is
    # this await's generator region), so skip emitting a duplicate A row.
    a_covered = False;
    if from_delegation {
        a_covered = split_open_gen_tails(g, als.yield_blk.id, a_start);
    }
    a_end = als.yield_blk.id;
    if frame is not None {
        fr = frame as try_await_frame;
        if fr.nop_blk < a_end {
            a_end = fr.nop_blk;
        }
        fr.carves.append((als.yield_blk.id, als.after_resume_blk.id));
    }
    if a_start < a_end and not a_covered {
        g.u.except_regions.append(
            except_region(
                start_block=a_start,
                end_block=a_end,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        g.open_gen_tails.append(len(g.u.except_regions) - 1);
    }
    g.await_region_barrier = als.after_resume_blk.id;
    # Yield-window carve -> CLEANUP_THROW.
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
    if frame is None {
        # Post-resume generator region. Following a previous delegation,
        # CPython ends this row at the PREVIOUS cleanup jump (the CJ block
        # itself stays uncovered) and gives this pair its own [ct..cj) row
        # when the footers are placed; the first delegation's row runs to its
        # own CJ (coalesced with the CT coverage). Inside a try body this row
        # is emitted by the frame flush instead ([protect_end .. first CT)).
        prev_cj = -1;
        njobs = len(g.pending_await_footers);
        if njobs > 1 {
            prev_cj = (g.pending_await_footers[njobs - 2] as await_footer_job).cj.id;
        }
        c_end = pep479_end_blk;
        if prev_cj >= 0 {
            c_end = prev_cj;
            (g.pending_await_footers[njobs - 1] as await_footer_job).emit_ct_row = True;
        }
        g.u.except_regions.append(
            except_region(
                start_block=als.after_resume_blk.id,
                end_block=c_end,
                handler_block=ar_handler,
                stack_depth=after_resume_stack_depth,
                preserve_lasti=after_resume_preserve_lasti
            )
        );
        if after_resume_handler < 0 {
            g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
            g.open_gen_tails.append(len(g.u.except_regions) - 1);
        }
    }
}

def emit_control_unwind(
    g: cfg_builder, wloc: cloc, preserve_value: bool, stop_depth: int = 0
) -> control_unwind {
    frames = g.cleanup_stack[:];
    if len(frames) <= stop_depth {
        return control_unwind();
    }
    end = g.new_deferred_block();
    loops = g.loop_stack[:];
    saved_depth = g.handler_nest_depth;
    loop_index = len(loops);
    try {
        for frame_index in range(len(frames) - 1, stop_depth - 1, -1) {
            fb = frames[frame_index];
            boundary = g.new_block();
            g.use(boundary);
            fb.unwind_spans.append((boundary.id, end.id));
            g.cleanup_stack = frames[:frame_index];
            if preserve_value {
                while loop_index > fb.loop_depth {
                    loop_index -= 1;
                    if loops[loop_index].pops_iter {
                        g.emit_op(OP_SWAP, 2, wloc);
                        g.emit_op(OP_POP_TOP, 0, wloc);
                    }
                }
                g.loop_stack = loops[:loop_index];
            }
            if fb.kind == "finally" {
                # The pending return stays below the cleanup's operands. A
                # return/break/continue inside that cleanup must discard it.
                if preserve_value {
                    g.cleanup_stack.append(
                        cleanup_frame(kind="value", pop_count=1, loop_depth=loop_index)
                    );
                    g.handler_nest_depth += 1;
                }
                cont = stmt_handlers["visit_cleanup_stmts"](g, fb.body, fb.ann_ctx);
                if preserve_value {
                    g.handler_nest_depth -= 1;
                }
                if cont.terminated {
                    return control_unwind(end=end, terminated=True);
                }
            } elif fb.kind == "exception" or fb.kind == "value" {
                for unused in range(fb.pop_count) {
                    if preserve_value {
                        g.emit_op(OP_SWAP, 2, wloc);
                    }
                    g.emit_op(OP_POP_TOP, 0, wloc);
                    g.handler_nest_depth -= 1;
                }
                if fb.kind == "exception" {
                    if preserve_value {
                        g.emit_op(OP_SWAP, 2, wloc);
                    }
                    g.emit_op(OP_POP_EXCEPT, 0, wloc);
                    g.handler_nest_depth -= 1;
                    if fb.exception_name is not None {
                        stmt_handlers["clear_exception_name"](
                            g, fb.exception_name, wloc
                        );
                    }
                }
            } elif fb.kind == "with" {
                if preserve_value {
                    g.emit_op(OP_SWAP, 3, wloc);
                    g.emit_op(OP_SWAP, 2, wloc);
                }
                none_idx = g.u.add_const(py_none());
                for unused in range(3) {
                    g.emit_op(OP_LOAD_CONST, none_idx, wloc);
                }
                g.emit_op(OP_CALL, 3, wloc);
                if fb.is_async {
                    emit_send_delegation_loop(g, OP_GET_AWAITABLE, 2, 3, wloc);
                }
                g.emit_op(OP_POP_TOP, 0, wloc);
                g.handler_nest_depth -= 2;
            }
        }
    } finally {
        g.cleanup_stack = frames;
        g.loop_stack = loops;
        g.handler_nest_depth = saved_depth;
    }
    return control_unwind(end=end);
}

def finish_control_unwind(g: cfg_builder, result: control_unwind) {
    if result.end is not None {
        terminated = g.cur;
        g.use(result.end);
        g.use(terminated);
    }
}

def emit_return_unwind(g: cfg_builder, wloc: cloc) -> control_unwind {
    return emit_control_unwind(g, wloc, True);
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
    # CPython visits each default expr (interning every scalar leaf const in
    # pre-order), then the optimizer folds the BUILD_TUPLE and appends the
    # folded tuple const AFTER all visit-time consts (stage_late_const). Dead
    # leaves are dropped later by remove_unused_consts (index 0 always kept).
    values: list[PyObj] = [];
    leaves: list[expr] = [];
    di = 0;
    while di < len(defaults) {
        v = fold_default_leaf_values(defaults[di], leaves);
        if v is None {
            break;
        }
        values.append(v);
        di = di + 1;
    }
    if len(values) == len(defaults) {
        li = 0;
        while li < len(leaves) {
            lf = leaves[li];
            register_int_literal_const(g, lf, True);
            if isinstance(lf, Constant)
                and not isinstance((lf as Constant).value, PyInt) {
                g.u.add_const((lf as Constant).value);
            }
            li = li + 1;
        }
        idx = g.u.stage_late_const(PyTuple(t="tuple", items=values));
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
            kwonly_arg = args.kwonlyargs[ki];
            key_idx = g.u.add_const(
                PyStr(t="str", val=codegen_mangle(g, kwonly_arg.arg))
            );
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
    # CPython adds the code object const at MAKE_FUNCTION emission time, i.e.
    # AFTER the defaults/kwdefaults visitors interned their consts.
    if has_defaults {
        fn_args = args as arguments;
        if not emit_function_defaults(g, fn_args.defaults, tloc) {
            return;
        }
    }
    if has_kwdefaults {
        fn_args = args as arguments;
        if not emit_function_kwdefaults(g, fn_args, tloc) {
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
    cidx = g.u.add_const(co);
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
            and ch.annotation_kind != "an annotation"
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

def emit_local_or_cell_store(g: cfg_builder, name: str, tloc: cloc) -> bool {
    name = codegen_mangle(g, name);
    # Cell/free scope FIRST (see emit_name_load): a STORE_FAST into a
    # cellvar's converted slot would replace the cell object itself,
    # desynchronizing every closure sharing it. CPython stores deref.
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            g.emit_op(OP_STORE_DEREF, idx, tloc);
            return True;
        }
    }
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_STORE_FAST, fi, tloc);
        return True;
    }
    return False;
}

def emit_name_load(
    g: cfg_builder, name: str, tloc: cloc, for_call: bool = False
) -> bool {
    # Returns True when a separate PUSH_NULL is required before CALL (LOAD_NAME
    # and fast locals). LOAD_GLOBAL folds NULL into the oparg low bit (CPython 3.14).
    name = codegen_mangle(g, name);
    # Cell/free scope FIRST: a cellvar param shares the localsplus fast-slot
    # region, but its slot holds the raw PyCell (LOAD_FAST_BORROW's closure
    # view). Reads must deref (LOAD_DEREF unwraps) exactly like CPython, which
    # never emits a fast load for a CO_FAST_CELL name -- a raw cell escaping
    # as a call argument crashed functools.wraps (wrapped=cell) and
    # recursive_repr (user_function=cell).
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            if g.sym_top.block_type == "class" and scope == SCOPE_FREE {
                # Class bodies resolve free names through the class namespace
                # first: LOAD_LOCALS + LOAD_FROM_DICT_OR_DEREF lets a same-named
                # class attribute shadow the enclosing cell (CPython
                # compile_name_op class-scope rule).
                g.emit_op(OP_LOAD_LOCALS, 0, tloc);
                g.emit_op(OP_LOAD_FROM_DICT_OR_DEREF, idx, tloc);
            } elif g.u.classdict_names and name != "__classdict__" {
                # Lazy class annotations and type expressions see the current
                # class namespace before a captured enclosing binding.
                g.emit_op(OP_LOAD_DEREF, localsplus_index(g, "__classdict__"), tloc);
                g.emit_op(OP_LOAD_FROM_DICT_OR_DEREF, idx, tloc);
            } else {
                g.emit_op(OP_LOAD_DEREF, idx, tloc);
            }
            return True;
        }
    }
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
    flags = sym_dict_get(g.sym_top.symbols, name, 0) if g.sym_top is not None else 0;
    if g.u.classdict_names and sym_scope_of(flags) != SCOPE_GLOBAL_EXPLICIT {
        # Class-scope __annotate__ body: every free name resolves through the
        # class namespace first, then globals/builtins (PEP 649 classdict
        # resolution; CPython emits the LOAD_DEREF/LOAD_FROM_DICT_OR_GLOBALS
        # pair per name -- the pair also (re-)seeds the __classdict__ cell
        # that stays on the value stack across entries).
        clp = localsplus_index_u(g.u, "__classdict__");
        g.emit_op(OP_LOAD_DEREF, clp, tloc);
        idx = g.u.add_name(name);
        g.emit_op(OP_LOAD_FROM_DICT_OR_GLOBALS, idx, tloc);
        return True;
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
    # Cell/free names deref even when they occupy a localsplus fast slot
    # (CO_FAST_CELL param): a fast load would leak the raw PyCell.
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            return OP_LOAD_DEREF;
        }
    }
    if fast_local_index(g, name) >= 0 {
        return OP_LOAD_FAST;
    }
    if g.sym_top is None {
        return OP_LOAD_NAME;
    }
    flags = sym_dict_get(g.sym_top.symbols, name, 0);
    scope = sym_scope_of(flags);
    if scope == SCOPE_GLOBAL_EXPLICIT
        or (scope == SCOPE_GLOBAL_IMPLICIT and g.sym_top.block_type != "module") {
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
                # CPython keeps the dead small-int slot ONLY when the pool is
                # still empty (index 0), mirroring register_int_literal_const;
                # later subscript keys are pure LOAD_SMALL_INT with no entry.
                in_class_body = g.sym_top is not None
                    and g.sym_top.block_type == "class";
                if len(g.u.consts) == 0 and not in_class_body {
                    g.u.add_const(cv);
                }
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
        if ei < n - 1 {
            g.emit_op(OP_SWAP, 2, cloc_cmp);
            g.emit_op(OP_COPY, 2, cloc_cmp);
        }
        if not emit_cmp_link(g, c.ops[ei] as PyObj, cloc_cmp, False) {
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
            join = g.new_deferred_block();
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
        # Defer until after the rhs is visited. Eager placement left the join
        # between short-circuit fragments and the following statement (e.g. a
        # second `if`), breaking stackdepth on `a and not (b and c)` tests.
        join = g.new_deferred_block();
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
            fe_blk = false_exit as basicblock;
            false_target = fe_blk.id;
        } else {
            join_blk = join as basicblock;
            false_target = join_blk.id;
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

# F-string lowering (CPython 3.14 shapes, pinned via host dis):
#   text Constant part            -> LOAD_CONST
#   FormattedValue                -> <value>
#                                    [CONVERT_VALUE 1|2|3]  (!s/!r/!a)
#                                    FORMAT_SIMPLE          (no spec)
#                                    <spec>; FORMAT_WITH_SPEC
#   parts joined                  -> BUILD_STRING n
# The host emits the join only for two or more parts (its optimizer drops
# BUILD_STRING 1), so a lone part reduces to its own sequence.
def fstring_conversion_oparg(conversion: int) -> int {
    # AST conversion codes: -1 none, 115 's', 114 'r', 97 'a' (PEP 501-era
    # CPython convention); CONVERT_VALUE opargs: 0 none, 1 str, 2 repr,
    # 3 ascii; -1 flags an unrecognized code (caller reports it).
    if conversion == -1 {
        return 0;
    }
    if conversion == 115 {
        return 1;
    }
    if conversion == 114 {
        return 2;
    }
    if conversion == 97 {
        return 3;
    }
    return -1;
}

def emit_joinedstr(g: cfg_builder, js: JoinedStr) {
    jsloc = nloc(js.lineno, js.end_lineno, js.col_offset, js.end_col_offset);
    vals = js.values if js.values is not None else [];
    if not vals {
        g.emit_op(OP_LOAD_CONST, g.u.add_const(PyStr(t="str", val="")), jsloc);
        return;
    }
    vi = 0;
    while vi < len(vals) {
        v = vals[vi];
        if isinstance(v, FormattedValue) {
            fv = v as FormattedValue;
            vloc = expr_loc(fv);
            visit_expr(g, fv.value);
            if codegen_busy(g) {
                return;
            }
            conv = fstring_conversion_oparg(fv.conversion);
            if conv < 0 {
                codegen_fail(g, "SyntaxError", "invalid f-string conversion");
                return;
            }
            if conv > 0 {
                g.emit_op(OP_CONVERT_VALUE, conv, vloc);
            }
            if fv.format_spec is not None {
                visit_expr(g, fv.format_spec);
                if codegen_busy(g) {
                    return;
                }
                g.emit_op(OP_FORMAT_WITH_SPEC, 0, vloc);
            } else {
                g.emit_op(OP_FORMAT_SIMPLE, 0, vloc);
            }
        } elif isinstance(v, Constant) {
            c = v as Constant;
            idx = g.u.add_const(c.value);
            g.emit_op(
                OP_LOAD_CONST,
                idx,
                nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset)
            );
        } else {
            # Bare expression part without a FormattedValue wrapper (defensive:
            # the parser always wraps interpolation parts). Format it directly.
            visit_expr(g, v);
            if codegen_busy(g) {
                return;
            }
            g.emit_op(OP_FORMAT_SIMPLE, 0, expr_loc(v));
        }
        vi = vi + 1;
    }
    if len(vals) > 1 {
        g.emit_op(OP_BUILD_STRING, len(vals), jsloc);
    }
}

def emit_template(g: cfg_builder, template: TemplateStr) {
    strings: list[PyObj] = [];
    interpolations: list[Interpolation] = [];
    text = "";
    for part in template.values {
        if isinstance(part, Constant) and isinstance(part.value, PyStr) {
            text += part.value.val;
        } elif isinstance(part, Interpolation) {
            strings.append(PyStr(t="str", val=text));
            text = "";
            interpolations.append(part);
        } else {
            codegen_fail(g, "TypeError", "invalid template string component");
            return;
        }
    }
    strings.append(PyStr(t="str", val=text));
    location = expr_loc(template);
    g.emit_op(
        OP_LOAD_CONST, g.u.add_const(PyTuple(t="tuple", items=strings)), location
    );
    for part in interpolations {
        visit_expr(g, part.value);
        g.emit_op(OP_LOAD_CONST, g.u.add_const(part.str), expr_loc(part));
        conversion = fstring_conversion_oparg(part.conversion);
        if conversion < 0 {
            codegen_fail(g, "SyntaxError", "invalid template string conversion");
            return;
        }
        if part.format_spec is not None {
            visit_expr(g, part.format_spec);
        }
        operand = 2 | (conversion << 2) | int(part.format_spec is not None);
        g.emit_op(OP_BUILD_INTERPOLATION, operand, expr_loc(part));
    }
    g.emit_op(OP_BUILD_TUPLE, len(interpolations), location);
    g.emit_op(OP_BUILD_TEMPLATE, 0, location);
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
    if isinstance(e, Starred) {
        codegen_fail(g, "SyntaxError", "can't use starred expression here");
        return None;
    }
    if isinstance(e, TemplateStr) {
        emit_template(g, e);
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
        if n.id == "__debug__" {
            import from jaclang.compiler.backends.py.jacpython.compiler_context {
                current_optimization_level
            }
            value = PyBool(t="bool", val=current_optimization_level() == 0);
            g.emit_op(OP_LOAD_CONST, g.u.add_const(value), expr_loc(n));
            return None;
        }
        emit_name_load(
            g, n.id, nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset)
        );
        return None;
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
        folded = try_fold_binop(b.left, b.op as PyObj, b.right);
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
        # CPython folds unary minus on int constants in its POST-visit
        # optimizer pass: the operand keeps its visit-time const slot (dead
        # small-int registration included) and the negated const is interned
        # AFTER every visit-time const (incl. the epilogue None), so -1
        # lowers to LOAD_CONST <late>, never LOAD_SMALL_INT + UNARY_NEGATIVE.
        if isinstance(un.op, USub) and isinstance(un.operand, Constant) {
            cv = (un.operand as Constant).value;
            if isinstance(cv, PyFloat) or isinstance(cv, PyComplex) {
                if isinstance(cv, PyFloat) {
                    negated: PyObj = PyFloat(t="float", val=-cv.val);
                } else {
                    negated = PyComplex(t="complex", real=-cv.real, imag=-cv.imag);
                }
                idx = g.u.add_const(negated);
                g.emit_op(OP_LOAD_CONST, idx, expr_loc(un));
                return None;
            }
            if isinstance(cv, PyInt) {
                uloc = nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
                # The operand's own const is removed by CPython's optimizer
                # unless it occupies the protected index-0 dead slot.
                if len(g.u.consts) == 0 {
                    in_class_body = g.sym_top is not None
                        and g.sym_top.block_type == "class";
                    if not in_class_body {
                        g.u.add_const(cv);
                        g.u.dead_small_int_const = True;
                    }
                }
                late_idx = g.u.stage_late_const(
                    PyInt(t="int", val=-((cv as PyInt).val))
                );
                g.emit_op(OP_LOAD_CONST, late_idx, uloc);
                return None;
            }
        }
        if isinstance(un.op, UAdd) {
            # 3.14 dropped UNARY_POSITIVE: unary + lowers to CALL_INTRINSIC_1
            # (INTRINSIC_UNARY_POSITIVE). A constant operand folds to the plain
            # const load located at the UnaryOp span, matching the host
            # optimizer's +const fold.
            uloc = nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
            if isinstance(un.operand, Constant) {
                cvu = (un.operand as Constant).value;
                if isinstance(cvu, PyInt) {
                    register_int_literal_const(g, un.operand, register_int_const);
                    emit_folded_int(g, (cvu as PyInt).val, uloc);
                    return None;
                }
                idxu = g.u.add_const(cvu);
                g.emit_op(OP_LOAD_CONST, idxu, uloc);
                return None;
            }
            visit_expr(g, un.operand);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_CALL_INTRINSIC_1, 5, uloc);
            return None;
        }
        visit_expr(g, un.operand);
        if isinstance(un.op, Not) {
            need_to_bool = True;
            if isinstance(un.operand, Compare)
                and len((un.operand as Compare).ops) == 1 {
                need_to_bool = False;
            }
            if need_to_bool {
                g.emit_op(
                    OP_TO_BOOL,
                    0,
                    nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset)
                );
            }
        }
        opc = unary_opcode(un.op as PyObj);
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
        # The test can allocate its own blocks (chained comparisons/booleans).
        # Place each arm only after that test and its preceding arm finish.
        else_blk = g.new_deferred_block();
        join_blk = g.new_deferred_block();
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
            method_form = not call_has_unpacking(ca);
            if not try_load_super_attr(g, attr.value, attr.attr, method_form, aloc) {
                visit_expr(g, attr.value);
                idx = g.u.add_name(codegen_mangle(g, attr.attr));
                g.emit_op(OP_LOAD_ATTR, (idx << 1) | int(method_form), aloc);
            }
            if not method_form {
                g.emit_op(OP_PUSH_NULL, 0, floc);
            }
        } else {
            visit_expr(g, ca.func);
            g.emit_op(OP_PUSH_NULL, 0, floc);
        }
        cmp_cleanup: basicblock | None = None;
        call_args = call_effective_args(ca);
        cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
        kws = call_effective_keywords(ca);
        if (
            len(call_args) == 1
            and len(kws) == 0
            and not call_has_unpacking(ca)
            and isinstance(call_args[0], GeneratorExp)
            and len((call_args[0] as GeneratorExp).generators) > 0
        ) {
            # Sole generator-expression argument: CPython lowers the genexp
            # (nested function + outermost GET_ITER + hidden-argument CALL 0)
            # directly against the callee setup instead of pushing generic args,
            # then performs the enclosing call over the produced generator.
            visit_expr(g, call_args[0]);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_CALL, len(call_args), cloc_call);
            return None;
        }
        if call_has_unpacking(ca) {
            # CALL_FUNCTION_EX site: build the positional slot here; the kwargs
            # mapping and the call itself go through emit_call_keyword_values /
            # emit_call_instruction below (and in the compare-cleanup paths).
            emit_call_ex_positional(g, ca, cloc_call, not g.u.nested_code_emitted);
        } else {
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
        }
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
        if try_load_super_attr(g, a.value, a.attr, False, aloc) {
            return None;
        }
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
    if isinstance(e, NamedExpr) {
        ne = e as NamedExpr;
        wloc = nloc(ne.lineno, ne.end_lineno, ne.col_offset, ne.end_col_offset);
        visit_expr(
            g,
            ne.value,
            false_shortcircuit_returns,
            compare_use_join,
            register_int_const
        );
        if codegen_busy(g) {
            return None;
        }
        # PEP 572: the value stays as the expression result while a copy is
        # bound to the target in the scope where the assignment lands.
        g.emit_op(OP_COPY, 1, wloc);
        if not isinstance(ne.target, Name) {
            codegen_fail(g, "NotImplementedError", "unsupported walrus target");
            return None;
        }
        emit_expr_name_store(g, (ne.target as Name).id, expr_loc(ne.target));
        return None;
    }
    if isinstance(e, GeneratorExp) {
        visit_genexp(g, e as GeneratorExp);
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
        g.emit_op(OP_RESUME, 1 if g.cleanup_stack else 5, yloc);
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
        await_expr = e as Await;
        aloc = nloc(
            await_expr.lineno,
            await_expr.end_lineno,
            await_expr.col_offset,
            await_expr.end_col_offset
        );
        visit_expr(g, await_expr.value);
        if codegen_busy(g) {
            return None;
        }
        emit_send_delegation_loop(g, OP_GET_AWAITABLE, 0, 3, aloc);
        return None;
    }
    if isinstance(e, Slice) {
        sloc = expr_loc(e);
        folded = fold_slice_const(e);
        if folded is not None {
            g.emit_op(OP_LOAD_CONST, g.u.add_const(folded), sloc);
        } else {
            emit_slice_bound(g, e.lower, sloc);
            emit_slice_bound(g, e.upper, sloc);
            if e.step is not None {
                visit_expr(g, e.step);
            }
            g.emit_op(OP_BUILD_SLICE, 3 if e.step is not None else 2, sloc);
        }
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
            ti2 = 0;
            while ti2 < len(telts) {
                register_int_literal_const(g, telts[ti2], True);
                ti2 = ti2 + 1;
            }
            cidx = g.u.stage_late_const(
                PyTuple(t="tuple", items=display_const_items(telts))
            );
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
        # CPython packs an all-constant list as an empty list extended by a
        # folded const tuple only from three elements up (compile.c packs when
        # the display is longer than the small-element fast path): shorter ones
        # load each element then BUILD_LIST n.
        if len(lelts) >= 3 and display_all_constant(lelts) {
            li2 = 0;
            while li2 < len(lelts) {
                register_int_literal_const(g, lelts[li2], True);
                li2 = li2 + 1;
            }
            # CPython packs an all-constant list as an empty list extended by a
            # folded const tuple: BUILD_LIST 0; LOAD_CONST (tuple); LIST_EXTEND 1.
            g.emit_op(OP_BUILD_LIST, 0, dloc);
            cidx = g.u.stage_late_const(
                PyTuple(t="tuple", items=display_const_items(lelts))
            );
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
        if len(selts) >= 3 and display_all_constant(selts) {
            si3 = 0;
            while si3 < len(selts) {
                register_int_literal_const(g, selts[si3], True);
                si3 = si3 + 1;
            }
            # CPython packs an all-constant set as an empty set extended by a
            # folded frozenset const: BUILD_SET 0; LOAD_CONST (frozenset);
            # SET_UPDATE 1. Mirrors the all-constant list path above.
            frozen = PySet(t="frozenset", items={}, frozen=True);
            ci2 = 0;
            const_items = display_const_items(selts);
            while ci2 < len(const_items) {
                added = frozen.set_add(const_items[ci2]);
                if is_error(added) {
                    break;
                }
                ci2 = ci2 + 1;
            }
            g.emit_op(OP_BUILD_SET, 0, dloc);
            cidx_set = g.u.stage_late_const(frozen);
            g.emit_op(OP_LOAD_CONST, cidx_set, dloc);
            g.emit_op(OP_SET_UPDATE, 1, dloc);
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
                visit_expr(g, dkeys[di] as expr);
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
        map_pairs = 0;
        have_dict = False;
        di = 0;
        while di < len(dkeys) {
            k = dkeys[di];
            if k is None {
                if map_pairs > 0 or (not have_dict) {
                    g.emit_op(OP_BUILD_MAP, map_pairs, dloc);
                    if have_dict {
                        g.emit_op(OP_DICT_UPDATE, 1, dloc);
                    }
                    have_dict = True;
                    map_pairs = 0;
                }
                visit_expr(g, dvals[di]);
                g.emit_op(OP_DICT_UPDATE, 1, dloc);
            } else {
                visit_expr(g, k);
                visit_expr(g, dvals[di]);
                map_pairs = map_pairs + 1;
            }
            di = di + 1;
        }
        if map_pairs > 0 or (not have_dict) {
            g.emit_op(OP_BUILD_MAP, map_pairs, dloc);
            if have_dict {
                g.emit_op(OP_DICT_UPDATE, 1, dloc);
            }
        }
        if codegen_busy(g) {
            return None;
        }
        return None;
    }
    if isinstance(e, JoinedStr) {
        emit_joinedstr(g, e as JoinedStr);
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
    if not kws {
        return;
    }
    if call_has_unpacking(ca) {
        # CALL_FUNCTION_EX kwargs side: a base BUILD_MAP over the leading run of
        # explicit keywords (possibly zero pairs) opens the mapping; every
        # subsequent element -- an explicit-keyword run or a ** mapping -- is
        # merged onto it with DICT_MERGE, all in source order.
        ki = 0;
        while ki < len(kws) and kws[ki].arg is not None {
            kwl = kws[ki];
            kw_name = kwl.arg as str;
            name_idx = g.u.add_const(PyStr(t="str", val=kw_name));
            g.emit_op(OP_LOAD_CONST, name_idx, cloc_call);
            if comp_mode {
                visit_comp_elt(g, kwl.value, [], False);
            } else {
                visit_expr(g, kwl.value, False, False, register_int_const);
            }
            if codegen_busy(g) {
                return;
            }
            ki = ki + 1;
        }
        g.emit_op(OP_BUILD_MAP, ki, cloc_call);
        while ki < len(kws) {
            kw = kws[ki];
            if kw.arg is None {
                if comp_mode {
                    visit_comp_elt(g, kw.value, [], False);
                } else {
                    visit_expr(g, kw.value, False, False, register_int_const);
                }
                if codegen_busy(g) {
                    return;
                }
                g.emit_op(OP_DICT_MERGE, 1, cloc_call);
            } else {
                run_start = ki;
                while ki < len(kws) and kws[ki].arg is not None {
                    kwr = kws[ki];
                    kw_name = kwr.arg as str;
                    name_idx = g.u.add_const(PyStr(t="str", val=kw_name));
                    g.emit_op(OP_LOAD_CONST, name_idx, cloc_call);
                    if comp_mode {
                        visit_comp_elt(g, kwr.value, [], False);
                    } else {
                        visit_expr(g, kwr.value, False, False, register_int_const);
                    }
                    if codegen_busy(g) {
                        return;
                    }
                    ki = ki + 1;
                }
                g.emit_op(OP_BUILD_MAP, ki - run_start, cloc_call);
                g.emit_op(OP_DICT_MERGE, 1, cloc_call);
                continue;
            }
            ki = ki + 1;
        }
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
        kw_name = kws[ki].arg as str;
        names.append(PyStr(t="str", val=kw_name));
        ki = ki + 1;
    }
    tup = PyTuple(t="tuple", items=names);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, cloc_call);
}

# True when any positional argument is starred or any keyword is a ** mapping;
# such call sites lower to CALL_FUNCTION_EX instead of CALL/CALL_KW.
def call_has_unpacking(ca: Call) -> bool {
    args = call_effective_args(ca);
    ai = 0;
    while ai < len(args) {
        if isinstance(args[ai], Starred) {
            return True;
        }
        ai = ai + 1;
    }
    kws = call_effective_keywords(ca);
    ki = 0;
    while ki < len(kws) {
        if kws[ki].arg is None {
            return True;
        }
        ki = ki + 1;
    }
    return False;
}

# Emit the positional slot of a CALL_FUNCTION_EX site (below it: callable,
# NULL; above it: the kwargs mapping when present). CPython shapes:
#   - single lone *x: evaluate x directly (the VM tuple-izes it),
#   - otherwise BUILD_LIST over plain elements with LIST_EXTEND per *starred,
#     closed by CALL_INTRINSIC_1(LIST_TO_TUPLE); a kwargs-only call uses an
#     empty-tuple constant instead.
def emit_call_ex_positional(
    g: cfg_builder,
    ca: Call,
    cloc_call: cloc,
    register_int_const: bool = True,
    prefix_count: int = 0
) -> None {
    args = call_effective_args(ca);
    if prefix_count == 0 and len(args) == 1 and isinstance(args[0], Starred) {
        # Single lone *x: CPython evaluates x directly; the VM tuple-izes it.
        visit_expr(g, (args[0] as Starred).value, False, False, register_int_const);
        return;
    }
    any_star = False;
    ai = 0;
    while ai < len(args) {
        if isinstance(args[ai], Starred) {
            any_star = True;
        }
        ai = ai + 1;
    }
    if not any_star and prefix_count == 0 {
        # Plain-only positional side lowers as a tuple display (folded to a
        # late const tuple when every element is constant).
        tup = Tuple(
            elts=args,
            ctx=Load(),
            lineno=ca.lineno,
            col_offset=ca.col_offset,
            end_lineno=ca.end_lineno,
            end_col_offset=ca.end_col_offset
        );
        visit_expr(g, tup as expr, False, False, register_int_const);
        return;
    }
    n_lead = 0;
    while n_lead < len(args) and not isinstance(args[n_lead], Starred) {
        ai = n_lead;
        visit_expr(g, args[ai], False, False, register_int_const);
        if codegen_busy(g) {
            return None;
        }
        n_lead = n_lead + 1;
    }
    g.emit_op(OP_BUILD_LIST, prefix_count + n_lead, cloc_call);
    ai = n_lead;
    while ai < len(args) {
        el = args[ai];
        if isinstance(el, Starred) {
            visit_expr(g, (el as Starred).value, False, False, register_int_const);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_LIST_EXTEND, 1, cloc_call);
        } else {
            visit_expr(g, el, False, False, register_int_const);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_LIST_APPEND, 1, cloc_call);
        }
        ai = ai + 1;
    }
    # INTRINSIC_LIST_TO_TUPLE == 6
    g.emit_op(OP_CALL_INTRINSIC_1, 6, cloc_call);
    return None;
}

# Positional and keyword values must already be on the stack (names tuple last for CALL_KW).
def emit_call_instruction(
    g: cfg_builder, ca: Call, cloc_call: cloc, prefix_count: int = 0
) {
    args = call_effective_args(ca);
    kws = call_effective_keywords(ca);
    if call_has_unpacking(ca) {
        # CPython 3.14's CALL_FUNCTION_EX takes no oparg: the kwargs slot above
        # the positional tuple is either a mapping built by the keyword-side
        # emission or a NULL placeholder pushed here for pure *args calls.
        if len(kws) == 0 {
            g.emit_op(OP_PUSH_NULL, 0, cloc_call);
        }
        g.emit_op(OP_CALL_FUNCTION_EX, 0, cloc_call);
        return;
    }
    if len(kws) > 0 {
        g.emit_op(OP_CALL_KW, prefix_count + len(args) + len(kws), cloc_call);
    } else {
        g.emit_op(OP_CALL, prefix_count + len(args), cloc_call);
    }
}

# CPython codegen.c can_optimize_super_call / load_args_for_super: an attribute
# access through a direct super(...) call compiles to LOAD_SUPER_ATTR over
# (global super, class-or-arg0, self-or-arg1) instead of calling super first.
# Emits the whole operand sequence plus the opcode (+ trailing NOP) and returns
# True when this shape applied; callers then skip generic emission.
def try_load_super_attr(
    g: cfg_builder, value: expr, attr_name: str, method_form: bool, aloc: cloc
) -> bool {
    if not isinstance(value, Call) {
        return False;
    }
    ca = value as Call;
    if not isinstance(ca.func, Name) {
        return False;
    }
    sf = ca.func as Name;
    if sf.id != "super" {
        return False;
    }
    if attr_name == "__class__" {
        return False;
    }
    if len(call_effective_keywords(ca)) > 0 or call_has_unpacking(ca) {
        return False;
    }
    # 'super' must resolve GLOBAL_IMPLICIT in this unit and be absent from the
    # module top (static shadowing detection); otherwise fall back to the
    # generic call path like CPython.
    if g.sym_top is None {
        return False;
    }
    flags = sym_dict_get(g.sym_top.symbols, "super", 0);
    if sym_scope_of(flags) != SCOPE_GLOBAL_IMPLICIT {
        return False;
    }
    if g.sym_top.top_has_super {
        return False;
    }
    args = call_effective_args(ca);
    two_arg = False;
    if len(args) == 2 {
        if isinstance(args[0], Starred) or isinstance(args[1], Starred) {
            return False;
        }
        two_arg = True;
    } elif len(args) != 0 {
        return False;
    } else {
        # Zero-arg form needs a first positional parameter to bind as self and
        # the symtable-provided __class__ free cell.
        if g.u.argcount == 0 and g.u.posonlyargcount == 0 {
            return False;
        }
        cls_flags = sym_dict_get(g.sym_top.symbols, "__class__", 0);
        if sym_scope_of(cls_flags) != SCOPE_FREE {
            return False;
        }
    }
    emit_name_load(g, "super", call_func_loc(ca.func), False);
    if codegen_busy(g) {
        return True;
    }
    if two_arg {
        visit_expr(g, args[0]);
        if codegen_busy(g) {
            return True;
        }
        visit_expr(g, args[1]);
        if codegen_busy(g) {
            return True;
        }
    } else {
        emit_name_load(g, "__class__", aloc);
        # Inlined comprehensions and nested functions can capture self/cls.
        # The first parameter then lives in a cell and needs the same deref
        # load as an ordinary reference to that parameter.
        emit_name_load(g, g.u.varnames[0], aloc);
    }
    idx = g.u.add_name(codegen_mangle(g, attr_name));
    oparg = (idx << 2) | (2 if two_arg else 0) | (1 if method_form else 0);
    g.emit_op(OP_LOAD_SUPER_ATTR, oparg, aloc);
    g.emit_op(OP_NOP, 0, aloc);
    return True;
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

def fast_local_index(g: cfg_builder, name: str) -> int {
    if g.sym_top is not None {
        scope = sym_scope_of(sym_dict_get(g.sym_top.symbols, name, 0));
        # A captured parameter's slot holds a cell, not its value. Callers
        # selecting fast-load shortcuts must fall back to scope-aware loads.
        if scope
            in (SCOPE_GLOBAL_EXPLICIT, SCOPE_GLOBAL_IMPLICIT, SCOPE_CELL, SCOPE_FREE) {
            return -1;
        }
        if g.sym_top.block_type in ("module", "class") and name not in g.scope_names {
            return -1;
        }
    }
    name = g.scope_names.get(name, name);
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

# True when every bound name of the comprehension target is a cell variable of
# the enclosing scope -- i.e. the loop variable is captured by an inner function
# (lambda/nested def), so CPython runs the comprehension through the slot's live
# cell (LOAD_FAST_AND_CLEAR + MAKE_CELL + STORE_DEREF) instead of plain fasts.
# Module scope is excluded to match emit_name_load's DEREF gating.
def comp_name_is_cell(g: cfg_builder, name: str) -> bool {
    if g.sym_top is None or g.sym_top.block_type == "module" {
        return False;
    }
    flags = sym_dict_get(g.sym_top.symbols, name, 0);
    return sym_scope_of(flags) == SCOPE_CELL;
}

def comp_target_is_cell(g: cfg_builder, target: expr) -> bool {
    if isinstance(target, Name) {
        return comp_name_is_cell(g, (target as Name).id);
    }
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) == 0 {
            return False;
        }
        ni = 0;
        while ni < len(elts) {
            if not isinstance(elts[ni], Name)
                or not comp_name_is_cell(g, (elts[ni] as Name).id) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    return False;
}

# Slot index for a comprehension target name: plain fasts keep their varname
# index; cell-scope names address the merged localsplus region.
def comp_target_slot_index(g: cfg_builder, name: str) -> int {
    fi = fast_local_index(g, name);
    if fi >= 0 {
        return fi;
    }
    if comp_name_is_cell(g, name) {
        return localsplus_index(g, name);
    }
    return -1;
}

def comp_slot_already_stored(stored: list[int], slot: int) -> bool {
    si = 0;
    while si < len(stored) {
        if stored[si] == slot {
            return True;
        }
        si = si + 1;
    }
    return False;
}

def comp_slot_appears_later(elem_slots: list[int], from_idx: int) -> bool {
    slot = elem_slots[from_idx];
    j = from_idx + 1;
    while j < len(elem_slots) {
        if elem_slots[j] == slot {
            return True;
        }
        j = j + 1;
    }
    return False;
}

def comp_should_sfsf_pair(remaining: int) -> bool {
    if remaining == 2 or remaining == 3 {
        return True;
    }
    if remaining >= 4 and remaining % 2 == 0 {
        return True;
    }
    return False;
}

def comp_target_element_slots(g: cfg_builder, target: expr) -> list[int] | None {
    if isinstance(target, Name) {
        fi = comp_target_slot_index(g, (target as Name).id);
        if fi < 0 {
            return None;
        }
        return [fi];
    }
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) == 0 {
            return None;
        }
        out: list[int] = [];
        ei = 0;
        while ei < len(elts) {
            if not isinstance(elts[ei], Name) {
                return None;
            }
            fi = comp_target_slot_index(g, (elts[ei] as Name).id);
            if fi < 0 {
                return None;
            }
            out.append(fi);
            ei = ei + 1;
        }
        return out;
    }
    return None;
}

def comp_target_slots(g: cfg_builder, target: expr) -> list[int] | None {
    elem_slots = comp_target_element_slots(g, target);
    if elem_slots is None {
        return None;
    }
    out: list[int] = [];
    si = 0;
    while si < len(elem_slots) {
        slot = elem_slots[si];
        if not comp_slot_already_stored(out, slot) {
            out.append(slot);
        }
        si = si + 1;
    }
    return out;
}

# A cell-targeted comprehension clears its slot(s) into a fresh cell before the
# loop: each execution mints new cells so closures captured by earlier runs are
# not clobbered (pairs with the tail STORE_FAST wholesale restore).
def comp_emit_cell_init(g: cfg_builder, target: expr, slots: list[int], loc: cloc) {
    if comp_target_is_cell(g, target) {
        si = 0;
        while si < len(slots) {
            g.emit_op(OP_MAKE_CELL, slots[si], loc);
            si = si + 1;
        }
    }
}

# Fast-local slot of the loop variable the comprehension body evaluates first,
# or -1 when the lead leaf is not a bound target name.
def comp_lead_loopvar_slot(
    g: cfg_builder, gen: comprehension, body_first: expr, bound_names: list[str]
) -> int {
    first: expr = body_first;
    if len(gen.ifs) > 0 {
        first = gen.ifs[0];
    }
    leaf = comp_leftmost_leaf(first);
    if not isinstance(leaf, Name) {
        return -1;
    }
    nid = (leaf as Name).id;
    if not comp_name_bound(nid, bound_names) {
        return -1;
    }
    return fast_local_index(g, nid);
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
            visit_comp_elt(g, c.comparators[ci], bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            if not emit_cmp_link(g, c.ops[ci] as PyObj, cloc_cmp, filter_compare) {
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
        if isinstance(ca.func, Name) {
            n = ca.func as Name;
            needs_null = emit_name_load(g, n.id, floc, True);
            if codegen_busy(g) {
                return;
            }
            if needs_null {
                g.emit_op(OP_PUSH_NULL, 0, floc);
            }
        } else {
            visit_comp_elt(g, ca.func, bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            g.emit_op(OP_PUSH_NULL, 0, floc);
        }
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
        # Same negative-int fold as visit_expr (CPython's post-visit optimizer
        # folds comprehension elements too; negated consts are interned late).
        if isinstance(un.op, USub) and isinstance(un.operand, Constant) {
            cv = (un.operand as Constant).value;
            if isinstance(cv, PyInt) {
                ul = nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
                if len(g.u.consts) == 0 {
                    in_class_body = g.sym_top is not None
                        and g.sym_top.block_type == "class";
                    if not in_class_body {
                        g.u.add_const(cv);
                        g.u.dead_small_int_const = True;
                    }
                }
                late_idx = g.u.stage_late_const(
                    PyInt(t="int", val=-((cv as PyInt).val))
                );
                g.emit_op(OP_LOAD_CONST, late_idx, ul);
                return;
            }
        }
        if isinstance(un.op, UAdd) {
            # Same CALL_INTRINSIC_1 lowering as visit_expr (3.14 dropped
            # UNARY_POSITIVE); constant operand folds to the const load at the
            # UnaryOp span.
            uloc = nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
            if isinstance(un.operand, Constant) {
                visit_comp_elt(g, un.operand, bound_names, filter_compare);
                return;
            }
            visit_comp_elt(g, un.operand, bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            g.emit_op(OP_CALL_INTRINSIC_1, 5, uloc);
            return;
        }
        ul = nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
        visit_comp_elt(g, un.operand, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        opc = unary_opcode(un.op as PyObj);
        if opc < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported unary operator");
            return;
        }
        g.emit_op(opc, 0, ul);
        return;
    }
    visit_expr(g, e);
}

# Bind the comprehension loop target. When `lead_slot` is the fast index of the
# loop variable the body evaluates first, CPython fuses the final bind with that
# load via STORE_FAST_LOAD_FAST (odd arity) or leaves a borrow for LOAD_FAST_BORROW
# (even arity after STORE_FAST_STORE_FAST pairs). emit_name_load consumes
# comp_pending_borrow for the fused case.
def comp_emit_bind_target(
    g: cfg_builder, target: expr, slots: list[int], lead_slot: int = -1
) {
    tloc = expr_loc(target);
    g.u.comp_pending_borrow = -1;
    elem_slots = comp_target_element_slots(g, target);
    if elem_slots is None {
        codegen_fail(g, "NotImplementedError", "unsupported comprehension loop target");
        return;
    }
    n = len(elem_slots);
    if comp_target_is_cell(g, target) {
        # Cell-scope target: bind through the slot's live cell. UNPACK_SEQUENCE
        # pushes elements left-to-right, so stores run last-to-first.
        if n > 1 {
            g.emit_op(OP_UNPACK_SEQUENCE, n, tloc);
        }
        si = len(slots) - 1;
        while si >= 0 {
            g.emit_op(OP_STORE_DEREF, slots[si], tloc);
            si = si - 1;
        }
        return;
    }
    if n == 1 {
        si = elem_slots[0];
        if lead_slot >= 0 and lead_slot == si {
            g.emit_op(OP_STORE_FAST_LOAD_FAST, si * 16 + lead_slot, tloc);
            g.u.comp_pending_borrow = lead_slot;
        } else {
            g.emit_op(OP_STORE_FAST, si, tloc);
        }
        return;
    }
    g.emit_op(OP_UNPACK_SEQUENCE, n, tloc);
    stored: list[int] = [];
    i = 0;
    while i < n {
        remaining = n - i;
        s0 = elem_slots[i];
        if i < n - 1 {
            s1 = elem_slots[i + 1];
            if s0 != s1 and comp_should_sfsf_pair(remaining) {
                store_loc = tloc;
                if isinstance(target, Tuple) {
                    elts = (target as Tuple).elts;
                    if i < len(elts) {
                        store_loc = expr_loc(elts[i]);
                    }
                }
                g.emit_op(OP_STORE_FAST_STORE_FAST, s0 * 16 + s1, store_loc);
                if not comp_slot_already_stored(stored, s0) {
                    stored.append(s0);
                }
                if not comp_slot_already_stored(stored, s1) {
                    stored.append(s1);
                }
                i = i + 2;
                continue;
            }
        }
        si = elem_slots[i];
        if i == n - 1 {
            if lead_slot >= 0 and n % 2 == 1 {
                g.emit_op(OP_STORE_FAST_LOAD_FAST, si * 16 + lead_slot, tloc);
                g.u.comp_pending_borrow = lead_slot;
            } elif comp_slot_already_stored(stored, si) {
                g.emit_op(OP_POP_TOP, 0, tloc);
            } else {
                g.emit_op(OP_STORE_FAST, si, tloc);
            }
            break;
        }
        if comp_slot_appears_later(elem_slots, i) {
            g.emit_op(OP_POP_TOP, 0, tloc);
        } else {
            g.emit_op(OP_STORE_FAST, si, tloc);
            if not comp_slot_already_stored(stored, si) {
                stored.append(si);
            }
        }
        i = i + 1;
    }
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
        # CPython lowers filters through codegen_jump_if: `not` folds into the
        # branch polarity, a single comparison keeps its bool-oparg COMPARE_OP
        # (no TO_BOOL -- comparisons yield exact bools), and every other
        # expression gets TO_BOOL before the branch.
        fe = ife;
        invert = False;
        while isinstance(fe, UnaryOp) and isinstance((fe as UnaryOp).op, Not) {
            invert = not invert;
            fe = (fe as UnaryOp).operand;
        }
        is_single_cmp = isinstance(fe, Compare) and len((fe as Compare).ops) == 1;
        visit_comp_elt(g, fe, bound_names, True);
        if codegen_busy(g) {
            return (element_entry, region_start);
        }
        if not is_single_cmp {
            g.emit_op(OP_TO_BOOL, 0, expr_loc(fe));
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
        jump_op = OP_POP_JUMP_IF_TRUE;
        if invert {
            jump_op = OP_POP_JUMP_IF_FALSE;
        }
        g.emit_jump(jump_op, pass_blk.id, filter_jump_loc);
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
    comp_emit_cell_init(g, gen.target, slots, cloc_comp);
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

# PEP 709 comprehensions keep the outer iterator evaluation outside the
# temporary binding scope. Every saved local is restored on success or error;
# exception depths come from the actual operand prefix at the protected entry.
def comp_target_names(target: expr) -> list[str] {
    if isinstance(target, Name) {
        return [target.id];
    }
    if isinstance(target, Starred) {
        return comp_target_names(target.value);
    }
    if isinstance(target, Tuple) or isinstance(target, List) {
        names: list[str] = [];
        for item in target.elts {
            names.extend(comp_target_names(item));
        }
        return names;
    }
    return [];
}

def comp_restore_slots(g: cfg_builder, slots: list[int], lc: cloc) {
    for slot in reversed(slots) {
        g.emit_op(OP_SWAP, 2, lc);
        g.emit_op(OP_STORE_FAST_MAYBE_NULL, slot, lc);
    }
}

def emit_comprehension_loop(
    g: cfg_builder,
    generators: list[comprehension],
    index: int,
    element: expr,
    value: expr | None,
    add_op: int
) {
    import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
        visit_store_target_tos
    }
    gen = generators[index];
    iloc = expr_loc(gen.iter);
    if index > 0 {
        visit_expr(g, gen.iter);
        g.emit_op(OP_GET_AITER if gen.is_async else OP_GET_ITER, 0, iloc);
    }
    head = g.new_block();
    after = g.new_deferred_block();
    g.use(head);
    end_send = -1;
    if gen.is_async {
        end_send = emit_send_delegation_loop(g, OP_GET_ANEXT, 0, 3, iloc);
    } else {
        g.emit_jump(OP_FOR_ITER, after.id, iloc);
    }
    body = g.new_block();
    g.use(body);
    visit_store_target_tos(g, gen.target);
    for condition in gen.ifs {
        test_loc = expr_loc(condition);
        kind = visit_test_expr(g, condition, test_loc, True);
        passed = g.new_deferred_block();
        emit_branch_if_test_true(g, kind, passed.id, test_loc);
        g.emit_jump(OP_JUMP_BACKWARD, head.id, test_loc);
        g.use(passed);
    }
    if index + 1 < len(generators) {
        emit_comprehension_loop(g, generators, index + 1, element, value, add_op);
    } else {
        visit_expr(g, element);
        if value is not None {
            visit_expr(g, value);
        }
        if add_op == OP_YIELD_VALUE {
            if g.u.flags & CO_ASYNC_GENERATOR {
                g.emit_op(OP_CALL_INTRINSIC_1, 4, expr_loc(element));
            }
            g.emit_op(OP_YIELD_VALUE, 0, expr_loc(element));
            g.emit_op(OP_RESUME, 5, expr_loc(element));
            g.emit_op(OP_POP_TOP, 0, expr_loc(element));
        } else {
            g.emit_op(add_op, len(generators) + 1, expr_loc(element));
        }
    }
    g.emit_jump(OP_JUMP_BACKWARD, head.id, iloc);
    g.use(after);
    if gen.is_async {
        g.emit_jump(OP_END_ASYNC_FOR, end_send, iloc);
        g.u.except_regions.append(
            except_region(
                start_block=head.id,
                end_block=body.id,
                handler_block=after.id,
                stack_depth=0,
                depth_from_block=head.id,
                depth_offset=1
            )
        );
    } else {
        g.emit_op(OP_END_FOR, 0, iloc);
        g.emit_op(OP_POP_ITER, 0, iloc);
    }
}

def visit_inline_comprehension(
    g: cfg_builder,
    generators: list[comprehension],
    element: expr,
    value: expr | None,
    build_op: int,
    add_op: int,
    lc: cloc
) {
    if not generators {
        codegen_fail(g, "ValueError", "comprehension with no generators");
        return;
    }
    first = generators[0];
    visit_expr(g, first.iter);
    g.emit_op(OP_GET_AITER if first.is_async else OP_GET_ITER, 0, expr_loc(first.iter));
    kind = "listcomp"
        if build_op == OP_BUILD_LIST
        else "setcomp" if build_op == OP_BUILD_SET else "dictcomp";
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "comprehension without symbol table");
        return;
    }
    scope = sym_function_child_at(g.sym_top, kind, lc.lineno, lc.col_offset);
    if scope is None {
        codegen_fail(g, "SystemError", "missing inlined comprehension scope");
        return;
    }
    parent = g.sym_top;
    parent_names = g.scope_names;
    parent_classdict_names = g.u.classdict_names;
    g.sym_top = scope;
    g.scope_names = parent_names | scope.inline_aliases;
    g.u.classdict_names = False;
    try {
        slots: list[int] = [];
        cells: list[int] = [];
        for gen in generators {
            for name in comp_target_names(gen.target) {
                slot = comp_target_slot_index(g, codegen_mangle(g, name));
                if slot < 0 {
                    codegen_fail(
                        g, "SystemError", "missing comprehension binding: " + name
                    );
                    return;
                }
                if slot not in slots {
                    slots.append(slot);
                    g.emit_op(OP_LOAD_FAST_AND_CLEAR, slot, lc);
                    if comp_name_is_cell(g, codegen_mangle(g, name)) {
                        cells.append(slot);
                    }
                }
            }
        }
        # Move the outer iterator above all saved bindings, retaining their order.
        for depth in range(2, len(slots) + 2) {
            g.emit_op(OP_SWAP, depth, lc);
        }
        start = g.new_block();
        g.use(start);
        for slot in cells {
            g.emit_op(OP_MAKE_CELL, slot, lc);
        }
        g.emit_op(build_op, 0, lc);
        g.emit_op(OP_SWAP, 2, lc);
        emit_comprehension_loop(g, generators, 0, element, value, add_op);
        end = g.new_block();
        g.use(end);
        comp_restore_slots(g, slots, lc);
        join = g.new_deferred_block();
        g.emit_jump(OP_JUMP_FORWARD, join.id, lc);
        handler = g.new_block();
        g.use(handler);
        comp_restore_slots(g, slots, lc);
        g.emit_op(OP_RERAISE, 0, lc);
        g.use(join);
        g.u.except_regions.append(
            except_region(
                start_block=start.id,
                end_block=end.id,
                handler_block=handler.id,
                stack_depth=0,
                depth_from_block=start.id
            )
        );
    } finally {
        g.sym_top = parent;
        g.scope_names = parent_names;
        g.u.classdict_names = parent_classdict_names;
    }
}


def visit_list_comp(g: cfg_builder, lc: ListComp) {
    visit_inline_comprehension(
        g, lc.generators, lc.elt, None, OP_BUILD_LIST, OP_LIST_APPEND, expr_loc(lc)
    );
}

def visit_set_comp(g: cfg_builder, sc: SetComp) {
    visit_inline_comprehension(
        g, sc.generators, sc.elt, None, OP_BUILD_SET, OP_SET_ADD, expr_loc(sc)
    );
}

def visit_dict_comp(g: cfg_builder, dc: DictComp) {
    visit_inline_comprehension(
        g, dc.generators, dc.key, dc.value, OP_BUILD_MAP, OP_MAP_ADD, expr_loc(dc)
    );
}

# visit_test_expr return kinds. NORMAL leaves a bool on the stack, consumed by a
# POP_JUMP_IF_FALSE. IS_NONE / IS_NOT_NONE leave the bare operand on the stack;
# the caller must consume it with POP_JUMP_IF_NOT_NONE / POP_JUMP_IF_NONE (the
# CPython `x is None` jump peephole), via emit_branch_if_test_false.
# The *_INV variants mean the test was compiled under a folded `not` (CPython's
# compiler_jump_if_not): same stack shape, branch polarity flipped.
glob TEST_NORMAL: int = 0,
     TEST_IS_NONE: int = 1,
     TEST_IS_NOT_NONE: int = 2,
     TEST_NORMAL_INV: int = 3,
     TEST_IS_NONE_INV: int = 4,
     TEST_IS_NOT_NONE_INV: int = 5;

def visit_test_expr(
    g: cfg_builder,
    e: expr,
    test_loc: cloc,
    allow_none_peephole: bool = False,
    invert: bool = False
) -> int {
    # Fold `not <test>` into an inverted branch instead of emitting UNARY_NOT
    # (CPython never materializes `not` in jump context). Double negation
    # recurses naturally; value-context `not` still goes through visit_expr.
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        if isinstance(un.op, Not) {
            return visit_test_expr(
                g, un.operand, test_loc, allow_none_peephole, not invert
            );
        }
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        if len(c.ops) == 1 {
            cloc_cmp = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
            if is_none_identity_test(c.ops[0] as PyObj, c.comparators[0]) {
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
                        return TEST_IS_NONE + (3 if invert else 0);
                    }
                    return TEST_IS_NOT_NONE + (3 if invert else 0);
                }
            }
            visit_expr(g, c.left);
            visit_expr(g, c.comparators[0]);
            if not emit_cmp_link(g, c.ops[0] as PyObj, cloc_cmp, True) {
                codegen_fail(
                    g, "NotImplementedError", "unsupported comparison operator"
                );
                return TEST_NORMAL + (3 if invert else 0);
            }
            return TEST_NORMAL + (3 if invert else 0);
        }
    }
    visit_expr(g, e);
    g.emit_op(OP_TO_BOOL, 0, test_loc);
    return TEST_NORMAL + (3 if invert else 0);
}

# Emit the conditional branch taken when a visit_test_expr result is FALSE. For
# the None-identity kinds this is the CPython jump peephole:
#   `x is None`     -> POP_JUMP_IF_NOT_NONE  (branch away when x is NOT None)
#   `x is not None` -> POP_JUMP_IF_NONE      (branch away when x IS None)
# Inverted kinds flip the opcode polarity for a folded `not`:
#   `not (x is None)` -> POP_JUMP_IF_NONE, etc.
def emit_branch_if_test_false(g: cfg_builder, kind: int, target_id: int, loc: cloc) {
    if kind == TEST_IS_NONE or kind == TEST_IS_NOT_NONE_INV {
        g.emit_jump(OP_POP_JUMP_IF_NOT_NONE, target_id, loc);
        return;
    }
    if kind == TEST_IS_NOT_NONE or kind == TEST_IS_NONE_INV {
        g.emit_jump(OP_POP_JUMP_IF_NONE, target_id, loc);
        return;
    }
    if kind == TEST_NORMAL_INV {
        g.emit_jump(OP_POP_JUMP_IF_TRUE, target_id, loc);
        return;
    }
    g.emit_jump(OP_POP_JUMP_IF_FALSE, target_id, loc);
}

# Mirror of emit_branch_if_test_false branching on TRUE (e.g. assert jumps to
# the raise path when the test is false, so its skip-jump branches on true).
# CPython folds `assert not t` by double negation: the skip-jump keeps the
# plain-false polarity of the operand.
def emit_branch_if_test_true(g: cfg_builder, kind: int, target_id: int, loc: cloc) {
    inv_kind = kind - 3 if kind >= 3 else kind + 3;
    emit_branch_if_test_false(g, inv_kind, target_id, loc);
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
    u_fn = compile_lambda_cfg(
        lam,
        g.u.filename,
        sym_fn,
        g.private,
        g.sym_top.block_type == "class",
        nested_code_qualname(g.sym_top.block_type, g.u.qualname, "<lambda>")
    );
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
    lam: Lambda,
    filename: str,
    sym_fn: sym_block,
    private: str | None = None,
    in_class: bool = False,
    qualname: str | None = None
) -> unverified_cfg {
    (argcount, posonly, kwonly) = function_argcounts(lam.args);
    u = unverified_cfg(
        filename=filename,
        name="<lambda>",
        qualname=qualname if qualname is not None else "<lambda>",
        firstlineno=lam.lineno
    );
    u.argcount = argcount;
    u.posonlyargcount = posonly;
    u.kwonlyargcount = kwonly;
    u.param_count = len(sym_fn.varnames);
    u.flags = function_code_flags(lam.args, in_class);
    u.varnames = fast_varnames_from_sym(sym_fn);
    if sym_fn.nested {
        u.flags = u.flags | CO_NESTED;
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_fn, private);
    if sym_fn.generator {
        u.flags |= CO_GENERATOR;
    }
    protect_start = emit_function_prologue(g, sym_fn, lam.lineno, sym_fn.generator);
    bloc = expr_loc(lam.body);
    visit_expr(g, lam.body);
    if codegen_busy(g) {
        return u;
    }
    g.emit_op(OP_RETURN_VALUE, 0, bloc);
    # CPython appends a dead implicit-return None epilogue to every function
    # unit, interning the const after all body consts (kept at index 0 by
    # remove_unused_consts, dropped otherwise).
    u.add_const(py_none());
    stmt_handlers["deferred_comp_handlers"](g);
    if sym_fn.generator {
        emit_generator_except_handler(g, protect_start);
    }
    return u;
}

# Scope-aware store of TOS into a plain name, for expression-side lowering
# (walrus). Mirrors the statement-side name store; kept here because the
# statement-level helpers live above this layer (codegen imports emit).
def emit_expr_name_store(g: cfg_builder, name: str, tloc: cloc) -> None {
    name = codegen_mangle(g, name);
    if emit_local_or_cell_store(g, name, tloc) {
        return;
    }
    opcode = OP_STORE_NAME;
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        scope = sym_scope_of(sym_dict_get(g.sym_top.symbols, name, 0));
        if scope in (SCOPE_GLOBAL_EXPLICIT, SCOPE_GLOBAL_IMPLICIT) {
            opcode = OP_STORE_GLOBAL;
        }
    }
    g.emit_op(opcode, g.u.add_name(name), tloc);
}

# Lower a generator expression: nested <genexpr> PyCode + MAKE_FUNCTION, then
# evaluate the outermost iterable in the ENCLOSING frame and call the function
# via CALL 0 -- CPython binds the function's `.0` parameter from CALL's hidden
# self_or_null slot (GET_ITER result lands directly under the callable).
def visit_genexp(g: cfg_builder, ge: GeneratorExp) -> None {
    gloc = nloc(ge.lineno, ge.end_lineno, ge.col_offset, ge.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "generator expression without symtable");
        return;
    }
    sym_fn = sym_function_child_at(g.sym_top, "genexpr", ge.lineno, ge.col_offset);
    if sym_fn is None {
        codegen_fail(g, "SystemError", "missing symtable for generator expression");
        return;
    }
    u_fn = compile_genexp_cfg(ge, g.u.filename, sym_fn, g.private);
    u_fn.qualname = nested_code_qualname(
        g.sym_top.block_type, g.u.qualname, "<genexpr>"
    );
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
    emit_make_function_with_closure(g, sym_fn, co, gloc, None);
    gen0 = ge.generators[0];
    iloc = expr_loc(gen0.iter);
    visit_expr(g, gen0.iter);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_GET_AITER if gen0.is_async else OP_GET_ITER, 0, iloc);
    g.emit_op(OP_CALL, 0, gloc);
}

# Build unverified_cfg for a generator expression body. The `.0` parameter
# carries the outermost iterator; each further `for` clause evaluates its
# iterable inside the loop it nests in. The body yields elt once per innermost
# iteration; filters branch back to their loop header.
def compile_genexp_cfg(
    ge: GeneratorExp, filename: str, sym_fn: sym_block, private: str | None = None
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name="<genexpr>", qualname="<genexpr>", firstlineno=ge.lineno
    );
    u.argcount = 1;
    u.param_count = 1;
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    u.flags |= CO_ASYNC_GENERATOR if sym_fn.coroutine else CO_GENERATOR;
    if sym_fn.nested {
        u.flags = u.flags | CO_NESTED;
    }
    u.varnames = fast_varnames_from_sym(sym_fn);
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_fn, private);
    protect_start = emit_function_prologue(g, sym_fn, ge.lineno, True);
    g.emit_op(OP_LOAD_FAST, 0, expr_loc(ge.generators[0].target));
    emit_comprehension_loop(g, ge.generators, 0, ge.elt, None, OP_YIELD_VALUE);
    elt_loc = expr_loc(ge.elt);
    g.emit_op(OP_LOAD_CONST, u.add_const(py_none()), elt_loc);
    g.emit_op(OP_RETURN_VALUE, 0, elt_loc);
    stmt_handlers["deferred_comp_handlers"](g);
    emit_generator_except_handler(g, protect_start);
    u.flush_late_consts();
    return u;
}
