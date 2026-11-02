impl cg_addop(c: cpy_compiler, opcode: int, loc: srcloc) {
    c.unit().seq.addop(opcode, 0, loc);
}

impl cg_addop_i(c: cpy_compiler, opcode: int, oparg: int, loc: srcloc) {
    c.unit().seq.addop(opcode, oparg, loc);
}

impl cg_addop_j(c: cpy_compiler, opcode: int, target: int, loc: srcloc) {
    c.unit().seq.addop(opcode, target, loc);
}

impl cg_new_label(c: cpy_compiler) -> int {
    return c.unit().seq.new_label();
}

impl cg_use_label(c: cpy_compiler, lbl: int) {
    c.unit().seq.use_label(lbl);
}

impl cg_load_const(c: cpy_compiler, o: PyObj, loc: srcloc) {
    arg = cpy_compile_add_const(c, o);
    cg_addop_i(c, OP_LOAD_CONST, arg, loc);
}

impl cg_load_none(c: cpy_compiler, loc: srcloc) {
    cg_load_const(c, py_none(), loc);
}

impl cg_load_int(c: cpy_compiler, value: int, loc: srcloc) {
    cg_load_const(c, PyInt(t="int", val=value), loc);
}

impl cg_load_str(c: cpy_compiler, value: str, loc: srcloc) {
    cg_load_const(c, PyStr(t="str", val=value), loc);
}

impl cg_dict_add(c: cpy_compiler, kind: int, name: str) -> int {
    md = c.unit().md;
    if kind == CG_VARNAMES {
        return cpy_dict_add(md.varnames, md.varname_index, name);
    } elif kind == CG_CELLVARS {
        return cpy_dict_add(md.cellvars, md.cellvar_index, name);
    } elif kind == CG_FREEVARS {
        return cpy_dict_add(md.freevars, md.freevar_index, name);
    }
    return cpy_dict_add(md.names, md.name_index, name);
}

impl cg_addop_n(c: cpy_compiler, loc: srcloc, opcode: int, kind: int, name: str) {
    arg = cg_dict_add(c, kind, name);
    cg_addop_i(c, opcode, arg, loc);
}

impl cg_addop_name(c: cpy_compiler, loc: srcloc, opcode: int, kind: int, name: str) {
    mangled = cpy_compile_maybe_mangle(c, name);
    arg = cg_dict_add(c, kind, mangled);
    op = opcode;
    if op == OP_LOAD_ATTR {
        arg = arg << 1;
    }
    if op == CG_LOAD_METHOD {
        op = OP_LOAD_ATTR;
        arg = (arg << 1) | 1;
    }
    if op == OP_LOAD_SUPER_ATTR {
        arg = (arg << 2) | 2;
    }
    if op == CG_LOAD_SUPER_METHOD {
        op = OP_LOAD_SUPER_ATTR;
        arg = (arg << 2) | 3;
    }
    if op == CG_LOAD_ZERO_SUPER_ATTR {
        op = OP_LOAD_SUPER_ATTR;
        arg = arg << 2;
    }
    if op == CG_LOAD_ZERO_SUPER_METHOD {
        op = OP_LOAD_SUPER_ATTR;
        arg = (arg << 2) | 1;
    }
    cg_addop_i(c, op, arg, loc);
}

impl cg_call_exit_with_nones(c: cpy_compiler, loc: srcloc) {
    cg_load_none(c, loc);
    cg_load_none(c, loc);
    cg_load_none(c, loc);
    cg_addop_i(c, OP_CALL, 3, loc);
}

impl cg_add_yield_from(c: cpy_compiler, loc: srcloc, await_: bool) {
    send = cg_new_label(c);
    fail = cg_new_label(c);
    exit_label = cg_new_label(c);
    cg_use_label(c, send);
    cg_addop_j(c, OP_SEND, exit_label, loc);
    cg_addop_j(c, OP_SETUP_FINALLY, fail, loc);
    cg_addop_i(c, OP_YIELD_VALUE, 1, loc);
    cg_addop(c, OP_POP_BLOCK, no_location());
    cg_addop_i(
        c, OP_RESUME, RESUME_AFTER_AWAIT if await_ else RESUME_AFTER_YIELD_FROM, loc
    );
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, send, loc);
    cg_use_label(c, fail);
    cg_addop(c, OP_CLEANUP_THROW, loc);
    cg_use_label(c, exit_label);
    cg_addop(c, OP_END_SEND, loc);
}

impl cg_pop_except_and_reraise(c: cpy_compiler, loc: srcloc) {
    cg_addop_i(c, OP_COPY, 3, loc);
    cg_addop(c, OP_POP_EXCEPT, loc);
    cg_addop_i(c, OP_RERAISE, 1, loc);
}

