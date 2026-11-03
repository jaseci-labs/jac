# Feature-version checks for ASTs given to compile() with feature_version.

def validate_feature_version(value: any, version: int) {
    if version >= 14 {
        return;
    }
    if isinstance(value, list) {
        for item in value {
            validate_feature_version(item, version);
        }
        return;
    }
    if not isinstance(value, ast_node) {
        return;
    }
    minimum = 0;
    feature = "";
    if isinstance(value, AsyncFunctionDef) {
        minimum = 5;
        feature = "Async functions are";
    } elif isinstance(value, AsyncFor) {
        minimum = 5;
        feature = "Async for loops are";
    } elif isinstance(value, AsyncWith) {
        minimum = 5;
        feature = "Async with statements are";
    } elif isinstance(value, Await) {
        minimum = 5;
        feature = "Await expressions are";
    } elif isinstance(value, (BinOp, AugAssign)) and isinstance(value.op, MatMult) {
        minimum = 5;
        feature = "The '@' operator is";
    } elif isinstance(value, AnnAssign) {
        minimum = 6;
        feature = "Variable annotation syntax is";
    } elif isinstance(value, comprehension) and value.is_async {
        minimum = 6;
        feature = "Async comprehensions are";
    } elif isinstance(value, arguments) and value.posonlyargs {
        minimum = 8;
        feature = "Positional-only parameters are";
    } elif isinstance(value, NamedExpr) {
        minimum = 8;
        feature = "Assignment expressions are";
    } elif isinstance(value, Match) {
        minimum = 10;
        feature = "Pattern matching is";
    } elif isinstance(value, TryStar) {
        minimum = 11;
        feature = "Exception groups are";
    } elif isinstance(value, TypeAlias) {
        minimum = 12;
        feature = "Type statement is";
    } elif isinstance(value, TemplateStr) {
        minimum = 14;
        feature = "t-strings are";
    }
    if isinstance(value, (FunctionDef, AsyncFunctionDef, ClassDef))
        and value.type_params
        and minimum < 12 {
        minimum = 12;
        feature = "Type parameter lists are";
    }
    if isinstance(value, (TypeVar, TypeVarTuple, ParamSpec))
        and value.default_value is not None {
        minimum = 13;
        feature = "Type parameter defaults are";
    }
    if version < minimum {
        line = 1;
        column = 0;
        if isinstance(value, (stmt, expr, type_param)) {
            line = value.lineno;
            column = value.col_offset;
        }
        raise syntax_failure(
            f"{feature} only supported in Python 3.{minimum} and greater",
            filename="<unknown>",
            lineno=line,
            offset=column + 1
        );
    }
    visit_ast_children(value, feature_version_walk(version=version));
}

obj feature_version_walk(ast_child_visitor) {
    has version: int;

    def child(field: str, value: ast_node) {
        validate_feature_version(value, self.version);
    }
}
