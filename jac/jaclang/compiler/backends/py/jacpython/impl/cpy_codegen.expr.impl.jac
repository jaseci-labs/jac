impl cg_ctx(ctx: expr_context) -> int {
    if isinstance(ctx, Store) {
        return CG_STORE;
    }
    if isinstance(ctx, Del) {
        return CG_DEL;
    }
    return CG_LOAD;
}

impl cg_is_const_tuple(elts: list[expr]) -> bool {
    for e in elts {
        if not isinstance(e, Constant) {
            return False;
        }
    }
    return True;
}

impl cg_check_is_arg(e: expr) -> bool {
    if isinstance(e, Tuple) {
        return not cg_is_const_tuple(e.elts);
    }
    if not isinstance(e, Constant) {
        return True;
    }
    value = e.value;
    return isinstance(value, PyNoneType)
        or isinstance(value, PyBool)
        or isinstance(value, PyEllipsis);
}

impl cg_const_type_name(value: PyObj) -> str {
    if isinstance(value, PyNoneType) {
        return "NoneType";
    }
    if isinstance(value, PyEllipsis) {
        return "ellipsis";
    }
    if isinstance(value, PyBool) {
        return "bool";
    }
    if isinstance(value, PyInt) or isinstance(value, PyBigInt) {
        return "int";
    }
    if isinstance(value, PyFloat) {
        return "float";
    }
    if isinstance(value, PyComplex) {
        return "complex";
    }
    if isinstance(value, PyStr) {
        return "str";
    }
    if isinstance(value, PyBytes) {
        return "bytes";
    }
    if isinstance(value, PyTuple) {
        return "tuple";
    }
    if isinstance(value, PySet) {
        return "frozenset" if value.frozen else "set";
    }
    return value.t;
}

impl cg_infer_type(e: expr) -> str | None {
    if isinstance(e, Tuple) {
        return "tuple";
    }
    if isinstance(e, List) or isinstance(e, ListComp) {
        return "list";
    }
    if isinstance(e, Dict) or isinstance(e, DictComp) {
        return "dict";
    }
    if isinstance(e, Set) or isinstance(e, SetComp) {
        return "set";
    }
    if isinstance(e, GeneratorExp) {
        return "generator";
    }
    if isinstance(e, Lambda) {
        return "function";
    }
    if isinstance(e, TemplateStr) or isinstance(e, Interpolation) {
        return "string.templatelib.Template";
    }
    if isinstance(e, JoinedStr) or isinstance(e, FormattedValue) {
        return "str";
    }
    if isinstance(e, Constant) {
        return cg_const_type_name(e.value);
    }
    return None;
}

impl cg_check_compare(c: cpy_compiler, e: Compare) {
    left = cg_check_is_arg(e.left);
    left_expr = e.left;
    n = len(e.ops);
    i = 0;
    while i < n {
        op = e.ops[i];
        right_expr = e.comparators[i];
        right = cg_check_is_arg(right_expr);
        if isinstance(op, Is) or isinstance(op, IsNot) {
            if not right or not left {
                literal = left_expr if not left else right_expr;
                tname = cg_infer_type(literal);
                tn: str = "object";
                if tname is not None {
                    tn = tname;
                }
                if isinstance(op, Is) {
                    cpy_compile_warn(
                        c,
                        expr_loc(e),
                        "\"is\" with '" + tn + "' literal. Did you mean \"==\"?"
                    );
                } else {
                    cpy_compile_warn(
                        c,
                        expr_loc(e),
                        "\"is not\" with '" + tn + "' literal. Did you mean \"!=\"?"
                    );
                }
                return;
            }
        }
        left = right;
        left_expr = right_expr;
        i += 1;
    }
}

impl cg_addcompare(c: cpy_compiler, loc: srcloc, op: cmpop) {
    cmp = 0;
    if isinstance(op, Eq) {
        cmp = CMP_EQ;
    } elif isinstance(op, NotEq) {
        cmp = CMP_NE;
    } elif isinstance(op, Lt) {
        cmp = CMP_LT;
    } elif isinstance(op, LtE) {
        cmp = CMP_LE;
    } elif isinstance(op, Gt) {
        cmp = CMP_GT;
    } elif isinstance(op, GtE) {
        cmp = CMP_GE;
    } elif isinstance(op, Is) {
        cg_addop_i(c, OP_IS_OP, 0, loc);
        return;
    } elif isinstance(op, IsNot) {
        cg_addop_i(c, OP_IS_OP, 1, loc);
        return;
    } elif isinstance(op, In) {
        cg_addop_i(c, OP_CONTAINS_OP, 0, loc);
        return;
    } elif isinstance(op, NotIn) {
        cg_addop_i(c, OP_CONTAINS_OP, 1, loc);
        return;
    }
    cg_addop_i(c, OP_COMPARE_OP, compare_oparg(cmp), loc);
}

impl cg_jump_if(c: cpy_compiler, loc: srcloc, e: expr, next: int, cond: bool) {
    if isinstance(e, UnaryOp) and isinstance(e.op, Not) {
        cg_jump_if(c, loc, e.operand, next, not cond);
        return;
    }
    if isinstance(e, BoolOp) {
        s = e.values;
        n = len(s) - 1;
        cond2 = isinstance(e.op, Or);
        next2 = next;
        if cond2 != cond {
            next2 = cg_new_label(c);
        }
        i = 0;
        while i < n {
            cg_jump_if(c, loc, s[i], next2, cond2);
            i += 1;
        }
        cg_jump_if(c, loc, s[n], next, cond);
        if next2 != next {
            cg_use_label(c, next2);
        }
        return;
    }
    if isinstance(e, IfExp) {
        end = cg_new_label(c);
        next2 = cg_new_label(c);
        cg_jump_if(c, loc, e.test, next2, False);
        cg_jump_if(c, loc, e.body, next, cond);
        cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
        cg_use_label(c, next2);
        cg_jump_if(c, loc, e.orelse, next, cond);
        cg_use_label(c, end);
        return;
    }
    if isinstance(e, Compare) {
        n = len(e.ops) - 1;
        if n > 0 {
            cg_check_compare(c, e);
            cleanup = cg_new_label(c);
            cg_visit_expr(c, e.left);
            eloc = expr_loc(e);
            i = 0;
            while i < n {
                cg_visit_expr(c, e.comparators[i]);
                cg_addop_i(c, OP_SWAP, 2, eloc);
                cg_addop_i(c, OP_COPY, 2, eloc);
                cg_addcompare(c, eloc, e.ops[i]);
                cg_addop(c, OP_TO_BOOL, eloc);
                cg_addop_j(c, OP_POP_JUMP_IF_FALSE, cleanup, eloc);
                i += 1;
            }
            cg_visit_expr(c, e.comparators[n]);
            cg_addcompare(c, eloc, e.ops[n]);
            cg_addop(c, OP_TO_BOOL, eloc);
            cg_addop_j(
                c, OP_POP_JUMP_IF_TRUE if cond else OP_POP_JUMP_IF_FALSE, next, eloc
            );
            end = cg_new_label(c);
            cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
            cg_use_label(c, cleanup);
            cg_addop(c, OP_POP_TOP, eloc);
            if not cond {
                cg_addop_j(c, OP_JUMP_NO_INTERRUPT, next, no_location());
            }
            cg_use_label(c, end);
            return;
        }
    }
    cg_visit_expr(c, e);
    eloc = expr_loc(e);
    cg_addop(c, OP_TO_BOOL, eloc);
    cg_addop_j(c, OP_POP_JUMP_IF_TRUE if cond else OP_POP_JUMP_IF_FALSE, next, eloc);
}

