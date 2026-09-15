"""Typed expression rendering for postponed Python annotations.

The compiler owns traversal and precedence; no Python AST or unparser is used.
"""
import from jaclang.compiler.frontend.python.ast_nodes {
    ast_node,
    expr,
    arg,
    arguments,
    comprehension,
    AnnAssign,
    FunctionDef,
    AsyncFunctionDef,
    Constant,
    Name,
    Attribute,
    Subscript,
    Slice,
    Starred,
    Tuple,
    List,
    Set,
    Dict,
    BinOp,
    UnaryOp,
    BoolOp,
    Compare,
    Lambda,
    IfExp,
    NamedExpr,
    Await,
    Yield,
    YieldFrom,
    Call,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    JoinedStr,
    TemplateStr,
    FormattedValue,
    Interpolation,
    Add,
    Sub,
    Mult,
    MatMult,
    Div,
    Mod,
    FloorDiv,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    Eq,
    NotEq,
    Lt,
    LtE,
    Gt,
    GtE,
    Is,
    IsNot,
    In,
    NotIn,
    Invert,
    Not,
    UAdd,
    USub,
    And,
    Or
}
import from jaclang.compiler.frontend.python.ast_walk { ast_children }
import from jaclang.runtime.python.objects {
    PyObj,
    PyInt,
    PyBool,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PyNoneType,
    PyEllipsis
}
import from jaclang.runtime.python.compiler_integer { PyBigInt, integer_decimal }

def annotation_operator(value: ast_node) -> tuple[str, int] {
    if isinstance(value, Add) {
        return ('+', 13);
    }
    if isinstance(value, Sub) {
        return ('-', 13);
    }
    if isinstance(value, Mult) {
        return ('*', 14);
    }
    if isinstance(value, MatMult) {
        return ('@', 14);
    }
    if isinstance(value, Div) {
        return ('/', 14);
    }
    if isinstance(value, Mod) {
        return ('%', 14);
    }
    if isinstance(value, FloorDiv) {
        return ('//', 14);
    }
    if isinstance(value, Pow) {
        return ('**', 16);
    }
    if isinstance(value, LShift) {
        return ('<<', 12);
    }
    if isinstance(value, RShift) {
        return ('>>', 12);
    }
    if isinstance(value, BitOr) {
        return ('|', 9);
    }
    if isinstance(value, BitXor) {
        return ('^', 10);
    }
    if isinstance(value, BitAnd) {
        return ('&', 11);
    }
    if isinstance(value, Eq) {
        return ('==', 8);
    }
    if isinstance(value, NotEq) {
        return ('!=', 8);
    }
    if isinstance(value, Lt) {
        return ('<', 8);
    }
    if isinstance(value, LtE) {
        return ('<=', 8);
    }
    if isinstance(value, Gt) {
        return ('>', 8);
    }
    if isinstance(value, GtE) {
        return ('>=', 8);
    }
    if isinstance(value, Is) {
        return ('is', 8);
    }
    if isinstance(value, IsNot) {
        return ('is not', 8);
    }
    if isinstance(value, In) {
        return ('in', 8);
    }
    if isinstance(value, NotIn) {
        return ('not in', 8);
    }
    if isinstance(value, Invert) {
        return ('~', 15);
    }
    if isinstance(value, Not) {
        return ('not ', 7);
    }
    if isinstance(value, UAdd) {
        return ('+', 15);
    }
    if isinstance(value, USub) {
        return ('-', 15);
    }
    if isinstance(value, And) {
        return ('and', 6);
    }
    if isinstance(value, Or) {
        return ('or', 5);
    }
    raise ValueError("Unknown annotation operator");
}

