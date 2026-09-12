# Explicit AST field traversal for the native compiler.
import from jaclang.compiler.frontend.python.ast_nodes {
    AnnAssign,
    Assert,
    Assign,
    AsyncFor,
    AsyncFunctionDef,
    AsyncWith,
    Attribute,
    AugAssign,
    Await,
    BinOp,
    BoolOp,
    Call,
    ClassDef,
    Compare,
    Delete,
    Dict,
    DictComp,
    ExceptHandler,
    Expr,
    Expression,
    For,
    FormattedValue,
    FunctionDef,
    FunctionType,
    GeneratorExp,
    If,
    IfExp,
    Import,
    ImportFrom,
    Interactive,
    Interpolation,
    JoinedStr,
    Lambda,
    List,
    ListComp,
    Match,
    MatchAs,
    MatchClass,
    MatchMapping,
    MatchOr,
    MatchSequence,
    MatchValue,
    Module,
    Name,
    NamedExpr,
    ParamSpec,
    Raise,
    Return,
    Set,
    SetComp,
    Slice,
    Starred,
    Subscript,
    TemplateStr,
    Try,
    TryStar,
    Tuple,
    TypeAlias,
    TypeVar,
    TypeVarTuple,
    UnaryOp,
    While,
    With,
    Yield,
    YieldFrom,
    arg,
    arguments,
    ast_node,
    comprehension,
    excepthandler,
    keyword,
    match_case,
    withitem,
    alias,
    boolop,
    cmpop,
    expr,
    expr_context,
    operator,
    pattern,
    stmt,
    type_ignore,
    type_param,
    unaryop,
}

obj ast_child {
    has field: str,
        value: ast_node;
}