impl cg_ifexp(c: cpy_compiler, e: IfExp) {
    end = cg_new_label(c);
    next = cg_new_label(c);
    cg_jump_if(c, expr_loc(e), e.test, next, False);
    cg_visit_expr(c, e.body);
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
    cg_use_label(c, next);
    cg_visit_expr(c, e.orelse);
    cg_use_label(c, end);
}

impl cg_addop_yield(c: cpy_compiler, loc: srcloc) {
    ste = c.unit().ste;
    if ste.generator and ste.coroutine {
        cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_ASYNC_GEN_WRAP, loc);
    }
    cg_addop_i(c, OP_YIELD_VALUE, 0, loc);
    cg_addop_i(c, OP_RESUME, RESUME_AFTER_YIELD, loc);
}

impl cg_load_classdict_freevar(c: cpy_compiler, loc: srcloc) {
    cg_addop_n(c, loc, OP_LOAD_DEREF, CG_FREEVARS, "__classdict__");
}

impl cg_nameop(c: cpy_compiler, loc: srcloc, name: str, ctx: int) {
    mangled = cpy_compile_maybe_mangle(c, name);
    u = c.unit();
    ste = u.ste;
    scope = cpy_st_get_scope(ste, mangled);
    (optype, arg) = cpy_compile_resolve_nameop(c, mangled, scope);
    op = 0;
    if optype == COMPILE_OP_DEREF {
        if ctx == CG_LOAD {
            if ste.ste_type == ClassBlock and not u.in_inlined_comp {
                op = OP_LOAD_FROM_DICT_OR_DEREF;
                cg_addop(c, OP_LOAD_LOCALS, loc);
            } elif ste.can_see_class_scope {
                op = OP_LOAD_FROM_DICT_OR_DEREF;
                cg_load_classdict_freevar(c, loc);
            } else {
                op = OP_LOAD_DEREF;
            }
        } elif ctx == CG_STORE {
            op = OP_STORE_DEREF;
        } else {
            op = OP_DELETE_DEREF;
        }
    } elif optype == COMPILE_OP_FAST {
        if ctx == CG_LOAD {
            op = OP_LOAD_FAST;
        } elif ctx == CG_STORE {
            op = OP_STORE_FAST;
        } else {
            op = OP_DELETE_FAST;
        }
        cg_addop_n(c, loc, op, CG_VARNAMES, mangled);
        return;
    } elif optype == COMPILE_OP_GLOBAL {
        if ctx == CG_LOAD {
            if ste.can_see_class_scope and scope == ST_GLOBAL_IMPLICIT {
                op = OP_LOAD_FROM_DICT_OR_GLOBALS;
                cg_load_classdict_freevar(c, loc);
            } else {
                op = OP_LOAD_GLOBAL;
            }
        } elif ctx == CG_STORE {
            op = OP_STORE_GLOBAL;
        } else {
            op = OP_DELETE_GLOBAL;
        }
    } else {
        if ctx == CG_LOAD {
            op = OP_LOAD_GLOBAL
                if ste.ste_type == ClassBlock and u.in_inlined_comp
                else OP_LOAD_NAME;
        } elif ctx == CG_STORE {
            op = OP_STORE_NAME;
        } else {
            op = OP_DELETE_NAME;
        }
    }
    if op == OP_LOAD_GLOBAL {
        arg = arg << 1;
    }
    cg_addop_i(c, op, arg, loc);
}

impl cg_boolop(c: cpy_compiler, e: BoolOp) {
    loc = expr_loc(e);
    jumpi = OP_JUMP_IF_FALSE if isinstance(e.op, And) else OP_JUMP_IF_TRUE;
    end = cg_new_label(c);
    s = e.values;
    n = len(s) - 1;
    i = 0;
    while i < n {
        cg_visit_expr(c, s[i]);
        cg_addop_j(c, jumpi, end, loc);
        cg_addop(c, OP_POP_TOP, loc);
        i += 1;
    }
    cg_visit_expr(c, s[n]);
    cg_use_label(c, end);
}

impl cg_starunpack_helper(
    c: cpy_compiler,
    loc: srcloc,
    elts: list[expr],
    injected_arg: str | None,
    pushed: int,
    build: int,
    add: int,
    extend: int,
    tuple_: bool
) {
    n = len(elts);
    big = n + pushed + (1 if injected_arg is not None else 0) > STACK_USE_GUIDELINE;
    seen_star = False;
    for elt in elts {
        if isinstance(elt, Starred) {
            seen_star = True;
            break;
        }
    }
    if not seen_star and not big {
        for elt in elts {
            cg_visit_expr(c, elt);
        }
        if injected_arg is not None {
            cg_nameop(c, loc, injected_arg, CG_LOAD);
            n += 1;
        }
        if tuple_ {
            cg_addop_i(c, OP_BUILD_TUPLE, n + pushed, loc);
        } else {
            cg_addop_i(c, build, n + pushed, loc);
        }
        return;
    }
    sequence_built = False;
    if big {
        cg_addop_i(c, build, pushed, loc);
        sequence_built = True;
    }
    i = 0;
    while i < n {
        elt = elts[i];
        if isinstance(elt, Starred) {
            if not sequence_built {
                cg_addop_i(c, build, i + pushed, loc);
                sequence_built = True;
            }
            cg_visit_expr(c, elt.value);
            cg_addop_i(c, extend, 1, loc);
        } else {
            cg_visit_expr(c, elt);
            if sequence_built {
                cg_addop_i(c, add, 1, loc);
            }
        }
        i += 1;
    }
    if injected_arg is not None {
        cg_nameop(c, loc, injected_arg, CG_LOAD);
        cg_addop_i(c, add, 1, loc);
    }
    if tuple_ {
        cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_LIST_TO_TUPLE, loc);
    }
}

impl cg_unpack_helper(c: cpy_compiler, loc: srcloc, elts: list[expr]) {
    n = len(elts);
    seen_star = False;
    i = 0;
    while i < n {
        elt = elts[i];
        if isinstance(elt, Starred) and not seen_star {
            if i >= (1 << 8) or n - i - 1 >= (2147483647 >> 8) {
                cpy_compile_error(
                    c, loc, "too many expressions in star-unpacking assignment"
                );
            }
            cg_addop_i(c, OP_UNPACK_EX, i + ((n - i - 1) << 8), loc);
            seen_star = True;
        } elif isinstance(elt, Starred) {
            cpy_compile_error(c, loc, "multiple starred expressions in assignment");
        }
        i += 1;
    }
    if not seen_star {
        cg_addop_i(c, OP_UNPACK_SEQUENCE, n, loc);
    }
}