def annotation_value(value: PyObj) -> str {
    if isinstance(value, PyBigInt) {
        return integer_decimal(value);
    }
    if isinstance(value, PyInt) {
        return str(value.val);
    }
    if isinstance(value, PyBool) {
        return "True" if value.val else "False";
    }
    if isinstance(value, PyNoneType) {
        return "None";
    }
    if isinstance(value, PyEllipsis) {
        return "...";
    }
    if isinstance(value, PyStr) {
        return repr(value.val);
    }
    if isinstance(value, PyBytes) {
        return repr(bytes(value.val));
    }
    if isinstance(value, PyFloat) {
        return repr(value.val).replace("inf", "1e309").replace("nan", "(1e309-1e309)");
    }
    if isinstance(value, PyComplex) {
        # Complex constants are normally imaginary literals or folded values.
        imag = repr(value.imag).removesuffix(".0");
        if value.real == 0.0 and not repr(value.real).startswith("-") {
            text = imag + "j";
        } else {
            real = repr(value.real).removesuffix(".0");
            text = "(" + real + ("" if imag.startswith("-") else "+") + imag + "j)";
        }
        return text.replace("inf", "1e309").replace("nan", "(1e309-1e309)");
    }
    if isinstance(value, PyTuple) {
        parts = [annotation_value(item) for item in value.items];
        return "(" + ", ".join(parts) + ("," if len(parts) == 1 else "") + ")";
    }
    raise ValueError("Invalid annotation constant");
}

def annotation_items(values: list[expr], precedence: int = 4) -> str {
    return ", ".join([render_annotation(value, precedence) for value in values]);
}

def annotation_arguments(value: arguments) -> str {
    parts: list[str] = [];
    positional = value.posonlyargs + value.args;
    offset = len(positional) - len(value.defaults);
    for index in range(len(positional)) {
        text = positional[index].arg;
        if positional[index].annotation is not None {
            text += ": " + render_annotation(positional[index].annotation);
        }
        if index >= offset {
            text += "=" + render_annotation(value.defaults[index - offset]);
        }
        parts.append(text);
        if index + 1 == len(value.posonlyargs) {
            parts.append("/");
        }
    }
    if value.vararg is not None {
        text = "*" + value.vararg.arg;
        if value.vararg.annotation is not None {
            text += ": " + render_annotation(value.vararg.annotation);
        }
        parts.append(text);
    } elif value.kwonlyargs {
        parts.append("*");
    }
    for index in range(len(value.kwonlyargs)) {
        text = value.kwonlyargs[index].arg;
        if value.kwonlyargs[index].annotation is not None {
            text += ": " + render_annotation(value.kwonlyargs[index].annotation);
        }
        default_value = value.kw_defaults[index];
        if default_value is not None {
            text += "=" + render_annotation(default_value);
        }
        parts.append(text);
    }
    if value.kwarg is not None {
        text = "**" + value.kwarg.arg;
        if value.kwarg.annotation is not None {
            text += ": " + render_annotation(value.kwarg.annotation);
        }
        parts.append(text);
    }
    return ", ".join(parts);
}

def annotation_generators(values: list[comprehension]) -> str {
    result = "";
    for value in values {
        result += " async for " if value.is_async else " for ";
        result += render_annotation(value.target, 2)
            + " in "
            + render_annotation(value.iter, 5);
        for condition in value.ifs {
            result += " if " + render_annotation(condition, 5);
        }
    }
    return result;
}

def annotation_interpolation(
    value: expr, conversion: int, format_spec: expr | None, spelling: str | None = None
) -> str {
    inner = spelling if spelling is not None else render_annotation(value, 5);
    result = "{ " if inner.startswith("{") else "{";
    result += inner;
    if conversion != -1 {
        result += "!" + chr(conversion);
    }
    if format_spec is not None {
        result += ":" + annotation_string_inner(format_spec, True);
    }
    return result + "}";
}

def annotation_string_inner(value: expr, format_spec: bool = False) -> str {
    if isinstance(value, Constant) and isinstance(value.value, PyStr) {
        text = value.value.val.replace("{", "{{").replace("}", "}}");
        if format_spec {
            text = text.replace("\\", "\\\\").replace("'", "\\'").replace(
                "\"", "\\\""
            ).replace(
                "\n", "\\n"
            );
        }
        return text;
    }
    if isinstance(value, JoinedStr) {
        return "".join(
            [annotation_string_inner(part, format_spec) for part in value.values]
        );
    }
    if isinstance(value, FormattedValue) {
        return annotation_interpolation(
            value.value, value.conversion, value.format_spec
        );
    }
    if isinstance(value, Interpolation) {
        spelling: str | None = None;
        if isinstance(value.str, PyStr) {
            spelling = value.str.val;
        }
        return annotation_interpolation(
            value.value, value.conversion, value.format_spec, spelling
        );
    }
    raise ValueError("Invalid interpolated annotation string");
}

