"""Native validation of manually constructed ASTs after schema conversion."""

glob AST_KIND_NAMES: list[str] = [
         "Module",
         "Interactive",
         "Expression",
         "FunctionType",
         "FunctionDef",
         "AsyncFunctionDef",
         "ClassDef",
         "Return",
         "Delete",
         "Assign",
         "TypeAlias",
         "AugAssign",
         "AnnAssign",
         "For",
         "AsyncFor",
         "While",
         "If",
         "With",
         "AsyncWith",
         "Match",
         "Raise",
         "Try",
         "TryStar",
         "Assert",
         "Import",
         "ImportFrom",
         "Global",
         "Nonlocal",
         "Expr",
         "Pass",
         "Break",
         "Continue",
         "BoolOp",
         "NamedExpr",
         "BinOp",
         "UnaryOp",
         "Lambda",
         "IfExp",
         "Dict",
         "Set",
         "ListComp",
         "SetComp",
         "DictComp",
         "GeneratorExp",
         "Await",
         "Yield",
         "YieldFrom",
         "Compare",
         "Call",
         "FormattedValue",
         "Interpolation",
         "JoinedStr",
         "TemplateStr",
         "Constant",
         "Attribute",
         "Subscript",
         "Starred",
         "Name",
         "List",
         "Tuple",
         "Slice",
         "Load",
         "Store",
         "Del",
         "And",
         "Or",
         "Add",
         "Sub",
         "Mult",
         "MatMult",
         "Div",
         "Mod",
         "Pow",
         "LShift",
         "RShift",
         "BitOr",
         "BitXor",
         "BitAnd",
         "FloorDiv",
         "Invert",
         "Not",
         "UAdd",
         "USub",
         "Eq",
         "NotEq",
         "Lt",
         "LtE",
         "Gt",
         "GtE",
         "Is",
         "IsNot",
         "In",
         "NotIn",
         "comprehension",
         "ExceptHandler",
         "arguments",
         "arg",
         "keyword",
         "alias",
         "withitem",
         "match_case",
         "MatchValue",
         "MatchSingleton",
         "MatchSequence",
         "MatchMapping",
         "MatchClass",
         "MatchStar",
         "MatchAs",
         "MatchOr",
         "TypeIgnore",
         "TypeVar",
         "ParamSpec",
         "TypeVarTuple"
     ];

def ast_kind_name(value: ast_node) -> str {
    kind = value.node_kind().value;
    if kind >= 0 and kind < len(AST_KIND_NAMES) {
        return AST_KIND_NAMES[kind];
    }
    return "AST";
}

def ast_positions(value: ast_node) -> tuple[int, int, int, int] {
    kind = value.node_kind().value;
    if kind >= 32 and kind <= 60 {
        e = value as expr;
        return (
            e.lineno,
            e.col_offset,
            e.end_lineno if e.end_lineno is not None else e.lineno,
            e.end_col_offset if e.end_col_offset is not None else e.col_offset
        );
    }
    if kind >= 4 and kind <= 31 {
        st = value as stmt;
        return (
            st.lineno,
            st.col_offset,
            st.end_lineno if st.end_lineno is not None else st.lineno,
            st.end_col_offset if st.end_col_offset is not None else st.col_offset
        );
    }
    if isinstance(value, pattern) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, arg) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, excepthandler) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, type_param) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    return (0, 0, 0, 0);
}

def ast_has_items(value: ast_node, field: str) -> bool {
    if isinstance(value, Module) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Interactive) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, FunctionDef) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, AsyncFunctionDef) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, ClassDef) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Delete) {
        if field == "targets" {
            return len(value.targets) > 0;
        }
    }
    if isinstance(value, Assign) {
        if field == "targets" {
            return len(value.targets) > 0;
        }
    }
    if isinstance(value, For) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, AsyncFor) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, While) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, If) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, With) {
        if field == "items" {
            return len(value.items) > 0;
        }
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, AsyncWith) {
        if field == "items" {
            return len(value.items) > 0;
        }
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Match) {
        if field == "cases" {
            return len(value.cases) > 0;
        }
    }
    if isinstance(value, Try) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, TryStar) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Import) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, ImportFrom) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, Global) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, Nonlocal) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, ExceptHandler) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, match_case) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    return False;
}

