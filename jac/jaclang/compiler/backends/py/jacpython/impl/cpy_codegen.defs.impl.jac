impl cg_kwonlydefaults(
    c: cpy_compiler, loc: srcloc, kwonlyargs: list[arg], kw_defaults: list[expr | None]
) -> bool {
    default_count = 0;
    i = 0;
    while i < len(kwonlyargs) {
        a = kwonlyargs[i];
        default_value = kw_defaults[i] if i < len(kw_defaults) else None;
        if default_value is not None {
            default_count += 1;
            mangled = cpy_compile_maybe_mangle(c, a.arg);
            cg_load_str(c, mangled, loc);
            cg_visit_expr(c, default_value);
        }
        i += 1;
    }
    if default_count {
        cg_addop_i(c, OP_BUILD_MAP, default_count, loc);
        return True;
    }
    return False;
}

impl cg_argannotation(
    c: cpy_compiler, name: str, annotation: expr | None, loc: srcloc
) -> int {
    if annotation is None {
        return 0;
    }
    mangled = cpy_compile_maybe_mangle(c, name);
    cg_load_str(c, mangled, loc);
    if c.future_features & CO_FUTURE_ANNOTATIONS {
        cg_load_str(c, render_annotation(annotation), expr_loc(annotation));
    } elif isinstance(annotation, Starred) {
        cg_visit_expr(c, annotation.value);
        cg_addop_i(c, OP_UNPACK_SEQUENCE, 1, loc);
    } else {
        cg_visit_expr(c, annotation);
    }
    return 1;
}

impl cg_argannotations(c: cpy_compiler, args: list[arg], loc: srcloc) -> int {
    count = 0;
    for a in args {
        count += cg_argannotation(c, a.arg, a.annotation, loc);
    }
    return count;
}

impl cg_annotations_in_scope(
    c: cpy_compiler, loc: srcloc, args: arguments, returns: expr | None
) -> int {
    count = cg_argannotations(c, args.args, loc);
    count += cg_argannotations(c, args.posonlyargs, loc);
    vararg = args.vararg;
    if vararg is not None and vararg.annotation is not None {
        count += cg_argannotation(c, vararg.arg, vararg.annotation, loc);
    }
    count += cg_argannotations(c, args.kwonlyargs, loc);
    kwarg = args.kwarg;
    if kwarg is not None and kwarg.annotation is not None {
        count += cg_argannotation(c, kwarg.arg, kwarg.annotation, loc);
    }
    count += cg_argannotation(c, "return", returns, loc);
    return count;
}

impl cg_function_annotations(
    c: cpy_compiler, loc: srcloc, args: arguments, returns: expr | None
) -> int {
    ste = cpy_symtable_lookup(c.st, cpy_st_key(args));
    if ste.annotations_used {
        cg_setup_annotations_scope(c, loc, cpy_st_key(args), ste.name);
        annotations_len = cg_annotations_in_scope(c, loc, args, returns);
        cg_addop_i(c, OP_BUILD_MAP, annotations_len, loc);
        cg_leave_annotations_scope(c, loc);
        return MAKE_FUNCTION_ANNOTATE;
    }
    return 0;
}

impl cg_default_arguments(c: cpy_compiler, loc: srcloc, args: arguments) -> int {
    funcflags = 0;
    if len(args.defaults) > 0 {
        for d in args.defaults {
            cg_visit_expr(c, d);
        }
        cg_addop_i(c, OP_BUILD_TUPLE, len(args.defaults), loc);
        funcflags |= MAKE_FUNCTION_DEFAULTS;
    }
    if cg_kwonlydefaults(c, loc, args.kwonlyargs, args.kw_defaults) {
        funcflags |= MAKE_FUNCTION_KWDEFAULTS;
    }
    return funcflags;
}

impl cg_wrap_in_stopiteration_handler(c: cpy_compiler) {
    handler = cg_new_label(c);
    c.unit().seq.insert_instruction(0, OP_SETUP_CLEANUP, handler, no_location());
    cg_load_none(c, no_location());
    cg_addop(c, OP_RETURN_VALUE, no_location());
    cg_use_label(c, handler);
    cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_STOPITERATION_ERROR, no_location());
    cg_addop_i(c, OP_RERAISE, 1, no_location());
}