impl cg_assignment_helper(c: cpy_compiler, loc: srcloc, elts: list[expr]) {
    cg_unpack_helper(c, loc, elts);
    for elt in elts {
        if isinstance(elt, Starred) {
            cg_visit_expr(c, elt.value);
        } else {
            cg_visit_expr(c, elt);
        }
    }
}

impl cg_list(c: cpy_compiler, e: List) {
    loc = expr_loc(e);
    ctx = cg_ctx(e.ctx);
    if ctx == CG_STORE {
        cg_assignment_helper(c, loc, e.elts);
    } elif ctx == CG_LOAD {
        cg_starunpack_helper(
            c,
            loc,
            e.elts,
            None,
            0,
            OP_BUILD_LIST,
            OP_LIST_APPEND,
            OP_LIST_EXTEND,
            False
        );
    } else {
        for elt in e.elts {
            cg_visit_expr(c, elt);
        }
    }
}

impl cg_tuple(c: cpy_compiler, e: Tuple) {
    loc = expr_loc(e);
    ctx = cg_ctx(e.ctx);
    if ctx == CG_STORE {
        cg_assignment_helper(c, loc, e.elts);
    } elif ctx == CG_LOAD {
        cg_starunpack_helper(
            c, loc, e.elts, None, 0, OP_BUILD_LIST, OP_LIST_APPEND, OP_LIST_EXTEND, True
        );
    } else {
        for elt in e.elts {
            cg_visit_expr(c, elt);
        }
    }
}

impl cg_set(c: cpy_compiler, e: Set) {
    cg_starunpack_helper(
        c, expr_loc(e), e.elts, None, 0, OP_BUILD_SET, OP_SET_ADD, OP_SET_UPDATE, False
    );
}

impl cg_subdict(c: cpy_compiler, e: Dict, begin: int, end: int) {
    n = end - begin;
    big = n * 2 > STACK_USE_GUIDELINE;
    loc = expr_loc(e);
    if big {
        cg_addop_i(c, OP_BUILD_MAP, 0, loc);
    }
    i = begin;
    while i < end {
        key = e.keys[i];
        if key is not None {
            cg_visit_expr(c, key);
        }
        cg_visit_expr(c, e.values[i]);
        if big {
            cg_addop_i(c, OP_MAP_ADD, 1, loc);
        }
        i += 1;
    }
    if not big {
        cg_addop_i(c, OP_BUILD_MAP, n, loc);
    }
}

impl cg_dict(c: cpy_compiler, e: Dict) {
    loc = expr_loc(e);
    n = len(e.values);
    have_dict = False;
    elements = 0;
    i = 0;
    while i < n {
        is_unpacking = e.keys[i] is None;
        if is_unpacking {
            if elements {
                cg_subdict(c, e, i - elements, i);
                if have_dict {
                    cg_addop_i(c, OP_DICT_UPDATE, 1, loc);
                }
                have_dict = True;
                elements = 0;
            }
            if not have_dict {
                cg_addop_i(c, OP_BUILD_MAP, 0, loc);
                have_dict = True;
            }
            cg_visit_expr(c, e.values[i]);
            cg_addop_i(c, OP_DICT_UPDATE, 1, loc);
        } else {
            if elements * 2 > STACK_USE_GUIDELINE {
                cg_subdict(c, e, i - elements, i + 1);
                if have_dict {
                    cg_addop_i(c, OP_DICT_UPDATE, 1, loc);
                }
                have_dict = True;
                elements = 0;
            } else {
                elements += 1;
            }
        }
        i += 1;
    }
    if elements {
        cg_subdict(c, e, n - elements, n);
        if have_dict {
            cg_addop_i(c, OP_DICT_UPDATE, 1, loc);
        }
        have_dict = True;
    }
    if not have_dict {
        cg_addop_i(c, OP_BUILD_MAP, 0, loc);
    }
}

impl cg_compare(c: cpy_compiler, e: Compare) {
    loc = expr_loc(e);
    cg_check_compare(c, e);
    cg_visit_expr(c, e.left);
    n = len(e.ops) - 1;
    if n == 0 {
        cg_visit_expr(c, e.comparators[0]);
        cg_addcompare(c, loc, e.ops[0]);
        return;
    }
    cleanup = cg_new_label(c);
    i = 0;
    while i < n {
        cg_visit_expr(c, e.comparators[i]);
        cg_addop_i(c, OP_SWAP, 2, loc);
        cg_addop_i(c, OP_COPY, 2, loc);
        cg_addcompare(c, loc, e.ops[i]);
        cg_addop_i(c, OP_COPY, 1, loc);
        cg_addop(c, OP_TO_BOOL, loc);
        cg_addop_j(c, OP_POP_JUMP_IF_FALSE, cleanup, loc);
        cg_addop(c, OP_POP_TOP, loc);
        i += 1;
    }
    cg_visit_expr(c, e.comparators[n]);
    cg_addcompare(c, loc, e.ops[n]);
    end = cg_new_label(c);
    cg_addop_j(c, OP_JUMP_NO_INTERRUPT, end, no_location());
    cg_use_label(c, cleanup);
    cg_addop_i(c, OP_SWAP, 2, loc);
    cg_addop(c, OP_POP_TOP, loc);
    cg_use_label(c, end);
}

impl cg_check_caller(c: cpy_compiler, e: expr) {
    if isinstance(e, Constant)
        or isinstance(e, Tuple)
        or isinstance(e, List)
        or isinstance(e, ListComp)
        or isinstance(e, Dict)
        or isinstance(e, DictComp)
        or isinstance(e, Set)
        or isinstance(e, SetComp)
        or isinstance(e, GeneratorExp)
        or isinstance(e, JoinedStr)
        or isinstance(e, TemplateStr)
        or isinstance(e, FormattedValue)
        or isinstance(e, Interpolation) {
        tname = cg_infer_type(e);
        cpy_compile_warn(
            c,
            expr_loc(e),
            "'"
                + (tname if tname is not None else "object")
                + "' object is not callable; perhaps you missed a comma?"
        );
    }
}

impl cg_check_subscripter(c: cpy_compiler, e: expr) {
    if isinstance(e, Constant) {
        v = e.value;
        if not (
            isinstance(v, PyNoneType)
            or isinstance(v, PyEllipsis)
            or isinstance(v, PyInt)
            or isinstance(v, PyBigInt)
            or isinstance(v, PyBool)
            or isinstance(v, PyFloat)
            or isinstance(v, PyComplex)
            or isinstance(v, PySet)
        ) {
            return;
        }
    } elif not (
        isinstance(e, Set)
        or isinstance(e, SetComp)
        or isinstance(e, GeneratorExp)
        or isinstance(e, TemplateStr)
        or isinstance(e, Interpolation)
        or isinstance(e, Lambda)
    ) {
        return;
    }
    tname = cg_infer_type(e);
    cpy_compile_warn(
        c,
        expr_loc(e),
        "'"
            + (tname if tname is not None else "object")
            + "' object is not subscriptable; perhaps you missed a comma?"
    );
}

