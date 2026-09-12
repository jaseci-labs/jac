# Exception-handling codegen (try/except/finally, with, raise) extracted
# from compiler_codegen.jac. Pure mechanical move; see compiler_codegen.jac for
# the module-initialization ordering contract.

import from jaclang.runtime.python.objects { py_none }
import from jaclang.runtime.python.opcode_meta {
    OP_BUILD_LIST,
    OP_CALL,
    OP_CALL_INTRINSIC_1,
    OP_CALL_INTRINSIC_2,
    OP_CHECK_EG_MATCH,
    OP_CHECK_EXC_MATCH,
    OP_CLEANUP_THROW,
    OP_COPY,
    OP_END_FOR,
    OP_END_SEND,
    OP_GET_AWAITABLE,
    OP_JUMP_BACKWARD,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_JUMP_FORWARD,
    OP_LIST_APPEND,
    OP_LOAD_CONST,
    OP_LOAD_SPECIAL,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_POP_EXCEPT,
    OP_POP_ITER,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_TOP,
    OP_PUSH_EXC_INFO,
    OP_RAISE_VARARGS,
    OP_RERAISE,
    OP_RESUME,
    OP_RETURN_VALUE,
    OP_SEND,
    OP_STORE_FAST,
    OP_SWAP,
    OP_TO_BOOL,
    OP_WITH_EXCEPT_START,
    OP_YIELD_VALUE,
}
import from jaclang.compiler.frontend.python.ast_nodes {
    AsyncWith,
    ExceptHandler,
    Pass,
    Raise,
    Return,
    Try,
    TryStar,
    With,
    expr,
    stmt,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    basicblock,
    cfg_builder,
    cloc,
    except_region,
    loc,
    no_loc,
    stmt_cont,
    cleanup_frame,
    with_unwind_rec,
    await_footer_job,
    try_await_frame,
}
import from jaclang.compiler.backends.py.jacpython.flowgraph {
    build_layout_pos,
    layout_pos
}
import from jaclang.compiler.backends.py.jacpython.compiler_emit {
    anext_send_loop,
    await_send_loop,
    codegen_busy,
    codegen_fail,
    emit_await_send_except_regions,
    emit_await_send_loop_footer,
    emit_await_send_loop_header,
    emit_return_unwind,
    emit_send_delegation_loop,
    visit_expr,
}
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    body_is_try_except_only,
    body_is_try_finally_only,
    exec_tail_emits_code,
    expr_loc,
    nloc,
    stmt_loc,
    try_handler_span,
}
import from jaclang.compiler.backends.py.jacpython.compiler_annotations {
    ann_scope_plan
}
import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
    emit_module_return,
    emit_name_delete,
    emit_name_store,
    emit_unit_loop_exit_epilogue,
    visit_return_stmt,
    visit_stmt_tail,
    visit_stmts,
    visit_store_target_tos
}
import from jaclang.compiler.backends.py.jacpython.compiler_dispatch { stmt_handlers }

def visit_cleanup_stmts(
    g: cfg_builder, body: list[stmt], ann_ctx: ann_scope_plan | None
) -> stmt_cont {
    join = g.new_deferred_block();
    previous = g.fallthrough_target;
    g.fallthrough_target = join;
    try {
        result = visit_stmts(g, body, 0, False, None, 0, None, ann_ctx);
    } finally {
        g.fallthrough_target = previous;
    }
    if not result.terminated or join.fallthrough_used {
        if not result.terminated and g.u.blocks[-1] is not g.cur {
            g.emit_jump(OP_JUMP_FORWARD, join.id, result.loc);
        }
        g.use(join);
        return stmt_cont(loc=result.loc);
    }
    return result;
}

def clear_exception_name(g: cfg_builder, name: str, lc: cloc) {
    idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, idx, lc);
    emit_name_store(g, name, lc);
    emit_name_delete(g, name, lc);
}

def loop_protect_except_bump(g: cfg_builder) -> int {
    return sum(
        1
        for frame in g.loop_stack
        if frame.pops_iter
    );
}

def try_protect_stack_depth(g: cfg_builder) -> int {
    return 1 + g.handler_nest_depth + loop_protect_except_bump(g);
}

def try_unwind_stack_depth(g: cfg_builder) -> int {
    return 3 + g.handler_nest_depth + loop_protect_except_bump(g);
}