impl cg_type_param_bound_or_default(
    c: cpy_compiler, e: expr, name: str, key: int, allow_starred: bool
) {
    loc = expr_loc(e);
    cg_load_const(c, PyTuple(t="tuple", items=[PyInt(t="int", val=1)]), loc);
    cg_setup_annotations_scope(c, loc, key, name);
    if allow_starred and isinstance(e, Starred) {
        cg_visit_expr(c, e.value);
        cg_addop_i(c, OP_UNPACK_SEQUENCE, 1, loc);
    } else {
        cg_visit_expr(c, e);
    }
    cg_addop(c, OP_RETURN_VALUE, loc);
    co = cpy_compile_optimize_and_assemble(c, True);
    cpy_compile_exit_scope(c);
    cg_make_closure(c, loc, co, MAKE_FUNCTION_DEFAULTS);
}

impl cg_type_params(c: cpy_compiler, type_params: list[type_param]) {
    n = len(type_params);
    seen_default = False;
    for tp in type_params {
        loc = type_param_loc(tp);
        if isinstance(tp, TypeVar) {
            cg_load_str(c, tp.name, loc);
            bound = tp.bound;
            if bound is not None {
                cg_type_param_bound_or_default(
                    c, bound, tp.name, cpy_st_key(tp), False
                );
                intrinsic = INTRINSIC_TYPEVAR_WITH_CONSTRAINTS
                    if isinstance(bound, Tuple)
                    else INTRINSIC_TYPEVAR_WITH_BOUND;
                cg_addop_i(c, OP_CALL_INTRINSIC_2, intrinsic, loc);
            } else {
                cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_TYPEVAR, loc);
            }
            default_value = tp.default_value;
            if default_value is not None {
                seen_default = True;
                cg_type_param_bound_or_default(
                    c, default_value, tp.name, cpy_st_key(tp, 1), False
                );
                cg_addop_i(
                    c, OP_CALL_INTRINSIC_2, INTRINSIC_SET_TYPEPARAM_DEFAULT, loc
                );
            } elif seen_default {
                cpy_compile_error(
                    c,
                    loc,
                    "non-default type parameter '"
                        + tp.name
                        + "' follows default type parameter"
                );
            }
            cg_addop_i(c, OP_COPY, 1, loc);
            cg_nameop(c, loc, tp.name, CG_STORE);
        } elif isinstance(tp, TypeVarTuple) {
            cg_load_str(c, tp.name, loc);
            cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_TYPEVARTUPLE, loc);
            default_value = tp.default_value;
            if default_value is not None {
                cg_type_param_bound_or_default(
                    c, default_value, tp.name, cpy_st_key(tp), True
                );
                cg_addop_i(
                    c, OP_CALL_INTRINSIC_2, INTRINSIC_SET_TYPEPARAM_DEFAULT, loc
                );
                seen_default = True;
            } elif seen_default {
                cpy_compile_error(
                    c,
                    loc,
                    "non-default type parameter '"
                        + tp.name
                        + "' follows default type parameter"
                );
            }
            cg_addop_i(c, OP_COPY, 1, loc);
            cg_nameop(c, loc, tp.name, CG_STORE);
        } elif isinstance(tp, ParamSpec) {
            cg_load_str(c, tp.name, loc);
            cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_PARAMSPEC, loc);
            default_value = tp.default_value;
            if default_value is not None {
                cg_type_param_bound_or_default(
                    c, default_value, tp.name, cpy_st_key(tp), False
                );
                cg_addop_i(
                    c, OP_CALL_INTRINSIC_2, INTRINSIC_SET_TYPEPARAM_DEFAULT, loc
                );
                seen_default = True;
            } elif seen_default {
                cpy_compile_error(
                    c,
                    loc,
                    "non-default type parameter '"
                        + tp.name
                        + "' follows default type parameter"
                );
            }
            cg_addop_i(c, OP_COPY, 1, loc);
            cg_nameop(c, loc, tp.name, CG_STORE);
        }
    }
    cg_addop_i(c, OP_BUILD_TUPLE, n, type_param_loc(type_params[0]));
}

