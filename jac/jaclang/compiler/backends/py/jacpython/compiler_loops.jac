# Loop/if control-flow codegen (if, while, for, async for) extracted from
# compiler_codegen.jac. Pure mechanical move; see compiler_codegen.jac for the
# module-initialization ordering contract.

import from jaclang.runtime.python.opcode_meta {
    OP_END_ASYNC_FOR,
    OP_END_FOR,
    OP_FOR_ITER,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_GET_ITER,
    OP_GET_YIELD_FROM_ITER,
    OP_JUMP_BACKWARD,
    OP_JUMP_FORWARD,
    OP_LOAD_CONST,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_POP_ITER,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_TOP,
    OP_RETURN_VALUE,
    has_target,
    is_scope_exit_opcode,
    is_unconditional_jump_opcode,
}
import from jaclang.compiler.frontend.python.ast_nodes {
    AsyncFor,
    Constant,
    For,
    If,
    Name,
    While,
    stmt,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    basicblock,
    break_site,
    cfg_builder,
    cloc,
    cinstr,
    except_region,
    loc,
    loop_frame,
    mk_instr,
    mk_jump,
    no_loc,
    same_loc,
    stmt_cont,
}
import from jaclang.runtime.python.objects { py_none }
import from jaclang.compiler.backends.py.jacpython.flowgraph {
    MAX_COPY_SIZE,
    copy_cinstr
}
import from jaclang.compiler.backends.py.jacpython.compiler_emit {
    codegen_busy,
    codegen_fail,
    emit_anext_send_loop_footer,
    emit_anext_send_loop_header,
    emit_send_delegation_loop,
    emit_branch_if_test_false,
    emit_branch_if_test_true,
    visit_expr,
    visit_test_expr,
}
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    exec_tail_emits_code,
    expr_loc,
    loop_body_has_break,
    loop_body_has_try,
    nloc,
}
import from jaclang.compiler.backends.py.jacpython.compiler_annotations {
    ann_scope_plan
}
import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
    emit_module_return,
    emit_tail_and_finish,
    visit_stmt_tail,
    visit_stmts,
    visit_store_target_tos
}
import from jaclang.compiler.backends.py.jacpython.compiler_exc {
    emit_anext_send_except_regions
}

# ---------------- break-edge tail duplication (CPython parity) ----------------
#
# CPython lowers `break` as an unwind plus a jump to the loop's exit anchor,
# which sits AFTER orelse (codegen.c codegen_break / codegen_for). Its flowgraph
# optimizer then tail-duplicates that anchor into each break edge when the
# anchor ends up a small scope-exit block (flowgraph.c
# inline_small_exit_blocks, MAX_COPY_SIZE) and prunes the artificial break NOP
# per line-number rules. We emit the post-optimizer shape directly: break sites
# record themselves in the loop frame, the shared continuation block is built
# once, then finish_break_sites copies it over each break jump when CPython
# would have.

# Does control fall out of the block (CPython BB_HAS_FALLTHROUGH)?
def block_is_terminated(b: basicblock) -> bool {
    n = len(b.instrs);
    if n == 0 {
        return False;
    }
    op = b.instrs[n - 1].opcode;
    return is_unconditional_jump_opcode(op) or is_scope_exit_opcode(op);
}

# Mirror inline_small_exit_blocks' target test for the continuation block.
# The driver-appended unit epilogue (LOAD_CONST None; RETURN_VALUE) counts
# toward MAX_COPY_SIZE when the tail itself falls through.
def join_inlinable(join: basicblock, tail_terminated: bool) -> bool {
    # Yield-from lowering leaves a short prefix on the join block while the
    # SEND/END_SEND sequence lives on deferred blocks. Inlining that prefix onto
    # break edges (plus a synthetic return) is not a complete continuation.
    if len(join.instrs) > 0 and join.instrs[0].opcode == OP_GET_YIELD_FROM_ITER {
        return False;
    }
    count = len(join.instrs);
    if not tail_terminated {
        count = count + 2;
    } else {
        if count == 0 {
            return False;
        }
        if not is_scope_exit_opcode(join.instrs[count - 1].opcode) {
            return False;
        }
    }
    if count > MAX_COPY_SIZE {
        return False;
    }
    ii = 0;
    while ii < len(join.instrs) {
        if has_target(join.instrs[ii].opcode) {
            # A branch inside the continuation means CPython's block would have
            # been split before the scope exit; no duplication happened there.
            return False;
        }
        ii = ii + 1;
    }
    return True;
}

