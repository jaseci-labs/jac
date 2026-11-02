impl cg_comprehension_generator(
    c: cpy_compiler,
    loc: srcloc,
    generators: list[comprehension],
    gen_index: int,
    depth: int,
    elt: expr,
    val: expr | None,
    comp_type: int,
    iter_on_stack: bool
) {
    gen = generators[gen_index];
    if gen.is_async {
        cg_async_comprehension_generator(
            c, loc, generators, gen_index, depth, elt, val, comp_type, iter_on_stack
        );
    } else {
        cg_sync_comprehension_generator(
            c, loc, generators, gen_index, depth, elt, val, comp_type, iter_on_stack
        );
    }
}

impl cg_comprehension_element(
    c: cpy_compiler, elt: expr, val: expr | None, comp_type: int, depth: int
) -> srcloc {
    elt_loc = expr_loc(elt);
    if comp_type == COMP_GENEXP {
        cg_visit_expr(c, elt);
        cg_addop_yield(c, elt_loc);
        cg_addop(c, OP_POP_TOP, elt_loc);
    } elif comp_type == COMP_LISTCOMP {
        cg_visit_expr(c, elt);
        cg_addop_i(c, OP_LIST_APPEND, depth + 1, elt_loc);
    } elif comp_type == COMP_SETCOMP {
        cg_visit_expr(c, elt);
        cg_addop_i(c, OP_SET_ADD, depth + 1, elt_loc);
    } elif comp_type == COMP_DICTCOMP and val is not None {
        cg_visit_expr(c, elt);
        cg_visit_expr(c, val);
        val_end_lineno = val.end_lineno if val.end_lineno is not None else val.lineno;
        val_end_col = val.end_col_offset
            if val.end_col_offset is not None
            else val.col_offset;
        elt_loc = mkloc(elt.lineno, val_end_lineno, elt.col_offset, val_end_col);
        cg_addop_i(c, OP_MAP_ADD, depth + 1, elt_loc);
    } else {
        raise SystemError("unknown comprehension type");
    }
    return elt_loc;
}

impl cg_sync_comprehension_generator(
    c: cpy_compiler,
    loc: srcloc,
    generators: list[comprehension],
    gen_index: int,
    depth: int,
    elt: expr,
    val: expr | None,
    comp_type: int,
    iter_on_stack: bool
) {
    start = cg_new_label(c);
    if_cleanup = cg_new_label(c);
    anchor = cg_new_label(c);
    gen = generators[gen_index];
    if not iter_on_stack {
        if gen_index == 0 {
            cg_addop_i(c, OP_LOAD_FAST, 0, loc);
        } else {
            giter = gen.iter;
            elts: list[expr] = [];
            if isinstance(giter, List) {
                elts = giter.elts;
            } elif isinstance(giter, Tuple) {
                elts = giter.elts;
            }
            if len(elts) == 1 {
                one = elts[0];
                if not isinstance(one, Starred) {
                    cg_visit_expr(c, one);
                    start = NO_LABEL;
                }
            }
            if start >= 0 {
                cg_visit_expr(c, giter);
                cg_addop(c, OP_GET_ITER, expr_loc(giter));
            }
        }
    }
    if start >= 0 {
        depth += 1;
        cg_use_label(c, start);
        cg_addop_j(c, OP_FOR_ITER, anchor, expr_loc(gen.iter));
    }
    cg_visit_expr(c, gen.target);
    for e in gen.ifs {
        cg_jump_if(c, loc, e, if_cleanup, False);
    }
    gen_index += 1;
    if gen_index < len(generators) {
        cg_comprehension_generator(
            c, loc, generators, gen_index, depth, elt, val, comp_type, False
        );
    }
    elt_loc = expr_loc(elt);
    if gen_index >= len(generators) {
        elt_loc = cg_comprehension_element(c, elt, val, comp_type, depth);
    }
    cg_use_label(c, if_cleanup);
    if start >= 0 {
        cg_addop_j(c, OP_JUMP, start, elt_loc);
        cg_use_label(c, anchor);
        cg_addop(c, OP_END_FOR, no_location());
        cg_addop(c, OP_POP_ITER, no_location());
    }
}