impl cg_check_index(c: cpy_compiler, e: expr, s: expr) {
    inferred = cg_infer_type(s);
    if inferred is None {
        return;
    }
    index_type: str = inferred;
    if index_type == "int" or index_type == "bool" {
        return;
    }
    if isinstance(e, Constant) {
        v = e.value;
        if not (
            isinstance(v, PyStr) or isinstance(v, PyBytes) or isinstance(v, PyTuple)
        ) {
            return;
        }
    } elif not (
        isinstance(e, Tuple)
        or isinstance(e, List)
        or isinstance(e, ListComp)
        or isinstance(e, JoinedStr)
        or isinstance(e, FormattedValue)
    ) {
        return;
    }
    tname = cg_infer_type(e);
    cpy_compile_warn(
        c,
        expr_loc(e),
        (tname if tname is not None else "object")
            + " indices must be integers or slices, not "
            + index_type
            + "; perhaps you missed a comma?"
    );
}

impl cg_is_import_originated(c: cpy_compiler, e: expr) -> bool {
    if not isinstance(e, Name) {
        return False;
    }
    top = c.st.top;
    if top is None {
        return False;
    }
    flags = cpy_st_get_symbol(top, e.id);
    return (flags & ST_DEF_IMPORT) != 0;
}

impl cg_can_optimize_super_call(c: cpy_compiler, attr: Attribute) -> bool {
    e = attr.value;
    if not isinstance(e, Call) {
        return False;
    }
    func = e.func;
    if not isinstance(func, Name)
        or func.id != "super"
        or attr.attr == "__class__"
        or len(e.keywords) != 0 {
        return False;
    }
    num_args = len(e.args);
    super_name = func.id;
    u = c.unit();
    scope = cpy_st_get_scope(u.ste, super_name);
    if scope != ST_GLOBAL_IMPLICIT {
        return False;
    }
    top = c.st.top;
    if top is not None and cpy_st_get_scope(top, super_name) != 0 {
        return False;
    }
    if num_args == 2 {
        for elt in e.args {
            if isinstance(elt, Starred) {
                return False;
            }
        }
        return True;
    }
    if num_args != 0 {
        return False;
    }
    if u.md.argcount == 0 and u.md.posonlyargcount == 0 {
        return False;
    }
    if cpy_compile_get_ref_type(c, "__class__") == ST_FREE {
        return True;
    }
    return False;
}

impl cg_load_args_for_super(c: cpy_compiler, e: Call) {
    loc = expr_loc(e);
    func = e.func;
    if isinstance(func, Name) {
        cg_nameop(c, expr_loc(func), func.id, CG_LOAD);
    }
    if len(e.args) == 2 {
        cg_visit_expr(c, e.args[0]);
        cg_visit_expr(c, e.args[1]);
        return;
    }
    cg_nameop(c, loc, "__class__", CG_LOAD);
    md = c.unit().md;
    if len(md.varnames) == 0 {
        raise SystemError("no first argument for super()");
    }
    cg_nameop(c, loc, md.varnames[0], CG_LOAD);
}

impl cg_update_start_location_to_match_attr(
    c: cpy_compiler, loc: srcloc, attr: Attribute
) -> srcloc {
    attr_end_lineno = attr.end_lineno if attr.end_lineno is not None else attr.lineno;
    attr_end_col = attr.end_col_offset
        if attr.end_col_offset is not None
        else attr.col_offset;
    if loc.lineno != attr_end_lineno {
        lineno = attr_end_lineno;
        col_offset = loc.col_offset;
        end_col_offset = loc.end_col_offset;
        alen = len(attr.attr);
        if alen <= attr_end_col {
            col_offset = attr_end_col - alen;
        } else {
            col_offset = -1;
            end_col_offset = -1;
        }
        end_lineno = max(lineno, loc.end_lineno);
        if lineno == end_lineno {
            end_col_offset = max(col_offset, end_col_offset);
        }
        return mkloc(lineno, end_lineno, col_offset, end_col_offset);
    }
    return loc;
}

impl cg_maybe_optimize_function_call(c: cpy_compiler, e: Call, end: int) -> bool {
    args = e.args;
    func = e.func;
    if not (
        isinstance(func, Name)
        and len(args) == 1
        and len(e.keywords) == 0
        and isinstance(args[0], GeneratorExp)
    ) {
        return False;
    }
    generator_exp = args[0];
    generator_entry = cpy_symtable_lookup(c.st, cpy_st_key(generator_exp));
    if generator_entry.coroutine {
        return False;
    }
    loc = expr_loc(func);
    optimized = False;
    skip_optimization = cg_new_label(c);
    const_oparg = -1;
    initial_res: PyObj | None = None;
    continue_jump_opcode = -1;
    fname = func.id if isinstance(func, Name) else "";
    if fname == "all" {
        const_oparg = CONSTANT_BUILTIN_ALL;
        initial_res = PyBool(t="bool", val=True);
        continue_jump_opcode = OP_POP_JUMP_IF_TRUE;
    } elif fname == "any" {
        const_oparg = CONSTANT_BUILTIN_ANY;
        initial_res = PyBool(t="bool", val=False);
        continue_jump_opcode = OP_POP_JUMP_IF_FALSE;
    } elif fname == "tuple" {
        const_oparg = CONSTANT_BUILTIN_TUPLE;
    }
    if const_oparg != -1 {
        cg_addop_i(c, OP_COPY, 1, loc);
        cg_addop_i(c, OP_LOAD_COMMON_CONSTANT, const_oparg, loc);
        cg_addop_i(c, OP_IS_OP, 0, loc);
        cg_addop_j(c, OP_POP_JUMP_IF_FALSE, skip_optimization, loc);
        cg_addop(c, OP_POP_TOP, loc);
        if const_oparg == CONSTANT_BUILTIN_TUPLE {
            cg_addop_i(c, OP_BUILD_LIST, 0, loc);
        }
        cg_visit_expr(c, generator_exp);
        loop = cg_new_label(c);
        cleanup = cg_new_label(c);
        cg_use_label(c, loop);
        cg_addop_j(c, OP_FOR_ITER, cleanup, loc);
        if const_oparg == CONSTANT_BUILTIN_TUPLE {
            cg_addop_i(c, OP_LIST_APPEND, 2, loc);
            cg_addop_j(c, OP_JUMP, loop, loc);
        } else {
            cg_addop(c, OP_TO_BOOL, loc);
            cg_addop_j(c, continue_jump_opcode, loop, loc);
        }
        cg_addop(c, OP_POP_ITER, no_location());
        if const_oparg != CONSTANT_BUILTIN_TUPLE {
            cg_load_const(
                c, PyBool(t="bool", val=const_oparg != CONSTANT_BUILTIN_ALL), loc
            );
        }
        cg_addop_j(c, OP_JUMP, end, loc);
        cg_use_label(c, cleanup);
        cg_addop(c, OP_END_FOR, no_location());
        cg_addop(c, OP_POP_ITER, no_location());
        if const_oparg == CONSTANT_BUILTIN_TUPLE {
            cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_LIST_TO_TUPLE, loc);
        } elif initial_res is not None {
            cg_load_const(c, initial_res, loc);
        }
        optimized = True;
        cg_addop_j(c, OP_JUMP, end, loc);
    }
    cg_use_label(c, skip_optimization);
    return optimized;
}

