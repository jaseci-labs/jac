import from c {
    def PyUnicodeWriter_WriteUTF8(
        writer: ptr[PyUnicodeWriter], text: ptr[u8], size_in: i64
    ) -> i32;  def PyUnicode_Replace(
        str_obj: ptr[PyObject],
        substr: ptr[PyObject],
        replstr: ptr[PyObject],
        maxcount: i64
    ) -> ptr[PyObject];  def PyUnicode_Find(
        str_obj: ptr[PyObject],
        substr: ptr[PyObject],
        start: i64,
        end: i64,
        direction: i32
    ) -> i64;
}

glob:priv PR_TUPLE: Final[i32] = 0,
     PR_TEST: Final[i32] = 1,
     PR_OR: Final[i32] = 2,
     PR_AND: Final[i32] = 3,
     PR_NOT: Final[i32] = 4,
     PR_CMP: Final[i32] = 5,
     PR_EXPR: Final[i32] = 6,
     PR_BOR: Final[i32] = 6,
     PR_BXOR: Final[i32] = 7,
     PR_BAND: Final[i32] = 8,
     PR_SHIFT: Final[i32] = 9,
     PR_ARITH: Final[i32] = 10,
     PR_TERM: Final[i32] = 11,
     PR_FACTOR: Final[i32] = 12,
     PR_POWER: Final[i32] = 13,
     PR_AWAIT: Final[i32] = 14,
     PR_ATOM: Final[i32] = 15,
     DBL_MAX: Final[f64] = 1.7976931348623157e308;

def expr_at(seq: ptr[asdl_seq], index: i64) -> ptr[_expr];

def expr_kind(e: ptr[_expr]) -> i32;

def append_char(writer: ptr[PyUnicodeWriter], ch: u32) -> i32;

def append_charp(writer: ptr[PyUnicodeWriter], charp: ptr[u8]) -> i32;

def float_check_exact(op: ptr[PyObject]) -> bool;

def complex_check_exact(op: ptr[PyObject]) -> bool;

def long_check_exact(op: ptr[PyObject]) -> bool;

def tuple_check_exact(op: ptr[PyObject]) -> bool;

def is_infinite(value: f64) -> bool;

def append_repr(writer: ptr[PyUnicodeWriter], obj_: ptr[PyObject]) -> i32;