def validate_ast_positions(value_node: ast_node) {
    (line, col, end_line, end_col) = ast_positions(value_node);
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

def require_ast_items(value_node: ast_node, field: str) {
    if not ast_has_items(value_node, field) {
        raise ValueError("empty " + field + " on " + ast_kind_name(value_node));
    }
}

def ast_literal_number(
    value_node: ast_node, real: bool = True, imaginary: bool = True
) -> bool {
    return isinstance(value_node, Constant)
        and (
            (real and isinstance(value_node.value, (PyInt, PyBigInt, PyFloat)))
            or (imaginary and isinstance(value_node.value, PyComplex))
        );
}

def ast_literal_negative(
    value_node: ast_node, real: bool = True, imaginary: bool = True
) -> bool {
    return isinstance(value_node, UnaryOp)
        and isinstance(value_node.op, USub)
        and ast_literal_number(value_node.operand, real, imaginary);
}

def validate_ast_pattern_value(value_node: ast_node) {
    validate_ast_value(value_node);
    if isinstance(value_node, Constant) {
        if not isinstance(
            value_node.value, (PyInt, PyBigInt, PyFloat, PyComplex, PyStr, PyBytes)
        ) {
            raise ValueError("unexpected constant inside of a literal pattern");
        }
        return;
    }
    if isinstance(value_node, (Attribute, JoinedStr, TemplateStr))
        or ast_literal_negative(value_node) {
        return;
    }
    if isinstance(value_node, BinOp)
        and isinstance(value_node.op, (Add, Sub))
        and (
            ast_literal_number(value_node.left, True, False)
            or ast_literal_negative(value_node.left, True, False)
        )
        and ast_literal_number(value_node.right, False, True) {
        return;
    }
    raise ValueError("patterns may only match literals and attribute lookups");
}

def validate_ast_constant(value: PyObj) {
    if isinstance(
        value,
        (
            PyNoneType,
            PyEllipsis,
            PyBool,
            PyInt,
            PyBigInt,
            PyFloat,
            PyComplex,
            PyStr,
            PyBytes
        )
    ) {
        return;
    }
    if isinstance(value, PyTuple) {
        for item in value.items {
            validate_ast_constant(item);
        }
        return;
    }
    if isinstance(value, PySet) and value.frozen {
        for item in value.items.values() {
            validate_ast_constant(item);
        }
        return;
    }
    raise TypeError("got an invalid type in Constant");
}

def validate_ast_value(
    value_node: ast_node | None, context: str = "Load", star_ok: bool = False
) {
    if value_node is None {
        return;
    }
    kind = value_node.node_kind();
    kind_value = kind.value;
    if (kind_value >= 4 and kind_value <= 60)
        or (kind_value >= 101 and kind_value <= 108)
        or (kind_value >= 110 and kind_value <= 112)
        or kind == ast_kind.ExceptHandler
        or kind == ast_kind.arg {
        validate_ast_positions(value_node);
    }
    if kind_value >= 32 and kind_value <= 60 {
        if (kind == ast_kind.Name and isinstance(value_node, Name)) {
            validate_ast_identifier(value_node.id);
        }
        if (
            (
                kind == ast_kind.Name
                or kind == ast_kind.Attribute
                or kind == ast_kind.Subscript
                or kind == ast_kind.Starred
                or kind == ast_kind.List
                or kind == ast_kind.Tuple
            )
            and isinstance(
                value_node, (Name, Attribute, Subscript, Starred, List, Tuple)
            )
        ) {
            actual = ast_kind_name(value_node.ctx);
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
    if (kind == ast_kind.Constant and isinstance(value_node, Constant)) {
        validate_ast_constant(value_node.value);
        return;
    }
    if (kind == ast_kind.BoolOp and isinstance(value_node, BoolOp))
        and len(value_node.values) < 2 {
        raise ValueError("BoolOp with less than 2 values");
    }
    if (kind == ast_kind.Compare and isinstance(value_node, Compare)) {
        if not value_node.comparators {
            raise ValueError("Compare with no comparators");
        }
        if len(value_node.comparators) != len(value_node.ops) {
            raise ValueError(
                "Compare has a different number of comparators and operands"
            );
        }
    }
    if (kind == ast_kind.Dict and isinstance(value_node, Dict))
        and len(value_node.keys) != len(value_node.values) {
        raise ValueError("Dict doesn't have the same number of keys as values");
    }
    if (
        (
            kind == ast_kind.ListComp
            or kind == ast_kind.SetComp
            or kind == ast_kind.GeneratorExp
            or kind == ast_kind.DictComp
        )
        and isinstance(value_node, (ListComp, SetComp, GeneratorExp, DictComp))
    ) {
        if not value_node.generators {
            raise ValueError("comprehension with no generators");
        }
        for item in value_node.generators {
            validate_ast_value(item);
        }
    }
    if (kind == ast_kind.arguments and isinstance(value_node, arguments)) {
        for item in value_node.posonlyargs {
            validate_ast_value(item);
        }
        for item in value_node.args {
            validate_ast_value(item);
        }
        if value_node.vararg is not None {
            validate_ast_value(value_node.vararg.annotation);
        }
        for item in value_node.kwonlyargs {
            validate_ast_value(item);
        }
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
        for item in value_node.defaults {
            validate_ast_value(item);
        }
        for item in value_node.kw_defaults {
            validate_ast_value(item);
        }
        return;
    }
    if isinstance(
        value_node,
        (
            FunctionDef,
            AsyncFunctionDef,
            ClassDef,
            For,
            AsyncFor,
            While,
            If,
            With,
            AsyncWith,
            Try,
            TryStar,
            ExceptHandler,
            match_case
        )
    ) {
        require_ast_items(value_node, "body");
    }
    if (
        (kind == ast_kind.Assign or kind == ast_kind.Delete)
        and isinstance(value_node, (Assign, Delete))
    ) {
        require_ast_items(value_node, "targets");
    }
    if (
        (
            kind == ast_kind.Import
            or kind == ast_kind.ImportFrom
            or kind == ast_kind.Global
            or kind == ast_kind.Nonlocal
        )
        and isinstance(value_node, (Import, ImportFrom, Global, Nonlocal))
    ) {
        require_ast_items(value_node, "names");
    }
    if (
        (kind == ast_kind.With or kind == ast_kind.AsyncWith)
        and isinstance(value_node, (With, AsyncWith))
    ) {
        require_ast_items(value_node, "items");
    }
    if (kind == ast_kind.Match and isinstance(value_node, Match)) {
        require_ast_items(value_node, "cases");
    }
    if (kind == ast_kind.ImportFrom and isinstance(value_node, ImportFrom))
        and (value_node.level or 0) < 0 {
        raise ValueError("Negative ImportFrom level");
    }
    if (kind == ast_kind.Raise and isinstance(value_node, Raise))
        and value_node.exc is None
        and value_node.cause is not None {
        raise ValueError("Raise with cause but no exception");
    }
    if (
        (kind == ast_kind.Try or kind == ast_kind.TryStar)
        and isinstance(value_node, (Try, TryStar))
    ) {
        name = ast_kind_name(value_node);
        if not value_node.handlers and not value_node.finalbody {
            raise ValueError(f"{name} has neither except handlers nor finalbody");
        }
        if not value_node.handlers and value_node.orelse {
            raise ValueError(f"{name} has orelse but no except handlers");
        }
    }
    if (kind == ast_kind.NamedExpr and isinstance(value_node, NamedExpr)) {
        if not isinstance(value_node.target, Name) {
            raise TypeError("NamedExpr target must be a Name");
        }
        validate_ast_value(value_node.value);
        return;
    }
    if (kind == ast_kind.AnnAssign and isinstance(value_node, AnnAssign))
        and value_node.simple
        and not isinstance(value_node.target, Name) {
        raise TypeError("AnnAssign with simple non-Name target");
    }
    if (kind == ast_kind.TypeAlias and isinstance(value_node, TypeAlias))
        and not isinstance(value_node.name, Name) {
        raise TypeError("TypeAlias with non-Name name");
    }
    if (
        (
            kind == ast_kind.TypeVar
            or kind == ast_kind.TypeVarTuple
            or kind == ast_kind.ParamSpec
        )
        and isinstance(value_node, (TypeVar, TypeVarTuple, ParamSpec))
    ) {
        validate_ast_identifier(value_node.name);
    }
    if (kind == ast_kind.MatchValue and isinstance(value_node, MatchValue)) {
        validate_ast_pattern_value(value_node.value);
        return;
    }
    if (kind == ast_kind.MatchSingleton and isinstance(value_node, MatchSingleton)) {
        if not isinstance(value_node.value, (PyNoneType, PyBool)) {
            raise ValueError("MatchSingleton can only contain True, False and None");
        }
        return;
    }
    if (kind == ast_kind.MatchMapping and isinstance(value_node, MatchMapping)) {
        if len(value_node.keys) != len(value_node.patterns) {
            raise ValueError(
                "MatchMapping doesn't have the same number of keys as patterns"
            );
        }
        if value_node.rest is not None {
            validate_ast_identifier(value_node.rest, True);
        }
        for key in value_node.keys {
            if isinstance(key, Constant)
                and (isinstance(key.value, (PyNoneType, PyBool))) {
                continue;
            }
            validate_ast_pattern_value(key);
        }
    }
    if (kind == ast_kind.MatchClass and isinstance(value_node, MatchClass)) {
        if len(value_node.kwd_attrs) != len(value_node.kwd_patterns) {
            raise ValueError(
                "MatchClass doesn't have the same number of keyword attributes as patterns"
            );
        }
        cls = value_node.cls;
        while isinstance(cls, Attribute) {
            cls = cls.value;
        }
        if not isinstance(cls, Name) {
            raise ValueError(
                "MatchClass cls field can only contain Name or Attribute nodes."
            );
        }
        for name in value_node.kwd_attrs {
            validate_ast_identifier(name);
        }
    }
    if (
        (kind == ast_kind.MatchStar or kind == ast_kind.MatchAs)
        and isinstance(value_node, (MatchStar, MatchAs))
    ) {
        if value_node.name is not None {
            validate_ast_identifier(value_node.name, True);
        }
        if (kind == ast_kind.MatchStar and isinstance(value_node, MatchStar))
            and not star_ok {
            raise ValueError("can't use MatchStar here");
        }
        if (kind == ast_kind.MatchAs and isinstance(value_node, MatchAs))
            and value_node.pattern is not None
            and value_node.name is None {
            raise ValueError(
                "MatchAs must specify a target name if a pattern is given"
            );
        }
    }
    if (kind == ast_kind.MatchOr and isinstance(value_node, MatchOr))
        and len(value_node.patterns) < 2 {
        raise ValueError("MatchOr requires at least 2 patterns");
    }
    visit_ast_children(
        value_node, ast_value_children(owner=value_node, context=context)
    );
}

# Expression context each child of `owner` must carry (Python/ast.c validate).
obj ast_value_children(ast_child_visitor) {
    has owner: ast_node,
        context: str;

    def child(field: str, value: ast_node) {
        kind = self.owner.node_kind();
        if (
            (
                kind == ast_kind.Name
                or kind == ast_kind.Attribute
                or kind == ast_kind.Subscript
                or kind == ast_kind.Starred
                or kind == ast_kind.List
                or kind == ast_kind.Tuple
            )
            and field == "ctx"
        )
            or (
                (
                    kind == ast_kind.ListComp
                    or kind == ast_kind.SetComp
                    or kind == ast_kind.GeneratorExp
                    or kind == ast_kind.DictComp
                )
                and field == "generators"
            )
            or (kind == ast_kind.MatchMapping and field == "keys") {
            return;
        }
        child_context = "Load";
        if kind == ast_kind.Delete and field == "targets" {
            child_context = "Del";
        } elif (
            (
                kind == ast_kind.AugAssign
                or kind == ast_kind.AnnAssign
                or kind == ast_kind.For
                or kind == ast_kind.AsyncFor
                or kind == ast_kind.comprehension
            )
            and field == "target"
        )
            or (kind == ast_kind.Assign and field == "targets")
            or (kind == ast_kind.TypeAlias and field == "name")
            or (kind == ast_kind.withitem and field == "optional_vars") {
            child_context = "Store";
        } elif ((kind == ast_kind.List or kind == ast_kind.Tuple) and field == "elts")
            or (kind == ast_kind.Starred and field == "value") {
            child_context = self.context;
        }
        validate_ast_value(value, child_context, kind == ast_kind.MatchSequence);
    }
}