def ast_children(value: ast_node) -> list[ast_child] {
    children: list[ast_child] = [];
    if isinstance(value, Module) {
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.type_ignores {
            children.append(ast_child(field="type_ignores", value=child));
        }
        return children;
    }
    if isinstance(value, Interactive) {
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        return children;
    }
    if isinstance(value, Expression) {
        children.append(ast_child(field="body", value=value.body));
        return children;
    }
    if isinstance(value, FunctionType) {
        for child in value.argtypes {
            children.append(ast_child(field="argtypes", value=child));
        }
        children.append(ast_child(field="returns", value=value.returns));
        return children;
    }
    if isinstance(value, FunctionDef) {
        children.append(ast_child(field="args", value=value.args));
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.decorator_list {
            children.append(ast_child(field="decorator_list", value=child));
        }
        if value.returns is not None {
            children.append(ast_child(field="returns", value=value.returns));
        }
        for child in value.type_params {
            children.append(ast_child(field="type_params", value=child));
        }
        return children;
    }
    if isinstance(value, AsyncFunctionDef) {
        children.append(ast_child(field="args", value=value.args));
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.decorator_list {
            children.append(ast_child(field="decorator_list", value=child));
        }
        if value.returns is not None {
            children.append(ast_child(field="returns", value=value.returns));
        }
        for child in value.type_params {
            children.append(ast_child(field="type_params", value=child));
        }
        return children;
    }
    if isinstance(value, ClassDef) {
        for child in value.bases {
            children.append(ast_child(field="bases", value=child));
        }
        for child in value.keywords {
            children.append(ast_child(field="keywords", value=child));
        }
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.decorator_list {
            children.append(ast_child(field="decorator_list", value=child));
        }
        for child in value.type_params {
            children.append(ast_child(field="type_params", value=child));
        }
        return children;
    }
    if isinstance(value, Return) {
        if value.value is not None {
            children.append(ast_child(field="value", value=value.value));
        }
        return children;
    }
    if isinstance(value, Delete) {
        for child in value.targets {
            children.append(ast_child(field="targets", value=child));
        }
        return children;
    }
    if isinstance(value, Assign) {
        for child in value.targets {
            children.append(ast_child(field="targets", value=child));
        }
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, TypeAlias) {
        children.append(ast_child(field="name", value=value.name));
        for child in value.type_params {
            children.append(ast_child(field="type_params", value=child));
        }
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, AugAssign) {
        children.append(ast_child(field="target", value=value.target));
        children.append(ast_child(field="op", value=value.op));
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, AnnAssign) {
        children.append(ast_child(field="target", value=value.target));
        children.append(ast_child(field="annotation", value=value.annotation));
        if value.value is not None {
            children.append(ast_child(field="value", value=value.value));
        }
        return children;
    }
    if isinstance(value, For) {
        children.append(ast_child(field="target", value=value.target));
        children.append(ast_child(field="iter", value=value.iter));
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.orelse {
            children.append(ast_child(field="orelse", value=child));
        }
        return children;
    }
    if isinstance(value, AsyncFor) {
        children.append(ast_child(field="target", value=value.target));
        children.append(ast_child(field="iter", value=value.iter));
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.orelse {
            children.append(ast_child(field="orelse", value=child));
        }
        return children;
    }
    if isinstance(value, While) {
        children.append(ast_child(field="test", value=value.`test));
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.orelse {
            children.append(ast_child(field="orelse", value=child));
        }
        return children;
    }
    if isinstance(value, If) {
        children.append(ast_child(field="test", value=value.`test));
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.orelse {
            children.append(ast_child(field="orelse", value=child));
        }
        return children;
    }
    if isinstance(value, With) {
        for child in value.items {
            children.append(ast_child(field="items", value=child));
        }
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        return children;
    }
    if isinstance(value, AsyncWith) {
        for child in value.items {
            children.append(ast_child(field="items", value=child));
        }
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        return children;
    }
    if isinstance(value, Match) {
        children.append(ast_child(field="subject", value=value.subject));
        for child in value.cases {
            children.append(ast_child(field="cases", value=child));
        }
        return children;
    }
    if isinstance(value, Raise) {
        if value.exc is not None {
            children.append(ast_child(field="exc", value=value.exc));
        }
        if value.cause is not None {
            children.append(ast_child(field="cause", value=value.cause));
        }
        return children;
    }
    if isinstance(value, Try) {
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.handlers {
            children.append(ast_child(field="handlers", value=child));
        }
        for child in value.orelse {
            children.append(ast_child(field="orelse", value=child));
        }
        for child in value.finalbody {
            children.append(ast_child(field="finalbody", value=child));
        }
        return children;
    }
    if isinstance(value, TryStar) {
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        for child in value.handlers {
            children.append(ast_child(field="handlers", value=child));
        }
        for child in value.orelse {
            children.append(ast_child(field="orelse", value=child));
        }
        for child in value.finalbody {
            children.append(ast_child(field="finalbody", value=child));
        }
        return children;
    }
    if isinstance(value, Assert) {
        children.append(ast_child(field="test", value=value.`test));
        if value.msg is not None {
            children.append(ast_child(field="msg", value=value.msg));
        }
        return children;
    }
    if isinstance(value, Import) {
        for child in value.names {
            children.append(ast_child(field="names", value=child));
        }
        return children;
    }
    if isinstance(value, ImportFrom) {
        for child in value.names {
            children.append(ast_child(field="names", value=child));
        }
        return children;
    }
    if isinstance(value, Expr) {
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, BoolOp) {
        children.append(ast_child(field="op", value=value.op));
        for child in value.values {
            children.append(ast_child(field="values", value=child));
        }
        return children;
    }
    if isinstance(value, NamedExpr) {
        children.append(ast_child(field="target", value=value.target));
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, BinOp) {
        children.append(ast_child(field="left", value=value.left));
        children.append(ast_child(field="op", value=value.op));
        children.append(ast_child(field="right", value=value.right));
        return children;
    }
    if isinstance(value, UnaryOp) {
        children.append(ast_child(field="op", value=value.op));
        children.append(ast_child(field="operand", value=value.operand));
        return children;
    }
    if isinstance(value, Lambda) {
        children.append(ast_child(field="args", value=value.args));
        children.append(ast_child(field="body", value=value.body));
        return children;
    }
    if isinstance(value, IfExp) {
        children.append(ast_child(field="test", value=value.`test));
        children.append(ast_child(field="body", value=value.body));
        children.append(ast_child(field="orelse", value=value.orelse));
        return children;
    }
    if isinstance(value, Dict) {
        for child in value.keys {
            if child is None {
                continue;
            }
            children.append(ast_child(field="keys", value=child));
        }
        for child in value.values {
            children.append(ast_child(field="values", value=child));
        }
        return children;
    }
    if isinstance(value, Set) {
        for child in value.elts {
            children.append(ast_child(field="elts", value=child));
        }
        return children;
    }
    if isinstance(value, ListComp) {
        children.append(ast_child(field="elt", value=value.elt));
        for child in value.generators {
            children.append(ast_child(field="generators", value=child));
        }
        return children;
    }
    if isinstance(value, SetComp) {
        children.append(ast_child(field="elt", value=value.elt));
        for child in value.generators {
            children.append(ast_child(field="generators", value=child));
        }
        return children;
    }
    if isinstance(value, DictComp) {
        children.append(ast_child(field="key", value=value.key));
        children.append(ast_child(field="value", value=value.value));
        for child in value.generators {
            children.append(ast_child(field="generators", value=child));
        }
        return children;
    }
    if isinstance(value, GeneratorExp) {
        children.append(ast_child(field="elt", value=value.elt));
        for child in value.generators {
            children.append(ast_child(field="generators", value=child));
        }
        return children;
    }
    if isinstance(value, Await) {
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, Yield) {
        if value.value is not None {
            children.append(ast_child(field="value", value=value.value));
        }
        return children;
    }
    if isinstance(value, YieldFrom) {
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, Compare) {
        children.append(ast_child(field="left", value=value.left));
        for child in value.ops {
            children.append(ast_child(field="ops", value=child));
        }
        for child in value.comparators {
            children.append(ast_child(field="comparators", value=child));
        }
        return children;
    }
    if isinstance(value, Call) {
        children.append(ast_child(field="func", value=value.func));
        for child in value.args {
            children.append(ast_child(field="args", value=child));
        }
        for child in value.keywords {
            children.append(ast_child(field="keywords", value=child));
        }
        return children;
    }
    if isinstance(value, FormattedValue) {
        children.append(ast_child(field="value", value=value.value));
        if value.format_spec is not None {
            children.append(ast_child(field="format_spec", value=value.format_spec));
        }
        return children;
    }
    if isinstance(value, Interpolation) {
        children.append(ast_child(field="value", value=value.value));
        if value.format_spec is not None {
            children.append(ast_child(field="format_spec", value=value.format_spec));
        }
        return children;
    }
    if isinstance(value, JoinedStr) {
        for child in value.values {
            children.append(ast_child(field="values", value=child));
        }
        return children;
    }
    if isinstance(value, TemplateStr) {
        for child in value.values {
            children.append(ast_child(field="values", value=child));
        }
        return children;
    }
    if isinstance(value, Attribute) {
        children.append(ast_child(field="value", value=value.value));
        children.append(ast_child(field="ctx", value=value.ctx));
        return children;
    }
    if isinstance(value, Subscript) {
        children.append(ast_child(field="value", value=value.value));
        children.append(ast_child(field="slice", value=value.slice));
        children.append(ast_child(field="ctx", value=value.ctx));
        return children;
    }
    if isinstance(value, Starred) {
        children.append(ast_child(field="value", value=value.value));
        children.append(ast_child(field="ctx", value=value.ctx));
        return children;
    }
    if isinstance(value, Name) {
        children.append(ast_child(field="ctx", value=value.ctx));
        return children;
    }
    if isinstance(value, List) {
        for child in value.elts {
            children.append(ast_child(field="elts", value=child));
        }
        children.append(ast_child(field="ctx", value=value.ctx));
        return children;
    }
    if isinstance(value, Tuple) {
        for child in value.elts {
            children.append(ast_child(field="elts", value=child));
        }
        children.append(ast_child(field="ctx", value=value.ctx));
        return children;
    }
    if isinstance(value, Slice) {
        if value.lower is not None {
            children.append(ast_child(field="lower", value=value.lower));
        }
        if value.upper is not None {
            children.append(ast_child(field="upper", value=value.upper));
        }
        if value.step is not None {
            children.append(ast_child(field="step", value=value.step));
        }
        return children;
    }
    if isinstance(value, comprehension) {
        children.append(ast_child(field="target", value=value.target));
        children.append(ast_child(field="iter", value=value.iter));
        for child in value.ifs {
            children.append(ast_child(field="ifs", value=child));
        }
        return children;
    }
    if isinstance(value, excepthandler) {
        if value.type is not None {
            children.append(ast_child(field="type", value=value.type));
        }
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        return children;
    }
    if isinstance(value, ExceptHandler) {
        if value.type is not None {
            children.append(ast_child(field="type", value=value.type));
        }
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        return children;
    }
    if isinstance(value, arguments) {
        for child in value.posonlyargs {
            children.append(ast_child(field="posonlyargs", value=child));
        }
        for child in value.args {
            children.append(ast_child(field="args", value=child));
        }
        if value.vararg is not None {
            children.append(ast_child(field="vararg", value=value.vararg));
        }
        for child in value.kwonlyargs {
            children.append(ast_child(field="kwonlyargs", value=child));
        }
        for child in value.kw_defaults {
            if child is None {
                continue;
            }
            children.append(ast_child(field="kw_defaults", value=child));
        }
        if value.kwarg is not None {
            children.append(ast_child(field="kwarg", value=value.kwarg));
        }
        for child in value.defaults {
            children.append(ast_child(field="defaults", value=child));
        }
        return children;
    }
    if isinstance(value, arg) {
        if value.annotation is not None {
            children.append(ast_child(field="annotation", value=value.annotation));
        }
        return children;
    }
    if isinstance(value, keyword) {
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, withitem) {
        children.append(ast_child(field="context_expr", value=value.context_expr));
        if value.optional_vars is not None {
            children.append(
                ast_child(field="optional_vars", value=value.optional_vars)
            );
        }
        return children;
    }
    if isinstance(value, match_case) {
        children.append(ast_child(field="pattern", value=value.pattern));
        if value.guard is not None {
            children.append(ast_child(field="guard", value=value.guard));
        }
        for child in value.body {
            children.append(ast_child(field="body", value=child));
        }
        return children;
    }
    if isinstance(value, MatchValue) {
        children.append(ast_child(field="value", value=value.value));
        return children;
    }
    if isinstance(value, MatchSequence) {
        for child in value.patterns {
            children.append(ast_child(field="patterns", value=child));
        }
        return children;
    }
    if isinstance(value, MatchMapping) {
        for child in value.keys {
            children.append(ast_child(field="keys", value=child));
        }
        for child in value.patterns {
            children.append(ast_child(field="patterns", value=child));
        }
        return children;
    }
    if isinstance(value, MatchClass) {
        children.append(ast_child(field="cls", value=value.cls));
        for child in value.patterns {
            children.append(ast_child(field="patterns", value=child));
        }
        for child in value.kwd_patterns {
            children.append(ast_child(field="kwd_patterns", value=child));
        }
        return children;
    }
    if isinstance(value, MatchAs) {
        if value.pattern is not None {
            children.append(ast_child(field="pattern", value=value.pattern));
        }
        return children;
    }
    if isinstance(value, MatchOr) {
        for child in value.patterns {
            children.append(ast_child(field="patterns", value=child));
        }
        return children;
    }
    if isinstance(value, TypeVar) {
        if value.bound is not None {
            children.append(ast_child(field="bound", value=value.bound));
        }
        if value.default_value is not None {
            children.append(
                ast_child(field="default_value", value=value.default_value)
            );
        }
        return children;
    }
    if isinstance(value, ParamSpec) {
        if value.default_value is not None {
            children.append(
                ast_child(field="default_value", value=value.default_value)
            );
        }
        return children;
    }
    if isinstance(value, TypeVarTuple) {
        if value.default_value is not None {
            children.append(
                ast_child(field="default_value", value=value.default_value)
            );
        }
        return children;
    }
    return children;
}