def append_ast_boolop(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_binop(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_unaryop(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_arg(writer: ptr[PyUnicodeWriter], nd: ptr[_arg]) -> i32;

def append_ast_args(writer: ptr[PyUnicodeWriter], args: ptr[_arguments]) -> i32;

def append_ast_lambda(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_ifexp(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_dict(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_elements(
    writer: ptr[PyUnicodeWriter], elts: ptr[asdl_seq], open_char: u32, close_char: u32
) -> i32;

def append_ast_set(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_list(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_tuple(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_comprehension(
    writer: ptr[PyUnicodeWriter], gen: ptr[_comprehension]
) -> i32;

def append_ast_comprehensions(
    writer: ptr[PyUnicodeWriter], comprehensions: ptr[asdl_seq]
) -> i32;

def append_comprehension_display(
    writer: ptr[PyUnicodeWriter],
    elt: ptr[_expr],
    generators: ptr[asdl_seq],
    open_char: u32,
    close_char: u32
) -> i32;

def append_ast_genexp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_listcomp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_setcomp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_dictcomp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_compare(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_keyword(writer: ptr[PyUnicodeWriter], kw: ptr[_keyword]) -> i32;

def append_ast_call(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def escape_braces(orig: ptr[PyObject]) -> ptr[PyObject];

def append_fstring_unicode(
    writer: ptr[PyUnicodeWriter], unicode: ptr[PyObject]
) -> i32;

def append_fstring_element(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr], is_format_spec: bool
) -> i32;

def build_ftstring_body(values: ptr[asdl_seq], is_format_spec: bool) -> ptr[PyObject];

def append_templatestr(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_joinedstr(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr], is_format_spec: bool
) -> i32;

def append_interpolation_str(writer: ptr[PyUnicodeWriter], text: ptr[PyObject]) -> i32;

def append_interpolation_value(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_interpolation_conversion(
    writer: ptr[PyUnicodeWriter], conversion: i32
) -> i32;

def append_interpolation_format_spec(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr]
) -> i32;

def append_interpolation(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_formattedvalue(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_constant(writer: ptr[PyUnicodeWriter], constant: ptr[PyObject]) -> i32;

def append_ast_attribute(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_slice(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_subscript(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_starred(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_yield(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_yield_from(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32;

def append_ast_await(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_named_expr(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def append_ast_expr(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32;

def expr_as_unicode(e: ptr[_expr], level: i32) -> ptr[PyObject];

import from c {
    def _PyAST_ExprAsUnicode(e: ptr[_expr]) -> ptr[PyObject] {
        return expr_as_unicode(e, PR_TEST);
    }
}

impl expr_at(seq: ptr[asdl_seq], index: i64) -> ptr[_expr] {
    return ptr[_expr](asdl_seq_get_untyped(seq, index));
}

impl expr_kind(e: ptr[_expr]) -> i32 {
    return e.view(1)[0].kind;
}

impl append_char(writer: ptr[PyUnicodeWriter], ch: u32) -> i32 {
    return PyUnicodeWriter_WriteChar(writer, ch);
}

impl append_charp(writer: ptr[PyUnicodeWriter], charp: ptr[u8]) -> i32 {
    return PyUnicodeWriter_WriteUTF8(writer, charp, -1);
}

impl float_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyFloat_Type)));
}

impl complex_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyComplex_Type)));
}

impl long_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyLong_Type)));
}

impl tuple_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyTuple_Type)));
}

impl is_infinite(value: f64) -> bool {
    return value > DBL_MAX or value < -DBL_MAX;
}

impl append_repr(writer: ptr[PyUnicodeWriter], obj_: ptr[PyObject]) -> i32 {
    repr = PyObject_Repr(obj_);
    if not repr {
        return -1;
    }
    replace_inf = complex_check_exact(obj_);
    if float_check_exact(obj_) {
        replace_inf = is_infinite(PyFloat_AsDouble(obj_));
    }
    if replace_inf {
        new_repr = PyUnicode_Replace(
            repr, py_id(_Py_ID_inf), py_id(_Py_STR_str_replace_inf), -1
        );
        object_decref(repr);
        if not new_repr {
            return -1;
        }
        repr = new_repr;
    }
    ret = PyUnicodeWriter_WriteStr(writer, repr);
    object_decref(repr);
    return ret;
}

impl append_ast_boolop(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    nd = ptr[_expr_BoolOp](node_union(ptr(e)));
    op = ptr[u8](" or ");
    pr: i32 = PR_OR;
    if nd.view(1)[0].op == And {
        op = ptr[u8](" and ");
        pr = PR_AND;
    }
    if level > pr and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    values = nd.view(1)[0].values;
    value_count = asdl_seq_len(values);
    i: i64 = 0;
    while i < value_count {
        if i > 0 and append_charp(writer, op) == -1 {
            return -1;
        }
        if append_ast_expr(writer, expr_at(values, i), pr + 1) == -1 {
            return -1;
        }
        i += 1;
    }
    if level > pr and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_binop(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    nd = ptr[_expr_BinOp](node_union(ptr(e)));
    kind = nd.view(1)[0].op;
    op = ptr[u8]("");
    pr: i32 = 0;
    rassoc = False;
    if kind == Add {
        op = ptr[u8](" + ");
        pr = PR_ARITH;
    } elif kind == Sub {
        op = ptr[u8](" - ");
        pr = PR_ARITH;
    } elif kind == Mult {
        op = ptr[u8](" * ");
        pr = PR_TERM;
    } elif kind == MatMult {
        op = ptr[u8](" @ ");
        pr = PR_TERM;
    } elif kind == Div {
        op = ptr[u8](" / ");
        pr = PR_TERM;
    } elif kind == Mod {
        op = ptr[u8](" % ");
        pr = PR_TERM;
    } elif kind == LShift {
        op = ptr[u8](" << ");
        pr = PR_SHIFT;
    } elif kind == RShift {
        op = ptr[u8](" >> ");
        pr = PR_SHIFT;
    } elif kind == BitOr {
        op = ptr[u8](" | ");
        pr = PR_BOR;
    } elif kind == BitXor {
        op = ptr[u8](" ^ ");
        pr = PR_BXOR;
    } elif kind == BitAnd {
        op = ptr[u8](" & ");
        pr = PR_BAND;
    } elif kind == FloorDiv {
        op = ptr[u8](" // ");
        pr = PR_TERM;
    } elif kind == Pow {
        op = ptr[u8](" ** ");
        pr = PR_POWER;
        rassoc = True;
    } else {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("unknown binary operator"));
        return -1;
    }
    left_level: i32 = pr;
    right_level: i32 = pr + 1;
    if rassoc {
        left_level = pr + 1;
        right_level = pr;
    }
    if level > pr and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].left, left_level) == -1 {
        return -1;
    }
    if append_charp(writer, op) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].right, right_level) == -1 {
        return -1;
    }
    if level > pr and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_unaryop(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32
) -> i32 {
    nd = ptr[_expr_UnaryOp](node_union(ptr(e)));
    kind = nd.view(1)[0].op;
    op = ptr[u8]("");
    pr: i32 = 0;
    if kind == Invert {
        op = ptr[u8]("~");
        pr = PR_FACTOR;
    } elif kind == Not {
        op = ptr[u8]("not ");
        pr = PR_NOT;
    } elif kind == UAdd {
        op = ptr[u8]("+");
        pr = PR_FACTOR;
    } elif kind == USub {
        op = ptr[u8]("-");
        pr = PR_FACTOR;
    } else {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("unknown unary operator"));
        return -1;
    }
    if level > pr and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    if append_charp(writer, op) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].operand, pr) == -1 {
        return -1;
    }
    if level > pr and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_arg(writer: ptr[PyUnicodeWriter], nd: ptr[_arg]) -> i32 {
    if PyUnicodeWriter_WriteStr(writer, nd.view(1)[0].arg) < 0 {
        return -1;
    }
    if nd.view(1)[0].annotation {
        if append_charp(writer, ptr[u8](": ")) == -1 {
            return -1;
        }
        if append_ast_expr(writer, nd.view(1)[0].annotation, PR_TEST) == -1 {
            return -1;
        }
    }
    return 0;
}