impl cg_function_body(
    c: cpy_compiler,
    s: stmt,
    is_async: bool,
    name: str,
    args: arguments,
    body: list[stmt],
    funcflags: int,
    firstlineno: int
) {
    scope_type = COMPILE_SCOPE_ASYNC_FUNCTION if is_async else COMPILE_SCOPE_FUNCTION;
    cg_enter_scope(
        c,
        name,
        scope_type,
        cpy_st_key(s),
        firstlineno,
        None,
        len(args.args),
        len(args.posonlyargs),
        len(args.kwonlyargs)
    );
    ste = c.unit().ste;
    first_instr = 0;
    if ste.has_docstring {
        docstring = cpy_get_docstring(body);
        first_instr = 1;
        cleaned = cpy_clean_doc(docstring if docstring is not None else "");
        cpy_compile_add_const(c, PyStr(t="str", val=cleaned));
    }
    start = cg_new_label(c);
    cg_use_label(c, start);
    add_stopiteration_handler = ste.coroutine or ste.generator;
    if add_stopiteration_handler {
        cpy_compile_push_fblock(
            c, no_location(), COMPILE_FBLOCK_STOP_ITERATION, start, NO_LABEL
        );
    }
    i = first_instr;
    while i < len(body) {
        cg_visit_stmt(c, body[i]);
        i += 1;
    }
    if add_stopiteration_handler {
        cg_wrap_in_stopiteration_handler(c);
        cpy_compile_pop_fblock(c, COMPILE_FBLOCK_STOP_ITERATION, start);
    }
    co = cpy_compile_optimize_and_assemble(c, True);
    cpy_compile_exit_scope(c);
    cg_make_closure(c, stmt_loc(s), co, funcflags);
}

impl cg_function(c: cpy_compiler, s: FunctionDef) {
    cg_function_impl(
        c, s, False, s.args, s.returns, s.decorator_list, s.name, s.type_params, s.body
    );
}

impl cg_async_function(c: cpy_compiler, s: AsyncFunctionDef) {
    cg_function_impl(
        c, s, True, s.args, s.returns, s.decorator_list, s.name, s.type_params, s.body
    );
}

impl cg_function_impl(
    c: cpy_compiler,
    s: stmt,
    is_async: bool,
    args: arguments,
    returns: expr | None,
    decos: list[expr],
    name: str,
    type_params: list[type_param],
    body: list[stmt]
) {
    cg_decorators(c, decos);
    firstlineno = s.lineno;
    if len(decos) {
        firstlineno = decos[0].lineno;
    }
    loc = stmt_loc(s);
    is_generic = len(type_params) > 0;
    funcflags = cg_default_arguments(c, loc, args);
    num_typeparam_args = 0;
    if is_generic {
        if funcflags & MAKE_FUNCTION_DEFAULTS {
            num_typeparam_args += 1;
        }
        if funcflags & MAKE_FUNCTION_KWDEFAULTS {
            num_typeparam_args += 1;
        }
        if num_typeparam_args == 2 {
            cg_addop_i(c, OP_SWAP, 2, loc);
        }
        cg_enter_scope(
            c,
            "<generic parameters of " + name + ">",
            COMPILE_SCOPE_ANNOTATIONS,
            cpy_st_key(type_params),
            firstlineno,
            None,
            num_typeparam_args,
            0,
            0
        );
        cg_type_params(c, type_params);
        i = 0;
        while i < num_typeparam_args {
            cg_addop_i(c, OP_LOAD_FAST, i, loc);
            i += 1;
        }
    }
    funcflags |= cg_function_annotations(c, loc, args, returns);
    cg_function_body(c, s, is_async, name, args, body, funcflags, firstlineno);
    if is_generic {
        cg_addop_i(c, OP_SWAP, 2, loc);
        cg_addop_i(c, OP_CALL_INTRINSIC_2, INTRINSIC_SET_FUNCTION_TYPE_PARAMS, loc);
        co = cpy_compile_optimize_and_assemble(c, False);
        cpy_compile_exit_scope(c);
        cg_make_closure(c, loc, co, 0);
        if num_typeparam_args > 0 {
            cg_addop_i(c, OP_SWAP, num_typeparam_args + 1, loc);
            cg_addop_i(c, OP_CALL, num_typeparam_args - 1, loc);
        } else {
            cg_addop(c, OP_PUSH_NULL, loc);
            cg_addop_i(c, OP_CALL, 0, loc);
        }
    }
    cg_apply_decorators(c, decos);
    cg_nameop(c, loc, name, CG_STORE);
}