impl cg_async_comprehension_generator(
    c: cpy_compiler,
    loc: srcloc,
    generators: list[comprehension],
    gen_index: int,
    depth: int,
    elt: expr,
    val: expr | None,
    comp_type: int,
    iter_on_stack: bool
) {
    start = cg_new_label(c);
    send = cg_new_label(c);
    except_label = cg_new_label(c);
    if_cleanup = cg_new_label(c);
    gen = generators[gen_index];
    if not iter_on_stack {
        if gen_index == 0 {
            cg_addop_i(c, OP_LOAD_FAST, 0, loc);
        } else {
            cg_visit_expr(c, gen.iter);
            cg_addop(c, OP_GET_AITER, expr_loc(gen.iter));
        }
    }
    cg_use_label(c, start);
    cpy_compile_push_fblock(
        c, loc, COMPILE_FBLOCK_ASYNC_COMPREHENSION_GENERATOR, start, NO_LABEL
    );
    cg_addop_j(c, OP_SETUP_FINALLY, except_label, loc);
    cg_addop(c, OP_GET_ANEXT, loc);
    cg_load_none(c, loc);
    cg_use_label(c, send);
    cg_add_yield_from(c, loc, True);
    cg_addop(c, OP_POP_BLOCK, loc);
    cg_visit_expr(c, gen.target);
    for e in gen.ifs {
        cg_jump_if(c, loc, e, if_cleanup, False);
    }
    depth += 1;
    gen_index += 1;
    if gen_index < len(generators) {
        cg_comprehension_generator(
            c, loc, generators, gen_index, depth, elt, val, comp_type, False
        );
    }
    elt_loc = expr_loc(elt);
    if gen_index >= len(generators) {
        elt_loc = cg_comprehension_element(c, elt, val, comp_type, depth);
    }
    cg_use_label(c, if_cleanup);
    cg_addop_j(c, OP_JUMP, start, elt_loc);
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_ASYNC_COMPREHENSION_GENERATOR, start);
    cg_use_label(c, except_label);
    cg_addop_j(c, OP_END_ASYNC_FOR, send, loc);
}

impl cg_push_inlined_comprehension_locals(
    c: cpy_compiler, loc: srcloc, comp: cpy_ste, state: cpy_inline_state
) {
    u = c.unit();
    in_class_block = u.ste.ste_type == ClassBlock and not u.in_inlined_comp;
    outer = u.ste;
    for k in list(comp.symbol_order) {
        symbol = comp.symbols[k];
        scope = (symbol >> ST_SCOPE_OFFSET) & ST_SCOPE_MASK;
        outsymbol = cpy_st_get_symbol(outer, k);
        outsc = (outsymbol >> ST_SCOPE_OFFSET) & ST_SCOPE_MASK;
        if ((symbol & ST_DEF_LOCAL) and not (symbol & ST_DEF_NONLOCAL))
            or in_class_block {
            pushed = state.pushed_locals;
            if pushed is None {
                pushed = [];
                state.pushed_locals = pushed;
            }
            cg_addop_name(c, loc, OP_LOAD_FAST_AND_CLEAR, CG_VARNAMES, k);
            if scope == ST_CELL {
                if outsc == ST_FREE {
                    cg_addop_name(c, loc, OP_MAKE_CELL, CG_FREEVARS, k);
                } else {
                    cg_addop_name(c, loc, OP_MAKE_CELL, CG_CELLVARS, k);
                }
            }
            pushed.append(k);
        }
    }
    pushed = state.pushed_locals;
    if pushed is not None {
        cg_addop_i(c, OP_SWAP, len(pushed) + 1, loc);
        cleanup = cg_new_label(c);
        state.cleanup = cleanup;
        cg_addop_j(c, OP_SETUP_FINALLY, cleanup, loc);
    }
}