impl append_ast_args(writer: ptr[PyUnicodeWriter], args: ptr[_arguments]) -> i32 {
    first = True;
    a = args.view(1)[0];
    posonlyarg_count = asdl_seq_len(a.posonlyargs);
    arg_count = asdl_seq_len(a.args);
    default_count = asdl_seq_len(a.defaults);
    i: i64 = 0;
    while i < posonlyarg_count + arg_count {
        if not first and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        first = False;
        if i < posonlyarg_count {
            if append_ast_arg(writer, ptr[_arg](asdl_seq_get_untyped(a.posonlyargs, i)))
                == -1 {
                return -1;
            }
        } elif append_ast_arg(
            writer, ptr[_arg](asdl_seq_get_untyped(a.args, i - posonlyarg_count))
        )
            == -1 {
            return -1;
        }
        di = i - posonlyarg_count - arg_count + default_count;
        if di >= 0 {
            if append_char(writer, u32(61)) == -1 {
                return -1;
            }
            if append_ast_expr(writer, expr_at(a.defaults, di), PR_TEST) == -1 {
                return -1;
            }
        }
        if posonlyarg_count != 0 and i + 1 == posonlyarg_count {
            if append_charp(writer, ptr[u8](", /")) == -1 {
                return -1;
            }
        }
        i += 1;
    }
    if a.vararg or asdl_seq_len(a.kwonlyargs) != 0 {
        if not first and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        first = False;
        if append_charp(writer, ptr[u8]("*")) == -1 {
            return -1;
        }
        if a.vararg {
            if append_ast_arg(writer, a.vararg) == -1 {
                return -1;
            }
        }
    }
    kwonly_count = asdl_seq_len(a.kwonlyargs);
    kw_default_count = asdl_seq_len(a.kw_defaults);
    k: i64 = 0;
    while k < kwonly_count {
        if not first and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        first = False;
        if append_ast_arg(writer, ptr[_arg](asdl_seq_get_untyped(a.kwonlyargs, k)))
            == -1 {
            return -1;
        }
        kdi = k - kwonly_count + kw_default_count;
        if kdi >= 0 {
            default_ = expr_at(a.kw_defaults, kdi);
            if default_ {
                if append_char(writer, u32(61)) == -1 {
                    return -1;
                }
                if append_ast_expr(writer, default_, PR_TEST) == -1 {
                    return -1;
                }
            }
        }
        k += 1;
    }
    if a.kwarg {
        if not first and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        first = False;
        if append_charp(writer, ptr[u8]("**")) == -1 {
            return -1;
        }
        if append_ast_arg(writer, a.kwarg) == -1 {
            return -1;
        }
    }
    return 0;
}