impl cg_unwind_fblock(
    c: cpy_compiler, loc: srcloc, info: cpy_fblock, preserve_tos: bool
) -> srcloc {
    t = info.fb_type;
    if t == COMPILE_FBLOCK_WHILE_LOOP
        or t == COMPILE_FBLOCK_EXCEPTION_HANDLER
        or t == COMPILE_FBLOCK_EXCEPTION_GROUP_HANDLER
        or t == COMPILE_FBLOCK_ASYNC_COMPREHENSION_GENERATOR
        or t == COMPILE_FBLOCK_STOP_ITERATION {
        return loc;
    }
    if t == COMPILE_FBLOCK_FOR_LOOP {
        if preserve_tos {
            cg_addop_i(c, OP_SWAP, 2, loc);
        }
        cg_addop(c, OP_POP_TOP, loc);
        return loc;
    }
    if t == COMPILE_FBLOCK_TRY_EXCEPT {
        cg_addop(c, OP_POP_BLOCK, loc);
        return loc;
    }
    if t == COMPILE_FBLOCK_FINALLY_TRY {
        cg_addop(c, OP_POP_BLOCK, loc);
        if preserve_tos {
            cpy_compile_push_fblock(
                c, loc, COMPILE_FBLOCK_POP_VALUE, NO_LABEL, NO_LABEL
            );
        }
        body = info.fb_body;
        if body is not None {
            cg_visit_stmts(c, body);
        }
        if preserve_tos {
            cpy_compile_pop_fblock(c, COMPILE_FBLOCK_POP_VALUE, NO_LABEL);
        }
        return no_location();
    }
    if t == COMPILE_FBLOCK_FINALLY_END {
        if preserve_tos {
            cg_addop_i(c, OP_SWAP, 2, loc);
        }
        cg_addop(c, OP_POP_TOP, loc);
        if preserve_tos {
            cg_addop_i(c, OP_SWAP, 2, loc);
        }
        cg_addop(c, OP_POP_BLOCK, loc);
        cg_addop(c, OP_POP_EXCEPT, loc);
        return loc;
    }
    if t == COMPILE_FBLOCK_WITH or t == COMPILE_FBLOCK_ASYNC_WITH {
        wloc = info.fb_loc;
        cg_addop(c, OP_POP_BLOCK, wloc);
        if preserve_tos {
            cg_addop_i(c, OP_SWAP, 3, wloc);
            cg_addop_i(c, OP_SWAP, 2, wloc);
        }
        cg_call_exit_with_nones(c, wloc);
        if t == COMPILE_FBLOCK_ASYNC_WITH {
            cg_addop_i(c, OP_GET_AWAITABLE, 2, wloc);
            cg_load_none(c, wloc);
            cg_add_yield_from(c, wloc, True);
        }
        cg_addop(c, OP_POP_TOP, wloc);
        return no_location();
    }
    if t == COMPILE_FBLOCK_HANDLER_CLEANUP {
        name = info.fb_name;
        if name is not None {
            cg_addop(c, OP_POP_BLOCK, loc);
        }
        if preserve_tos {
            cg_addop_i(c, OP_SWAP, 2, loc);
        }
        cg_addop(c, OP_POP_BLOCK, loc);
        cg_addop(c, OP_POP_EXCEPT, loc);
        if name is not None {
            cg_load_none(c, loc);
            cg_nameop(c, loc, name, CG_STORE);
            cg_nameop(c, loc, name, CG_DEL);
        }
        return loc;
    }
    if t == COMPILE_FBLOCK_POP_VALUE {
        if preserve_tos {
            cg_addop_i(c, OP_SWAP, 2, loc);
        }
        cg_addop(c, OP_POP_TOP, loc);
        return loc;
    }
    raise SystemError("unknown frame block type");
}

impl cg_unwind_fblock_stack(
    c: cpy_compiler, loc: srcloc, preserve_tos: bool, want_loop: bool
) -> tuple[srcloc, cpy_fblock | None] {
    top = cpy_compile_top_fblock(c);
    if top is None {
        return (loc, None);
    }
    if top.fb_type == COMPILE_FBLOCK_EXCEPTION_GROUP_HANDLER {
        cpy_compile_error(
            c, loc, "'break', 'continue' and 'return' cannot appear in an except* block"
        );
    }
    if want_loop
        and (
            top.fb_type == COMPILE_FBLOCK_WHILE_LOOP
            or top.fb_type == COMPILE_FBLOCK_FOR_LOOP
        ) {
        return (loc, top);
    }
    cpy_compile_pop_fblock(c, top.fb_type, top.fb_block);
    loc = cg_unwind_fblock(c, loc, top, preserve_tos);
    (loc, loop) = cg_unwind_fblock_stack(c, loc, preserve_tos, want_loop);
    cpy_compile_push_fblock(
        c, top.fb_loc, top.fb_type, top.fb_block, top.fb_exit, top.fb_body, top.fb_name
    );
    return (loc, loop);
}

impl cg_enter_scope(
    c: cpy_compiler,
    name: str,
    scope_type: int,
    key: int,
    lineno: int,
    private: str | None,
    argcount: int,
    posonlyargcount: int,
    kwonlyargcount: int
) {
    cpy_compile_enter_scope(
        c,
        name,
        scope_type,
        key,
        lineno,
        private,
        argcount,
        posonlyargcount,
        kwonlyargcount
    );
    loc = mkloc(lineno, lineno, 0, 0);
    if scope_type == COMPILE_SCOPE_MODULE {
        loc = mkloc(0, lineno, 0, 0);
    }
    cg_addop_i(c, OP_RESUME, RESUME_AT_FUNC_START, loc);
    if scope_type == COMPILE_SCOPE_MODULE {
        cg_addop(c, OP_ANNOTATIONS_PLACEHOLDER, loc);
    }
}

impl cg_setup_annotations_scope(c: cpy_compiler, loc: srcloc, key: int, name: str) {
    cg_enter_scope(c, name, COMPILE_SCOPE_ANNOTATIONS, key, loc.lineno, None, 0, 1, 0);
    cg_addop_i(c, OP_LOAD_FAST, 0, loc);
    cg_load_int(c, ANNOTATE_FORMAT_VALUE_WITH_FAKE_GLOBALS, loc);
    cg_addop_i(c, OP_COMPARE_OP, compare_oparg(CMP_GT), loc);
    body = cg_new_label(c);
    cg_addop_j(c, OP_POP_JUMP_IF_FALSE, body, loc);
    cg_addop_i(c, OP_LOAD_COMMON_CONSTANT, CONSTANT_NOTIMPLEMENTEDERROR, loc);
    cg_addop_i(c, OP_RAISE_VARARGS, 1, loc);
    cg_use_label(c, body);
}

impl cg_leave_annotations_scope(c: cpy_compiler, loc: srcloc) {
    cg_addop(c, OP_RETURN_VALUE, loc);
    co = cpy_compile_optimize_and_assemble(c, True);
    if len(co.localsplusnames) > 0 {
        co.localsplusnames[0] = "format";
        co.unshared_localsplus = True;
    }
    if len(co.varnames) > 0 {
        co.varnames[0] = "format";
    }
    cpy_compile_exit_scope(c);
    cg_make_closure(c, loc, co, 0);
}