impl cg_maybe_optimize_method_call(c: cpy_compiler, e: Call) -> bool {
    meth = e.func;
    args = e.args;
    kwds = e.keywords;
    if not isinstance(meth, Attribute) or not isinstance(meth.ctx, Load) {
        return False;
    }
    if cg_is_import_originated(c, meth.value) {
        return False;
    }
    argsl = len(args);
    kwdsl = len(kwds);
    if argsl + kwdsl + (1 if kwdsl != 0 else 0) >= STACK_USE_GUIDELINE {
        return False;
    }
    for elt in args {
        if isinstance(elt, Starred) {
            return False;
        }
    }
    for kw in kwds {
        if kw.arg is None {
            return False;
        }
    }
    loc = expr_loc(meth);
    value = meth.value;
    if cg_can_optimize_super_call(c, meth) and isinstance(value, Call) {
        cg_load_args_for_super(c, value);
        opcode = CG_LOAD_SUPER_METHOD if len(value.args) else CG_LOAD_ZERO_SUPER_METHOD;
        cg_addop_name(c, loc, opcode, CG_NAMES, meth.attr);
        loc = cg_update_start_location_to_match_attr(c, loc, meth);
        cg_addop(c, OP_NOP, loc);
    } else {
        cg_visit_expr(c, value);
        loc = cg_update_start_location_to_match_attr(c, loc, meth);
        cg_addop_name(c, loc, CG_LOAD_METHOD, CG_NAMES, meth.attr);
    }
    for a in args {
        cg_visit_expr(c, a);
    }
    if kwdsl {
        for kw in kwds {
            cg_visit_expr(c, kw.value);
        }
        cg_call_simple_kw_helper(c, loc, kwds, kwdsl);
        loc = cg_update_start_location_to_match_attr(c, expr_loc(e), meth);
        cg_addop_i(c, OP_CALL_KW, argsl + kwdsl, loc);
    } else {
        loc = cg_update_start_location_to_match_attr(c, expr_loc(e), meth);
        cg_addop_i(c, OP_CALL, argsl, loc);
    }
    return True;
}

impl cg_validate_keywords(c: cpy_compiler, keywords: list[keyword]) {
    n = len(keywords);
    i = 0;
    while i < n {
        key = keywords[i];
        karg = key.arg;
        if karg is not None {
            j = i + 1;
            while j < n {
                other = keywords[j];
                if other.arg is not None and other.arg == karg {
                    cpy_compile_error(
                        c, keyword_loc(other), "keyword argument repeated: " + karg
                    );
                }
                j += 1;
            }
        }
        i += 1;
    }
}

impl cg_call(c: cpy_compiler, e: Call) {
    cg_validate_keywords(c, e.keywords);
    if cg_maybe_optimize_method_call(c, e) {
        return;
    }
    skip_normal_call = cg_new_label(c);
    cg_check_caller(c, e.func);
    cg_visit_expr(c, e.func);
    cg_maybe_optimize_function_call(c, e, skip_normal_call);
    cg_addop(c, OP_PUSH_NULL, expr_loc(e.func));
    cg_call_helper(c, expr_loc(e), 0, e.args, None, e.keywords);
    cg_use_label(c, skip_normal_call);
}

impl cg_template_str(c: cpy_compiler, e: TemplateStr) {
    loc = expr_loc(e);
    last_was_interpolation = True;
    stringslen = 0;
    for value in e.values {
        if isinstance(value, Interpolation) {
            if last_was_interpolation {
                cg_load_str(c, "", loc);
                stringslen += 1;
            }
            last_was_interpolation = True;
        } else {
            cg_visit_expr(c, value);
            stringslen += 1;
            last_was_interpolation = False;
        }
    }
    if last_was_interpolation {
        cg_load_str(c, "", loc);
        stringslen += 1;
    }
    cg_addop_i(c, OP_BUILD_TUPLE, stringslen, loc);
    interpolationslen = 0;
    for value in e.values {
        if isinstance(value, Interpolation) {
            cg_visit_expr(c, value);
            interpolationslen += 1;
        }
    }
    cg_addop_i(c, OP_BUILD_TUPLE, interpolationslen, loc);
    cg_addop(c, OP_BUILD_TEMPLATE, loc);
}

impl cg_joined_str(c: cpy_compiler, e: JoinedStr) {
    loc = expr_loc(e);
    value_count = len(e.values);
    if value_count > STACK_USE_GUIDELINE {
        cg_load_str(c, "", loc);
        cg_addop_name(c, loc, CG_LOAD_METHOD, CG_NAMES, "join");
        cg_addop_i(c, OP_BUILD_LIST, 0, loc);
        for value in e.values {
            cg_visit_expr(c, value);
            cg_addop_i(c, OP_LIST_APPEND, 1, loc);
        }
        cg_addop_i(c, OP_CALL, 1, loc);
    } else {
        for value in e.values {
            cg_visit_expr(c, value);
        }
        if value_count > 1 {
            cg_addop_i(c, OP_BUILD_STRING, value_count, loc);
        } elif value_count == 0 {
            cg_load_str(c, "", loc);
        }
    }
}

impl cg_conversion_oparg(conversion: int) -> int {
    if conversion == 115 {
        return FVC_STR;
    }
    if conversion == 114 {
        return FVC_REPR;
    }
    if conversion == 97 {
        return FVC_ASCII;
    }
    raise SystemError("Unrecognized conversion character " + str(conversion));
}

impl cg_interpolation(c: cpy_compiler, e: Interpolation) {
    loc = expr_loc(e);
    cg_visit_expr(c, e.value);
    cg_load_const(c, e.str, loc);
    oparg = 2;
    format_spec = e.format_spec;
    if format_spec is not None {
        oparg += 1;
        cg_visit_expr(c, format_spec);
    }
    if e.conversion != -1 {
        oparg |= cg_conversion_oparg(e.conversion) << 2;
    }
    cg_addop_i(c, OP_BUILD_INTERPOLATION, oparg, loc);
}