impl append_ast_lambda(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    nd = ptr[_expr_Lambda](node_union(ptr(e)));
    if level > PR_TEST and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    args = nd.view(1)[0].args;
    n_positional = asdl_seq_len(args.view(1)[0].args)
        + asdl_seq_len(args.view(1)[0].posonlyargs);
    keyword = ptr[u8]("lambda");
    if n_positional != 0 {
        keyword = ptr[u8]("lambda ");
    }
    if append_charp(writer, keyword) == -1 {
        return -1;
    }
    if append_ast_args(writer, args) == -1 {
        return -1;
    }
    if append_charp(writer, ptr[u8](": ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].body, PR_TEST) == -1 {
        return -1;
    }
    if level > PR_TEST and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_ifexp(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    nd = ptr[_expr_IfExp](node_union(ptr(e)));
    if level > PR_TEST and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].body, PR_TEST + 1) == -1 {
        return -1;
    }
    if append_charp(writer, ptr[u8](" if ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].test_, PR_TEST + 1) == -1 {
        return -1;
    }
    if append_charp(writer, ptr[u8](" else ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].orelse, PR_TEST) == -1 {
        return -1;
    }
    if level > PR_TEST and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_dict(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Dict](node_union(ptr(e)));
    if append_char(writer, u32(123)) == -1 {
        return -1;
    }
    value_count = asdl_seq_len(nd.view(1)[0].values);
    i: i64 = 0;
    while i < value_count {
        if i > 0 and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        key_node = expr_at(nd.view(1)[0].keys, i);
        if key_node {
            if append_ast_expr(writer, key_node, PR_TEST) == -1 {
                return -1;
            }
            if append_charp(writer, ptr[u8](": ")) == -1 {
                return -1;
            }
            if append_ast_expr(writer, expr_at(nd.view(1)[0].values, i), PR_TEST)
                == -1 {
                return -1;
            }
        } else {
            if append_charp(writer, ptr[u8]("**")) == -1 {
                return -1;
            }
            if append_ast_expr(writer, expr_at(nd.view(1)[0].values, i), PR_EXPR)
                == -1 {
                return -1;
            }
        }
        i += 1;
    }
    return append_char(writer, u32(125));
}

impl append_elements(
    writer: ptr[PyUnicodeWriter], elts: ptr[asdl_seq], open_char: u32, close_char: u32
) -> i32 {
    if append_char(writer, open_char) == -1 {
        return -1;
    }
    elem_count = asdl_seq_len(elts);
    i: i64 = 0;
    while i < elem_count {
        if i > 0 and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        if append_ast_expr(writer, expr_at(elts, i), PR_TEST) == -1 {
            return -1;
        }
        i += 1;
    }
    return append_char(writer, close_char);
}

impl append_ast_set(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Set](node_union(ptr(e)));
    return append_elements(writer, nd.view(1)[0].elts, u32(123), u32(125));
}

impl append_ast_list(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_List](node_union(ptr(e)));
    return append_elements(writer, nd.view(1)[0].elts, u32(91), u32(93));
}

impl append_ast_tuple(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    nd = ptr[_expr_Tuple](node_union(ptr(e)));
    elts = nd.view(1)[0].elts;
    elem_count = asdl_seq_len(elts);
    if elem_count == 0 {
        return append_charp(writer, ptr[u8]("()"));
    }
    if level > PR_TUPLE and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    i: i64 = 0;
    while i < elem_count {
        if i > 0 and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        if append_ast_expr(writer, expr_at(elts, i), PR_TEST) == -1 {
            return -1;
        }
        i += 1;
    }
    if elem_count == 1 and append_charp(writer, ptr[u8](",")) == -1 {
        return -1;
    }
    if level > PR_TUPLE and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_comprehension(
    writer: ptr[PyUnicodeWriter], gen: ptr[_comprehension]
) -> i32 {
    g = gen.view(1)[0];
    keyword = ptr[u8](" for ");
    if g.is_async != 0 {
        keyword = ptr[u8](" async for ");
    }
    if append_charp(writer, keyword) == -1 {
        return -1;
    }
    if append_ast_expr(writer, g.target, PR_TUPLE) == -1 {
        return -1;
    }
    if append_charp(writer, ptr[u8](" in ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, g.iter, PR_TEST + 1) == -1 {
        return -1;
    }
    if_count = asdl_seq_len(g.ifs);
    i: i64 = 0;
    while i < if_count {
        if append_charp(writer, ptr[u8](" if ")) == -1 {
            return -1;
        }
        if append_ast_expr(writer, expr_at(g.ifs, i), PR_TEST + 1) == -1 {
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl append_ast_comprehensions(
    writer: ptr[PyUnicodeWriter], comprehensions: ptr[asdl_seq]
) -> i32 {
    gen_count = asdl_seq_len(comprehensions);
    i: i64 = 0;
    while i < gen_count {
        if append_ast_comprehension(
            writer, ptr[_comprehension](asdl_seq_get_untyped(comprehensions, i))
        )
            == -1 {
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl append_comprehension_display(
    writer: ptr[PyUnicodeWriter],
    elt: ptr[_expr],
    generators: ptr[asdl_seq],
    open_char: u32,
    close_char: u32
) -> i32 {
    if append_char(writer, open_char) == -1 {
        return -1;
    }
    if append_ast_expr(writer, elt, PR_TEST) == -1 {
        return -1;
    }
    if append_ast_comprehensions(writer, generators) == -1 {
        return -1;
    }
    return append_char(writer, close_char);
}

impl append_ast_genexp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_GeneratorExp](node_union(ptr(e)));
    return append_comprehension_display(
        writer, nd.view(1)[0].elt, nd.view(1)[0].generators, u32(40), u32(41)
    );
}

impl append_ast_listcomp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_ListComp](node_union(ptr(e)));
    return append_comprehension_display(
        writer, nd.view(1)[0].elt, nd.view(1)[0].generators, u32(91), u32(93)
    );
}

impl append_ast_setcomp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_SetComp](node_union(ptr(e)));
    return append_comprehension_display(
        writer, nd.view(1)[0].elt, nd.view(1)[0].generators, u32(123), u32(125)
    );
}

impl append_ast_dictcomp(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_DictComp](node_union(ptr(e)));
    if append_char(writer, u32(123)) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].key, PR_TEST) == -1 {
        return -1;
    }
    if append_charp(writer, ptr[u8](": ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].value, PR_TEST) == -1 {
        return -1;
    }
    if append_ast_comprehensions(writer, nd.view(1)[0].generators) == -1 {
        return -1;
    }
    return append_char(writer, u32(125));
}