impl cg_deferred_annotations_body(
    c: cpy_compiler,
    loc: srcloc,
    deferred: list[AnnAssign],
    indices: list[int],
    scope_type: int
) {
    cg_addop_i(c, OP_BUILD_MAP, 0, loc);
    i = 0;
    while i < len(deferred) {
        st = deferred[i];
        target = st.target;
        target_name = "";
        if isinstance(target, Name) {
            target_name = target.id;
        }
        mangled = cpy_compile_mangle(c, target_name);
        idx = indices[i];
        not_set = cg_new_label(c);
        sloc = stmt_loc(st);
        if idx != -1 {
            cg_load_int(c, idx, sloc);
            if scope_type == COMPILE_SCOPE_CLASS {
                cg_addop_name(
                    c, sloc, OP_LOAD_DEREF, CG_FREEVARS, "__conditional_annotations__"
                );
            } else {
                cg_addop_name(
                    c, sloc, OP_LOAD_GLOBAL, CG_NAMES, "__conditional_annotations__"
                );
            }
            cg_addop_i(c, OP_CONTAINS_OP, 0, sloc);
            cg_addop_j(c, OP_POP_JUMP_IF_FALSE, not_set, sloc);
        }
        cg_visit_expr(c, st.annotation);
        cg_addop_i(c, OP_COPY, 2, sloc);
        cg_load_str(c, mangled, sloc);
        cg_addop(c, OP_STORE_SUBSCR, loc);
        cg_use_label(c, not_set);
        i += 1;
    }
}

impl cg_process_deferred_annotations(c: cpy_compiler, loc: srcloc) {
    u = c.unit();
    deferred = u.deferred_annotations;
    indices = u.conditional_annotation_indices;
    if deferred is None or indices is None {
        return;
    }
    scope_type = u.scope_type;
    need_separate_block = scope_type == COMPILE_SCOPE_MODULE;
    if need_separate_block {
        cpy_compile_start_annotation_setup(c);
    }
    ste = u.ste;
    block = ste.annotation_block;
    block_name = block.name if block is not None else "__annotate__";
    cg_setup_annotations_scope(c, loc, ste.id + 1, block_name);
    cg_deferred_annotations_body(c, loc, deferred, indices, scope_type);
    cg_leave_annotations_scope(c, loc);
    cg_nameop(
        c,
        loc,
        "__annotate_func__" if ste.ste_type == ClassBlock else "__annotate__",
        CG_STORE
    );
    if need_separate_block {
        cpy_compile_end_annotation_setup(c);
    }
}

impl cg_module(c: cpy_compiler, loc: srcloc, stmts: list[stmt], is_interactive: bool) {
    if c.unit().ste.has_conditional_annotations {
        cg_addop_i(c, OP_BUILD_SET, 0, loc);
        cg_addop_n(c, loc, OP_STORE_NAME, CG_NAMES, "__conditional_annotations__");
    }
    cg_body(c, loc, stmts, is_interactive);
}

impl cg_body(c: cpy_compiler, loc: srcloc, stmts: list[stmt], is_interactive: bool) {
    ste = c.unit().ste;
    if (c.future_features & CO_FUTURE_ANNOTATIONS) and ste.annotations_used {
        cg_addop(c, OP_SETUP_ANNOTATIONS, loc);
    }
    if len(stmts) == 0 {
        return;
    }
    first_instr = 0;
    if not is_interactive and ste.has_docstring {
        docstring = cpy_get_docstring(stmts);
        first_instr = 1;
        cleandoc = cpy_clean_doc(docstring if docstring is not None else "");
        st = stmts[0];
        if isinstance(st, Expr) {
            cg_load_str(c, cleandoc, expr_loc(st.value));
        }
        cg_nameop(c, no_location(), "__doc__", CG_STORE);
    }
    i = first_instr;
    while i < len(stmts) {
        cg_visit_stmt(c, stmts[i]);
        i += 1;
    }
    if not (c.future_features & CO_FUTURE_ANNOTATIONS) {
        cg_process_deferred_annotations(c, loc);
    }
}

impl cg_make_closure(c: cpy_compiler, loc: srcloc, co: PyCode, flags: int) {
    nfree = len(co.freevars);
    if nfree {
        nlocalsplus = len(co.localsplusnames);
        i = nlocalsplus - nfree;
        while i < nlocalsplus {
            name = co.localsplusnames[i];
            arg = cpy_compile_lookup_arg(c, co, name);
            cg_addop_i(c, OP_LOAD_CLOSURE, arg, loc);
            i += 1;
        }
        flags |= MAKE_FUNCTION_CLOSURE;
        cg_addop_i(c, OP_BUILD_TUPLE, nfree, loc);
    }
    cg_load_const(c, co, loc);
    cg_addop(c, OP_MAKE_FUNCTION, loc);
    if flags & MAKE_FUNCTION_CLOSURE {
        cg_addop_i(c, OP_SET_FUNCTION_ATTRIBUTE, MAKE_FUNCTION_CLOSURE, loc);
    }
    if flags & MAKE_FUNCTION_ANNOTATIONS {
        cg_addop_i(c, OP_SET_FUNCTION_ATTRIBUTE, MAKE_FUNCTION_ANNOTATIONS, loc);
    }
    if flags & MAKE_FUNCTION_ANNOTATE {
        cg_addop_i(c, OP_SET_FUNCTION_ATTRIBUTE, MAKE_FUNCTION_ANNOTATE, loc);
    }
    if flags & MAKE_FUNCTION_KWDEFAULTS {
        cg_addop_i(c, OP_SET_FUNCTION_ATTRIBUTE, MAKE_FUNCTION_KWDEFAULTS, loc);
    }
    if flags & MAKE_FUNCTION_DEFAULTS {
        cg_addop_i(c, OP_SET_FUNCTION_ATTRIBUTE, MAKE_FUNCTION_DEFAULTS, loc);
    }
}

impl cg_decorators(c: cpy_compiler, decos: list[expr]) {
    for d in decos {
        cg_visit_expr(c, d);
    }
}

impl cg_apply_decorators(c: cpy_compiler, decos: list[expr]) {
    i = len(decos) - 1;
    while i > -1 {
        cg_addop_i(c, OP_CALL, 0, expr_loc(decos[i]));
        i -= 1;
    }
}

impl cg_visit_stmts(c: cpy_compiler, stmts: list[stmt]) {
    for s in stmts {
        cg_visit_stmt(c, s);
    }
}

impl cg_if(c: cpy_compiler, s: If) {
    end = cg_new_label(c);
    next = end;
    if len(s.orelse) {
        next = cg_new_label(c);
    }
    cg_jump_if(c, stmt_loc(s), s.test, next, False);
    cg_visit_stmts(c, s.body);
    if len(s.orelse) {
        cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
        cg_use_label(c, next);
        cg_visit_stmts(c, s.orelse);
    }
    cg_use_label(c, end);
}

