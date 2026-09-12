import ast;
import from types { GenericAlias, UnionType }
import jaclang.compiler.frontend.python.ast_nodes as nodes;
import from jaclang.runtime.python.objects {
    PyObj,
    PyBool,
    PyInt,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PySet,
    PyEllipsis,
    py_none
}

def constant_from_python(value: any) -> PyObj {
    if value is None {
        return py_none();
    }
    if value is ... {
        return PyEllipsis(t="ellipsis");
    }
    if isinstance(value, bool) {
        return PyBool(t="bool", val=value);
    }
    if isinstance(value, int) {
        return PyInt(t="int", val=value);
    }
    if isinstance(value, float) {
        return PyFloat(t="float", val=value);
    }
    if isinstance(value, complex) {
        return PyComplex(t="complex", real=value.real, imag=value.imag);
    }
    if isinstance(value, str) {
        return PyStr(t="str", val=value);
    }
    if isinstance(value, bytes) {
        return PyBytes(t="bytes", val=list(value));
    }
    if isinstance(value, tuple) {
        return PyTuple(t="tuple", items=[constant_from_python(item) for item in value]);
    }
    if isinstance(value, frozenset) {
        return PySet(
            t="frozenset",
            frozen=True,
            items={str(i): constant_from_python(item) for (i, item) in enumerate(value)}
        );
    }
    raise TypeError(f"Invalid AST constant: {type(value).__name__}");
}

def field_matches(value: any, expected: any) -> bool {
    if isinstance(expected, UnionType) {
        return any(field_matches(value, item) for item in expected.__args__);
    }
    if isinstance(expected, GenericAlias) {
        origin = expected.__origin__;
        return isinstance(origin, type)
            and isinstance(value, origin)
            and all(
                item is None or field_matches(item, expected.__args__[0])
                for item in value
            );
    }
    return isinstance(value, expected);
}

def from_python_ast(value: any) -> any {
    if isinstance(value, list) {
        return [from_python_ast(item) for item in value];
    }
    if not isinstance(value, ast.AST) {
        return value;
    }
    for (key, expected) in value._field_types.items() {
        if not hasattr(value, key) {
            raise TypeError(
                f'required field "{key}" missing from {type(value).__name__}'
            );
        }
        child = getattr(value, key);
        if not field_matches(child, expected) {
            raise TypeError(f'expected {expected} for field "{key}", got {child!r}');
        }
    }
    if isinstance(value, ast.NamedExpr) and not isinstance(value.target, ast.Name) {
        raise TypeError("NamedExpr target must be a Name");
    }
    if isinstance(value, ast.TypeAlias) and not isinstance(value.name, ast.Name) {
        raise TypeError("TypeAlias with non-Name name");
    }
    name = type(value).__name__;
    constructor = getattr(nodes, name, None);
    if constructor is None {
        raise TypeError(f"Unsupported Python AST node: {name}");
    }
    fields: dict[str, any] = {};
    for (key, child) in ast.iter_fields(value) {
        if isinstance(value, ast.Constant) and key == "value" {
            fields[key] = constant_from_python(child);
        } elif isinstance(value, ast.MatchSingleton) and key == "value" {
            fields[key] = constant_from_python(child);
        } elif isinstance(value, ast.Interpolation) and key == "str" {
            fields[key] = constant_from_python(child);
        } else {
            fields[key] = from_python_ast(child);
        }
    }
    for key in value._attributes {
        fields[key] = getattr(value, key, None);
    }
    return constructor(**fields);
}

def to_python_ast(value: any, convert_constant: any) -> any {
    if isinstance(value, list) {
        return [to_python_ast(item, convert_constant) for item in value];
    }
    if isinstance(value, PyObj) {
        return convert_constant(value);
    }
    if not isinstance(value, nodes.ast_node) {
        return value;
    }
    constructor = getattr(ast, type(value).__name__);
    fields: dict[str, any] = {};
    for key in constructor._fields {
        fields[key] = to_python_ast(getattr(value, key), convert_constant);
    }
    for key in constructor._attributes {
        child = getattr(value, key, None);
        if child is not None {
            fields[key] = child;
        }
    }
    return constructor(**fields);
}

# Validate manually constructed ASTs before lowering or AST-only preprocessing.
# Field schema checks and language placement checks are separate concerns.
def validate_python_ast(tree: ast.AST) {
    validate_ast_schema(tree);
    validate_ast_value(tree);
}