impl append_ast_compare(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32
) -> i32 {
    nd = ptr[_expr_Compare](node_union(ptr(e)));
    if level > PR_CMP and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    comparators = nd.view(1)[0].comparators;
    ops = nd.view(1)[0].ops;
    comparator_count = asdl_seq_len(comparators);
    if append_ast_expr(writer, nd.view(1)[0].left, PR_CMP + 1) == -1 {
        return -1;
    }
    i: i64 = 0;
    while i < comparator_count {
        kind = asdl_int_seq_get(ops, i);
        op = ptr[u8]("");
        if kind == Eq {
            op = ptr[u8](" == ");
        } elif kind == NotEq {
            op = ptr[u8](" != ");
        } elif kind == Lt {
            op = ptr[u8](" < ");
        } elif kind == LtE {
            op = ptr[u8](" <= ");
        } elif kind == Gt {
            op = ptr[u8](" > ");
        } elif kind == GtE {
            op = ptr[u8](" >= ");
        } elif kind == Is {
            op = ptr[u8](" is ");
        } elif kind == IsNot {
            op = ptr[u8](" is not ");
        } elif kind == In {
            op = ptr[u8](" in ");
        } elif kind == NotIn {
            op = ptr[u8](" not in ");
        } else {
            PyErr_SetString(PyExc_SystemError, ptr[u8]("unexpected comparison kind"));
            return -1;
        }
        if append_charp(writer, op) == -1 {
            return -1;
        }
        if append_ast_expr(writer, expr_at(comparators, i), PR_CMP + 1) == -1 {
            return -1;
        }
        i += 1;
    }
    if level > PR_CMP and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_keyword(writer: ptr[PyUnicodeWriter], kw: ptr[_keyword]) -> i32 {
    if not kw.view(1)[0].arg {
        if append_charp(writer, ptr[u8]("**")) == -1 {
            return -1;
        }
    } else {
        if PyUnicodeWriter_WriteStr(writer, kw.view(1)[0].arg) == -1 {
            return -1;
        }
        if append_char(writer, u32(61)) == -1 {
            return -1;
        }
    }
    if append_ast_expr(writer, kw.view(1)[0].value, PR_TEST) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_call(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Call](node_union(ptr(e)));
    if append_ast_expr(writer, nd.view(1)[0].func, PR_ATOM) == -1 {
        return -1;
    }
    args = nd.view(1)[0].args;
    keywords = nd.view(1)[0].keywords;
    arg_count = asdl_seq_len(args);
    kw_count = asdl_seq_len(keywords);
    if arg_count == 1 and kw_count == 0 {
        only = expr_at(args, 0);
        if expr_kind(only) == GeneratorExp_kind {
            return append_ast_genexp(writer, only);
        }
    }
    if append_char(writer, u32(40)) == -1 {
        return -1;
    }
    first = True;
    i: i64 = 0;
    while i < arg_count {
        if not first and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        first = False;
        if append_ast_expr(writer, expr_at(args, i), PR_TEST) == -1 {
            return -1;
        }
        i += 1;
    }
    k: i64 = 0;
    while k < kw_count {
        if not first and append_charp(writer, ptr[u8](", ")) == -1 {
            return -1;
        }
        first = False;
        if append_ast_keyword(writer, ptr[_keyword](asdl_seq_get_untyped(keywords, k)))
            == -1 {
            return -1;
        }
        k += 1;
    }
    return append_char(writer, u32(41));
}

impl escape_braces(orig: ptr[PyObject]) -> ptr[PyObject] {
    temp = PyUnicode_Replace(
        orig, latin1_char(u32(123)), py_id(_Py_STR_dbl_open_br), -1
    );
    if not temp {
        return NULL;
    }
    result = PyUnicode_Replace(
        temp, latin1_char(u32(125)), py_id(_Py_STR_dbl_close_br), -1
    );
    object_decref(temp);
    return result;
}

impl append_fstring_unicode(
    writer: ptr[PyUnicodeWriter], unicode: ptr[PyObject]
) -> i32 {
    result: i32 = -1;
    escaped = escape_braces(unicode);
    if escaped {
        result = PyUnicodeWriter_WriteStr(writer, escaped);
        object_decref(escaped);
    }
    return result;
}

impl append_fstring_element(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr], is_format_spec: bool
) -> i32 {
    kind = expr_kind(e);
    if kind == Constant_kind {
        return append_fstring_unicode(
            writer, ptr[_expr_Constant](node_union(ptr(e))).view(1)[0].value
        );
    } elif kind == JoinedStr_kind {
        return append_joinedstr(writer, e, is_format_spec);
    } elif kind == TemplateStr_kind {
        return append_templatestr(writer, e);
    } elif kind == FormattedValue_kind {
        return append_formattedvalue(writer, e);
    } elif kind == Interpolation_kind {
        return append_interpolation(writer, e);
    }
    PyErr_SetString(
        PyExc_SystemError,
        ptr[u8]("unknown expression kind inside f-string or t-string")
    );
    return -1;
}