impl cg_formatted_value(c: cpy_compiler, e: FormattedValue) {
    cg_visit_expr(c, e.value);
    loc = expr_loc(e);
    if e.conversion != -1 {
        cg_addop_i(c, OP_CONVERT_VALUE, cg_conversion_oparg(e.conversion), loc);
    }
    format_spec = e.format_spec;
    if format_spec is not None {
        cg_visit_expr(c, format_spec);
        cg_addop(c, OP_FORMAT_WITH_SPEC, loc);
    } else {
        cg_addop(c, OP_FORMAT_SIMPLE, loc);
    }
}

impl cg_subkwargs(
    c: cpy_compiler, loc: srcloc, keywords: list[keyword], begin: int, end: int
) {
    n = end - begin;
    big = n * 2 > STACK_USE_GUIDELINE;
    if big {
        cg_addop_i(c, OP_BUILD_MAP, 0, no_location());
    }
    i = begin;
    while i < end {
        kw = keywords[i];
        karg = kw.arg;
        cg_load_str(c, karg if karg is not None else "", loc);
        cg_visit_expr(c, kw.value);
        if big {
            cg_addop_i(c, OP_MAP_ADD, 1, no_location());
        }
        i += 1;
    }
    if not big {
        cg_addop_i(c, OP_BUILD_MAP, n, loc);
    }
}

impl cg_call_simple_kw_helper(
    c: cpy_compiler, loc: srcloc, keywords: list[keyword], nkwelts: int
) {
    items: list[PyObj] = [];
    i = 0;
    while i < nkwelts {
        karg = keywords[i].arg;
        items.append(PyStr(t="str", val=karg if karg is not None else ""));
        i += 1;
    }
    cg_load_const(c, PyTuple(t="tuple", items=items), loc);
}

impl cg_call_helper(
    c: cpy_compiler,
    loc: srcloc,
    n: int,
    args: list[expr],
    injected_arg: str | None,
    keywords: list[keyword]
) {
    cg_validate_keywords(c, keywords);
    nelts = len(args);
    nkwelts = len(keywords);
    ex_call = nelts + nkwelts * 2 > STACK_USE_GUIDELINE;
    if not ex_call {
        for elt in args {
            if isinstance(elt, Starred) {
                ex_call = True;
                break;
            }
        }
    }
    if not ex_call {
        for kw in keywords {
            if kw.arg is None {
                ex_call = True;
                break;
            }
        }
    }
    if not ex_call {
        for elt in args {
            cg_visit_expr(c, elt);
        }
        if injected_arg is not None {
            cg_nameop(c, loc, injected_arg, CG_LOAD);
            nelts += 1;
        }
        if nkwelts {
            for kw in keywords {
                cg_visit_expr(c, kw.value);
            }
            cg_call_simple_kw_helper(c, loc, keywords, nkwelts);
            cg_addop_i(c, OP_CALL_KW, n + nelts + nkwelts, loc);
        } else {
            cg_addop_i(c, OP_CALL, n + nelts, loc);
        }
        return;
    }
    first = args[0] if nelts == 1 else None;
    if n == 0 and nelts == 1 and isinstance(first, Starred) {
        cg_visit_expr(c, first.value);
    } else {
        cg_starunpack_helper(
            c,
            loc,
            args,
            injected_arg,
            n,
            OP_BUILD_LIST,
            OP_LIST_APPEND,
            OP_LIST_EXTEND,
            True
        );
    }
    if nkwelts {
        have_dict = False;
        nseen = 0;
        i = 0;
        while i < nkwelts {
            kw = keywords[i];
            if kw.arg is None {
                if nseen {
                    cg_subkwargs(c, loc, keywords, i - nseen, i);
                    if have_dict {
                        cg_addop_i(c, OP_DICT_MERGE, 1, loc);
                    }
                    have_dict = True;
                    nseen = 0;
                }
                if not have_dict {
                    cg_addop_i(c, OP_BUILD_MAP, 0, loc);
                    have_dict = True;
                }
                cg_visit_expr(c, kw.value);
                cg_addop_i(c, OP_DICT_MERGE, 1, loc);
            } else {
                nseen += 1;
            }
            i += 1;
        }
        if nseen {
            cg_subkwargs(c, loc, keywords, nkwelts - nseen, nkwelts);
            if have_dict {
                cg_addop_i(c, OP_DICT_MERGE, 1, loc);
            }
            have_dict = True;
        }
    }
    if nkwelts == 0 {
        cg_addop(c, OP_PUSH_NULL, loc);
    }
    cg_addop(c, OP_CALL_FUNCTION_EX, loc);
}

impl cg_binop_oparg(op: operator, inplace: bool) -> int {
    if isinstance(op, Add) {
        return NB_INPLACE_ADD if inplace else NB_ADD;
    }
    if isinstance(op, Sub) {
        return NB_INPLACE_SUBTRACT if inplace else NB_SUBTRACT;
    }
    if isinstance(op, Mult) {
        return NB_INPLACE_MULTIPLY if inplace else NB_MULTIPLY;
    }
    if isinstance(op, MatMult) {
        return NB_INPLACE_MATRIX_MULTIPLY if inplace else NB_MATRIX_MULTIPLY;
    }
    if isinstance(op, Div) {
        return NB_INPLACE_TRUE_DIVIDE if inplace else NB_TRUE_DIVIDE;
    }
    if isinstance(op, Mod) {
        return NB_INPLACE_REMAINDER if inplace else NB_REMAINDER;
    }
    if isinstance(op, Pow) {
        return NB_INPLACE_POWER if inplace else NB_POWER;
    }
    if isinstance(op, LShift) {
        return NB_INPLACE_LSHIFT if inplace else NB_LSHIFT;
    }
    if isinstance(op, RShift) {
        return NB_INPLACE_RSHIFT if inplace else NB_RSHIFT;
    }
    if isinstance(op, BitOr) {
        return NB_INPLACE_OR if inplace else NB_OR;
    }
    if isinstance(op, BitXor) {
        return NB_INPLACE_XOR if inplace else NB_XOR;
    }
    if isinstance(op, BitAnd) {
        return NB_INPLACE_AND if inplace else NB_AND;
    }
    if isinstance(op, FloorDiv) {
        return NB_INPLACE_FLOOR_DIVIDE if inplace else NB_FLOOR_DIVIDE;
    }
    raise SystemError(
        ("inplace" if inplace else "binary") + " op should not be possible"
    );
}