impl cg_for(c: cpy_compiler, s: For) {
    loc = stmt_loc(s);
    start = cg_new_label(c);
    body = cg_new_label(c);
    cleanup = cg_new_label(c);
    end = cg_new_label(c);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_FOR_LOOP, start, end);
    cg_visit_expr(c, s.iter);
    loc = expr_loc(s.iter);
    cg_addop(c, OP_GET_ITER, loc);
    cg_use_label(c, start);
    cg_addop_j(c, OP_FOR_ITER, cleanup, loc);
    cg_addop(c, OP_NOP, expr_loc(s.target));
    cg_use_label(c, body);
    cg_visit_expr(c, s.target);
    cg_visit_stmts(c, s.body);
    cg_addop_j(c, OP_JUMP, start, no_location());
    cg_use_label(c, cleanup);
    cg_addop(c, OP_END_FOR, no_location());
    cg_addop(c, OP_POP_ITER, no_location());
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_FOR_LOOP, start);
    cg_visit_stmts(c, s.orelse);
    cg_use_label(c, end);
}

impl cg_async_for(c: cpy_compiler, s: AsyncFor) {
    loc = stmt_loc(s);
    start = cg_new_label(c);
    send = cg_new_label(c);
    except_label = cg_new_label(c);
    end = cg_new_label(c);
    cg_visit_expr(c, s.iter);
    cg_addop(c, OP_GET_AITER, expr_loc(s.iter));
    cg_use_label(c, start);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_FOR_LOOP, start, end);
    cg_addop_j(c, OP_SETUP_FINALLY, except_label, loc);
    cg_addop(c, OP_GET_ANEXT, loc);
    cg_load_none(c, loc);
    cg_use_label(c, send);
    cg_add_yield_from(c, loc, True);
    cg_addop(c, OP_POP_BLOCK, loc);
    cg_addop(c, OP_NOT_TAKEN, loc);
    cg_visit_expr(c, s.target);
    cg_visit_stmts(c, s.body);
    cg_addop_j(c, OP_JUMP, start, no_location());
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_FOR_LOOP, start);
    cg_use_label(c, except_label);
    loc = expr_loc(s.iter);
    cg_addop_j(c, OP_END_ASYNC_FOR, send, loc);
    cg_visit_stmts(c, s.orelse);
    cg_use_label(c, end);
}

impl cg_while(c: cpy_compiler, s: While) {
    loop = cg_new_label(c);
    end = cg_new_label(c);
    anchor = cg_new_label(c);
    cg_use_label(c, loop);
    cpy_compile_push_fblock(c, stmt_loc(s), COMPILE_FBLOCK_WHILE_LOOP, loop, end);
    cg_jump_if(c, stmt_loc(s), s.test, anchor, False);
    cg_visit_stmts(c, s.body);
    cg_addop_j(c, OP_JUMP, loop, no_location());
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_WHILE_LOOP, loop);
    cg_use_label(c, anchor);
    cg_visit_stmts(c, s.orelse);
    cg_use_label(c, end);
}

impl cg_return(c: cpy_compiler, s: Return) {
    loc = stmt_loc(s);
    value = s.value;
    preserve_tos = value is not None and not isinstance(value, Constant);
    ste = c.unit().ste;
    if not cpy_st_is_function_like(ste) {
        cpy_compile_error(c, loc, "'return' outside function");
    }
    if value is not None and ste.coroutine and ste.generator {
        cpy_compile_error(c, loc, "'return' with value in async generator");
    }
    if preserve_tos and value is not None {
        cg_visit_expr(c, value);
    } elif value is not None {
        loc = expr_loc(value);
        cg_addop(c, OP_NOP, loc);
    }
    if value is None or value.lineno != s.lineno {
        loc = stmt_loc(s);
        cg_addop(c, OP_NOP, loc);
    }
    (loc, _) = cg_unwind_fblock_stack(c, loc, preserve_tos, False);
    if value is None {
        cg_load_none(c, loc);
    } elif not preserve_tos and isinstance(value, Constant) {
        cg_load_const(c, value.value, loc);
    }
    cg_addop(c, OP_RETURN_VALUE, loc);
}

impl cg_break(c: cpy_compiler, loc: srcloc) {
    origin_loc = loc;
    cg_addop(c, OP_NOP, loc);
    (loc, loop) = cg_unwind_fblock_stack(c, loc, False, True);
    if loop is None {
        cpy_compile_error(c, origin_loc, "'break' outside loop");
        return;
    }
    loc = cg_unwind_fblock(c, loc, loop, False);
    cg_addop_j(c, OP_JUMP, loop.fb_exit, loc);
}

impl cg_continue(c: cpy_compiler, loc: srcloc) {
    origin_loc = loc;
    cg_addop(c, OP_NOP, loc);
    (loc, loop) = cg_unwind_fblock_stack(c, loc, False, True);
    if loop is None {
        cpy_compile_error(c, origin_loc, "'continue' not properly in loop");
        return;
    }
    cg_addop_j(c, OP_JUMP, loop.fb_block, loc);
}

impl cg_try_finally(c: cpy_compiler, s: Try) {
    loc = stmt_loc(s);
    body = cg_new_label(c);
    end = cg_new_label(c);
    exit_label = cg_new_label(c);
    cleanup = cg_new_label(c);
    cg_addop_j(c, OP_SETUP_FINALLY, end, loc);
    cg_use_label(c, body);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_FINALLY_TRY, body, end, s.finalbody);
    if len(s.handlers) {
        cg_try_except(c, s);
    } else {
        cg_visit_stmts(c, s.body);
    }
    cg_addop(c, OP_POP_BLOCK, no_location());
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_FINALLY_TRY, body);
    cg_visit_stmts(c, s.finalbody);
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, exit_label, no_location());
    cg_use_label(c, end);
    loc = no_location();
    cg_addop_j(c, OP_SETUP_CLEANUP, cleanup, loc);
    cg_addop(c, OP_PUSH_EXC_INFO, loc);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_FINALLY_END, end, NO_LABEL);
    cg_visit_stmts(c, s.finalbody);
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_FINALLY_END, end);
    loc = no_location();
    cg_addop_i(c, OP_RERAISE, 0, loc);
    cg_use_label(c, cleanup);
    cg_pop_except_and_reraise(c, loc);
    cg_use_label(c, exit_label);
}