def validate_ast_schema(value_node: any) {
    if isinstance(value_node, list) {
        for item in value_node {
            if item is not None {
                validate_ast_schema(item);
            }
        }
        return;
    }
    if not isinstance(value_node, ast.AST) {
        return;
    }
    if not hasattr(value_node, "_field_types") {
        raise TypeError(f"expected a concrete AST node, but got {value_node!r}");
    }
    for (key, expected) in value_node._field_types.items() {
        if not hasattr(value_node, key) {
            raise TypeError(
                f'required field "{key}" missing from {type(value_node).__name__}'
            );
        }
        child = getattr(value_node, key);
        if isinstance(expected, GenericAlias)
            and expected.__origin__ is list
            and isinstance(child, list) {
            # obj2ast permits null list elements; the structural validator below
            # rejects them except in dictionary keys and keyword defaults.
            if not all(
                item is None or field_matches(item, expected.__args__[0])
                for item in child
            ) {
                raise TypeError(
                    f'expected {expected} for field "{key}", got {child!r}'
                );
            }
        } elif not field_matches(child, expected) {
            if child is None and not isinstance(expected, GenericAlias) {
                raise ValueError(
                    f"field '{key}' is required for {type(value_node).__name__}"
                );
            }
            if expected is str {
                raise TypeError(
                    f"identifier must be of type str, not {type(child).__name__}"
                );
            }
            raise TypeError(f'expected {expected} for field "{key}", got {child!r}');
        }
        validate_ast_schema(child);
    }
    for key in value_node._attributes {
        if key in ("lineno", "col_offset") and not hasattr(value_node, key) {
            raise TypeError(
                f'required field "{key}" missing from {type(value_node).__name__}'
            );
        }
        number = getattr(value_node, key, None);
        if number is not None {
            if not isinstance(number, int) {
                raise ValueError(f'invalid integer value: {number!r}');
            }
            if number < -(1 << 31) or number >= (1 << 31) {
                raise OverflowError("Python int too large to convert to C int");
            }
        }
    }
}

def validate_ast_positions(value_node: any) {
    line = value_node.lineno;
    col = value_node.col_offset;
    end_line = value_node.end_lineno if value_node.end_lineno is not None else line;
    end_col = value_node.end_col_offset
        if value_node.end_col_offset is not None
        else col;
    if line > end_line {
        raise ValueError(f"AST node line range ({line}, {end_line}) is not valid");
    }
    if (line < 0 and end_line != line) or (col < 0 and end_col != col) {
        raise ValueError(
            f"AST node column range ({col}, {end_col}) for line range ({line}, {end_line}) is not valid"
        );
    }
    if line == end_line and col > end_col {
        raise ValueError(f"line {line}, column {col}-{end_col} is not a valid range");
    }
}

def validate_ast_identifier(name: str, capture: bool = False) {
    if capture and name == "_" {
        raise ValueError("can't capture name '_' in patterns");
    }
    if name in ("True", "False", "None") {
        raise ValueError(f"identifier field can't represent '{name}' constant");
    }
}

def require_ast_items(value_node: any, field: str) {
    if not getattr(value_node, field) {
        raise ValueError(f"empty {field} on {type(value_node).__name__}");
    }
}

def validate_ast_list(
    items: list,
    context: str = "Load",
    kind: str = "expression",
    null_ok: bool = False,
    star_ok: bool = False
) {
    for item in items {
        if item is None {
            if not null_ok {
                raise ValueError(f"None disallowed in {kind} list");
            }
        } else {
            validate_ast_value(item, context, star_ok);
        }
    }
}

def ast_literal_number(
    value_node: any, real: bool = True, imaginary: bool = True
) -> bool {
    return isinstance(value_node, ast.Constant)
        and (
            (real and type(value_node.value) in (int, float))
            or (imaginary and type(value_node.value) is complex)
        );
}

def ast_literal_negative(
    value_node: any, real: bool = True, imaginary: bool = True
) -> bool {
    return isinstance(value_node, ast.UnaryOp)
        and isinstance(value_node.op, ast.USub)
        and ast_literal_number(value_node.operand, real, imaginary);
}

def validate_ast_pattern_value(value_node: any) {
    validate_ast_value(value_node);
    if isinstance(value_node, ast.Constant) {
        if type(value_node.value) not in (int, float, complex, str, bytes) {
            raise ValueError("unexpected constant inside of a literal pattern");
        }
        return;
    }
    if isinstance(value_node, (ast.Attribute, ast.JoinedStr, ast.TemplateStr))
        or ast_literal_negative(value_node) {
        return;
    }
    if isinstance(value_node, ast.BinOp)
        and isinstance(value_node.op, (ast.Add, ast.Sub))
        and (
            ast_literal_number(value_node.left, True, False)
            or ast_literal_negative(value_node.left, True, False)
        )
        and ast_literal_number(value_node.right, False, True) {
        return;
    }
    raise ValueError("patterns may only match literals and attribute lookups");
}