# A typed visitor can rewrite child fields without Python getattr/setattr.
# The explicit base reserves a dispatch slot when this module is compiled
# independently of the modules declaring concrete visitors.
obj ast_visitor {}

obj ast_rewriter(ast_visitor) {
    def transform(value: ast_node) -> ast_node {
        return value;
    }
    def visit_field(owner: ast_node, field: str) -> bool {
        return True;
    }
}

def rewrite_ast_children(value: ast_node, visitor: ast_rewriter) {
    child: expr | None = None;
    if isinstance(value, Module) {
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "type_ignores") {
            for index in range(len(value.type_ignores)) {
                value.type_ignores[index] = visitor.transform(
                    value.type_ignores[index]
                ) as type_ignore;
            }
        }
        return;
    }
    if isinstance(value, Interactive) {
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, Expression) {
        if visitor.visit_field(value, "body") {
            value.body = visitor.transform(value.body) as expr;
        }
        return;
    }
    if isinstance(value, FunctionType) {
        if visitor.visit_field(value, "argtypes") {
            for index in range(len(value.argtypes)) {
                value.argtypes[index] = visitor.transform(
                    value.argtypes[index]
                ) as expr;
            }
        }
        if visitor.visit_field(value, "returns") {
            value.returns = visitor.transform(value.returns) as expr;
        }
        return;
    }
    if isinstance(value, FunctionDef) {
        if visitor.visit_field(value, "args") {
            value.args = visitor.transform(value.args) as arguments;
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "decorator_list") {
            for index in range(len(value.decorator_list)) {
                value.decorator_list[index] = visitor.transform(
                    value.decorator_list[index]
                ) as expr;
            }
        }
        if visitor.visit_field(value, "returns") {
            if value.returns is not None {
                value.returns = visitor.transform(value.returns) as expr;
            }
        }
        if visitor.visit_field(value, "type_params") {
            for index in range(len(value.type_params)) {
                value.type_params[index] = visitor.transform(
                    value.type_params[index]
                ) as type_param;
            }
        }
        return;
    }
    if isinstance(value, AsyncFunctionDef) {
        if visitor.visit_field(value, "args") {
            value.args = visitor.transform(value.args) as arguments;
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "decorator_list") {
            for index in range(len(value.decorator_list)) {
                value.decorator_list[index] = visitor.transform(
                    value.decorator_list[index]
                ) as expr;
            }
        }
        if visitor.visit_field(value, "returns") {
            if value.returns is not None {
                value.returns = visitor.transform(value.returns) as expr;
            }
        }
        if visitor.visit_field(value, "type_params") {
            for index in range(len(value.type_params)) {
                value.type_params[index] = visitor.transform(
                    value.type_params[index]
                ) as type_param;
            }
        }
        return;
    }
    if isinstance(value, ClassDef) {
        if visitor.visit_field(value, "bases") {
            for index in range(len(value.bases)) {
                value.bases[index] = visitor.transform(value.bases[index]) as expr;
            }
        }
        if visitor.visit_field(value, "keywords") {
            for index in range(len(value.keywords)) {
                value.keywords[index] = visitor.transform(
                    value.keywords[index]
                ) as keyword;
            }
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "decorator_list") {
            for index in range(len(value.decorator_list)) {
                value.decorator_list[index] = visitor.transform(
                    value.decorator_list[index]
                ) as expr;
            }
        }
        if visitor.visit_field(value, "type_params") {
            for index in range(len(value.type_params)) {
                value.type_params[index] = visitor.transform(
                    value.type_params[index]
                ) as type_param;
            }
        }
        return;
    }
    if isinstance(value, Return) {
        if visitor.visit_field(value, "value") {
            if value.value is not None {
                value.value = visitor.transform(value.value) as expr;
            }
        }
        return;
    }
    if isinstance(value, Delete) {
        if visitor.visit_field(value, "targets") {
            for index in range(len(value.targets)) {
                value.targets[index] = visitor.transform(value.targets[index]) as expr;
            }
        }
        return;
    }
    if isinstance(value, Assign) {
        if visitor.visit_field(value, "targets") {
            for index in range(len(value.targets)) {
                value.targets[index] = visitor.transform(value.targets[index]) as expr;
            }
        }
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, TypeAlias) {
        if visitor.visit_field(value, "name") {
            value.name = visitor.transform(value.name) as expr;
        }
        if visitor.visit_field(value, "type_params") {
            for index in range(len(value.type_params)) {
                value.type_params[index] = visitor.transform(
                    value.type_params[index]
                ) as type_param;
            }
        }
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, AugAssign) {
        if visitor.visit_field(value, "target") {
            value.target = visitor.transform(value.target) as expr;
        }
        if visitor.visit_field(value, "op") {
            value.op = visitor.transform(value.op) as operator;
        }
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, AnnAssign) {
        if visitor.visit_field(value, "target") {
            value.target = visitor.transform(value.target) as expr;
        }
        if visitor.visit_field(value, "annotation") {
            value.annotation = visitor.transform(value.annotation) as expr;
        }
        if visitor.visit_field(value, "value") {
            if value.value is not None {
                value.value = visitor.transform(value.value) as expr;
            }
        }
        return;
    }
    if isinstance(value, For) {
        if visitor.visit_field(value, "target") {
            value.target = visitor.transform(value.target) as expr;
        }
        if visitor.visit_field(value, "iter") {
            value.iter = visitor.transform(value.iter) as expr;
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "orelse") {
            for index in range(len(value.orelse)) {
                value.orelse[index] = visitor.transform(value.orelse[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, AsyncFor) {
        if visitor.visit_field(value, "target") {
            value.target = visitor.transform(value.target) as expr;
        }
        if visitor.visit_field(value, "iter") {
            value.iter = visitor.transform(value.iter) as expr;
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "orelse") {
            for index in range(len(value.orelse)) {
                value.orelse[index] = visitor.transform(value.orelse[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, While) {
        if visitor.visit_field(value, "test") {
            value.`test = visitor.transform(value.`test) as expr;
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "orelse") {
            for index in range(len(value.orelse)) {
                value.orelse[index] = visitor.transform(value.orelse[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, If) {
        if visitor.visit_field(value, "test") {
            value.`test = visitor.transform(value.`test) as expr;
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "orelse") {
            for index in range(len(value.orelse)) {
                value.orelse[index] = visitor.transform(value.orelse[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, With) {
        if visitor.visit_field(value, "items") {
            for index in range(len(value.items)) {
                value.items[index] = visitor.transform(value.items[index]) as withitem;
            }
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, AsyncWith) {
        if visitor.visit_field(value, "items") {
            for index in range(len(value.items)) {
                value.items[index] = visitor.transform(value.items[index]) as withitem;
            }
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, Match) {
        if visitor.visit_field(value, "subject") {
            value.subject = visitor.transform(value.subject) as expr;
        }
        if visitor.visit_field(value, "cases") {
            for index in range(len(value.cases)) {
                value.cases[index] = visitor.transform(
                    value.cases[index]
                ) as match_case;
            }
        }
        return;
    }
    if isinstance(value, Raise) {
        if visitor.visit_field(value, "exc") {
            if value.exc is not None {
                value.exc = visitor.transform(value.exc) as expr;
            }
        }
        if visitor.visit_field(value, "cause") {
            if value.cause is not None {
                value.cause = visitor.transform(value.cause) as expr;
            }
        }
        return;
    }
    if isinstance(value, Try) {
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "handlers") {
            for index in range(len(value.handlers)) {
                value.handlers[index] = visitor.transform(
                    value.handlers[index]
                ) as excepthandler;
            }
        }
        if visitor.visit_field(value, "orelse") {
            for index in range(len(value.orelse)) {
                value.orelse[index] = visitor.transform(value.orelse[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "finalbody") {
            for index in range(len(value.finalbody)) {
                value.finalbody[index] = visitor.transform(
                    value.finalbody[index]
                ) as stmt;
            }
        }
        return;
    }
    if isinstance(value, TryStar) {
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "handlers") {
            for index in range(len(value.handlers)) {
                value.handlers[index] = visitor.transform(
                    value.handlers[index]
                ) as excepthandler;
            }
        }
        if visitor.visit_field(value, "orelse") {
            for index in range(len(value.orelse)) {
                value.orelse[index] = visitor.transform(value.orelse[index]) as stmt;
            }
        }
        if visitor.visit_field(value, "finalbody") {
            for index in range(len(value.finalbody)) {
                value.finalbody[index] = visitor.transform(
                    value.finalbody[index]
                ) as stmt;
            }
        }
        return;
    }
    if isinstance(value, Assert) {
        if visitor.visit_field(value, "test") {
            value.`test = visitor.transform(value.`test) as expr;
        }
        if visitor.visit_field(value, "msg") {
            if value.msg is not None {
                value.msg = visitor.transform(value.msg) as expr;
            }
        }
        return;
    }
    if isinstance(value, Import) {
        if visitor.visit_field(value, "names") {
            for index in range(len(value.names)) {
                value.names[index] = visitor.transform(value.names[index]) as alias;
            }
        }
        return;
    }
    if isinstance(value, ImportFrom) {
        if visitor.visit_field(value, "names") {
            for index in range(len(value.names)) {
                value.names[index] = visitor.transform(value.names[index]) as alias;
            }
        }
        return;
    }
    if isinstance(value, Expr) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, BoolOp) {
        if visitor.visit_field(value, "op") {
            value.op = visitor.transform(value.op) as boolop;
        }
        if visitor.visit_field(value, "values") {
            for index in range(len(value.values)) {
                value.values[index] = visitor.transform(value.values[index]) as expr;
            }
        }
        return;
    }
    if isinstance(value, NamedExpr) {
        if visitor.visit_field(value, "target") {
            value.target = visitor.transform(value.target) as expr;
        }
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, BinOp) {
        if visitor.visit_field(value, "left") {
            value.left = visitor.transform(value.left) as expr;
        }
        if visitor.visit_field(value, "op") {
            value.op = visitor.transform(value.op) as operator;
        }
        if visitor.visit_field(value, "right") {
            value.right = visitor.transform(value.right) as expr;
        }
        return;
    }
    if isinstance(value, UnaryOp) {
        if visitor.visit_field(value, "op") {
            value.op = visitor.transform(value.op) as unaryop;
        }
        if visitor.visit_field(value, "operand") {
            value.operand = visitor.transform(value.operand) as expr;
        }
        return;
    }
    if isinstance(value, Lambda) {
        if visitor.visit_field(value, "args") {
            value.args = visitor.transform(value.args) as arguments;
        }
        if visitor.visit_field(value, "body") {
            value.body = visitor.transform(value.body) as expr;
        }
        return;
    }
    if isinstance(value, IfExp) {
        if visitor.visit_field(value, "test") {
            value.`test = visitor.transform(value.`test) as expr;
        }
        if visitor.visit_field(value, "body") {
            value.body = visitor.transform(value.body) as expr;
        }
        if visitor.visit_field(value, "orelse") {
            value.orelse = visitor.transform(value.orelse) as expr;
        }
        return;
    }
    if isinstance(value, Dict) {
        if visitor.visit_field(value, "keys") {
            for index in range(len(value.keys)) {
                child = value.keys[index];
                if child is None {
                    continue;
                }
                value.keys[index] = visitor.transform(child) as expr;
            }
        }
        if visitor.visit_field(value, "values") {
            for index in range(len(value.values)) {
                value.values[index] = visitor.transform(value.values[index]) as expr;
            }
        }
        return;
    }
    if isinstance(value, Set) {
        if visitor.visit_field(value, "elts") {
            for index in range(len(value.elts)) {
                value.elts[index] = visitor.transform(value.elts[index]) as expr;
            }
        }
        return;
    }
    if isinstance(value, ListComp) {
        if visitor.visit_field(value, "elt") {
            value.elt = visitor.transform(value.elt) as expr;
        }
        if visitor.visit_field(value, "generators") {
            for index in range(len(value.generators)) {
                value.generators[index] = visitor.transform(
                    value.generators[index]
                ) as comprehension;
            }
        }
        return;
    }
    if isinstance(value, SetComp) {
        if visitor.visit_field(value, "elt") {
            value.elt = visitor.transform(value.elt) as expr;
        }
        if visitor.visit_field(value, "generators") {
            for index in range(len(value.generators)) {
                value.generators[index] = visitor.transform(
                    value.generators[index]
                ) as comprehension;
            }
        }
        return;
    }
    if isinstance(value, DictComp) {
        if visitor.visit_field(value, "key") {
            value.key = visitor.transform(value.key) as expr;
        }
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "generators") {
            for index in range(len(value.generators)) {
                value.generators[index] = visitor.transform(
                    value.generators[index]
                ) as comprehension;
            }
        }
        return;
    }
    if isinstance(value, GeneratorExp) {
        if visitor.visit_field(value, "elt") {
            value.elt = visitor.transform(value.elt) as expr;
        }
        if visitor.visit_field(value, "generators") {
            for index in range(len(value.generators)) {
                value.generators[index] = visitor.transform(
                    value.generators[index]
                ) as comprehension;
            }
        }
        return;
    }
    if isinstance(value, Await) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, Yield) {
        if visitor.visit_field(value, "value") {
            if value.value is not None {
                value.value = visitor.transform(value.value) as expr;
            }
        }
        return;
    }
    if isinstance(value, YieldFrom) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, Compare) {
        if visitor.visit_field(value, "left") {
            value.left = visitor.transform(value.left) as expr;
        }
        if visitor.visit_field(value, "ops") {
            for index in range(len(value.ops)) {
                value.ops[index] = visitor.transform(value.ops[index]) as cmpop;
            }
        }
        if visitor.visit_field(value, "comparators") {
            for index in range(len(value.comparators)) {
                value.comparators[index] = visitor.transform(
                    value.comparators[index]
                ) as expr;
            }
        }
        return;
    }
    if isinstance(value, Call) {
        if visitor.visit_field(value, "func") {
            value.func = visitor.transform(value.func) as expr;
        }
        if visitor.visit_field(value, "args") {
            for index in range(len(value.args)) {
                value.args[index] = visitor.transform(value.args[index]) as expr;
            }
        }
        if visitor.visit_field(value, "keywords") {
            for index in range(len(value.keywords)) {
                value.keywords[index] = visitor.transform(
                    value.keywords[index]
                ) as keyword;
            }
        }
        return;
    }
    if isinstance(value, FormattedValue) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "format_spec") {
            if value.format_spec is not None {
                value.format_spec = visitor.transform(value.format_spec) as expr;
            }
        }
        return;
    }
    if isinstance(value, Interpolation) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "format_spec") {
            if value.format_spec is not None {
                value.format_spec = visitor.transform(value.format_spec) as expr;
            }
        }
        return;
    }
    if isinstance(value, JoinedStr) {
        if visitor.visit_field(value, "values") {
            for index in range(len(value.values)) {
                value.values[index] = visitor.transform(value.values[index]) as expr;
            }
        }
        return;
    }
    if isinstance(value, TemplateStr) {
        if visitor.visit_field(value, "values") {
            for index in range(len(value.values)) {
                value.values[index] = visitor.transform(value.values[index]) as expr;
            }
        }
        return;
    }
    if isinstance(value, Attribute) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if isinstance(value, Subscript) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "slice") {
            value.slice = visitor.transform(value.slice) as expr;
        }
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if isinstance(value, Starred) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if isinstance(value, Name) {
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if isinstance(value, List) {
        if visitor.visit_field(value, "elts") {
            for index in range(len(value.elts)) {
                value.elts[index] = visitor.transform(value.elts[index]) as expr;
            }
        }
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if isinstance(value, Tuple) {
        if visitor.visit_field(value, "elts") {
            for index in range(len(value.elts)) {
                value.elts[index] = visitor.transform(value.elts[index]) as expr;
            }
        }
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if isinstance(value, Slice) {
        if visitor.visit_field(value, "lower") {
            if value.lower is not None {
                value.lower = visitor.transform(value.lower) as expr;
            }
        }
        if visitor.visit_field(value, "upper") {
            if value.upper is not None {
                value.upper = visitor.transform(value.upper) as expr;
            }
        }
        if visitor.visit_field(value, "step") {
            if value.step is not None {
                value.step = visitor.transform(value.step) as expr;
            }
        }
        return;
    }
    if isinstance(value, comprehension) {
        if visitor.visit_field(value, "target") {
            value.target = visitor.transform(value.target) as expr;
        }
        if visitor.visit_field(value, "iter") {
            value.iter = visitor.transform(value.iter) as expr;
        }
        if visitor.visit_field(value, "ifs") {
            for index in range(len(value.ifs)) {
                value.ifs[index] = visitor.transform(value.ifs[index]) as expr;
            }
        }
        return;
    }
    if isinstance(value, excepthandler) {
        if visitor.visit_field(value, "type") {
            if value.type is not None {
                value.type = visitor.transform(value.type) as expr;
            }
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, ExceptHandler) {
        if visitor.visit_field(value, "type") {
            if value.type is not None {
                value.type = visitor.transform(value.type) as expr;
            }
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, arguments) {
        if visitor.visit_field(value, "posonlyargs") {
            for index in range(len(value.posonlyargs)) {
                value.posonlyargs[index] = visitor.transform(
                    value.posonlyargs[index]
                ) as arg;
            }
        }
        if visitor.visit_field(value, "args") {
            for index in range(len(value.args)) {
                value.args[index] = visitor.transform(value.args[index]) as arg;
            }
        }
        if visitor.visit_field(value, "vararg") {
            if value.vararg is not None {
                value.vararg = visitor.transform(value.vararg) as arg;
            }
        }
        if visitor.visit_field(value, "kwonlyargs") {
            for index in range(len(value.kwonlyargs)) {
                value.kwonlyargs[index] = visitor.transform(
                    value.kwonlyargs[index]
                ) as arg;
            }
        }
        if visitor.visit_field(value, "kw_defaults") {
            for index in range(len(value.kw_defaults)) {
                child = value.kw_defaults[index];
                if child is None {
                    continue;
                }
                value.kw_defaults[index] = visitor.transform(child) as expr;
            }
        }
        if visitor.visit_field(value, "kwarg") {
            if value.kwarg is not None {
                value.kwarg = visitor.transform(value.kwarg) as arg;
            }
        }
        if visitor.visit_field(value, "defaults") {
            for index in range(len(value.defaults)) {
                value.defaults[index] = visitor.transform(
                    value.defaults[index]
                ) as expr;
            }
        }
        return;
    }
    if isinstance(value, arg) {
        if visitor.visit_field(value, "annotation") {
            if value.annotation is not None {
                value.annotation = visitor.transform(value.annotation) as expr;
            }
        }
        return;
    }
    if isinstance(value, keyword) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, withitem) {
        if visitor.visit_field(value, "context_expr") {
            value.context_expr = visitor.transform(value.context_expr) as expr;
        }
        if visitor.visit_field(value, "optional_vars") {
            if value.optional_vars is not None {
                value.optional_vars = visitor.transform(value.optional_vars) as expr;
            }
        }
        return;
    }
    if isinstance(value, match_case) {
        if visitor.visit_field(value, "pattern") {
            value.pattern = visitor.transform(value.pattern) as pattern;
        }
        if visitor.visit_field(value, "guard") {
            if value.guard is not None {
                value.guard = visitor.transform(value.guard) as expr;
            }
        }
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        return;
    }
    if isinstance(value, MatchValue) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if isinstance(value, MatchSequence) {
        if visitor.visit_field(value, "patterns") {
            for index in range(len(value.patterns)) {
                value.patterns[index] = visitor.transform(
                    value.patterns[index]
                ) as pattern;
            }
        }
        return;
    }
    if isinstance(value, MatchMapping) {
        if visitor.visit_field(value, "keys") {
            for index in range(len(value.keys)) {
                value.keys[index] = visitor.transform(value.keys[index]) as expr;
            }
        }
        if visitor.visit_field(value, "patterns") {
            for index in range(len(value.patterns)) {
                value.patterns[index] = visitor.transform(
                    value.patterns[index]
                ) as pattern;
            }
        }
        return;
    }
    if isinstance(value, MatchClass) {
        if visitor.visit_field(value, "cls") {
            value.cls = visitor.transform(value.cls) as expr;
        }
        if visitor.visit_field(value, "patterns") {
            for index in range(len(value.patterns)) {
                value.patterns[index] = visitor.transform(
                    value.patterns[index]
                ) as pattern;
            }
        }
        if visitor.visit_field(value, "kwd_patterns") {
            for index in range(len(value.kwd_patterns)) {
                value.kwd_patterns[index] = visitor.transform(
                    value.kwd_patterns[index]
                ) as pattern;
            }
        }
        return;
    }
    if isinstance(value, MatchAs) {
        if visitor.visit_field(value, "pattern") {
            if value.pattern is not None {
                value.pattern = visitor.transform(value.pattern) as pattern;
            }
        }
        return;
    }
    if isinstance(value, MatchOr) {
        if visitor.visit_field(value, "patterns") {
            for index in range(len(value.patterns)) {
                value.patterns[index] = visitor.transform(
                    value.patterns[index]
                ) as pattern;
            }
        }
        return;
    }
    if isinstance(value, TypeVar) {
        if visitor.visit_field(value, "bound") {
            if value.bound is not None {
                value.bound = visitor.transform(value.bound) as expr;
            }
        }
        if visitor.visit_field(value, "default_value") {
            if value.default_value is not None {
                value.default_value = visitor.transform(value.default_value) as expr;
            }
        }
        return;
    }
    if isinstance(value, ParamSpec) {
        if visitor.visit_field(value, "default_value") {
            if value.default_value is not None {
                value.default_value = visitor.transform(value.default_value) as expr;
            }
        }
        return;
    }
    if isinstance(value, TypeVarTuple) {
        if visitor.visit_field(value, "default_value") {
            if value.default_value is not None {
                value.default_value = visitor.transform(value.default_value) as expr;
            }
        }
        return;
    }
}