# The try body's exception-table span, split around each await/yield-from
# carve recorded while the body was visited. CPython's table has one row per
# warm stretch between the CLEANUP_THROW windows; our find_handler takes the
# first matching row, so the unsplit span would swallow the yield windows.
def try_body_span_rows(
    g: cfg_builder,
    fr: try_await_frame | None,
    start_blk: int,
    end_blk: int,
    handler_blk: int,
    depth: int
) -> list[except_region] {
    rows: list[except_region] = [];
    if fr is None or len((fr as try_await_frame).carves) == 0 {
        rows.append(
            except_region(
                start_block=start_blk,
                end_block=end_blk,
                handler_block=handler_blk,
                stack_depth=depth
            )
        );
        return rows;
    }
    cur = start_blk;
    ci = 0;
    while ci < len((fr as try_await_frame).carves) {
        (y_blk, r_blk) = (fr as try_await_frame).carves[ci];
        if y_blk > cur {
            rows.append(
                except_region(
                    start_block=cur,
                    end_block=y_blk,
                    handler_block=handler_blk,
                    stack_depth=depth
                )
            );
        }
        cur = r_blk;
        ci = ci + 1;
    }
    if end_blk > cur {
        rows.append(
            except_region(
                start_block=cur,
                end_block=end_blk,
                handler_block=handler_blk,
                stack_depth=depth
            )
        );
    }
    return rows;
}

# Flush the CLEANUP_THROW footers queued by awaits inside this try body.
# Each cold pair is placed after all warm body code (before the handler
# blocks; CPython push_cold_blocks_to_end), every pair gets its own
# [ct..cj) -> handler row, and the generator region resumes after the try
# span ([protect_end .. first CT), split around later await windows via the
# open-tail list). With the async-with defer flag set the pairs were already
# placed by the visit_async_with seam; region rows are pure data and are
# still recorded here.
def flush_try_await_footers(
    g: cfg_builder,
    fr: try_await_frame,
    protect_end: int,
    handler_blk: int,
    span_depth: int,
    place_now: bool
) {
    fq = fr.footer_base;
    n = len(g.pending_await_footers);
    first_ct = -1;
    if n > fq {
        first_ct = (g.pending_await_footers[fq] as await_footer_job).ct.id;
    }
    # Region rows first (pure data), then placement, then queue truncation.
    # All window comparisons use LAYOUT positions: ct/cj are deferred blocks
    # allocated at the await but placed here, so ids do not track offsets.
    fq = fr.footer_base;
    while fq < n {
        pf = g.pending_await_footers[fq] as await_footer_job;
        g.u.except_regions.append(
            except_region(
                start_block=pf.ct.id,
                end_block=pf.cj.id,
                handler_block=handler_blk,
                stack_depth=span_depth,
                preserve_lasti=False
            )
        );
        fq = fq + 1;
    }
    # Place the cold pairs only when no warm code can follow inside this
    # statement (no tail): a later-emitted delegation header on a block
    # laid out BEFORE the pair would fall through into CLEANUP_THROW at warm
    # depth. Deferred pairs are placed at unit end instead (all warm code
    # already terminated there). Layout positions are read AFTER placement:
    # ct/cj are deferred blocks whose ids do not track their offsets.
    placed = False;
    if not g.defer_await_footer_placement and place_now {
        placed = True;
        fq = fr.footer_base;
        while fq < n {
            pf = g.pending_await_footers[fq] as await_footer_job;
            pf.emit_ct_row = False;
            g.use(pf.ct);
            g.emit_op(OP_CLEANUP_THROW, 0, pf.loc);
            g.use(pf.cj);
            g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, pf.end_send.id, pf.loc);
            fq = fq + 1;
        }
        g.pending_await_footers = g.pending_await_footers[0:fr.footer_base];
    }
    # Layout positions AFTER placement: the ct/cj pairs were just laid out,
    # and deferred blocks' ids do not track their offsets.
    pos = build_layout_pos(g.u);
    pe_pos = layout_pos(pos, protect_end);
    ct_ok = False;
    if first_ct >= 0 {
        if placed {
            ct_ok = layout_pos(pos, first_ct) > pe_pos;
        } else {
            # Placement deferred: the pair lands after all warm code at unit
            # end, which is necessarily after protect_end.
            ct_ok = True;
        }
    }
    if ct_ok {
        ct_pos = layout_pos(pos, first_ct);
        end_blk = first_ct;
        end_pos = ct_pos;
        ti = 0;
        while ti < len(g.open_gen_tails) {
            oreg = g.u.except_regions[g.open_gen_tails[ti]];
            st_pos = layout_pos(pos, oreg.start_block);
            if st_pos > pe_pos and st_pos < end_pos {
                end_blk = oreg.start_block;
                end_pos = st_pos;
            }
            ti = ti + 1;
        }
        if end_pos > pe_pos {
            g.u.except_regions.append(
                except_region(
                    start_block=protect_end,
                    end_block=end_blk,
                    handler_block=-1,
                    stack_depth=2,
                    preserve_lasti=True
                )
            );
            g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
            g.open_gen_tails.append(len(g.u.except_regions) - 1);
        }
    }
    g.await_region_barrier = protect_end;
}