# Mirror inline_small_or_no_lineno_blocks' second target test (flowgraph.c):
# a continuation consisting solely of artificial (line-less) instructions that
# does not fall through is appended to every jumping predecessor regardless of
# size -- this is the shape nested-loop continuations take (the enclosing loop's
# back edge, END_FOR/POP_ITER cleanups). No MAX_COPY_SIZE cap applies there.
def join_artificial_tail(join: basicblock) -> bool {
    n = len(join.instrs);
    if n == 0 {
        return False;
    }
    if not block_is_terminated(join) {
        return False;
    }
    ii = 0;
    while ii < n {
        if join.instrs[ii].loc.lineno >= 0 {
            return False;
        }
        ii = ii + 1;
    }
    return True;
}

# Would CPython's remove_redundant_nops keep the artificial NOP emitted before
# a break jump that was tail-duplicated? It survives only when it differs in
# line from both its predecessor and the first copied instruction.
def break_nop_kept(site: break_site, first_copy_loc: cloc) -> bool {
    if site.loc.lineno < 0 {
        return False;
    }
    instrs = site.blk.instrs;
    if site.instr_idx > 0
        and instrs[site.instr_idx - 1].loc.lineno == site.loc.lineno {
        return False;
    }
    if first_copy_loc.lineno == site.loc.lineno or first_copy_loc.lineno < 0 {
        return False;
    }
    return True;
}