def annotation_string(values: list[expr], prefix: str) -> str {
    quotes = ["'", "\"", "\"\"\"", "'''"];
    parts: list[str] = [];
    for value in values {
        part = annotation_string_inner(value);
        if isinstance(value, Constant) {
            escaped = "";
            for ch in part {
                if ch == "\\" {
                    escaped += "\\\\";
                } elif ch == "\n" {
                    escaped += "\\n";
                } elif ch == "\r" {
                    escaped += "\\r";
                } elif ch == "\t" {
                    escaped += "\\t";
                } elif ch.isprintable() {
                    escaped += ch;
                } else {
                    escaped += repr(ch)[1:-1];
                }
            }
            part = escaped;
        }
        candidates = [
            quote
            for quote in quotes
            if quote not in part and (len(quote) == 3 or "\n" not in part)
        ];
        if candidates {
            quotes = candidates;
        }
        parts.append(part);
    }
    quote = quotes[0];
    # Escape literal segments only: expression text must remain untouched.
    for index in range(len(parts)) {
        if isinstance(values[index], Constant) {
            parts[index] = parts[index].replace(quote, "\\" + quote);
        }
    }
    return prefix + quote + "".join(parts) + quote;
}

def render_annotation(value: expr, outer: int = 4) -> str {
    precedence = 18;
    text = "";
    if isinstance(value, Name) {
        text = value.id;
    } elif isinstance(value, Constant) {
        text = ("u" if value.kind == "u" else "") + annotation_value(value.value);
    } elif isinstance(value, BinOp) {
        (operator_text, precedence) = annotation_operator(value.op);
        right_associative = operator_text == "**";
        text = render_annotation(
            value.left, precedence + (1 if right_associative else 0)
        )
            + " "
            + operator_text
            + " "
            + render_annotation(
                value.right, precedence + (0 if right_associative else 1)
            );
    } elif isinstance(value, UnaryOp) {
        (operator_text, precedence) = annotation_operator(value.op);
        text = operator_text + render_annotation(value.operand, precedence);
    } elif isinstance(value, BoolOp) {
        (operator_text, precedence) = annotation_operator(value.op);
        text = (" " + operator_text + " ").join(
            [render_annotation(item, precedence + 1) for item in value.values]
        );
    } elif isinstance(value, Compare) {
        precedence = 8;
        text = render_annotation(value.left, 9);
        for index in range(len(value.ops)) {
            (operator_text, unused) = annotation_operator(value.ops[index]);
            text += " "
                + operator_text
                + " "
                + render_annotation(value.comparators[index], 9);
        }
    } elif isinstance(value, IfExp) {
        precedence = 4;
        text = render_annotation(value.body, 5)
            + " if "
            + render_annotation(value.test, 5)
            + " else "
            + render_annotation(value.orelse, 4);
    } elif isinstance(value, Lambda) {
        precedence = 4;
        params = annotation_arguments(value.args);
        text = "lambda"
            + (" " + params if params else "")
            + ": "
            + render_annotation(value.body, 4);
    } elif isinstance(value, NamedExpr) {
        precedence = 1;
        text = render_annotation(value.target)
            + " := "
            + render_annotation(value.value);
    } elif isinstance(value, Attribute) {
        text = render_annotation(value.value, 18);
        if isinstance(value.value, Constant)
            and isinstance(value.value.value, (PyInt, PyBigInt, PyBool)) {
            text += " ";
        }
        text += "." + value.attr;
    } elif isinstance(value, Call) {
        text = render_annotation(value.func, 18);
        if len(value.args) == 1
            and not value.keywords
            and isinstance(value.args[0], GeneratorExp) {
            text += render_annotation(value.args[0]);
        } else {
            parts = [render_annotation(item) for item in value.args];
            for item in value.keywords {
                parts.append(
                    (item.arg + "=" if item.arg is not None else "**")
                        + render_annotation(item.value)
                );
            }
            text += "(" + ", ".join(parts) + ")";
        }
    } elif isinstance(value, Subscript) {
        slice_text = render_annotation(value.slice);
        if isinstance(value.slice, Tuple) and value.slice.elts {
            slice_text = annotation_items(value.slice.elts)
                + ("," if len(value.slice.elts) == 1 else "");
        }
        text = render_annotation(value.value, 18) + "[" + slice_text + "]";
    } elif isinstance(value, Slice) {
        text = (render_annotation(value.lower) if value.lower is not None else "")
            + ":"
            + (render_annotation(value.upper) if value.upper is not None else "");
        if value.step is not None {
            text += ":" + render_annotation(value.step);
        }
    } elif isinstance(value, Starred) {
        text = "*" + render_annotation(value.value, 9);
    } elif isinstance(value, Tuple) {
        precedence = 2 if value.elts else 18;
        text = annotation_items(value.elts) + ("," if len(value.elts) == 1 else "");
        if not value.elts {
            text = "()";
        }
    } elif isinstance(value, List) {
        text = "[" + annotation_items(value.elts) + "]";
    } elif isinstance(value, Set) {
        text = "{" + annotation_items(value.elts) + "}" if value.elts else "{*()}";
    } elif isinstance(value, Dict) {
        parts: list[str] = [];
        for index in range(len(value.keys)) {
            key = value.keys[index];
            item = value.values[index];
            parts.append(
                render_annotation(key) + ": " + render_annotation(item)
                    if key is not None
                    else "**" + render_annotation(item, 9)
            );
        }
        text = "{" + ", ".join(parts) + "}";
    } elif isinstance(value, (ListComp, SetComp, GeneratorExp)) {
        if isinstance(value, ListComp) {
            text = "["
                + render_annotation(value.elt)
                + annotation_generators(value.generators)
                + "]";
        } elif isinstance(value, SetComp) {
            text = "{"
                + render_annotation(value.elt)
                + annotation_generators(value.generators)
                + "}";
        } elif isinstance(value, GeneratorExp) {
            text = "("
                + render_annotation(value.elt)
                + annotation_generators(value.generators)
                + ")";
        }
    } elif isinstance(value, DictComp) {
        text = "{"
            + render_annotation(value.key)
            + ": "
            + render_annotation(value.value)
            + annotation_generators(value.generators)
            + "}";
    } elif isinstance(value, Await) {
        precedence = 17;
        text = "await " + render_annotation(value.value, 18);
    } elif isinstance(value, Yield) {
        precedence = 3;
        text = "yield"
            + (" " + render_annotation(value.value) if value.value is not None else "");
    } elif isinstance(value, YieldFrom) {
        precedence = 3;
        text = "yield from " + render_annotation(value.value);
    } elif isinstance(value, JoinedStr) {
        text = annotation_string(value.values, "f");
    } elif isinstance(value, TemplateStr) {
        text = annotation_string(value.values, "t");
    } else {
        raise ValueError("Invalid annotation expression");
    }
    return "(" + text + ")" if precedence < outer else text;
}

def annotation_constant(value: expr) -> Constant {
    return Constant(
        value=PyStr(t="str", val=render_annotation(value)),
        kind=None,
        lineno=value.lineno,
        col_offset=value.col_offset,
        end_lineno=value.end_lineno,
        end_col_offset=value.end_col_offset
    );
}

def stringify_future_annotations(tree: ast_node, filename: str) {
    pending: list[ast_node] = [tree];
    while pending {
        item = pending.pop();
        if isinstance(item, AnnAssign) {
            item.annotation = annotation_constant(item.annotation);
        } elif isinstance(item, arg) and item.annotation is not None {
            item.annotation = annotation_constant(item.annotation);
        } elif isinstance(item, (FunctionDef, AsyncFunctionDef))
            and item.returns is not None {
            item.returns = annotation_constant(item.returns);
        }
        for child in ast_children(item) {
            pending.append(child.value);
        }
    }
}