impl build_ftstring_body(values: ptr[asdl_seq], is_format_spec: bool) -> ptr[PyObject] {
    body_writer = PyUnicodeWriter_Create(256);
    if not body_writer {
        return NULL;
    }
    value_count = asdl_seq_len(values);
    i: i64 = 0;
    while i < value_count {
        if append_fstring_element(body_writer, expr_at(values, i), is_format_spec)
            == -1 {
            PyUnicodeWriter_Discard(body_writer);
            return NULL;
        }
        i += 1;
    }
    return PyUnicodeWriter_Finish(body_writer);
}

impl append_templatestr(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    result: i32 = -1;
    body = build_ftstring_body(
        ptr[_expr_TemplateStr](node_union(ptr(e))).view(1)[0].values, False
    );
    if not body {
        return -1;
    }
    if append_charp(writer, ptr[u8]("t")) != -1 and append_repr(writer, body) != -1 {
        result = 0;
    }
    object_decref(body);
    return result;
}

impl append_joinedstr(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr], is_format_spec: bool
) -> i32 {
    result: i32 = -1;
    body = build_ftstring_body(
        ptr[_expr_JoinedStr](node_union(ptr(e))).view(1)[0].values, is_format_spec
    );
    if not body {
        return -1;
    }
    if not is_format_spec {
        if append_charp(writer, ptr[u8]("f")) != -1
            and append_repr(writer, body) != -1 {
            result = 0;
        }
    } else {
        result = PyUnicodeWriter_WriteStr(writer, body);
    }
    object_decref(body);
    return result;
}

impl append_interpolation_str(
    writer: ptr[PyUnicodeWriter], text: ptr[PyObject]
) -> i32 {
    outer_brace = ptr[u8]("{");
    if PyUnicode_Find(text, latin1_char(u32(123)), 0, 1, 1) == 0 {
        outer_brace = ptr[u8]("{ ");
    }
    if append_charp(writer, outer_brace) == -1 {
        return -1;
    }
    if PyUnicodeWriter_WriteStr(writer, text) == -1 {
        return -1;
    }
    return 0;
}

impl append_interpolation_value(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    temp_fv_str = expr_as_unicode(e, PR_TEST + 1);
    if not temp_fv_str {
        return -1;
    }
    result = append_interpolation_str(writer, temp_fv_str);
    object_decref(temp_fv_str);
    return result;
}