impl cg_try_star_finally(c: cpy_compiler, s: TryStar) {
    loc = stmt_loc(s);
    body = cg_new_label(c);
    end = cg_new_label(c);
    exit_label = cg_new_label(c);
    cleanup = cg_new_label(c);
    cg_addop_j(c, OP_SETUP_FINALLY, end, loc);
    cg_use_label(c, body);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_FINALLY_TRY, body, end, s.finalbody);
    if len(s.handlers) {
        cg_try_star_except(c, s);
    } else {
        cg_visit_stmts(c, s.body);
    }
    cg_addop(c, OP_POP_BLOCK, no_location());
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_FINALLY_TRY, body);
    cg_visit_stmts(c, s.finalbody);
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, exit_label, no_location());
    cg_use_label(c, end);
    loc = no_location();
    cg_addop_j(c, OP_SETUP_CLEANUP, cleanup, loc);
    cg_addop(c, OP_PUSH_EXC_INFO, loc);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_FINALLY_END, end, NO_LABEL);
    cg_visit_stmts(c, s.finalbody);
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_FINALLY_END, end);
    loc = no_location();
    cg_addop_i(c, OP_RERAISE, 0, loc);
    cg_use_label(c, cleanup);
    cg_pop_except_and_reraise(c, loc);
    cg_use_label(c, exit_label);
}

impl cg_try_except(c: cpy_compiler, s: Try) {
    loc = stmt_loc(s);
    body = cg_new_label(c);
    except_label = cg_new_label(c);
    end = cg_new_label(c);
    cleanup = cg_new_label(c);
    cg_addop_j(c, OP_SETUP_FINALLY, except_label, loc);
    cg_use_label(c, body);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_TRY_EXCEPT, body, NO_LABEL);
    cg_visit_stmts(c, s.body);
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_TRY_EXCEPT, body);
    cg_addop(c, OP_POP_BLOCK, no_location());
    if len(s.orelse) {
        cg_visit_stmts(c, s.orelse);
    }
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
    n = len(s.handlers);
    cg_use_label(c, except_label);
    cg_addop_j(c, OP_SETUP_CLEANUP, cleanup, no_location());
    cg_addop(c, OP_PUSH_EXC_INFO, no_location());
    cpy_compile_push_fblock(
        c, loc, COMPILE_FBLOCK_EXCEPTION_HANDLER, NO_LABEL, NO_LABEL
    );
    i = 0;
    while i < n {
        handler = s.handlers[i];
        hloc = handler_loc(handler);
        if handler.type is None and i < n - 1 {
            cpy_compile_error(c, hloc, "default 'except:' must be last");
        }
        next_except = cg_new_label(c);
        except_label = next_except;
        htype = handler.type;
        if htype is not None {
            cg_visit_expr(c, htype);
            cg_addop(c, OP_CHECK_EXC_MATCH, hloc);
            cg_addop_j(c, OP_POP_JUMP_IF_FALSE, except_label, hloc);
        }
        hname = handler.name;
        if hname is not None {
            cleanup_end = cg_new_label(c);
            cleanup_body = cg_new_label(c);
            cg_nameop(c, hloc, hname, CG_STORE);
            cg_addop_j(c, OP_SETUP_CLEANUP, cleanup_end, hloc);
            cg_use_label(c, cleanup_body);
            cpy_compile_push_fblock(
                c,
                hloc,
                COMPILE_FBLOCK_HANDLER_CLEANUP,
                cleanup_body,
                NO_LABEL,
                None,
                hname
            );
            cg_visit_stmts(c, handler.body);
            cpy_compile_pop_fblock(c, COMPILE_FBLOCK_HANDLER_CLEANUP, cleanup_body);
            cg_addop(c, OP_POP_BLOCK, no_location());
            cg_addop(c, OP_POP_BLOCK, no_location());
            cg_addop(c, OP_POP_EXCEPT, no_location());
            cg_load_none(c, no_location());
            cg_nameop(c, no_location(), hname, CG_STORE);
            cg_nameop(c, no_location(), hname, CG_DEL);
            cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
            cg_use_label(c, cleanup_end);
            cg_load_none(c, no_location());
            cg_nameop(c, no_location(), hname, CG_STORE);
            cg_nameop(c, no_location(), hname, CG_DEL);
            cg_addop_i(c, OP_RERAISE, 1, no_location());
        } else {
            cleanup_body = cg_new_label(c);
            cg_addop(c, OP_POP_TOP, hloc);
            cg_use_label(c, cleanup_body);
            cpy_compile_push_fblock(
                c, hloc, COMPILE_FBLOCK_HANDLER_CLEANUP, cleanup_body, NO_LABEL
            );
            cg_visit_stmts(c, handler.body);
            cpy_compile_pop_fblock(c, COMPILE_FBLOCK_HANDLER_CLEANUP, cleanup_body);
            cg_addop(c, OP_POP_BLOCK, no_location());
            cg_addop(c, OP_POP_EXCEPT, no_location());
            cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
        }
        cg_use_label(c, except_label);
        i += 1;
    }
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_EXCEPTION_HANDLER, NO_LABEL);
    cg_addop_i(c, OP_RERAISE, 0, no_location());
    cg_use_label(c, cleanup);
    cg_pop_except_and_reraise(c, no_location());
    cg_use_label(c, end);
}