impl cg_visit_expr(c: cpy_compiler, e: expr) {
    loc = expr_loc(e);
    if isinstance(e, Name) {
        cg_nameop(c, loc, e.id, cg_ctx(e.ctx));
    } elif isinstance(e, Attribute) {
        cg_attribute(c, e, loc);
    } elif isinstance(e, Call) {
        cg_call(c, e);
    } elif isinstance(e, Constant) {
        cg_load_const(c, e.value, loc);
    } elif isinstance(e, Subscript) {
        cg_subscript(c, e);
    } elif isinstance(e, Tuple) {
        cg_tuple(c, e);
    } elif isinstance(e, BinOp) {
        cg_visit_expr(c, e.left);
        cg_visit_expr(c, e.right);
        cg_addop_i(c, OP_BINARY_OP, cg_binop_oparg(e.op, False), loc);
    } elif isinstance(e, Compare) {
        cg_compare(c, e);
    } elif isinstance(e, List) {
        cg_list(c, e);
    } elif isinstance(e, BoolOp) {
        cg_boolop(c, e);
    } elif isinstance(e, UnaryOp) {
        cg_visit_expr(c, e.operand);
        op = e.op;
        if isinstance(op, UAdd) {
            cg_addop_i(c, OP_CALL_INTRINSIC_1, INTRINSIC_UNARY_POSITIVE, loc);
        } elif isinstance(op, Not) {
            cg_addop(c, OP_TO_BOOL, loc);
            cg_addop(c, OP_UNARY_NOT, loc);
        } elif isinstance(op, Invert) {
            cg_addop(c, OP_UNARY_INVERT, loc);
        } elif isinstance(op, USub) {
            cg_addop(c, OP_UNARY_NEGATIVE, loc);
        } else {
            raise SystemError("unary op should not be possible");
        }
    } elif isinstance(e, JoinedStr) {
        cg_joined_str(c, e);
    } elif isinstance(e, FormattedValue) {
        cg_formatted_value(c, e);
    } elif isinstance(e, Dict) {
        cg_dict(c, e);
    } elif isinstance(e, Starred) {
        if cg_ctx(e.ctx) == CG_STORE {
            cpy_compile_error(
                c, loc, "starred assignment target must be in a list or tuple"
            );
        } else {
            cpy_compile_error(c, loc, "can't use starred expression here");
        }
    } elif isinstance(e, Slice) {
        cg_slice(c, e);
    } elif isinstance(e, ListComp) {
        cg_comprehension(c, e, COMP_LISTCOMP, "<listcomp>", e.generators, e.elt, None);
    } elif isinstance(e, GeneratorExp) {
        cg_comprehension(c, e, COMP_GENEXP, "<genexpr>", e.generators, e.elt, None);
    } elif isinstance(e, IfExp) {
        cg_ifexp(c, e);
    } elif isinstance(e, Lambda) {
        cg_lambda(c, e);
    } elif isinstance(e, DictComp) {
        cg_comprehension(
            c, e, COMP_DICTCOMP, "<dictcomp>", e.generators, e.key, e.value
        );
    } elif isinstance(e, SetComp) {
        cg_comprehension(c, e, COMP_SETCOMP, "<setcomp>", e.generators, e.elt, None);
    } elif isinstance(e, Set) {
        cg_set(c, e);
    } elif isinstance(e, Await) {
        cg_visit_expr(c, e.value);
        cg_addop_i(c, OP_GET_AWAITABLE, 0, loc);
        cg_load_none(c, loc);
        cg_add_yield_from(c, loc, True);
    } elif isinstance(e, Yield) {
        if not cpy_st_is_function_like(c.unit().ste) {
            cpy_compile_error(c, loc, "'yield' outside function");
        }
        value = e.value;
        if value is not None {
            cg_visit_expr(c, value);
        } else {
            cg_load_none(c, loc);
        }
        cg_addop_yield(c, loc);
    } elif isinstance(e, YieldFrom) {
        if not cpy_st_is_function_like(c.unit().ste) {
            cpy_compile_error(c, loc, "'yield from' outside function");
        }
        if c.unit().scope_type == COMPILE_SCOPE_ASYNC_FUNCTION {
            cpy_compile_error(c, loc, "'yield from' inside async function");
        }
        cg_visit_expr(c, e.value);
        cg_addop(c, OP_GET_YIELD_FROM_ITER, loc);
        cg_load_none(c, loc);
        cg_add_yield_from(c, loc, False);
    } elif isinstance(e, NamedExpr) {
        cg_visit_expr(c, e.value);
        cg_addop_i(c, OP_COPY, 1, loc);
        cg_visit_expr(c, e.target);
    } elif isinstance(e, TemplateStr) {
        cg_template_str(c, e);
    } elif isinstance(e, Interpolation) {
        cg_interpolation(c, e);
    }
}

impl cg_attribute(c: cpy_compiler, e: Attribute, loc: srcloc) {
    ctx = cg_ctx(e.ctx);
    value = e.value;
    if ctx == CG_LOAD
        and cg_can_optimize_super_call(c, e)
        and isinstance(value, Call) {
        cg_load_args_for_super(c, value);
        opcode = OP_LOAD_SUPER_ATTR if len(value.args) else CG_LOAD_ZERO_SUPER_ATTR;
        cg_addop_name(c, loc, opcode, CG_NAMES, e.attr);
        loc = cg_update_start_location_to_match_attr(c, loc, e);
        cg_addop(c, OP_NOP, loc);
        return;
    }
    cpy_compile_maybe_add_static_attribute(c, e);
    cg_visit_expr(c, value);
    loc = cg_update_start_location_to_match_attr(c, expr_loc(e), e);
    if ctx == CG_LOAD {
        cg_addop_name(c, loc, OP_LOAD_ATTR, CG_NAMES, e.attr);
    } elif ctx == CG_STORE {
        cg_addop_name(c, loc, OP_STORE_ATTR, CG_NAMES, e.attr);
    } else {
        cg_addop_name(c, loc, OP_DELETE_ATTR, CG_NAMES, e.attr);
    }
}

impl cg_is_constant_slice(s: expr) -> bool {
    if not isinstance(s, Slice) {
        return False;
    }
    lower = s.lower;
    upper = s.upper;
    step = s.step;
    return (lower is None or isinstance(lower, Constant))
        and (upper is None or isinstance(upper, Constant))
        and (step is None or isinstance(step, Constant));
}

impl cg_should_apply_two_element_slice_optimization(s: expr) -> bool {
    return not cg_is_constant_slice(s) and isinstance(s, Slice) and s.step is None;
}