impl cg_set_type_params_in_class(c: cpy_compiler, loc: srcloc) {
    cg_nameop(c, loc, ".type_params", CG_LOAD);
    cg_nameop(c, loc, "__type_params__", CG_STORE);
}

impl cg_class_body(c: cpy_compiler, s: ClassDef, firstlineno: int) {
    cg_enter_scope(
        c, s.name, COMPILE_SCOPE_CLASS, cpy_st_key(s), firstlineno, s.name, 0, 0, 0
    );
    loc = mkloc(firstlineno, firstlineno, 0, 0);
    cg_nameop(c, loc, "__name__", CG_LOAD);
    cg_nameop(c, loc, "__module__", CG_STORE);
    cg_load_str(c, c.unit().md.qualname, loc);
    cg_nameop(c, loc, "__qualname__", CG_STORE);
    cg_load_int(c, c.unit().md.firstlineno, loc);
    cg_nameop(c, loc, "__firstlineno__", CG_STORE);
    if len(s.type_params) > 0 {
        cg_set_type_params_in_class(c, loc);
    }
    if c.unit().ste.needs_classdict {
        cg_addop(c, OP_LOAD_LOCALS, loc);
        cg_addop_n(c, loc, OP_STORE_DEREF, CG_CELLVARS, "__classdict__");
    }
    if c.unit().ste.has_conditional_annotations {
        cg_addop_i(c, OP_BUILD_SET, 0, loc);
        cg_addop_n(c, loc, OP_STORE_DEREF, CG_CELLVARS, "__conditional_annotations__");
    }
    cg_body(c, loc, s.body, False);
    static_attributes = cpy_compile_static_attributes(c);
    cg_load_const(c, static_attributes, no_location());
    cg_nameop(c, no_location(), "__static_attributes__", CG_STORE);
    if c.unit().ste.needs_classdict {
        i = cpy_compile_lookup_cellvar(c, "__classdict__");
        cg_addop_i(c, OP_LOAD_CLOSURE, i, no_location());
        cg_nameop(c, no_location(), "__classdictcell__", CG_STORE);
    }
    if c.unit().ste.needs_class_closure {
        i = cpy_compile_lookup_cellvar(c, "__class__");
        cg_addop_i(c, OP_LOAD_CLOSURE, i, no_location());
        cg_addop_i(c, OP_COPY, 1, no_location());
        cg_nameop(c, no_location(), "__classcell__", CG_STORE);
    } else {
        cg_load_none(c, no_location());
    }
    cg_addop(c, OP_RETURN_VALUE, no_location());
    co = cpy_compile_optimize_and_assemble(c, True);
    cpy_compile_exit_scope(c);
    loc = stmt_loc(s);
    cg_addop(c, OP_LOAD_BUILD_CLASS, loc);
    cg_addop(c, OP_PUSH_NULL, loc);
    cg_make_closure(c, loc, co, 0);
    cg_load_str(c, s.name, loc);
}

