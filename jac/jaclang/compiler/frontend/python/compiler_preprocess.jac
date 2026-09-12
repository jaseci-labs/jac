"""AST preprocessing for CPython 3.14 source and AST compilation."""

import jaclang.compiler.frontend.python.ast_nodes as nodes;
import from jaclang.compiler.frontend.python.ast_bridge { constant_from_python }
import from jaclang.runtime.python.objects { PyInt, PyFloat, PyComplex, PyStr }

def ast_location(value: any) -> dict[str, any] {
    return {
        "lineno": value.lineno,
        "col_offset": value.col_offset,
        "end_lineno": value.end_lineno,
        "end_col_offset": value.end_col_offset
    };
}

def ast_constant(value: any, location: dict[str, any]) -> nodes.Constant {
    return nodes.Constant(value=constant_from_python(value), kind=None, **location);
}

def pattern_number(value: nodes.expr) -> any {
    if isinstance(value, nodes.Constant) {
        if isinstance(value.value, (PyInt, PyFloat)) {
            return value.value.val;
        }
        if isinstance(value.value, PyComplex) {
            return complex(value.value.real, value.value.imag);
        }
    }
    return None;
}

def fold_pattern(value: nodes.expr) -> nodes.expr {
    if isinstance(value, nodes.UnaryOp) and isinstance(value.op, nodes.USub) {
        operand = pattern_number(value.operand);
        if operand is not None {
            return ast_constant(-operand, ast_location(value));
        }
    } elif isinstance(value, nodes.BinOp)
        and isinstance(value.op, (nodes.Add, nodes.Sub)) {
        value.left = fold_pattern(value.left);
        left = pattern_number(value.left);
        right = pattern_number(value.right);
        if left is not None and right is not None {
            result = left + right if isinstance(value.op, nodes.Add) else left - right;
            return ast_constant(result, ast_location(value));
        }
    }
    return value;
}

# CPython only rewrites tuple-based %s/%r/%a formatting at the AST stage.
# Arithmetic constant folding belongs to bytecode optimization in 3.14.
def fold_percent_format(value: nodes.BinOp) -> nodes.expr {
    if not isinstance(value.op, nodes.Mod)
        or not isinstance(value.left, nodes.Constant)
        or not isinstance(value.left.value, PyStr)
        or not isinstance(value.right, nodes.Tuple)
        or any(isinstance(item, nodes.Starred) for item in value.right.elts) {
        return value;
    }
    source = value.left.value.val;
    args = value.right.elts;
    parts: list[nodes.expr] = [];
    pos = 0;
    count = 0;
    synthetic = {
        "lineno": -1,
        "col_offset": -1,
        "end_lineno": -1,
        "end_col_offset": -1
    };
    while True {
        literal = "";
        while pos < len(source) {
            if source[pos] != "%" {
                literal += source[pos];
                pos += 1;
            } elif source[pos:pos + 2] == "%%" {
                literal += "%";
                pos += 2;
            } else {
                break;
            }
        }
        if literal {
            parts.append(ast_constant(literal, synthetic));
        }
        if pos >= len(source) {
            break;
        }
        if count >= len(args) {
            return value;
        }
        pos += 1;
        left_justify = False;
        while pos < len(source) and source[pos] in "-+ #0" {
            left_justify |= source[pos] == "-";
            pos += 1;
        }
        width = "";
        while pos < len(source) and source[pos] in "0123456789" {
            width += source[pos];
            pos += 1;
        }
        if len(width) >= 3 {
            return value;
        }
        precision = "";
        if pos < len(source) and source[pos] == "." {
            pos += 1;
            digits = "";
            while pos < len(source) and source[pos] in "0123456789" {
                digits += source[pos];
                pos += 1;
            }
            if len(digits) >= 3 {
                return value;
            }
            precision = "." + str(int(digits or "0"));
        }
        if pos >= len(source) or source[pos] not in "sra" {
            return value;
        }
        conversion = ord(source[pos]);
        pos += 1;
        spec = "";
        if width {
            if int(width) > 0 and not left_justify {
                spec = ">";
            }
            spec += str(int(width));
        }
        spec += precision;
        argument = args[count];
        count += 1;
        parts.append(
            nodes.FormattedValue(
                value=argument,
                conversion=conversion,
                format_spec=ast_constant(spec, synthetic) if spec else None,
                **ast_location(argument)
            )
        );
    }
    if count != len(args) {
        return value;
    }
    return nodes.JoinedStr(values=parts, **ast_location(value));
}

def has_docstring(body: list[nodes.stmt]) -> bool {
    return bool(body)
        and isinstance(body[0], nodes.Expr)
        and isinstance(body[0].value, nodes.Constant)
        and isinstance(body[0].value.value, PyStr);
}

def preprocess_body(body: list[nodes.stmt], optimize: int, flags: int, fold: bool) {
    had_docstring = has_docstring(body);
    if had_docstring and optimize >= 2 {
        first = body[0];
        if len(body) == 1 {
            body[0] = nodes.Pass(
                lineno=first.lineno,
                col_offset=first.col_offset,
                end_lineno=first.lineno,
                end_col_offset=first.col_offset + 4
            );
        } else {
            body.pop(0);
        }
        had_docstring = False;
    }
    for item in body {
        preprocess_node(item, optimize, flags, fold);
    }
    if not had_docstring and has_docstring(body) {
        first_expr = body[0] as nodes.Expr;
        first_expr.value = nodes.JoinedStr(
            values=[first_expr.value], **ast_location(first_expr)
        );
    }
}

def preprocess_node(value: any, optimize: int, flags: int, fold: bool) -> any {
    if isinstance(value, list) {
        return [preprocess_node(item, optimize, flags, fold) for item in value];
    }
    if not isinstance(value, nodes.ast_node) or isinstance(value, nodes.FunctionType) {
        return value;
    }
    if isinstance(value, nodes.MatchValue) {
        if fold {
            value.value = fold_pattern(value.value);
        }
        return value;
    }
    # Pattern mapping keys only permit literal number folding.
    if isinstance(value, nodes.MatchMapping) and fold {
        value.keys = [fold_pattern(item) for item in value.keys];
    }
    for (key, child) in list(vars(value).items()) {
        if key == "keys" and isinstance(value, nodes.MatchMapping) {
            continue;
        }
        if flags & 0x1000000
            and (
                (
                    key == "annotation"
                    and isinstance(value, (nodes.arg, nodes.AnnAssign))
                )
                or (
                    key == "returns"
                    and isinstance(value, (nodes.FunctionDef, nodes.AsyncFunctionDef))
                )
            ) {
            continue;
        }
        if key == "body"
            and isinstance(
                value,
                (
                    nodes.Module,
                    nodes.FunctionDef,
                    nodes.AsyncFunctionDef,
                    nodes.ClassDef
                )
            ) {
            preprocess_body(child, optimize, flags, fold);
        } elif isinstance(child, (nodes.ast_node, list)) {
            setattr(value, key, preprocess_node(child, optimize, flags, fold));
        }
    }
    if fold
        and isinstance(value, nodes.Name)
        and isinstance(value.ctx, nodes.Load)
        and value.id == "__debug__" {
        return ast_constant(not optimize, ast_location(value));
    }
    if fold and isinstance(value, nodes.BinOp) {
        return fold_percent_format(value);
    }
    return value;
}