impl append_interpolation_conversion(
    writer: ptr[PyUnicodeWriter], conversion: i32
) -> i32 {
    if conversion < 0 {
        return 0;
    }
    conversion_str = ptr[u8]("");
    if conversion == 97 {
        conversion_str = ptr[u8]("!a");
    } elif conversion == 114 {
        conversion_str = ptr[u8]("!r");
    } elif conversion == 115 {
        conversion_str = ptr[u8]("!s");
    } else {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("unknown f-value conversion kind"));
        return -1;
    }
    if append_charp(writer, conversion_str) == -1 {
        return -1;
    }
    return 0;
}

impl append_interpolation_format_spec(
    writer: ptr[PyUnicodeWriter], e: ptr[_expr]
) -> i32 {
    if e {
        if PyUnicodeWriter_WriteChar(writer, u32(58)) == -1
            or append_fstring_element(writer, e, True) == -1 {
            return -1;
        }
    }
    return 0;
}

impl append_interpolation(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Interpolation](node_union(ptr(e)));
    if append_interpolation_str(writer, nd.view(1)[0].str_) == -1 {
        return -1;
    }
    if append_interpolation_conversion(writer, nd.view(1)[0].conversion) == -1 {
        return -1;
    }
    if append_interpolation_format_spec(writer, nd.view(1)[0].format_spec) == -1 {
        return -1;
    }
    return append_charp(writer, ptr[u8]("}"));
}

impl append_formattedvalue(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_FormattedValue](node_union(ptr(e)));
    if append_interpolation_value(writer, nd.view(1)[0].value) == -1 {
        return -1;
    }
    if append_interpolation_conversion(writer, nd.view(1)[0].conversion) == -1 {
        return -1;
    }
    if append_interpolation_format_spec(writer, nd.view(1)[0].format_spec) == -1 {
        return -1;
    }
    return append_char(writer, u32(125));
}

impl append_ast_constant(writer: ptr[PyUnicodeWriter], constant: ptr[PyObject]) -> i32 {
    if tuple_check_exact(constant) {
        elem_count = object_size(constant);
        if append_char(writer, u32(40)) == -1 {
            return -1;
        }
        i: i64 = 0;
        while i < elem_count {
            if i > 0 and append_charp(writer, ptr[u8](", ")) == -1 {
                return -1;
            }
            if append_ast_constant(writer, tuple_get_item(constant, i)) < 0 {
                return -1;
            }
            i += 1;
        }
        if elem_count == 1 and append_charp(writer, ptr[u8](",")) == -1 {
            return -1;
        }
        return append_char(writer, u32(41));
    }
    return append_repr(writer, constant);
}

impl append_ast_attribute(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Attribute](node_union(ptr(e)));
    v = nd.view(1)[0].value;
    if append_ast_expr(writer, v, PR_ATOM) == -1 {
        return -1;
    }
    period = ptr[u8](".");
    if expr_kind(v) == Constant_kind
        and long_check_exact(
            ptr[_expr_Constant](node_union(ptr(v))).view(1)[0].value
        ) {
        period = ptr[u8](" .");
    }
    if append_charp(writer, period) == -1 {
        return -1;
    }
    return PyUnicodeWriter_WriteStr(writer, nd.view(1)[0].attr);
}

impl append_ast_slice(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Slice](node_union(ptr(e)));
    if nd.view(1)[0].lower {
        if append_ast_expr(writer, nd.view(1)[0].lower, PR_TEST) == -1 {
            return -1;
        }
    }
    if append_char(writer, u32(58)) == -1 {
        return -1;
    }
    if nd.view(1)[0].upper {
        if append_ast_expr(writer, nd.view(1)[0].upper, PR_TEST) == -1 {
            return -1;
        }
    }
    if nd.view(1)[0].step {
        if append_char(writer, u32(58)) == -1 {
            return -1;
        }
        if append_ast_expr(writer, nd.view(1)[0].step, PR_TEST) == -1 {
            return -1;
        }
    }
    return 0;
}

impl append_ast_subscript(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Subscript](node_union(ptr(e)));
    if append_ast_expr(writer, nd.view(1)[0].value, PR_ATOM) == -1 {
        return -1;
    }
    if append_char(writer, u32(91)) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].slice, PR_TUPLE) == -1 {
        return -1;
    }
    return append_char(writer, u32(93));
}

impl append_ast_starred(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Starred](node_union(ptr(e)));
    if append_char(writer, u32(42)) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].value, PR_EXPR) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_yield(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_Yield](node_union(ptr(e)));
    if not nd.view(1)[0].value {
        return append_charp(writer, ptr[u8]("(yield)"));
    }
    if append_charp(writer, ptr[u8]("(yield ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].value, PR_TEST) == -1 {
        return -1;
    }
    return append_char(writer, u32(41));
}