def validate_ast_constant(value: any) {
    if value is None
        or value is ...
        or type(value) in (bool, int, float, complex, str, bytes) {
        return;
    }
    if type(value) in (tuple, frozenset) {
        for item in value {
            validate_ast_constant(item);
        }
        return;
    }
    raise TypeError(f"got an invalid type in Constant: {type(value).__name__}");
}

def validate_ast_value(value_node: any, context: str = "Load", star_ok: bool = False) {
    if value_node is None {
        return;
    }
    if isinstance(
        value_node,
        (ast.expr, ast.stmt, ast.pattern, ast.arg, ast.excepthandler, ast.type_param)
    ) {
        validate_ast_positions(value_node);
    }
    if isinstance(value_node, ast.expr) {
        if isinstance(value_node, ast.Name) {
            validate_ast_identifier(value_node.id);
        }
        if isinstance(
            value_node,
            (ast.Name, ast.Attribute, ast.Subscript, ast.Starred, ast.List, ast.Tuple)
        ) {
            actual = type(value_node.ctx).__name__;
            if actual != context {
                raise ValueError(
                    f"expression must have {context} context but has {actual} instead"
                );
            }
        } elif context != "Load" {
            raise ValueError(
                f"expression which can't be assigned to in {context} context"
            );
        }
    }
    if isinstance(value_node, ast.Constant) {
        validate_ast_constant(value_node.value);
        return;
    }
    if isinstance(value_node, ast.BoolOp) and len(value_node.values) < 2 {
        raise ValueError("BoolOp with less than 2 values");
    }
    if isinstance(value_node, ast.Compare) {
        if not value_node.comparators {
            raise ValueError("Compare with no comparators");
        }
        if len(value_node.comparators) != len(value_node.ops) {
            raise ValueError(
                "Compare has a different number of comparators and operands"
            );
        }
    }
    if isinstance(value_node, ast.Dict)
        and len(value_node.keys) != len(value_node.values) {
        raise ValueError("Dict doesn't have the same number of keys as values");
    }
    if isinstance(
        value_node, (ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp)
    ) {
        if not value_node.generators {
            raise ValueError("comprehension with no generators");
        }
        validate_ast_list(value_node.generators);
    }
    if isinstance(value_node, ast.arguments) {
        validate_ast_list(value_node.posonlyargs);
        validate_ast_list(value_node.args);
        if value_node.vararg is not None {
            validate_ast_value(value_node.vararg.annotation);
        }
        validate_ast_list(value_node.kwonlyargs);
        if value_node.kwarg is not None {
            validate_ast_value(value_node.kwarg.annotation);
        }
        if len(value_node.defaults)
            > len(value_node.args) + len(value_node.posonlyargs) {
            raise ValueError("more positional defaults than args on arguments");
        }
        if len(value_node.kw_defaults) != len(value_node.kwonlyargs) {
            raise ValueError(
                "length of kwonlyargs is not the same as kw_defaults on arguments"
            );
        }
        validate_ast_list(value_node.defaults);
        validate_ast_list(value_node.kw_defaults, null_ok=True);
        return;
    }
    if isinstance(
        value_node,
        (
            ast.FunctionDef,
            ast.AsyncFunctionDef,
            ast.ClassDef,
            ast.For,
            ast.AsyncFor,
            ast.While,
            ast.If,
            ast.With,
            ast.AsyncWith,
            ast.Try,
            ast.TryStar,
            ast.ExceptHandler,
            ast.match_case
        )
    ) {
        require_ast_items(value_node, "body");
    }
    if isinstance(value_node, (ast.Assign, ast.Delete)) {
        require_ast_items(value_node, "targets");
    }
    if isinstance(value_node, (ast.Import, ast.ImportFrom, ast.Global, ast.Nonlocal)) {
        require_ast_items(value_node, "names");
    }
    if isinstance(value_node, (ast.With, ast.AsyncWith)) {
        require_ast_items(value_node, "items");
    }
    if isinstance(value_node, ast.Match) {
        require_ast_items(value_node, "cases");
    }
    if isinstance(value_node, ast.ImportFrom) and value_node.level < 0 {
        raise ValueError("Negative ImportFrom level");
    }
    if isinstance(value_node, ast.Raise)
        and value_node.exc is None
        and value_node.cause is not None {
        raise ValueError("Raise with cause but no exception");
    }
    if isinstance(value_node, (ast.Try, ast.TryStar)) {
        name = type(value_node).__name__;
        if not value_node.handlers and not value_node.finalbody {
            raise ValueError(f"{name} has neither except handlers nor finalbody");
        }
        if not value_node.handlers and value_node.orelse {
            raise ValueError(f"{name} has orelse but no except handlers");
        }
    }
    if isinstance(value_node, ast.NamedExpr) {
        if not isinstance(value_node.target, ast.Name) {
            raise TypeError("NamedExpr target must be a Name");
        }
        validate_ast_value(value_node.value);
        return;
    }
    if isinstance(value_node, ast.AnnAssign)
        and value_node.simple
        and not isinstance(value_node.target, ast.Name) {
        raise TypeError("AnnAssign with simple non-Name target");
    }
    if isinstance(value_node, ast.TypeAlias)
        and not isinstance(value_node.name, ast.Name) {
        raise TypeError("TypeAlias with non-Name name");
    }
    if isinstance(value_node, (ast.TypeVar, ast.TypeVarTuple, ast.ParamSpec)) {
        validate_ast_identifier(value_node.name);
    }
    if isinstance(value_node, ast.MatchValue) {
        validate_ast_pattern_value(value_node.value);
        return;
    }
    if isinstance(value_node, ast.MatchSingleton) {
        if value_node.value is not None and type(value_node.value) is not bool {
            raise ValueError("MatchSingleton can only contain True, False and None");
        }
        return;
    }
    if isinstance(value_node, ast.MatchMapping) {
        if len(value_node.keys) != len(value_node.patterns) {
            raise ValueError(
                "MatchMapping doesn't have the same number of keys as patterns"
            );
        }
        if value_node.rest is not None {
            validate_ast_identifier(value_node.rest, True);
        }
        for key in value_node.keys {
            if isinstance(key, ast.Constant)
                and (key.value is None or type(key.value) is bool) {
                continue;
            }
            validate_ast_pattern_value(key);
        }
    }
    if isinstance(value_node, ast.MatchClass) {
        if len(value_node.kwd_attrs) != len(value_node.kwd_patterns) {
            raise ValueError(
                "MatchClass doesn't have the same number of keyword attributes as patterns"
            );
        }
        cls = value_node.cls;
        while isinstance(cls, ast.Attribute) {
            cls = cls.value;
        }
        if not isinstance(cls, ast.Name) {
            raise ValueError(
                "MatchClass cls field can only contain Name or Attribute nodes."
            );
        }
        for name in value_node.kwd_attrs {
            validate_ast_identifier(name);
        }
    }
    if isinstance(value_node, (ast.MatchStar, ast.MatchAs)) {
        if value_node.name is not None {
            validate_ast_identifier(value_node.name, True);
        }
        if isinstance(value_node, ast.MatchStar) and not star_ok {
            raise ValueError("can't use MatchStar here");
        }
        if isinstance(value_node, ast.MatchAs)
            and value_node.pattern is not None
            and value_node.name is None {
            raise ValueError(
                "MatchAs must specify a target name if a pattern is given"
            );
        }
    }
    if isinstance(value_node, ast.MatchOr) and len(value_node.patterns) < 2 {
        raise ValueError("MatchOr requires at least 2 patterns");
    }
    for (key, child) in ast.iter_fields(value_node) {
        if key == "ctx"
            or (
                key == "generators"
                and isinstance(
                    value_node,
                    (ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp)
                )
            )
            or (key == "keys" and isinstance(value_node, ast.MatchMapping)) {
            continue;
        }
        child_context = "Load";
        if key == "targets" and isinstance(value_node, ast.Delete) {
            child_context = "Del";
        } elif (
            key == "target"
            and isinstance(
                value_node,
                (ast.AugAssign, ast.AnnAssign, ast.For, ast.AsyncFor, ast.comprehension)
            )
        )
            or (key == "targets" and isinstance(value_node, ast.Assign))
            or (key == "name" and isinstance(value_node, ast.TypeAlias))
            or (key == "optional_vars" and isinstance(value_node, ast.withitem)) {
            child_context = "Store";
        } elif (key == "elts" and isinstance(value_node, (ast.List, ast.Tuple)))
            or (key == "value" and isinstance(value_node, ast.Starred)) {
            child_context = context;
        }
        if isinstance(child, ast.AST) {
            validate_ast_value(child, child_context);
        } elif isinstance(child, list) {
            null_ok = (key == "keys" and isinstance(value_node, ast.Dict))
                or (key == "kw_defaults" and isinstance(value_node, ast.arguments))
                or key == "type_params";
            kind = "statement"
                if key in ("body", "orelse", "finalbody")
                else "expression";
            for item in child {
                if item is None {
                    if not null_ok {
                        raise ValueError(f"None disallowed in {kind} list");
                    }
                } elif isinstance(item, ast.AST) {
                    validate_ast_value(
                        item, child_context, isinstance(value_node, ast.MatchSequence)
                    );
                }
            }
        }
    }
}