impl cg_class(c: cpy_compiler, s: ClassDef) {
    decos = s.decorator_list;
    cg_decorators(c, decos);
    firstlineno = s.lineno;
    if len(decos) {
        firstlineno = decos[0].lineno;
    }
    loc = stmt_loc(s);
    type_params = s.type_params;
    is_generic = len(type_params) > 0;
    if is_generic {
        cg_enter_scope(
            c,
            "<generic parameters of " + s.name + ">",
            COMPILE_SCOPE_ANNOTATIONS,
            cpy_st_key(type_params),
            firstlineno,
            s.name,
            0,
            0,
            0
        );
        cg_type_params(c, type_params);
        cg_nameop(c, loc, ".type_params", CG_STORE);
    }
    cg_class_body(c, s, firstlineno);
    if is_generic {
        cg_nameop(c, loc, ".type_params", CG_LOAD);
        cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_SUBSCRIPT_GENERIC, loc);
        cg_nameop(c, loc, ".generic_base", CG_STORE);
        cg_call_helper(c, loc, 2, s.bases, ".generic_base", s.keywords);
        co = cpy_compile_optimize_and_assemble(c, False);
        cpy_compile_exit_scope(c);
        cg_make_closure(c, loc, co, 0);
        cg_addop(c, OP_PUSH_NULL, loc);
        cg_addop_i(c, OP_CALL, 0, loc);
    } else {
        cg_call_helper(c, loc, 2, s.bases, None, s.keywords);
    }
    cg_apply_decorators(c, decos);
    cg_nameop(c, loc, s.name, CG_STORE);
}

impl cg_typealias_body(c: cpy_compiler, s: TypeAlias) {
    loc = stmt_loc(s);
    target = s.name;
    name = target.id if isinstance(target, Name) else "";
    cg_load_const(c, PyTuple(t="tuple", items=[PyInt(t="int", val=1)]), loc);
    cg_setup_annotations_scope(c, loc, cpy_st_key(s), name);
    cg_visit_expr(c, s.value);
    cg_addop(c, OP_RETURN_VALUE, loc);
    co = cpy_compile_optimize_and_assemble(c, False);
    cpy_compile_exit_scope(c);
    cg_make_closure(c, loc, co, MAKE_FUNCTION_DEFAULTS);
    cg_addop_i(c, OP_BUILD_TUPLE, 3, loc);
    cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_TYPEALIAS, loc);
}

impl cg_typealias(c: cpy_compiler, s: TypeAlias) {
    loc = stmt_loc(s);
    type_params = s.type_params;
    is_generic = len(type_params) > 0;
    target = s.name;
    name = target.id if isinstance(target, Name) else "";
    if is_generic {
        cg_enter_scope(
            c,
            "<generic parameters of " + name + ">",
            COMPILE_SCOPE_ANNOTATIONS,
            cpy_st_key(type_params),
            loc.lineno,
            None,
            0,
            0,
            0
        );
        cg_load_str(c, name, loc);
        cg_type_params(c, type_params);
    } else {
        cg_load_str(c, name, loc);
        cg_load_none(c, loc);
    }
    cg_typealias_body(c, s);
    if is_generic {
        co = cpy_compile_optimize_and_assemble(c, False);
        cpy_compile_exit_scope(c);
        cg_make_closure(c, loc, co, 0);
        cg_addop(c, OP_PUSH_NULL, loc);
        cg_addop_i(c, OP_CALL, 0, loc);
    }
    cg_nameop(c, loc, name, CG_STORE);
}

impl cg_lambda(c: cpy_compiler, e: Lambda) {
    args = e.args;
    loc = expr_loc(e);
    funcflags = cg_default_arguments(c, loc, args);
    cg_enter_scope(
        c,
        "<lambda>",
        COMPILE_SCOPE_LAMBDA,
        cpy_st_key(e),
        e.lineno,
        None,
        len(args.args),
        len(args.posonlyargs),
        len(args.kwonlyargs)
    );
    cg_visit_expr(c, e.body);
    co: PyCode | None = None;
    if c.unit().ste.generator {
        co = cpy_compile_optimize_and_assemble(c, False);
    } else {
        cg_addop(c, OP_RETURN_VALUE, expr_loc(e.body));
        co = cpy_compile_optimize_and_assemble(c, True);
    }
    cpy_compile_exit_scope(c);
    if co is not None {
        cg_make_closure(c, loc, co, funcflags);
    }
}