impl append_ast_yield_from(writer: ptr[PyUnicodeWriter], e: ptr[_expr]) -> i32 {
    nd = ptr[_expr_YieldFrom](node_union(ptr(e)));
    if append_charp(writer, ptr[u8]("(yield from ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].value, PR_TEST) == -1 {
        return -1;
    }
    return append_char(writer, u32(41));
}

impl append_ast_await(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    nd = ptr[_expr_Await](node_union(ptr(e)));
    if level > PR_AWAIT and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    if append_charp(writer, ptr[u8]("await ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].value, PR_ATOM) == -1 {
        return -1;
    }
    if level > PR_AWAIT and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_named_expr(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    nd = ptr[_expr_NamedExpr](node_union(ptr(e)));
    if level > PR_TUPLE and append_charp(writer, ptr[u8]("(")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].target, PR_ATOM) == -1 {
        return -1;
    }
    if append_charp(writer, ptr[u8](" := ")) == -1 {
        return -1;
    }
    if append_ast_expr(writer, nd.view(1)[0].value, PR_ATOM) == -1 {
        return -1;
    }
    if level > PR_TUPLE and append_charp(writer, ptr[u8](")")) == -1 {
        return -1;
    }
    return 0;
}

impl append_ast_expr(writer: ptr[PyUnicodeWriter], e: ptr[_expr], level: i32) -> i32 {
    kind = expr_kind(e);
    if kind == BoolOp_kind {
        return append_ast_boolop(writer, e, level);
    } elif kind == BinOp_kind {
        return append_ast_binop(writer, e, level);
    } elif kind == UnaryOp_kind {
        return append_ast_unaryop(writer, e, level);
    } elif kind == Lambda_kind {
        return append_ast_lambda(writer, e, level);
    } elif kind == IfExp_kind {
        return append_ast_ifexp(writer, e, level);
    } elif kind == Dict_kind {
        return append_ast_dict(writer, e);
    } elif kind == Set_kind {
        return append_ast_set(writer, e);
    } elif kind == GeneratorExp_kind {
        return append_ast_genexp(writer, e);
    } elif kind == ListComp_kind {
        return append_ast_listcomp(writer, e);
    } elif kind == SetComp_kind {
        return append_ast_setcomp(writer, e);
    } elif kind == DictComp_kind {
        return append_ast_dictcomp(writer, e);
    } elif kind == Yield_kind {
        return append_ast_yield(writer, e);
    } elif kind == YieldFrom_kind {
        return append_ast_yield_from(writer, e);
    } elif kind == Await_kind {
        return append_ast_await(writer, e, level);
    } elif kind == Compare_kind {
        return append_ast_compare(writer, e, level);
    } elif kind == Call_kind {
        return append_ast_call(writer, e);
    } elif kind == Constant_kind {
        nd = ptr[_expr_Constant](node_union(ptr(e)));
        if nd.view(1)[0].value == Py_Ellipsis {
            return append_charp(writer, ptr[u8]("..."));
        }
        if nd.view(1)[0].kind {
            if PyUnicodeWriter_WriteStr(writer, nd.view(1)[0].kind) == -1 {
                return -1;
            }
        }
        return append_ast_constant(writer, nd.view(1)[0].value);
    } elif kind == JoinedStr_kind {
        return append_joinedstr(writer, e, False);
    } elif kind == TemplateStr_kind {
        return append_templatestr(writer, e);
    } elif kind == FormattedValue_kind {
        return append_formattedvalue(writer, e);
    } elif kind == Interpolation_kind {
        return append_interpolation(writer, e);
    } elif kind == Attribute_kind {
        return append_ast_attribute(writer, e);
    } elif kind == Subscript_kind {
        return append_ast_subscript(writer, e);
    } elif kind == Starred_kind {
        return append_ast_starred(writer, e);
    } elif kind == Slice_kind {
        return append_ast_slice(writer, e);
    } elif kind == Name_kind {
        return PyUnicodeWriter_WriteStr(
            writer, ptr[_expr_Name](node_union(ptr(e))).view(1)[0].id
        );
    } elif kind == List_kind {
        return append_ast_list(writer, e);
    } elif kind == Tuple_kind {
        return append_ast_tuple(writer, e, level);
    } elif kind == NamedExpr_kind {
        return append_named_expr(writer, e, level);
    }
    PyErr_SetString(PyExc_SystemError, ptr[u8]("unknown expression kind"));
    return -1;
}

impl expr_as_unicode(e: ptr[_expr], level: i32) -> ptr[PyObject] {
    writer = PyUnicodeWriter_Create(256);
    if not writer {
        return NULL;
    }
    if append_ast_expr(writer, e, level) == -1 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}