impl cg_try_star_except(c: cpy_compiler, s: TryStar) {
    loc = stmt_loc(s);
    body = cg_new_label(c);
    except_label = cg_new_label(c);
    orelse = cg_new_label(c);
    end = cg_new_label(c);
    cleanup = cg_new_label(c);
    reraise_star = cg_new_label(c);
    cg_addop_j(c, OP_SETUP_FINALLY, except_label, loc);
    cg_use_label(c, body);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_TRY_EXCEPT, body, NO_LABEL);
    cg_visit_stmts(c, s.body);
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_TRY_EXCEPT, body);
    cg_addop(c, OP_POP_BLOCK, no_location());
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, orelse, no_location());
    n = len(s.handlers);
    cg_use_label(c, except_label);
    cg_addop_j(c, OP_SETUP_CLEANUP, cleanup, no_location());
    cg_addop(c, OP_PUSH_EXC_INFO, no_location());
    cpy_compile_push_fblock(
        c, loc, COMPILE_FBLOCK_EXCEPTION_GROUP_HANDLER, NO_LABEL, NO_LABEL
    );
    i = 0;
    while i < n {
        handler = s.handlers[i];
        hloc = handler_loc(handler);
        next_except = cg_new_label(c);
        except_label = next_except;
        except_with_error = cg_new_label(c);
        no_match = cg_new_label(c);
        if i == 0 {
            cg_addop_i(c, OP_BUILD_LIST, 0, hloc);
            cg_addop_i(c, OP_COPY, 2, hloc);
        }
        htype = handler.type;
        if htype is not None {
            cg_visit_expr(c, htype);
            cg_addop(c, OP_CHECK_EG_MATCH, hloc);
            cg_addop_i(c, OP_COPY, 1, hloc);
            cg_addop_j(c, OP_POP_JUMP_IF_NONE, no_match, hloc);
        }
        cleanup_end = cg_new_label(c);
        cleanup_body = cg_new_label(c);
        hname = handler.name;
        if hname is not None {
            cg_nameop(c, hloc, hname, CG_STORE);
        } else {
            cg_addop(c, OP_POP_TOP, hloc);
        }
        cg_addop_j(c, OP_SETUP_CLEANUP, cleanup_end, hloc);
        cg_use_label(c, cleanup_body);
        cpy_compile_push_fblock(
            c, hloc, COMPILE_FBLOCK_HANDLER_CLEANUP, cleanup_body, NO_LABEL, None, hname
        );
        cg_visit_stmts(c, handler.body);
        cpy_compile_pop_fblock(c, COMPILE_FBLOCK_HANDLER_CLEANUP, cleanup_body);
        cg_addop(c, OP_POP_BLOCK, no_location());
        if hname is not None {
            cg_load_none(c, no_location());
            cg_nameop(c, no_location(), hname, CG_STORE);
            cg_nameop(c, no_location(), hname, CG_DEL);
        }
        cg_addop_j(c, OP_JUMP_NO_INTERRUPT, except_label, no_location());
        cg_use_label(c, cleanup_end);
        if hname is not None {
            cg_load_none(c, no_location());
            cg_nameop(c, no_location(), hname, CG_STORE);
            cg_nameop(c, no_location(), hname, CG_DEL);
        }
        cg_addop_i(c, OP_LIST_APPEND, 3, no_location());
        cg_addop(c, OP_POP_TOP, no_location());
        cg_addop_j(c, OP_JUMP_NO_INTERRUPT, except_with_error, no_location());
        cg_use_label(c, except_label);
        cg_addop(c, OP_NOP, no_location());
        cg_addop_j(c, OP_JUMP_NO_INTERRUPT, except_with_error, no_location());
        cg_use_label(c, no_match);
        cg_addop(c, OP_POP_TOP, hloc);
        cg_use_label(c, except_with_error);
        if i == n - 1 {
            cg_addop_i(c, OP_LIST_APPEND, 1, no_location());
            cg_addop_j(c, OP_JUMP_NO_INTERRUPT, reraise_star, no_location());
        }
        i += 1;
    }
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_EXCEPTION_GROUP_HANDLER, NO_LABEL);
    reraise = cg_new_label(c);
    cg_use_label(c, reraise_star);
    cg_addop_i(c, OP_CALL_INTRINSIC_2, INTRINSIC_PREP_RERAISE_STAR, no_location());
    cg_addop_i(c, OP_COPY, 1, no_location());
    cg_addop_j(c, OP_POP_JUMP_IF_NOT_NONE, reraise, no_location());
    cg_addop(c, OP_POP_TOP, no_location());
    cg_addop(c, OP_POP_BLOCK, no_location());
    cg_addop(c, OP_POP_EXCEPT, no_location());
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
    cg_use_label(c, reraise);
    cg_addop(c, OP_POP_BLOCK, no_location());
    cg_addop_i(c, OP_SWAP, 2, no_location());
    cg_addop(c, OP_POP_EXCEPT, no_location());
    cg_addop_i(c, OP_RERAISE, 0, no_location());
    cg_use_label(c, cleanup);
    cg_pop_except_and_reraise(c, no_location());
    cg_use_label(c, orelse);
    cg_visit_stmts(c, s.orelse);
    cg_use_label(c, end);
}

impl cg_try(c: cpy_compiler, s: Try) {
    if len(s.finalbody) {
        cg_try_finally(c, s);
    } else {
        cg_try_except(c, s);
    }
}

impl cg_try_star(c: cpy_compiler, s: TryStar) {
    if len(s.finalbody) {
        cg_try_star_finally(c, s);
    } else {
        cg_try_star_except(c, s);
    }
}

impl cg_import_as(c: cpy_compiler, loc: srcloc, name: str, asname: str) {
    dot = name.find(".");
    if dot != -1 {
        while True {
            pos = dot + 1;
            dot = name.find(".", pos);
            attr = name[pos:dot] if dot != -1 else name[pos:];
            cg_addop_n(c, loc, OP_IMPORT_FROM, CG_NAMES, attr);
            if dot == -1 {
                break;
            }
            cg_addop_i(c, OP_SWAP, 2, loc);
            cg_addop(c, OP_POP_TOP, loc);
        }
        cg_nameop(c, loc, asname, CG_STORE);
        cg_addop(c, OP_POP_TOP, loc);
        return;
    }
    cg_nameop(c, loc, asname, CG_STORE);
}

impl cg_import(c: cpy_compiler, s: Import) {
    loc = stmt_loc(s);
    for a in s.names {
        cg_load_int(c, 0, loc);
        cg_load_none(c, loc);
        cg_addop_name(c, loc, OP_IMPORT_NAME, CG_NAMES, a.name);
        asname = a.asname;
        if asname is not None {
            cg_import_as(c, loc, a.name, asname);
        } else {
            tmp = a.name;
            dot = tmp.find(".");
            if dot != -1 {
                tmp = tmp[:dot];
            }
            cg_nameop(c, loc, tmp, CG_STORE);
        }
    }
}