def finish_break_sites(
    g: cfg_builder,
    frame: loop_frame,
    join: basicblock,
    tail_loc: cloc,
    tail_terminated: bool,
    allow_nop: bool
) {
    # CPython tries the small scope-exit copy first, then the artificial
    # no-lineno copy (optimize_cfg runs inline_small_or_no_lineno_blocks).
    copies: list[cinstr] | None = None;
    if join_inlinable(join, tail_terminated) {
        copies = [];
        ci = 0;
        while ci < len(join.instrs) {
            copies.append(copy_cinstr(join.instrs[ci]));
            ci = ci + 1;
        }
        if not tail_terminated {
            if g.fallthrough_target is not None {
                g.fallthrough_target.fallthrough_used = True;
                copies.append(
                    mk_jump(OP_JUMP_FORWARD, g.fallthrough_target.id, tail_loc)
                );
            } else {
                none_idx = g.u.add_const(py_none());
                copies.append(mk_instr(OP_LOAD_CONST, none_idx, tail_loc));
                copies.append(mk_instr(OP_RETURN_VALUE, 0, tail_loc));
            }
        }
    } elif join_artificial_tail(join) {
        copies = [];
        ci = 0;
        while ci < len(join.instrs) {
            copies.append(copy_cinstr(join.instrs[ci]));
            ci = ci + 1;
        }
    }
    if copies is None or len(copies) == 0 {
        return;
    }
    # Exit-per-block invariant (mirrors CPython flowgraph.c structure):
    # cfg_builder_maybe_start_new_block starts a fresh block after any
    # terminator, so a jump is always the LAST instruction of its block and
    # inline_small_or_no_lineno_blocks only ever rewrites
    # basicblock_last_instr -- one exit per block, structurally. Our break
    # sites record the index of their jump, which is last-instruction at
    # record time and stays last because visit_stmts halts at the
    # unconditional terminator. Several sites may still share a block; the
    # splice below therefore runs in DESCENDING index order, which keeps
    # lower indices valid while higher ones are rewritten. Enforce both
    # properties loudly instead of trusting callers.
    prev_blk_id = -1;
    prev_idx = -1;
    si = len(frame.break_sites) - 1;
    while si >= 0 {
        site = frame.break_sites[si];
        if site.instr_idx < 0 or site.instr_idx >= len(site.blk.instrs) {
            codegen_fail(
                g, "SystemError", "break site index out of range in finish_break_sites"
            );
            return;
        }
        if not is_unconditional_jump_opcode(site.blk.instrs[site.instr_idx].opcode) {
            codegen_fail(
                g, "SystemError", "break site does not point at its recorded jump"
            );
            return;
        }
        if site.blk.id == prev_blk_id and site.instr_idx >= prev_idx {
            # Same block as the site spliced just before us (higher index);
            # ours must sit strictly below it or the rebuild above would
            # drop instructions between the two exits.
            codegen_fail(
                g, "SystemError", "break sites in one block not in descending order"
            );
            return;
        }
        prev_blk_id = site.blk.id;
        prev_idx = site.instr_idx;
        si = si - 1;
    }
    first_loc = copies[0].loc as cloc;
    uniform_copy_locs = len(copies) > 0;
    if uniform_copy_locs {
        ci = 1;
        while ci < len(copies) {
            if not same_loc(copies[0].loc as cloc, copies[ci].loc as cloc) {
                uniform_copy_locs = False;
                break;
            }
            ci = ci + 1;
        }
    }
    si = len(frame.break_sites) - 1;
    while si >= 0 {
        site = frame.break_sites[si];
        old = site.blk.instrs;
        new_instrs: list[cinstr] = old[0:site.instr_idx];
        ci = 0;
        while ci < len(copies) {
            c = copy_cinstr(copies[ci]);
            if uniform_copy_locs and site.loc.lineno >= 0 {
                c.loc = site.loc;
            }
            new_instrs.append(c);
            ci = ci + 1;
        }
        ki = site.instr_idx + 1;
        while ki < len(old) {
            new_instrs.append(old[ki]);
            ki = ki + 1;
        }
        site.blk.instrs = new_instrs;
        if allow_nop and break_nop_kept(site, first_loc) {
            new_instrs.insert(site.instr_idx, mk_instr(OP_NOP, 0, site.loc));
        }
        si = si - 1;
    }
}