# Push the try-body frame awaits consult while the body is visited.
def push_try_await_frame(g: cfg_builder, nop_blk: int) -> try_await_frame {
    fr = try_await_frame(
        nop_blk=nop_blk, footer_base=len(g.pending_await_footers), carves=[]
    );
    g.open_try_frames.append(fr);
    return fr;
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


# Clear an except-as binding (STORE None + DELETE) before handler exit.
def emit_except_as_cleanup(g: cfg_builder, bind_name: str, cloc: cloc) {
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, cloc);
    emit_name_store(g, bind_name, cloc);
    emit_name_delete(g, bind_name, cloc);
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
def append_cleanup_regions(
    g: cfg_builder,
    frame: cleanup_frame,
    start: basicblock,
    end: basicblock,
    handler: basicblock,
    depth: int,
    lasti: bool
) {
    pos = build_layout_pos(g.u);
    spans = sorted(
        frame.unwind_spans,
        key=lambda (span: tuple[int, int]) { layout_pos(pos, span[0]); }
    );
    current = start.id;
    for (left, right) in spans {
        if layout_pos(pos, left) >= layout_pos(pos, end.id) {
            break;
        }
        if layout_pos(pos, current) < layout_pos(pos, left) {
            g.u.except_regions.append(
                except_region(
                    start_block=current,
                    end_block=left,
                    handler_block=handler.id,
                    stack_depth=depth,
                    preserve_lasti=lasti
                )
            );
        }
        if layout_pos(pos, right) > layout_pos(pos, current) {
            current = right;
        }
    }
    if layout_pos(pos, current) < layout_pos(pos, end.id) {
        g.u.except_regions.append(
            except_region(
                start_block=current,
                end_block=end.id,
                handler_block=handler.id,
                stack_depth=depth,
                preserve_lasti=lasti
            )
        );
    }
}

def visit_try_finally(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    depth = g.handler_nest_depth
        + sum(
            1
            for fr in g.loop_stack
            if fr.pops_iter
        );
    body = t.body;
    if t.handlers {
        body = [
            Try(
                body=t.body,
                handlers=t.handlers,
                orelse=t.orelse,
                finalbody=[],
                lineno=t.lineno,
                col_offset=t.col_offset,
                end_lineno=t.end_lineno,
                end_col_offset=t.end_col_offset
            )
        ];
    }
    g.emit_op(OP_NOP, 0, tloc);
    start = g.new_block();
    g.use(start);
    end = g.new_deferred_block();
    normal_end = g.new_deferred_block();
    handler = g.new_deferred_block();
    handler_end = g.new_deferred_block();
    unwind = g.new_deferred_block();
    join = g.new_deferred_block();
    frame = cleanup_frame(
        kind="finally", body=t.finalbody, ann_ctx=ann_ctx, loop_depth=len(g.loop_stack)
    );
    enclosing = g.cleanup_stack[:];
    g.cleanup_stack.append(frame);
    try_frame = push_try_await_frame(g, start.id);
    try {
        body_cont = visit_cleanup_stmts(g, body, ann_ctx);
    } finally {
        g.cleanup_stack = enclosing[:];
        g.open_try_frames.pop();
    }
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.use(end);
    if not body_cont.terminated {
        final_cont = visit_cleanup_stmts(g, t.finalbody, ann_ctx);
        if not final_cont.terminated {
            g.emit_jump(OP_JUMP_FORWARD, join.id, final_cont.loc);
        }
    }
    g.use(normal_end);
    flush_try_await_footers(g, try_frame, end.id, handler.id, depth + 1, False);
    g.use(handler);
    g.emit_op(OP_PUSH_EXC_INFO, 0, no_loc());
    exceptional = cleanup_frame(
        kind="exception", pop_count=1, loop_depth=len(g.loop_stack)
    );
    saved_depth = g.handler_nest_depth;
    g.handler_nest_depth += 2;
    g.cleanup_stack.append(exceptional);
    try {
        handler_cont = visit_cleanup_stmts(g, t.finalbody, ann_ctx);
    } finally {
        g.cleanup_stack = enclosing[:];
        g.handler_nest_depth = saved_depth;
    }
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    if not handler_cont.terminated {
        g.emit_op(OP_RERAISE, 0, no_loc());
    }
    g.use(handler_end);
    g.use(unwind);
    g.emit_op(OP_COPY, 3, no_loc());
    g.emit_op(OP_POP_EXCEPT, 0, no_loc());
    g.emit_op(OP_RERAISE, 1, no_loc());
    g.use(join);
    frame.unwind_spans.extend(try_frame.carves);
    append_cleanup_regions(g, frame, start, end, handler, depth + 1, False);
    append_cleanup_regions(
        g, exceptional, handler, handler_end, unwind, depth + 3, True
    );
    g.u.nested_try_finally_success_start = end.id;
    g.u.nested_try_finally_success_end = normal_end.id;
    g.u.nested_try_finally_unwind_start = unwind.id;
    return stmt_cont(loc=tloc);
}


def emit_finally_inline_block(
    g: cfg_builder,
    finalbody: list[stmt],
    blk: basicblock,
    with_nop: bool,
    more_code_follows: bool,
    tail: list[stmt] | None,
    tail_idx: int,
    tloc: cloc,
    ann_ctx: ann_scope_plan | None = None
) {
    g.use(blk);
    if with_nop {
        g.emit_op(OP_NOP, 0, tloc);
    }
    fc = visit_cleanup_stmts(g, finalbody, ann_ctx);
    if codegen_busy(g) {
        return;
    }
    fin_follows = more_code_follows;
    if not fin_follows and tail is not None and tail_idx < len(tail) {
        fin_follows = True;
    }
    if fin_follows and tail is not None {
        tail_more = False;
        if tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tc = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
        if codegen_busy(g) {
            return;
        }
        if not tc.terminated {
            emit_module_return(g, tc.loc);
        }
    } else {
        if not fc.terminated {
            emit_module_return(g, fc.loc);
        }
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
def merge_except_spans(
    g: cfg_builder, spans: list[except_region]
) -> list[except_region] {
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


def visit_try(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    if t.finalbody {
        return visit_try_finally(
            g, t, more_code_follows, tail, tail_idx, tail_join, ann_ctx
        );
    }
    tloc = stmt_loc(t);
    if not t.handlers {
        codegen_fail(g, "SyntaxError", "try without except or finally");
        return stmt_cont(loc=tloc);
    }
    depth = g.handler_nest_depth
        + sum(
            1
            for fr in g.loop_stack
            if fr.pops_iter
        );
    saved_depth = g.handler_nest_depth;
    enclosing = g.cleanup_stack[:];
    g.emit_op(OP_NOP, 0, tloc);
    start = g.new_block();
    g.use(start);
    end = g.new_deferred_block();
    handler = g.new_deferred_block();
    unwind = g.new_deferred_block();
    join = g.new_deferred_block();
    protection = cleanup_frame(kind="protect", loop_depth=len(g.loop_stack));
    g.cleanup_stack.append(protection);
    try_frame = push_try_await_frame(g, start.id);
    try {
        body_cont = visit_cleanup_stmts(g, t.body, ann_ctx);
    } finally {
        g.cleanup_stack = enclosing[:];
        g.open_try_frames.pop();
    }
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.use(end);
    if not body_cont.terminated {
        else_cont = visit_cleanup_stmts(g, t.orelse, ann_ctx);
        if not else_cont.terminated {
            g.emit_jump(OP_JUMP_FORWARD, join.id, else_cont.loc);
        }
    }
    flush_try_await_footers(g, try_frame, end.id, handler.id, depth + 1, False);
    g.use(handler);
    g.emit_op(OP_PUSH_EXC_INFO, 0, no_loc());
    dispatch_start = handler;
    for (index, raw_handler) in enumerate(t.handlers) {
        h = raw_handler as ExceptHandler;
        hloc = nloc(h.lineno, h.end_lineno, h.col_offset, h.end_col_offset);
        next_handler = g.new_deferred_block();
        g.handler_nest_depth = saved_depth + 2;
        if h.type is not None {
            visit_expr(g, h.type);
            g.emit_op(OP_CHECK_EXC_MATCH, 0, hloc);
            g.emit_jump(OP_POP_JUMP_IF_FALSE, next_handler.id, hloc);
        } elif index + 1 < len(t.handlers) {
            codegen_fail(g, "SyntaxError", "default 'except:' must be last");
            g.handler_nest_depth = saved_depth;
            return stmt_cont(loc=tloc);
        }
        if h.name is not None {
            emit_name_store(g, h.name, hloc);
        } else {
            g.emit_op(OP_POP_TOP, 0, hloc);
        }
        body_start = g.new_block();
        g.use(body_start);
        body_end = g.new_deferred_block();
        error_cleanup = g.new_deferred_block() if h.name is not None else unwind;
        frame = cleanup_frame(
            kind="exception", exception_name=h.name, loop_depth=len(g.loop_stack)
        );
        g.cleanup_stack.append(frame);
        g.handler_nest_depth = saved_depth + 1;
        try {
            handler_cont = visit_cleanup_stmts(g, h.body, ann_ctx);
        } finally {
            g.cleanup_stack = enclosing[:];
            g.handler_nest_depth = saved_depth;
        }
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        g.use(body_end);
        if not handler_cont.terminated {
            g.emit_op(OP_POP_EXCEPT, 0, hloc);
            if h.name is not None {
                clear_exception_name(g, h.name, hloc);
            }
            g.emit_jump(OP_JUMP_FORWARD, join.id, hloc);
        }
        if h.name is not None {
            g.use(error_cleanup);
            clear_exception_name(g, h.name, no_loc());
            name_cleared = g.new_block();
            g.use(name_cleared);
            g.emit_op(OP_COPY, 3, no_loc());
            g.emit_op(OP_POP_EXCEPT, 0, no_loc());
            g.emit_op(OP_RERAISE, 1, no_loc());
            g.u.except_regions.append(
                except_region(
                    start_block=error_cleanup.id,
                    end_block=name_cleared.id,
                    handler_block=unwind.id,
                    stack_depth=depth + 3,
                    preserve_lasti=True
                )
            );
        }
        g.use(next_handler);
        g.u.except_regions.append(
            except_region(
                start_block=dispatch_start.id,
                end_block=body_start.id,
                handler_block=unwind.id,
                stack_depth=depth + 3,
                preserve_lasti=True
            )
        );
        append_cleanup_regions(
            g, frame, body_start, body_end, error_cleanup, depth + 3, True
        );
        dispatch_start = next_handler;
        if h.type is None {
            break;
        }
    }
    g.emit_op(OP_RERAISE, 0, no_loc());
    g.use(unwind);
    g.emit_op(OP_COPY, 3, no_loc());
    g.emit_op(OP_POP_EXCEPT, 0, no_loc());
    g.emit_op(OP_RERAISE, 1, no_loc());
    g.use(join);
    g.u.except_regions.append(
        except_region(
            start_block=dispatch_start.id,
            end_block=unwind.id,
            handler_block=unwind.id,
            stack_depth=depth + 3,
            preserve_lasti=True
        )
    );
    protection.unwind_spans.extend(try_frame.carves);
    append_cleanup_regions(g, protection, start, end, handler, depth + 1, False);
    g.u.nested_try_except_start = start.id;
    g.u.nested_try_except_end = unwind.id;
    return stmt_cont(loc=tloc);
}

def trystar_best_end(base: cloc, ln: int | None, col: int | None) -> cloc {
    if ln is None {
        return base;
    }
    take = False;
    if base.end_lineno is None or ln > base.end_lineno {
        take = True;
    } elif ln == base.end_lineno {
        if col is not None
            and (base.end_col_offset is None or col > base.end_col_offset) {
            take = True;
        }
    }
    if take {
        return nloc(base.lineno, ln, base.col_offset, col);
    }
    return base;
}

def trystar_last_body_loc(body: list[stmt]) -> cloc | None {
    if body is None or len(body) == 0 {
        return None;
    }
    s = body[len(body) - 1];
    return nloc(s.lineno, s.end_lineno, s.col_offset, s.end_col_offset);
}

def trystar_handler_loc(h: ExceptHandler) -> cloc {
    end = trystar_last_body_loc(h.body);
    el = h.lineno;
    ec = h.col_offset;
    if end is not None {
        if end.end_lineno is not None {
            el = end.end_lineno;
        }
        if end.end_col_offset is not None {
            ec = end.end_col_offset;
        }
    }
    return nloc(h.lineno, el, h.col_offset, ec);
}

def trystar_stmt_loc(t: TryStar) -> cloc {
    best = nloc(t.lineno, t.lineno, t.col_offset, t.col_offset);
    cand = trystar_last_body_loc(t.body);
    if cand is not None {
        best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
    }
    if t.orelse is not None {
        cand = trystar_last_body_loc(t.orelse);
        if cand is not None {
            best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
        }
    }
    if t.finalbody is not None {
        cand = trystar_last_body_loc(t.finalbody);
        if cand is not None {
            best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
        }
    }
    hi = 0;
    while hi < len(t.handlers) {
        cand = trystar_handler_loc(t.handlers[hi] as ExceptHandler);
        best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
        hi = hi + 1;
    }
    return best;
}


# Lower try/except* (ExceptionGroup handlers). Dispatch + guards; the byte
# layout lives in visit_try_star_except. CPython: codegen_try_star.
def visit_try_star(
    g: cfg_builder,
    t: TryStar,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    if t.finalbody {
        inner = TryStar(
            body=t.body,
            handlers=t.handlers,
            orelse=t.orelse,
            finalbody=[],
            lineno=t.lineno,
            col_offset=t.col_offset,
            end_lineno=t.end_lineno,
            end_col_offset=t.end_col_offset
        );
        outer = Try(
            body=[inner],
            handlers=[],
            orelse=[],
            finalbody=t.finalbody,
            lineno=t.lineno,
            col_offset=t.col_offset,
            end_lineno=t.end_lineno,
            end_col_offset=t.end_col_offset
        );
        return visit_try_finally(
            g, outer, more_code_follows, tail, tail_idx, tail_join, ann_ctx
        );
    }
    tloc = stmt_loc(t);
    if not t.handlers {
        codegen_fail(g, "SyntaxError", "try* without except*");
        return stmt_cont(loc=tloc);
    }
    saved_depth = g.handler_nest_depth;
    depth = saved_depth
        + sum(
            1
            for fr in g.loop_stack
            if fr.pops_iter
        );
    enclosing = g.cleanup_stack[:];
    g.emit_op(OP_NOP, 0, tloc);
    start = g.new_block();
    g.use(start);
    end = g.new_deferred_block();
    handler = g.new_deferred_block();
    unwind = g.new_deferred_block();
    join = g.new_deferred_block();
    protection = cleanup_frame(kind="protect", loop_depth=len(g.loop_stack));
    g.cleanup_stack.append(protection);
    try_frame = push_try_await_frame(g, start.id);
    try {
        body_cont = visit_cleanup_stmts(g, t.body, ann_ctx);
    } finally {
        g.cleanup_stack = enclosing[:];
        g.open_try_frames.pop();
    }
    g.use(end);
    if not body_cont.terminated {
        else_cont = visit_cleanup_stmts(g, t.orelse, ann_ctx);
        if not else_cont.terminated {
            g.emit_jump(OP_JUMP_FORWARD, join.id, else_cont.loc);
        }
    }
    flush_try_await_footers(g, try_frame, end.id, handler.id, depth + 1, False);
    g.use(handler);
    g.emit_op(OP_PUSH_EXC_INFO, 0, no_loc());
    g.emit_op(OP_BUILD_LIST, 0, tloc);
    g.emit_op(OP_COPY, 2, tloc);
    # The split walk keeps [previous exception, original, raised list, rest].
    # A handler failure appends to raised, then the next clause still sees rest.
    for raw_handler in t.handlers {
        h = raw_handler as ExceptHandler;
        hloc = nloc(h.lineno, h.end_lineno, h.col_offset, h.end_col_offset);
        if h.type is None {
            codegen_fail(g, "SyntaxError", "except* requires an exception type");
            return stmt_cont(loc=tloc);
        }
        dispatch = g.cur;
        no_match = g.new_deferred_block();
        next_handler = g.new_deferred_block();
        body_end = g.new_deferred_block();
        error_cleanup = g.new_deferred_block();
        cleanup_end = g.new_deferred_block();
        g.handler_nest_depth = saved_depth + 4;
        visit_expr(g, h.type);
        g.emit_op(OP_CHECK_EG_MATCH, 0, hloc);
        g.emit_op(OP_COPY, 1, hloc);
        g.emit_jump(OP_POP_JUMP_IF_NONE, no_match.id, hloc);
        if h.name is not None {
            emit_name_store(g, h.name, hloc);
        } else {
            g.emit_op(OP_POP_TOP, 0, hloc);
        }
        body_start = g.new_block();
        g.use(body_start);
        try {
            hbody = visit_cleanup_stmts(g, h.body, ann_ctx);
        } finally {
            g.handler_nest_depth = saved_depth;
        }
        g.use(body_end);
        if not hbody.terminated {
            if h.name is not None {
                clear_exception_name(g, h.name, hloc);
            }
            g.emit_jump(OP_JUMP_FORWARD, next_handler.id, hloc);
        }
        g.use(error_cleanup);
        if h.name is not None {
            clear_exception_name(g, h.name, no_loc());
        }
        g.emit_op(OP_LIST_APPEND, 3, no_loc());
        g.emit_op(OP_POP_TOP, 0, no_loc());
        g.emit_jump(OP_JUMP_FORWARD, next_handler.id, no_loc());
        g.use(cleanup_end);
        g.use(no_match);
        g.emit_op(OP_POP_TOP, 0, hloc);
        g.use(next_handler);
        g.u.except_regions.append(
            except_region(
                start_block=dispatch.id,
                end_block=body_start.id,
                handler_block=unwind.id,
                stack_depth=depth + 3,
                preserve_lasti=True
            )
        );
        g.u.except_regions.append(
            except_region(
                start_block=body_start.id,
                end_block=body_end.id,
                handler_block=error_cleanup.id,
                stack_depth=depth + 6,
                preserve_lasti=True
            )
        );
        g.u.except_regions.append(
            except_region(
                start_block=body_end.id,
                end_block=cleanup_end.id,
                handler_block=unwind.id,
                stack_depth=depth + 3,
                preserve_lasti=True
            )
        );
    }
    reraising = g.cur;
    g.emit_op(OP_LIST_APPEND, 1, no_loc());
    g.emit_op(OP_CALL_INTRINSIC_2, 1, no_loc());
    g.emit_op(OP_COPY, 1, no_loc());
    reraise = g.new_deferred_block();
    g.emit_jump(OP_POP_JUMP_IF_NOT_NONE, reraise.id, no_loc());
    g.emit_op(OP_POP_TOP, 0, no_loc());
    restored = g.new_block();
    g.use(restored);
    g.emit_op(OP_POP_EXCEPT, 0, no_loc());
    g.emit_jump(OP_JUMP_FORWARD, join.id, no_loc());
    g.use(reraise);
    g.emit_op(OP_SWAP, 2, no_loc());
    g.emit_op(OP_POP_EXCEPT, 0, no_loc());
    g.emit_op(OP_RERAISE, 0, no_loc());
    g.use(unwind);
    g.emit_op(OP_COPY, 3, no_loc());
    g.emit_op(OP_POP_EXCEPT, 0, no_loc());
    g.emit_op(OP_RERAISE, 1, no_loc());
    g.use(join);
    g.u.except_regions.append(
        except_region(
            start_block=reraising.id,
            end_block=restored.id,
            handler_block=unwind.id,
            stack_depth=depth + 3,
            preserve_lasti=True
        )
    );
    protection.unwind_spans.extend(try_frame.carves);
    append_cleanup_regions(g, protection, start, end, handler, depth + 1, False);
    return stmt_cont(loc=tloc);
}

def visit_with(
    g: cfg_builder,
    w: With,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    if not w.items {
        codegen_fail(g, "SyntaxError", "with requires at least one item");
        return stmt_cont(loc=stmt_loc(w));
    }
    return visit_with_item(g, w, 0, ann_ctx);
}

# Each item owns one lexical cleanup frame. Recursive item lowering makes
# nested and comma-separated context managers use the same exception paths.
def visit_with_item(
    g: cfg_builder, w: With | AsyncWith, index: int, ann_ctx: ann_scope_plan | None
) -> stmt_cont {
    is_async = isinstance(w, AsyncWith);
    it = w.items[index];
    cl = expr_loc(it.context_expr);
    wloc = cl;
    base_depth = g.handler_nest_depth
        + sum(
            1
            for fr in g.loop_stack
            if fr.pops_iter
        );
    visit_expr(g, it.context_expr);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    g.emit_op(OP_COPY, 1, cl);
    g.emit_op(OP_LOAD_SPECIAL, 3 if is_async else 1, cl);
    g.emit_op(OP_SWAP, 2, cl);
    g.emit_op(OP_SWAP, 3, cl);
    g.emit_op(OP_LOAD_SPECIAL, 2 if is_async else 0, cl);
    g.emit_op(OP_CALL, 0, cl);
    if is_async {
        emit_send_delegation_loop(g, OP_GET_AWAITABLE, 1, 3, cl);
    }
    start = g.new_block();
    g.use(start);
    handler = g.new_deferred_block();
    cleanup = g.new_deferred_block();
    unwind = g.new_deferred_block();
    join = g.new_deferred_block();
    frame = cleanup_frame(
        is_async=is_async,
        protect_region=-1,
        frame_idx=len(g.cleanup_stack),
        loop_depth=len(g.loop_stack)
    );
    enclosing = g.cleanup_stack[:];
    old_depth = g.handler_nest_depth;
    g.cleanup_stack.append(frame);
    g.handler_nest_depth += 2;
    try {
        if it.optional_vars is None {
            g.emit_op(OP_POP_TOP, 0, cl);
        } else {
            visit_store_target_tos(g, it.optional_vars);
        }
        if index + 1 < len(w.items) {
            cont = visit_with_item(g, w, index + 1, ann_ctx);
        } else {
            cont = visit_cleanup_stmts(g, w.body, ann_ctx);
        }
    } finally {
        g.cleanup_stack = enclosing[:];
        g.handler_nest_depth = old_depth;
    }
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    end = g.new_block();
    g.use(end);
    if not cont.terminated {
        none_idx = g.u.add_const(py_none());
        for unused in range(3) {
            g.emit_op(OP_LOAD_CONST, none_idx, wloc);
        }
        g.emit_op(OP_CALL, 3, wloc);
        if is_async {
            emit_send_delegation_loop(g, OP_GET_AWAITABLE, 2, 3, wloc);
        }
        g.emit_op(OP_POP_TOP, 0, wloc);
        g.emit_jump(OP_JUMP_FORWARD, join.id, wloc);
    }
    g.use(handler);
    noloc = no_loc();
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    g.emit_op(OP_WITH_EXCEPT_START, 0, wloc);
    if is_async {
        emit_send_delegation_loop(g, OP_GET_AWAITABLE, 2, 3, wloc);
    }
    g.emit_op(OP_TO_BOOL, 0, noloc);
    suppressed = g.new_deferred_block();
    g.emit_jump(OP_POP_JUMP_IF_TRUE, suppressed.id, noloc);
    g.emit_op(OP_RERAISE, 2, noloc);
    g.use(suppressed);
    g.emit_op(OP_POP_TOP, 0, noloc);
    g.use(cleanup);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    for unused in range(3) {
        g.emit_op(OP_POP_TOP, 0, noloc);
    }
    g.emit_jump(OP_JUMP_FORWARD, join.id, wloc);
    g.use(unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    g.use(join);

    # Return/break/continue invoke __exit__ outside this frame's protected
    # range. Keep the frame available for other branches while carving those
    # emitted unwind paths out of its exception table.
    pos = build_layout_pos(g.u);
    spans = sorted(
        frame.unwind_spans,
        key=lambda (span: tuple[int, int]) { layout_pos(pos, span[0]); }
    );
    current = start.id;
    for (left, right) in spans {
        if layout_pos(pos, current) < layout_pos(pos, left) {
            g.u.except_regions.append(
                except_region(
                    start_block=current,
                    end_block=left,
                    handler_block=handler.id,
                    stack_depth=base_depth + 4,
                    preserve_lasti=True
                )
            );
        }
        if layout_pos(pos, right) > layout_pos(pos, current) {
            current = right;
        }
    }
    if layout_pos(pos, current) < layout_pos(pos, end.id) {
        g.u.except_regions.append(
            except_region(
                start_block=current,
                end_block=end.id,
                handler_block=handler.id,
                stack_depth=base_depth + 4,
                preserve_lasti=True
            )
        );
    }
    g.u.except_regions.append(
        except_region(
            start_block=handler.id,
            end_block=cleanup.id,
            handler_block=unwind.id,
            stack_depth=base_depth + 6,
            preserve_lasti=True
        )
    );
    # Exception suppression can reach the join even when every normal path
    # through the body returns or raises.
    return stmt_cont(loc=wloc);
}

def visit_async_with(
    g: cfg_builder,
    w: AsyncWith,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    if not w.items {
        codegen_fail(g, "SyntaxError", "async with requires at least one item");
        return stmt_cont(loc=stmt_loc(w));
    }
    return visit_with_item(g, w, 0, ann_ctx);
}


# Wire statement-dispatch handlers into the leaf registry (see
# compiler_dispatch.jac). Runs at module load via `with entry`; entry
# drivers (product_compile, compiler_slice) import this module so the
# registration always precedes the first compile. Dict item assignment
# mutates the holder in place (scalar-glob rebinding would be local).
with entry {
    stmt_handlers["visit_cleanup_stmts"] = visit_cleanup_stmts;
    stmt_handlers["clear_exception_name"] = clear_exception_name;
    stmt_handlers["visit_raise_stmt"] = visit_raise_stmt;
    stmt_handlers["visit_try"] = visit_try;
    stmt_handlers["visit_try_star"] = visit_try_star;
    stmt_handlers["visit_with"] = visit_with;
    stmt_handlers["visit_async_with"] = visit_async_with;
    stmt_handlers["deferred_comp_handlers"] = emit_deferred_comp_handlers;
}