impl cg_from_import(c: cpy_compiler, s: ImportFrom) {
    loc = stmt_loc(s);
    n = len(s.names);
    cg_load_int(c, s.level if s.level is not None else 0, loc);
    items: list[PyObj] = [];
    for a in s.names {
        items.append(PyStr(t="str", val=a.name));
    }
    cg_load_const(c, PyTuple(t="tuple", items=items), loc);
    module = s.module;
    cg_addop_name(
        c, loc, OP_IMPORT_NAME, CG_NAMES, module if module is not None else ""
    );
    i = 0;
    while i < n {
        a = s.names[i];
        if i == 0 and a.name.startswith("*") {
            cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_IMPORT_STAR, loc);
            cg_addop(c, OP_POP_TOP, no_location());
            return;
        }
        cg_addop_name(c, loc, OP_IMPORT_FROM, CG_NAMES, a.name);
        store_name = a.name;
        asname = a.asname;
        if asname is not None {
            store_name = asname;
        }
        cg_nameop(c, loc, store_name, CG_STORE);
        i += 1;
    }
    cg_addop(c, OP_POP_TOP, loc);
}

impl cg_assert(c: cpy_compiler, s: Assert) {
    t = s.test;
    if (isinstance(t, Tuple) and len(t.elts) > 0)
        or (
            isinstance(t, Constant)
            and isinstance(t.value, PyTuple)
            and len(t.value.items) > 0
        ) {
        cpy_compile_warn(
            c, stmt_loc(s), "assertion is always true, perhaps remove parentheses?"
        );
    }
    if c.optimize {
        return;
    }
    end = cg_new_label(c);
    cg_jump_if(c, stmt_loc(s), t, end, True);
    cg_addop_i(c, OP_LOAD_COMMON_CONSTANT, CONSTANT_ASSERTIONERROR, stmt_loc(s));
    msg = s.msg;
    if msg is not None {
        cg_visit_expr(c, msg);
        cg_addop_i(c, OP_CALL, 0, stmt_loc(s));
    }
    cg_addop_i(c, OP_RAISE_VARARGS, 1, expr_loc(t));
    cg_use_label(c, end);
}

impl cg_stmt_expr(c: cpy_compiler, loc: srcloc, value: expr) {
    if cpy_compile_is_interactive_top_level(c) {
        cg_visit_expr(c, value);
        cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_PRINT, loc);
        cg_addop(c, OP_POP_TOP, no_location());
        return;
    }
    if isinstance(value, Constant) {
        cg_addop(c, OP_NOP, loc);
        return;
    }
    cg_visit_expr(c, value);
    cg_addop(c, OP_POP_TOP, no_location());
}

impl cg_visit_stmt(c: cpy_compiler, s: stmt) {
    if isinstance(s, Expr) {
        cg_stmt_expr(c, stmt_loc(s), s.value);
    } elif isinstance(s, Assign) {
        n = len(s.targets);
        cg_visit_expr(c, s.value);
        i = 0;
        while i < n {
            if i < n - 1 {
                cg_addop_i(c, OP_COPY, 1, stmt_loc(s));
            }
            cg_visit_expr(c, s.targets[i]);
            i += 1;
        }
    } elif isinstance(s, Return) {
        cg_return(c, s);
    } elif isinstance(s, If) {
        cg_unit_conditional(c, 1);
        cg_if(c, s);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, FunctionDef) {
        cg_function(c, s);
    } elif isinstance(s, ClassDef) {
        cg_class(c, s);
    } elif isinstance(s, ImportFrom) {
        cg_from_import(c, s);
    } elif isinstance(s, Import) {
        cg_import(c, s);
    } elif isinstance(s, AugAssign) {
        cg_augassign(c, s);
    } elif isinstance(s, For) {
        cg_unit_conditional(c, 1);
        cg_for(c, s);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, Raise) {
        n = 0;
        exc = s.exc;
        if exc is not None {
            cg_visit_expr(c, exc);
            n += 1;
            cause = s.cause;
            if cause is not None {
                cg_visit_expr(c, cause);
                n += 1;
            }
        }
        cg_addop_i(c, OP_RAISE_VARARGS, n, stmt_loc(s));
    } elif isinstance(s, Try) {
        cg_unit_conditional(c, 1);
        cg_try(c, s);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, AnnAssign) {
        cg_annassign(c, s);
    } elif isinstance(s, While) {
        cg_unit_conditional(c, 1);
        cg_while(c, s);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, With) {
        cg_unit_conditional(c, 1);
        cg_with_inner(c, s, 0);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, Pass) {
        cg_addop(c, OP_NOP, stmt_loc(s));
    } elif isinstance(s, Delete) {
        for target in s.targets {
            cg_visit_expr(c, target);
        }
    } elif isinstance(s, Assert) {
        cg_assert(c, s);
    } elif isinstance(s, Break) {
        cg_break(c, stmt_loc(s));
    } elif isinstance(s, Continue) {
        cg_continue(c, stmt_loc(s));
    } elif isinstance(s, Global) or isinstance(s, Nonlocal) {
        return;
    } elif isinstance(s, AsyncFunctionDef) {
        cg_async_function(c, s);
    } elif isinstance(s, Match) {
        cg_unit_conditional(c, 1);
        cg_match(c, s);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, TryStar) {
        cg_unit_conditional(c, 1);
        cg_try_star(c, s);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, AsyncWith) {
        cg_unit_conditional(c, 1);
        cg_async_with_inner(c, s, 0);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, AsyncFor) {
        cg_unit_conditional(c, 1);
        cg_async_for(c, s);
        cg_unit_conditional(c, -1);
    } elif isinstance(s, TypeAlias) {
        cg_typealias(c, s);
    }
}

impl cg_with_except_finish(c: cpy_compiler, cleanup: int) {
    suppress = cg_new_label(c);
    cg_addop(c, OP_TO_BOOL, no_location());
    cg_addop_j(c, OP_POP_JUMP_IF_TRUE, suppress, no_location());
    cg_addop_i(c, OP_RERAISE, 2, no_location());
    cg_use_label(c, suppress);
    cg_addop(c, OP_POP_TOP, no_location());
    cg_addop(c, OP_POP_BLOCK, no_location());
    cg_addop(c, OP_POP_EXCEPT, no_location());
    cg_addop(c, OP_POP_TOP, no_location());
    cg_addop(c, OP_POP_TOP, no_location());
    cg_addop(c, OP_POP_TOP, no_location());
    exit_label = cg_new_label(c);
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, exit_label, no_location());
    cg_use_label(c, cleanup);
    cg_pop_except_and_reraise(c, no_location());
    cg_use_label(c, exit_label);
}