def visit_if(
    g: cfg_builder, i: If, ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    import jaclang.compiler.backends.py.jacpython.compiler_exc as dispatch_exc;
    iloc = nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    constant_test = None;
    if isinstance(i.`test, Constant) {
        constant_test = i.`test.value.tp_bool();
    } elif isinstance(i.`test, Name) and i.`test.id == "__debug__" {
        constant_test = g.u.context.optimize == 0;
    }
    if constant_test is not None {
        chosen = i.body if constant_test else i.orelse;
        test_loc = expr_loc(i.`test);
        g.emit_op(OP_NOP, 0, test_loc);
        if not chosen {
            return stmt_cont(loc=test_loc);
        }
        return dispatch_exc.visit_cleanup_stmts(g, chosen, ann_ctx);
    }
    test_loc = expr_loc(i.`test);
    kind = visit_test_expr(g, i.`test, test_loc, True);
    false_blk = g.new_deferred_block();
    join = g.new_deferred_block();
    emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
    body_cont = dispatch_exc.visit_cleanup_stmts(g, i.body, ann_ctx);
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
    }
    g.use(false_blk);
    else_cont = dispatch_exc.visit_cleanup_stmts(g, i.orelse, ann_ctx);
    if body_cont.terminated and else_cont.terminated {
        return stmt_cont(loc=iloc, terminated=True);
    }
    if not else_cont.terminated and g.u.blocks[-1] is not g.cur {
        g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
    }
    g.use(join);
    return stmt_cont(loc=iloc);
}

def visit_while(
    g: cfg_builder, w: While, ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    import jaclang.compiler.backends.py.jacpython.compiler_exc as dispatch_exc;
    wloc = nloc(w.lineno, w.end_lineno, w.col_offset, w.end_col_offset);
    test_loc = expr_loc(w.`test);
    head = g.new_block();
    exhausted = g.new_deferred_block();
    end = g.new_deferred_block();
    g.use(head);
    kind = visit_test_expr(g, w.`test, test_loc, True);
    emit_branch_if_test_false(g, kind, exhausted.id, test_loc);
    g.push_loop(head, end, True);
    body_cont = dispatch_exc.visit_cleanup_stmts(g, w.body, ann_ctx);
    g.pop_loop();
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, wloc);
    }
    g.use(exhausted);
    else_cont = dispatch_exc.visit_cleanup_stmts(g, w.orelse, ann_ctx);
    if not else_cont.terminated and g.u.blocks[-1] is not g.cur {
        g.emit_jump(OP_JUMP_FORWARD, end.id, wloc);
    }
    # Break always targets this lexical exit, after the else suite. Deferring
    # tail duplication to the CFG optimizer avoids redirecting it into a
    # surrounding handler's temporary cleanup continuation.
    g.use(end);
    return stmt_cont(loc=wloc);
}


def visit_for(
    g: cfg_builder, f: For, ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    import jaclang.compiler.backends.py.jacpython.compiler_exc as dispatch_exc;
    floc = nloc(f.lineno, f.end_lineno, f.col_offset, f.end_col_offset);
    iter_loc = expr_loc(f.iter);
    visit_expr(g, f.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_ITER, 0, iter_loc);
    head = g.new_block();
    exhausted = g.new_deferred_block();
    end = g.new_deferred_block();
    g.use(head);
    g.emit_jump(OP_FOR_ITER, exhausted.id, iter_loc);
    g.push_loop(head, end, True, True);
    visit_store_target_tos(g, f.target);
    body_cont = dispatch_exc.visit_cleanup_stmts(g, f.body, ann_ctx);
    g.pop_loop();
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, floc);
    }
    g.use(exhausted);
    g.emit_op(OP_END_FOR, 0, iter_loc);
    g.emit_op(OP_POP_ITER, 0, iter_loc);
    else_cont = dispatch_exc.visit_cleanup_stmts(g, f.orelse, ann_ctx);
    if not else_cont.terminated and g.u.blocks[-1] is not g.cur {
        g.emit_jump(OP_JUMP_FORWARD, end.id, floc);
    }
    g.use(end);
    return stmt_cont(loc=floc);
}


def visit_async_for(
    g: cfg_builder, af: AsyncFor, ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    import jaclang.compiler.backends.py.jacpython.compiler_exc as dispatch_exc;
    floc = nloc(af.lineno, af.end_lineno, af.col_offset, af.end_col_offset);
    iter_loc = expr_loc(af.iter);
    visit_expr(g, af.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    head = g.new_block();
    exhausted = g.new_deferred_block();
    end = g.new_deferred_block();
    g.use(head);
    end_send = emit_send_delegation_loop(g, OP_GET_ANEXT, 0, 3, iter_loc);
    body = g.new_block();
    g.use(body);
    g.push_loop(head, end, True, True);
    visit_store_target_tos(g, af.target);
    body_cont = dispatch_exc.visit_cleanup_stmts(g, af.body, ann_ctx);
    g.pop_loop();
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, floc);
    }
    g.use(exhausted);
    g.emit_jump(OP_END_ASYNC_FOR, end_send, iter_loc);
    else_cont = dispatch_exc.visit_cleanup_stmts(g, af.orelse, ann_ctx);
    if not else_cont.terminated and g.u.blocks[-1] is not g.cur {
        g.emit_jump(OP_JUMP_FORWARD, end.id, floc);
    }
    g.use(end);
    # Only __anext__ and its await are protected by StopAsyncIteration.
    # Exceptions from the target assignment or body propagate normally.
    g.u.except_regions.append(
        except_region(
            start_block=head.id,
            end_block=body.id,
            handler_block=exhausted.id,
            stack_depth=0,
            depth_from_block=head.id,
            depth_offset=1
        )
    );
    return stmt_cont(loc=floc);
}