impl cg_restore_inlined_comprehension_locals(
    c: cpy_compiler, loc: srcloc, state: cpy_inline_state
) {
    pushed = state.pushed_locals;
    if pushed is None {
        return;
    }
    npops = len(pushed);
    cg_addop_i(c, OP_SWAP, npops + 1, loc);
    i = npops - 1;
    while i >= 0 {
        cg_addop_name(c, loc, OP_STORE_FAST_MAYBE_NULL, CG_VARNAMES, pushed[i]);
        i -= 1;
    }
}

impl cg_pop_inlined_comprehension_locals(
    c: cpy_compiler, loc: srcloc, state: cpy_inline_state
) {
    if state.pushed_locals is not None {
        cg_addop(c, OP_POP_BLOCK, no_location());
        end = cg_new_label(c);
        cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
        cg_use_label(c, state.cleanup);
        cg_addop_i(c, OP_SWAP, 2, no_location());
        cg_addop(c, OP_POP_TOP, no_location());
        cg_restore_inlined_comprehension_locals(c, loc, state);
        cg_addop_i(c, OP_RERAISE, 0, no_location());
        cg_use_label(c, end);
        cg_restore_inlined_comprehension_locals(c, loc, state);
        state.pushed_locals = None;
    }
}

impl cg_comprehension_iter(c: cpy_compiler, comp: comprehension) {
    cg_visit_expr(c, comp.iter);
    if comp.is_async {
        cg_addop(c, OP_GET_AITER, expr_loc(comp.iter));
    } else {
        cg_addop(c, OP_GET_ITER, expr_loc(comp.iter));
    }
}

impl cg_comprehension(
    c: cpy_compiler,
    e: expr,
    comp_type: int,
    name: str,
    generators: list[comprehension],
    elt: expr,
    val: expr | None
) {
    inline_state = cpy_inline_state();
    comp_ste = cpy_symtable_lookup(c.st, cpy_st_key(e));
    is_inlined = comp_ste.comp_inlined != 0;
    is_async_comprehension = comp_ste.coroutine != 0;
    loc = expr_loc(e);
    outermost = generators[0];
    if is_inlined {
        cg_comprehension_iter(c, outermost);
        cpy_compile_tweak_inlined_comprehension_scopes(c, loc, comp_ste, inline_state);
        cg_push_inlined_comprehension_locals(c, loc, comp_ste, inline_state);
    } else {
        cg_enter_scope(
            c, name, COMPILE_SCOPE_COMPREHENSION, cpy_st_key(e), e.lineno, None, 1, 0, 0
        );
    }
    if comp_type != COMP_GENEXP {
        op = OP_BUILD_LIST;
        if comp_type == COMP_SETCOMP {
            op = OP_BUILD_SET;
        } elif comp_type == COMP_DICTCOMP {
            op = OP_BUILD_MAP;
        }
        cg_addop_i(c, op, 0, loc);
        if is_inlined {
            cg_addop_i(c, OP_SWAP, 2, loc);
        }
    }
    cg_comprehension_generator(
        c, loc, generators, 0, 0, elt, val, comp_type, is_inlined
    );
    if is_inlined {
        cg_pop_inlined_comprehension_locals(c, loc, inline_state);
        cpy_compile_revert_inlined_comprehension_scopes(c, loc, inline_state);
        return;
    }
    if comp_type != COMP_GENEXP {
        cg_addop(c, OP_RETURN_VALUE, expr_loc(e));
    }
    if comp_type == COMP_GENEXP {
        cg_wrap_in_stopiteration_handler(c);
    }
    co = cpy_compile_optimize_and_assemble(c, True);
    cpy_compile_exit_scope(c);
    loc = expr_loc(e);
    cg_make_closure(c, loc, co, 0);
    cg_comprehension_iter(c, outermost);
    cg_addop_i(c, OP_CALL, 0, loc);
    if is_async_comprehension and comp_type != COMP_GENEXP {
        cg_addop_i(c, OP_GET_AWAITABLE, 0, loc);
        cg_load_none(c, loc);
        cg_add_yield_from(c, loc, True);
    }
}
