"""AST preprocessing for CPython 3.14 source and AST compilation."""

import from jaclang.runtime.python.compiler_integer {
    PyBigInt,
    integer_add,
    integer_negate,
    integer_to_float
}

import from jaclang.compiler.frontend.python.ast_nodes {
    Add,
    AnnAssign,
    AsyncFunctionDef,
    BinOp,
    ClassDef,
    Constant,
    Expr,
    FormattedValue,
    FunctionDef,
    FunctionType,
    JoinedStr,
    Load,
    MatchMapping,
    MatchValue,
    Mod,
    Module,
    Name,
    Pass,
    Starred,
    Sub,
    Tuple,
    USub,
    UnaryOp,
    arg,
    ast_node,
    expr,
    stmt,
}
import from jaclang.compiler.frontend.python.ast_walk {
    ast_rewriter,
    rewrite_ast_children
}
import from jaclang.runtime.python.objects {
    PyObj,
    PyBool,
    PyInt,
    PyFloat,
    PyComplex,
    PyStr
}

def ast_constant(value: PyObj, location: expr | None = None) -> Constant {
    return Constant(
        value=value,
        kind=None,
        lineno=location.lineno if location is not None else -1,
        col_offset=location.col_offset if location is not None else -1,
        end_lineno=location.end_lineno if location is not None else -1,
        end_col_offset=location.end_col_offset if location is not None else -1
    );
}

def pattern_number(value: expr) -> PyObj | None {
    if isinstance(value, Constant)
        and isinstance(value.value, (PyInt, PyBigInt, PyFloat, PyComplex)) {
        return value.value;
    }
    return None;
}

def pattern_real(value: PyObj) -> float {
    if isinstance(value, (PyInt, PyBigInt)) {
        return integer_to_float(value);
    }
    if isinstance(value, PyFloat) {
        return value.val;
    }
    return (value as PyComplex).real;
}

def pattern_sum(left: PyObj, right: PyObj, subtract: bool) -> PyObj {
    if isinstance(left, (PyInt, PyBigInt)) and isinstance(right, (PyInt, PyBigInt)) {
        return integer_add(left, right, subtract);
    }
    real_left = pattern_real(left);
    real_right = pattern_real(right);
    real = real_left - real_right if subtract else real_left + real_right;
    if isinstance(left, PyComplex) or isinstance(right, PyComplex) {
        imag_left = left.imag if isinstance(left, PyComplex) else 0.0;
        imag_right = right.imag if isinstance(right, PyComplex) else 0.0;
        return PyComplex(
            t="complex",
            real=real,
            imag=imag_left - imag_right if subtract else imag_left + imag_right
        );
    }
    return PyFloat(t="float", val=real);
}

def fold_pattern(value: expr) -> expr {
    if isinstance(value, UnaryOp) and isinstance(value.op, USub) {
        operand = pattern_number(value.operand);
        if isinstance(operand, (PyInt, PyBigInt)) {
            return ast_constant(integer_negate(operand), value);
        }
        if isinstance(operand, PyFloat) {
            return ast_constant(PyFloat(t="float", val=-operand.val), value);
        }
        if isinstance(operand, PyComplex) {
            return ast_constant(
                PyComplex(t="complex", real=-operand.real, imag=-operand.imag), value
            );
        }
    } elif isinstance(value, BinOp) and isinstance(value.op, (Add, Sub)) {
        value.left = fold_pattern(value.left);
        left = pattern_number(value.left);
        right = pattern_number(value.right);
        if left is not None and right is not None {
            return ast_constant(
                pattern_sum(left, right, isinstance(value.op, Sub)), value
            );
        }
    }
    return value;
}

# CPython only rewrites tuple-based %s/%r/%a formatting at the AST stage.
# Arithmetic constant folding belongs to bytecode optimization in 3.14.
def fold_percent_format(value: BinOp) -> expr {
    if not isinstance(value.op, Mod)
        or not isinstance(value.left, Constant)
        or not isinstance(value.left.value, PyStr)
        or not isinstance(value.right, Tuple)
        or any(isinstance(item, Starred) for item in value.right.elts) {
        return value;
    }
    source = value.left.value.val;
    args = value.right.elts;
    parts: list[expr] = [];
    pos = 0;
    count = 0;
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
            parts.append(ast_constant(PyStr(t="str", val=literal)));
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
            FormattedValue(
                value=argument,
                conversion=conversion,
                format_spec=ast_constant(PyStr(t="str", val=spec)) if spec else None,
                lineno=argument.lineno,
                col_offset=argument.col_offset,
                end_lineno=argument.end_lineno,
                end_col_offset=argument.end_col_offset
            )
        );
    }
    if count != len(args) {
        return value;
    }
    return JoinedStr(
        values=parts,
        lineno=value.lineno,
        col_offset=value.col_offset,
        end_lineno=value.end_lineno,
        end_col_offset=value.end_col_offset
    );
}

def has_docstring(body: list[stmt]) -> bool {
    return bool(body)
        and isinstance(body[0], Expr)
        and isinstance(body[0].value, Constant)
        and isinstance(body[0].value.value, PyStr);
}

def preprocess_body(body: list[stmt], optimize: int, flags: int, fold: bool) {
    had_docstring = has_docstring(body);
    if had_docstring and optimize >= 2 {
        first = body[0];
        if len(body) == 1 {
            body[0] = Pass(
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
        first_expr = body[0] as Expr;
        first_expr.value = JoinedStr(
            values=[first_expr.value],
            lineno=first_expr.lineno,
            col_offset=first_expr.col_offset,
            end_lineno=first_expr.end_lineno,
            end_col_offset=first_expr.end_col_offset
        );
    }
}

obj ast_preprocessor(ast_rewriter) {
    has optimize: int,
        flags: int,
        fold: bool;

    def visit_field(owner: ast_node, field: str) -> bool {
        if isinstance(owner, MatchMapping) and field == "keys" {
            return False;
        }
        if field == "body"
            and isinstance(owner, (Module, FunctionDef, AsyncFunctionDef, ClassDef)) {
            return False;
        }
        if self.flags & 0x1000000 {
            if field == "annotation" and isinstance(owner, (arg, AnnAssign)) {
                return False;
            }
            if field == "returns"
                and isinstance(owner, (FunctionDef, AsyncFunctionDef)) {
                return False;
            }
        }
        return True;
    }

    def transform(value: ast_node) -> ast_node {
        if isinstance(value, FunctionType) {
            return value;
        }
        if isinstance(value, MatchValue) {
            if self.fold {
                value.value = fold_pattern(value.value);
            }
            return value;
        }
        if isinstance(value, MatchMapping) and self.fold {
            value.keys = [fold_pattern(item) for item in value.keys];
        }
        if isinstance(value, (Module, FunctionDef, AsyncFunctionDef, ClassDef)) {
            preprocess_body(value.body, self.optimize, self.flags, self.fold);
        }
        rewrite_ast_children(value, self);
        if self.fold
            and isinstance(value, Name)
            and isinstance(value.ctx, Load)
            and value.id == "__debug__" {
            return ast_constant(PyBool(t="bool", val=self.optimize == 0), value);
        }
        if self.fold and isinstance(value, BinOp) {
            return fold_percent_format(value);
        }
        return value;
    }
}

def preprocess_node(
    value: ast_node, optimize: int, flags: int, fold: bool
) -> ast_node {
    return ast_preprocessor(optimize=optimize, flags=flags, fold=fold).transform(value);
}