impl cg_async_with_inner(c: cpy_compiler, s: AsyncWith, pos: int) {
    loc = stmt_loc(s);
    item = s.items[pos];
    block = cg_new_label(c);
    final = cg_new_label(c);
    exit_label = cg_new_label(c);
    cleanup = cg_new_label(c);
    cg_visit_expr(c, item.context_expr);
    loc = expr_loc(item.context_expr);
    cg_addop_i(c, OP_COPY, 1, loc);
    cg_addop_i(c, OP_LOAD_SPECIAL, SPECIAL___AEXIT__, loc);
    cg_addop_i(c, OP_SWAP, 2, loc);
    cg_addop_i(c, OP_SWAP, 3, loc);
    cg_addop_i(c, OP_LOAD_SPECIAL, SPECIAL___AENTER__, loc);
    cg_addop_i(c, OP_CALL, 0, loc);
    cg_addop_i(c, OP_GET_AWAITABLE, 1, loc);
    cg_load_none(c, loc);
    cg_add_yield_from(c, loc, True);
    cg_addop_j(c, OP_SETUP_WITH, final, loc);
    cg_use_label(c, block);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_ASYNC_WITH, block, final);
    optional_vars = item.optional_vars;
    if optional_vars is not None {
        cg_visit_expr(c, optional_vars);
    } else {
        cg_addop(c, OP_POP_TOP, loc);
    }
    pos += 1;
    if pos == len(s.items) {
        cg_visit_stmts(c, s.body);
    } else {
        cg_async_with_inner(c, s, pos);
    }
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_ASYNC_WITH, block);
    cg_addop(c, OP_POP_BLOCK, loc);
    cg_call_exit_with_nones(c, loc);
    cg_addop_i(c, OP_GET_AWAITABLE, 2, loc);
    cg_load_none(c, loc);
    cg_add_yield_from(c, loc, True);
    cg_addop(c, OP_POP_TOP, loc);
    cg_addop_j(c, OP_JUMP, exit_label, loc);
    cg_use_label(c, final);
    cg_addop_j(c, OP_SETUP_CLEANUP, cleanup, loc);
    cg_addop(c, OP_PUSH_EXC_INFO, loc);
    cg_addop(c, OP_WITH_EXCEPT_START, loc);
    cg_addop_i(c, OP_GET_AWAITABLE, 2, loc);
    cg_load_none(c, loc);
    cg_add_yield_from(c, loc, True);
    cg_with_except_finish(c, cleanup);
    cg_use_label(c, exit_label);
}

impl cg_with_inner(c: cpy_compiler, s: With, pos: int) {
    item = s.items[pos];
    block = cg_new_label(c);
    final = cg_new_label(c);
    exit_label = cg_new_label(c);
    cleanup = cg_new_label(c);
    cg_visit_expr(c, item.context_expr);
    loc = expr_loc(item.context_expr);
    cg_addop_i(c, OP_COPY, 1, loc);
    cg_addop_i(c, OP_LOAD_SPECIAL, SPECIAL___EXIT__, loc);
    cg_addop_i(c, OP_SWAP, 2, loc);
    cg_addop_i(c, OP_SWAP, 3, loc);
    cg_addop_i(c, OP_LOAD_SPECIAL, SPECIAL___ENTER__, loc);
    cg_addop_i(c, OP_CALL, 0, loc);
    cg_addop_j(c, OP_SETUP_WITH, final, loc);
    cg_use_label(c, block);
    cpy_compile_push_fblock(c, loc, COMPILE_FBLOCK_WITH, block, final);
    optional_vars = item.optional_vars;
    if optional_vars is not None {
        cg_visit_expr(c, optional_vars);
    } else {
        cg_addop(c, OP_POP_TOP, loc);
    }
    pos += 1;
    if pos == len(s.items) {
        cg_visit_stmts(c, s.body);
    } else {
        cg_with_inner(c, s, pos);
    }
    cg_addop(c, OP_POP_BLOCK, no_location());
    cpy_compile_pop_fblock(c, COMPILE_FBLOCK_WITH, block);
    cg_call_exit_with_nones(c, loc);
    cg_addop(c, OP_POP_TOP, loc);
    cg_addop_j(c, OP_JUMP, exit_label, loc);
    cg_use_label(c, final);
    cg_addop_j(c, OP_SETUP_CLEANUP, cleanup, loc);
    cg_addop(c, OP_PUSH_EXC_INFO, loc);
    cg_addop(c, OP_WITH_EXCEPT_START, loc);
    cg_with_except_finish(c, cleanup);
    cg_use_label(c, exit_label);
}

impl cg_unit_conditional(c: cpy_compiler, delta: int) {
    c.unit().in_conditional_block += delta;
}

impl cg_start_location(stmts: list[stmt]) -> srcloc {
    if len(stmts) > 0 {
        return stmt_loc(stmts[0]);
    }
    return mkloc(1, 1, 0, 0);
}

impl cg_compiler_codegen(c: cpy_compiler, m: mod) {
    cg_enter_scope(
        c, "<module>", COMPILE_SCOPE_MODULE, cpy_st_key(m), 1, None, 0, 0, 0
    );
    if isinstance(m, Module) {
        cg_module(c, cg_start_location(m.body), m.body, False);
    } elif isinstance(m, Interactive) {
        c.interactive = True;
        cg_module(c, cg_start_location(m.body), m.body, True);
    } elif isinstance(m, Expression) {
        cg_visit_expr(c, m.body);
    } else {
        raise SystemError("module kind should not be possible");
    }
}

impl cpy_ast_compile(m: mod, filename: str, flags: int, optimize: int) -> PyCode {
    features = cpy_future_from_ast(m, filename);
    merged = features | flags;
    tree = preprocess_node(m, optimize, merged, True);
    if isinstance(tree, mod) {
        m = tree;
    }
    if isinstance(m, Module) {
        cpy_control_flow_warnings(filename, m.body);
    } elif isinstance(m, Interactive) {
        cpy_control_flow_warnings(filename, m.body);
    }
    st = cpy_symtable_build(m, filename, merged);
    c = cpy_compiler(
        filename=filename,
        st=st,
        future_features=merged,
        flags=merged,
        optimize=optimize,
        stack=[]
    );
    cg_compiler_codegen(c, m);
    co = cpy_compile_optimize_and_assemble(c, not isinstance(m, Expression));
    cpy_compile_exit_scope(c);
    return co;
}