impl cg_augassign(c: cpy_compiler, s: AugAssign) {
    e = s.target;
    loc = expr_loc(e);
    if isinstance(e, Attribute) {
        cg_visit_expr(c, e.value);
        cg_addop_i(c, OP_COPY, 1, loc);
        loc = cg_update_start_location_to_match_attr(c, loc, e);
        cg_addop_name(c, loc, OP_LOAD_ATTR, CG_NAMES, e.attr);
    } elif isinstance(e, Subscript) {
        cg_visit_expr(c, e.value);
        sl = e.slice;
        if cg_should_apply_two_element_slice_optimization(sl)
            and isinstance(sl, Slice) {
            cg_slice_two_parts(c, sl);
            cg_addop_i(c, OP_COPY, 3, loc);
            cg_addop_i(c, OP_COPY, 3, loc);
            cg_addop_i(c, OP_COPY, 3, loc);
            cg_addop(c, OP_BINARY_SLICE, loc);
        } else {
            cg_visit_expr(c, sl);
            cg_addop_i(c, OP_COPY, 2, loc);
            cg_addop_i(c, OP_COPY, 2, loc);
            cg_addop_i(c, OP_BINARY_OP, NB_SUBSCR, loc);
        }
    } elif isinstance(e, Name) {
        cg_nameop(c, loc, e.id, CG_LOAD);
    } else {
        raise SystemError("invalid node type for augmented assignment");
    }
    loc = stmt_loc(s);
    cg_visit_expr(c, s.value);
    cg_addop_i(c, OP_BINARY_OP, cg_binop_oparg(s.op, True), loc);
    loc = expr_loc(e);
    if isinstance(e, Attribute) {
        loc = cg_update_start_location_to_match_attr(c, loc, e);
        cg_addop_i(c, OP_SWAP, 2, loc);
        cg_addop_name(c, loc, OP_STORE_ATTR, CG_NAMES, e.attr);
    } elif isinstance(e, Subscript) {
        if cg_should_apply_two_element_slice_optimization(e.slice) {
            cg_addop_i(c, OP_SWAP, 4, loc);
            cg_addop_i(c, OP_SWAP, 3, loc);
            cg_addop_i(c, OP_SWAP, 2, loc);
            cg_addop(c, OP_STORE_SLICE, loc);
        } else {
            cg_addop_i(c, OP_SWAP, 3, loc);
            cg_addop_i(c, OP_SWAP, 2, loc);
            cg_addop(c, OP_STORE_SUBSCR, loc);
        }
    } elif isinstance(e, Name) {
        cg_nameop(c, loc, e.id, CG_STORE);
    }
}

impl cg_check_ann_expr(c: cpy_compiler, e: expr) {
    cg_visit_expr(c, e);
    cg_addop(c, OP_POP_TOP, expr_loc(e));
}

impl cg_check_annotation(c: cpy_compiler, s: AnnAssign) {
    if c.future_features & CO_FUTURE_ANNOTATIONS {
        return;
    }
    st = c.unit().scope_type;
    if st == COMPILE_SCOPE_MODULE or st == COMPILE_SCOPE_CLASS {
        cg_check_ann_expr(c, s.annotation);
    }
}

impl cg_check_ann_subscr(c: cpy_compiler, e: expr) {
    if isinstance(e, Slice) {
        lower = e.lower;
        if lower is not None {
            cg_check_ann_expr(c, lower);
        }
        upper = e.upper;
        if upper is not None {
            cg_check_ann_expr(c, upper);
        }
        step = e.step;
        if step is not None {
            cg_check_ann_expr(c, step);
        }
    } elif isinstance(e, Tuple) {
        for elt in e.elts {
            cg_check_ann_subscr(c, elt);
        }
    } else {
        cg_check_ann_expr(c, e);
    }
}

impl cg_annassign(c: cpy_compiler, s: AnnAssign) {
    loc = stmt_loc(s);
    targ = s.target;
    future_annotations = (c.future_features & CO_FUTURE_ANNOTATIONS) != 0;
    value = s.value;
    if value is not None {
        cg_visit_expr(c, value);
        cg_visit_expr(c, targ);
    }
    if isinstance(targ, Name) {
        st = c.unit().scope_type;
        if s.simple and (st == COMPILE_SCOPE_MODULE or st == COMPILE_SCOPE_CLASS) {
            if future_annotations {
                cg_load_str(c, render_annotation(s.annotation), expr_loc(s.annotation));
                cg_addop_name(c, loc, OP_LOAD_NAME, CG_NAMES, "__annotations__");
                mangled = cpy_compile_maybe_mangle(c, targ.id);
                cg_load_str(c, mangled, loc);
                cg_addop(c, OP_STORE_SUBSCR, loc);
            } else {
                index = cpy_compile_add_deferred_annotation(c, s);
                if index != -1 {
                    if st == COMPILE_SCOPE_CLASS {
                        cg_addop_name(
                            c,
                            loc,
                            OP_LOAD_DEREF,
                            CG_CELLVARS,
                            "__conditional_annotations__"
                        );
                    } else {
                        cg_addop_name(
                            c,
                            loc,
                            OP_LOAD_NAME,
                            CG_NAMES,
                            "__conditional_annotations__"
                        );
                    }
                    cg_load_int(c, index, loc);
                    cg_addop_i(c, OP_SET_ADD, 1, loc);
                    cg_addop(c, OP_POP_TOP, loc);
                }
            }
        }
    } elif isinstance(targ, Attribute) {
        if value is None {
            cg_check_ann_expr(c, targ.value);
        }
    } elif isinstance(targ, Subscript) {
        if value is None {
            cg_check_ann_expr(c, targ.value);
            cg_check_ann_subscr(c, targ.slice);
        }
    } else {
        raise SystemError("invalid node type for annotated assignment");
    }
    if future_annotations and not s.simple {
        cg_check_annotation(c, s);
    }
}

impl cg_subscript(c: cpy_compiler, e: Subscript) {
    loc = expr_loc(e);
    ctx = cg_ctx(e.ctx);
    if ctx == CG_LOAD {
        cg_check_subscripter(c, e.value);
        cg_check_index(c, e.value, e.slice);
    }
    cg_visit_expr(c, e.value);
    sl = e.slice;
    if cg_should_apply_two_element_slice_optimization(sl)
        and ctx != CG_DEL
        and isinstance(sl, Slice) {
        cg_slice_two_parts(c, sl);
        if ctx == CG_LOAD {
            cg_addop(c, OP_BINARY_SLICE, loc);
        } else {
            cg_addop(c, OP_STORE_SLICE, loc);
        }
    } else {
        cg_visit_expr(c, sl);
        if ctx == CG_LOAD {
            cg_addop_i(c, OP_BINARY_OP, NB_SUBSCR, loc);
        } elif ctx == CG_STORE {
            cg_addop(c, OP_STORE_SUBSCR, loc);
        } else {
            cg_addop(c, OP_DELETE_SUBSCR, loc);
        }
    }
}

impl cg_slice_two_parts(c: cpy_compiler, s: Slice) {
    lower = s.lower;
    if lower is not None {
        cg_visit_expr(c, lower);
    } else {
        cg_load_none(c, expr_loc(s));
    }
    upper = s.upper;
    if upper is not None {
        cg_visit_expr(c, upper);
    } else {
        cg_load_none(c, expr_loc(s));
    }
}

impl cg_slice_part(part: expr | None) -> PyObj {
    if part is not None and isinstance(part, Constant) {
        return part.value;
    }
    return py_none();
}

impl cg_slice(c: cpy_compiler, s: Slice) {
    n = 2;
    if cg_is_constant_slice(s) {
        value = PySlice(
            t="slice",
            start=cg_slice_part(s.lower),
            stop=cg_slice_part(s.upper),
            step=cg_slice_part(s.step)
        );
        cg_load_const(c, value, expr_loc(s));
        return;
    }
    cg_slice_two_parts(c, s);
    step = s.step;
    if step is not None {
        n += 1;
        cg_visit_expr(c, step);
    }
    cg_addop_i(c, OP_BUILD_SLICE, n, expr_loc(s));
}
