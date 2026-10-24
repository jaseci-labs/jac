obj ast_child_visitor {
    def child(field: str, value: ast_node) abst;
}

obj ast_child_buffer(ast_child_visitor) {
    has fields: list[str] = [],
        nodes: list[ast_node] = [];

    def child(field: str, value: ast_node);
    def collect(value: ast_node) -> int;
}

def visit_ast_children(value: ast_node, visitor: ast_child_visitor);

obj ast_visitor {}

obj ast_rewriter(ast_visitor) {
    def transform(value: ast_node) -> ast_node;
    def visit_field(owner: ast_node, field: str) -> bool;
}

def rewrite_ast_children(value: ast_node, visitor: ast_rewriter);

impl ast_child_buffer.child(field: str, value: ast_node) {
    self.fields.append(field);
    self.nodes.append(value);
}

impl ast_child_buffer.collect(value: ast_node) -> int {
    self.fields.clear();
    self.nodes.clear();
    visit_ast_children(value, self);
    return len(self.nodes);
}

impl visit_ast_children(value: ast_node, visitor: ast_child_visitor) {
    kind = value.kind();
    if kind == ast_kind.Module and isinstance(value, Module) {
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.type_ignores {
            visitor.child("type_ignores", child);
        }
        return;
    }
    if kind == ast_kind.Interactive and isinstance(value, Interactive) {
        for child in value.body {
            visitor.child("body", child);
        }
        return;
    }
    if kind == ast_kind.Expression and isinstance(value, Expression) {
        visitor.child("body", value.body);
        return;
    }
    if kind == ast_kind.FunctionType and isinstance(value, FunctionType) {
        for child in value.argtypes {
            visitor.child("argtypes", child);
        }
        visitor.child("returns", value.returns);
        return;
    }
    if kind == ast_kind.FunctionDef and isinstance(value, FunctionDef) {
        visitor.child("args", value.args);
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.decorator_list {
            visitor.child("decorator_list", child);
        }
        if value.returns is not None {
            visitor.child("returns", value.returns);
        }
        for child in value.type_params {
            visitor.child("type_params", child);
        }
        return;
    }
    if kind == ast_kind.AsyncFunctionDef and isinstance(value, AsyncFunctionDef) {
        visitor.child("args", value.args);
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.decorator_list {
            visitor.child("decorator_list", child);
        }
        if value.returns is not None {
            visitor.child("returns", value.returns);
        }
        for child in value.type_params {
            visitor.child("type_params", child);
        }
        return;
    }
    if kind == ast_kind.ClassDef and isinstance(value, ClassDef) {
        for child in value.bases {
            visitor.child("bases", child);
        }
        for child in value.keywords {
            visitor.child("keywords", child);
        }
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.decorator_list {
            visitor.child("decorator_list", child);
        }
        for child in value.type_params {
            visitor.child("type_params", child);
        }
        return;
    }
    if kind == ast_kind.Return and isinstance(value, Return) {
        if value.value is not None {
            visitor.child("value", value.value);
        }
        return;
    }
    if kind == ast_kind.Delete and isinstance(value, Delete) {
        for child in value.targets {
            visitor.child("targets", child);
        }
        return;
    }
    if kind == ast_kind.Assign and isinstance(value, Assign) {
        for child in value.targets {
            visitor.child("targets", child);
        }
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.TypeAlias and isinstance(value, TypeAlias) {
        visitor.child("name", value.name);
        for child in value.type_params {
            visitor.child("type_params", child);
        }
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.AugAssign and isinstance(value, AugAssign) {
        visitor.child("target", value.target);
        visitor.child("op", value.op);
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.AnnAssign and isinstance(value, AnnAssign) {
        visitor.child("target", value.target);
        visitor.child("annotation", value.annotation);
        if value.value is not None {
            visitor.child("value", value.value);
        }
        return;
    }
    if kind == ast_kind.For and isinstance(value, For) {
        visitor.child("target", value.target);
        visitor.child("iter", value.iter);
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.orelse {
            visitor.child("orelse", child);
        }
        return;
    }
    if kind == ast_kind.AsyncFor and isinstance(value, AsyncFor) {
        visitor.child("target", value.target);
        visitor.child("iter", value.iter);
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.orelse {
            visitor.child("orelse", child);
        }
        return;
    }
    if kind == ast_kind.While and isinstance(value, While) {
        visitor.child("test", value.`test);
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.orelse {
            visitor.child("orelse", child);
        }
        return;
    }
    if kind == ast_kind.If and isinstance(value, If) {
        visitor.child("test", value.`test);
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.orelse {
            visitor.child("orelse", child);
        }
        return;
    }
    if kind == ast_kind.With and isinstance(value, With) {
        for child in value.items {
            visitor.child("items", child);
        }
        for child in value.body {
            visitor.child("body", child);
        }
        return;
    }
    if kind == ast_kind.AsyncWith and isinstance(value, AsyncWith) {
        for child in value.items {
            visitor.child("items", child);
        }
        for child in value.body {
            visitor.child("body", child);
        }
        return;
    }
    if kind == ast_kind.Match and isinstance(value, Match) {
        visitor.child("subject", value.subject);
        for child in value.cases {
            visitor.child("cases", child);
        }
        return;
    }
    if kind == ast_kind.Raise and isinstance(value, Raise) {
        if value.exc is not None {
            visitor.child("exc", value.exc);
        }
        if value.cause is not None {
            visitor.child("cause", value.cause);
        }
        return;
    }
    if kind == ast_kind.Try and isinstance(value, Try) {
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.handlers {
            visitor.child("handlers", child);
        }
        for child in value.orelse {
            visitor.child("orelse", child);
        }
        for child in value.finalbody {
            visitor.child("finalbody", child);
        }
        return;
    }
    if kind == ast_kind.TryStar and isinstance(value, TryStar) {
        for child in value.body {
            visitor.child("body", child);
        }
        for child in value.handlers {
            visitor.child("handlers", child);
        }
        for child in value.orelse {
            visitor.child("orelse", child);
        }
        for child in value.finalbody {
            visitor.child("finalbody", child);
        }
        return;
    }
    if kind == ast_kind.Assert and isinstance(value, Assert) {
        visitor.child("test", value.`test);
        if value.msg is not None {
            visitor.child("msg", value.msg);
        }
        return;
    }
    if kind == ast_kind.Import and isinstance(value, Import) {
        for child in value.names {
            visitor.child("names", child);
        }
        return;
    }
    if kind == ast_kind.ImportFrom and isinstance(value, ImportFrom) {
        for child in value.names {
            visitor.child("names", child);
        }
        return;
    }
    if kind == ast_kind.Expr and isinstance(value, Expr) {
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.BoolOp and isinstance(value, BoolOp) {
        visitor.child("op", value.op);
        for child in value.values {
            visitor.child("values", child);
        }
        return;
    }
    if kind == ast_kind.NamedExpr and isinstance(value, NamedExpr) {
        visitor.child("target", value.target);
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.BinOp and isinstance(value, BinOp) {
        visitor.child("left", value.left);
        visitor.child("op", value.op);
        visitor.child("right", value.right);
        return;
    }
    if kind == ast_kind.UnaryOp and isinstance(value, UnaryOp) {
        visitor.child("op", value.op);
        visitor.child("operand", value.operand);
        return;
    }
    if kind == ast_kind.Lambda and isinstance(value, Lambda) {
        visitor.child("args", value.args);
        visitor.child("body", value.body);
        return;
    }
    if kind == ast_kind.IfExp and isinstance(value, IfExp) {
        visitor.child("test", value.`test);
        visitor.child("body", value.body);
        visitor.child("orelse", value.orelse);
        return;
    }
    if kind == ast_kind.Dict and isinstance(value, Dict) {
        for child in value.keys {
            if child is None {
                continue;
            }
            visitor.child("keys", child);
        }
        for child in value.values {
            visitor.child("values", child);
        }
        return;
    }
    if kind == ast_kind.Set and isinstance(value, Set) {
        for child in value.elts {
            visitor.child("elts", child);
        }
        return;
    }
    if kind == ast_kind.ListComp and isinstance(value, ListComp) {
        visitor.child("elt", value.elt);
        for child in value.generators {
            visitor.child("generators", child);
        }
        return;
    }
    if kind == ast_kind.SetComp and isinstance(value, SetComp) {
        visitor.child("elt", value.elt);
        for child in value.generators {
            visitor.child("generators", child);
        }
        return;
    }
    if kind == ast_kind.DictComp and isinstance(value, DictComp) {
        visitor.child("key", value.key);
        visitor.child("value", value.value);
        for child in value.generators {
            visitor.child("generators", child);
        }
        return;
    }
    if kind == ast_kind.GeneratorExp and isinstance(value, GeneratorExp) {
        visitor.child("elt", value.elt);
        for child in value.generators {
            visitor.child("generators", child);
        }
        return;
    }
    if kind == ast_kind.Await and isinstance(value, Await) {
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.Yield and isinstance(value, Yield) {
        if value.value is not None {
            visitor.child("value", value.value);
        }
        return;
    }
    if kind == ast_kind.YieldFrom and isinstance(value, YieldFrom) {
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.Compare and isinstance(value, Compare) {
        visitor.child("left", value.left);
        for child in value.ops {
            visitor.child("ops", child);
        }
        for child in value.comparators {
            visitor.child("comparators", child);
        }
        return;
    }
    if kind == ast_kind.Call and isinstance(value, Call) {
        visitor.child("func", value.func);
        for child in value.args {
            visitor.child("args", child);
        }
        for child in value.keywords {
            visitor.child("keywords", child);
        }
        return;
    }
    if kind == ast_kind.FormattedValue and isinstance(value, FormattedValue) {
        visitor.child("value", value.value);
        if value.format_spec is not None {
            visitor.child("format_spec", value.format_spec);
        }
        return;
    }
    if kind == ast_kind.Interpolation and isinstance(value, Interpolation) {
        visitor.child("value", value.value);
        if value.format_spec is not None {
            visitor.child("format_spec", value.format_spec);
        }
        return;
    }
    if kind == ast_kind.JoinedStr and isinstance(value, JoinedStr) {
        for child in value.values {
            visitor.child("values", child);
        }
        return;
    }
    if kind == ast_kind.TemplateStr and isinstance(value, TemplateStr) {
        for child in value.values {
            visitor.child("values", child);
        }
        return;
    }
    if kind == ast_kind.Attribute and isinstance(value, Attribute) {
        visitor.child("value", value.value);
        visitor.child("ctx", value.ctx);
        return;
    }
    if kind == ast_kind.Subscript and isinstance(value, Subscript) {
        visitor.child("value", value.value);
        visitor.child("slice", value.slice);
        visitor.child("ctx", value.ctx);
        return;
    }
    if kind == ast_kind.Starred and isinstance(value, Starred) {
        visitor.child("value", value.value);
        visitor.child("ctx", value.ctx);
        return;
    }
    if kind == ast_kind.Name and isinstance(value, Name) {
        visitor.child("ctx", value.ctx);
        return;
    }
    if kind == ast_kind.List and isinstance(value, List) {
        for child in value.elts {
            visitor.child("elts", child);
        }
        visitor.child("ctx", value.ctx);
        return;
    }
    if kind == ast_kind.Tuple and isinstance(value, Tuple) {
        for child in value.elts {
            visitor.child("elts", child);
        }
        visitor.child("ctx", value.ctx);
        return;
    }
    if kind == ast_kind.Slice and isinstance(value, Slice) {
        if value.lower is not None {
            visitor.child("lower", value.lower);
        }
        if value.upper is not None {
            visitor.child("upper", value.upper);
        }
        if value.step is not None {
            visitor.child("step", value.step);
        }
        return;
    }
    if kind == ast_kind.comprehension and isinstance(value, comprehension) {
        visitor.child("target", value.target);
        visitor.child("iter", value.iter);
        for child in value.ifs {
            visitor.child("ifs", child);
        }
        return;
    }
    if isinstance(value, excepthandler) {
        if value.type is not None {
            visitor.child("type", value.type);
        }
        for child in value.body {
            visitor.child("body", child);
        }
        return;
    }
    if kind == ast_kind.ExceptHandler and isinstance(value, ExceptHandler) {
        if value.type is not None {
            visitor.child("type", value.type);
        }
        for child in value.body {
            visitor.child("body", child);
        }
        return;
    }
    if kind == ast_kind.arguments and isinstance(value, arguments) {
        for child in value.posonlyargs {
            visitor.child("posonlyargs", child);
        }
        for child in value.args {
            visitor.child("args", child);
        }
        if value.vararg is not None {
            visitor.child("vararg", value.vararg);
        }
        for child in value.kwonlyargs {
            visitor.child("kwonlyargs", child);
        }
        for child in value.kw_defaults {
            if child is None {
                continue;
            }
            visitor.child("kw_defaults", child);
        }
        if value.kwarg is not None {
            visitor.child("kwarg", value.kwarg);
        }
        for child in value.defaults {
            visitor.child("defaults", child);
        }
        return;
    }
    if kind == ast_kind.arg and isinstance(value, arg) {
        if value.annotation is not None {
            visitor.child("annotation", value.annotation);
        }
        return;
    }
    if kind == ast_kind.keyword and isinstance(value, keyword) {
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.withitem and isinstance(value, withitem) {
        visitor.child("context_expr", value.context_expr);
        if value.optional_vars is not None {
            visitor.child("optional_vars", value.optional_vars);
        }
        return;
    }
    if kind == ast_kind.match_case and isinstance(value, match_case) {
        visitor.child("pattern", value.pattern);
        if value.guard is not None {
            visitor.child("guard", value.guard);
        }
        for child in value.body {
            visitor.child("body", child);
        }
        return;
    }
    if kind == ast_kind.MatchValue and isinstance(value, MatchValue) {
        visitor.child("value", value.value);
        return;
    }
    if kind == ast_kind.MatchSequence and isinstance(value, MatchSequence) {
        for child in value.patterns {
            visitor.child("patterns", child);
        }
        return;
    }
    if kind == ast_kind.MatchMapping and isinstance(value, MatchMapping) {
        for child in value.keys {
            visitor.child("keys", child);
        }
        for child in value.patterns {
            visitor.child("patterns", child);
        }
        return;
    }
    if kind == ast_kind.MatchClass and isinstance(value, MatchClass) {
        visitor.child("cls", value.cls);
        for child in value.patterns {
            visitor.child("patterns", child);
        }
        for child in value.kwd_patterns {
            visitor.child("kwd_patterns", child);
        }
        return;
    }
    if kind == ast_kind.MatchAs and isinstance(value, MatchAs) {
        if value.pattern is not None {
            visitor.child("pattern", value.pattern);
        }
        return;
    }
    if kind == ast_kind.MatchOr and isinstance(value, MatchOr) {
        for child in value.patterns {
            visitor.child("patterns", child);
        }
        return;
    }
    if kind == ast_kind.TypeVar and isinstance(value, TypeVar) {
        if value.bound is not None {
            visitor.child("bound", value.bound);
        }
        if value.default_value is not None {
            visitor.child("default_value", value.default_value);
        }
        return;
    }
    if kind == ast_kind.ParamSpec and isinstance(value, ParamSpec) {
        if value.default_value is not None {
            visitor.child("default_value", value.default_value);
        }
        return;
    }
    if kind == ast_kind.TypeVarTuple and isinstance(value, TypeVarTuple) {
        if value.default_value is not None {
            visitor.child("default_value", value.default_value);
        }
        return;
    }
    return;
}

impl ast_rewriter.transform(value: ast_node) -> ast_node {
    return value;
}

impl ast_rewriter.visit_field(owner: ast_node, field: str) -> bool {
    return True;
}

impl rewrite_ast_children(value: ast_node, visitor: ast_rewriter) {
    kind = value.kind();
    child: expr | None = None;
    if kind == ast_kind.Module and isinstance(value, Module) {
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
    if kind == ast_kind.Interactive and isinstance(value, Interactive) {
        if visitor.visit_field(value, "body") {
            for index in range(len(value.body)) {
                value.body[index] = visitor.transform(value.body[index]) as stmt;
            }
        }
        return;
    }
    if kind == ast_kind.Expression and isinstance(value, Expression) {
        if visitor.visit_field(value, "body") {
            value.body = visitor.transform(value.body) as expr;
        }
        return;
    }
    if kind == ast_kind.FunctionType and isinstance(value, FunctionType) {
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
    if kind == ast_kind.FunctionDef and isinstance(value, FunctionDef) {
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
    if kind == ast_kind.AsyncFunctionDef and isinstance(value, AsyncFunctionDef) {
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
    if kind == ast_kind.ClassDef and isinstance(value, ClassDef) {
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
    if kind == ast_kind.Return and isinstance(value, Return) {
        if visitor.visit_field(value, "value") {
            if value.value is not None {
                value.value = visitor.transform(value.value) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.Delete and isinstance(value, Delete) {
        if visitor.visit_field(value, "targets") {
            for index in range(len(value.targets)) {
                value.targets[index] = visitor.transform(value.targets[index]) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.Assign and isinstance(value, Assign) {
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
    if kind == ast_kind.TypeAlias and isinstance(value, TypeAlias) {
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
    if kind == ast_kind.AugAssign and isinstance(value, AugAssign) {
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
    if kind == ast_kind.AnnAssign and isinstance(value, AnnAssign) {
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
    if kind == ast_kind.For and isinstance(value, For) {
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
    if kind == ast_kind.AsyncFor and isinstance(value, AsyncFor) {
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
    if kind == ast_kind.While and isinstance(value, While) {
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
    if kind == ast_kind.If and isinstance(value, If) {
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
    if kind == ast_kind.With and isinstance(value, With) {
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
    if kind == ast_kind.AsyncWith and isinstance(value, AsyncWith) {
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
    if kind == ast_kind.Match and isinstance(value, Match) {
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
    if kind == ast_kind.Raise and isinstance(value, Raise) {
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
    if kind == ast_kind.Try and isinstance(value, Try) {
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
    if kind == ast_kind.TryStar and isinstance(value, TryStar) {
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
    if kind == ast_kind.Assert and isinstance(value, Assert) {
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
    if kind == ast_kind.Import and isinstance(value, Import) {
        if visitor.visit_field(value, "names") {
            for index in range(len(value.names)) {
                value.names[index] = visitor.transform(value.names[index]) as alias;
            }
        }
        return;
    }
    if kind == ast_kind.ImportFrom and isinstance(value, ImportFrom) {
        if visitor.visit_field(value, "names") {
            for index in range(len(value.names)) {
                value.names[index] = visitor.transform(value.names[index]) as alias;
            }
        }
        return;
    }
    if kind == ast_kind.Expr and isinstance(value, Expr) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if kind == ast_kind.BoolOp and isinstance(value, BoolOp) {
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
    if kind == ast_kind.NamedExpr and isinstance(value, NamedExpr) {
        if visitor.visit_field(value, "target") {
            value.target = visitor.transform(value.target) as expr;
        }
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if kind == ast_kind.BinOp and isinstance(value, BinOp) {
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
    if kind == ast_kind.UnaryOp and isinstance(value, UnaryOp) {
        if visitor.visit_field(value, "op") {
            value.op = visitor.transform(value.op) as unaryop;
        }
        if visitor.visit_field(value, "operand") {
            value.operand = visitor.transform(value.operand) as expr;
        }
        return;
    }
    if kind == ast_kind.Lambda and isinstance(value, Lambda) {
        if visitor.visit_field(value, "args") {
            value.args = visitor.transform(value.args) as arguments;
        }
        if visitor.visit_field(value, "body") {
            value.body = visitor.transform(value.body) as expr;
        }
        return;
    }
    if kind == ast_kind.IfExp and isinstance(value, IfExp) {
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
    if kind == ast_kind.Dict and isinstance(value, Dict) {
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
    if kind == ast_kind.Set and isinstance(value, Set) {
        if visitor.visit_field(value, "elts") {
            for index in range(len(value.elts)) {
                value.elts[index] = visitor.transform(value.elts[index]) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.ListComp and isinstance(value, ListComp) {
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
    if kind == ast_kind.SetComp and isinstance(value, SetComp) {
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
    if kind == ast_kind.DictComp and isinstance(value, DictComp) {
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
    if kind == ast_kind.GeneratorExp and isinstance(value, GeneratorExp) {
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
    if kind == ast_kind.Await and isinstance(value, Await) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if kind == ast_kind.Yield and isinstance(value, Yield) {
        if visitor.visit_field(value, "value") {
            if value.value is not None {
                value.value = visitor.transform(value.value) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.YieldFrom and isinstance(value, YieldFrom) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if kind == ast_kind.Compare and isinstance(value, Compare) {
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
    if kind == ast_kind.Call and isinstance(value, Call) {
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
    if kind == ast_kind.FormattedValue and isinstance(value, FormattedValue) {
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
    if kind == ast_kind.Interpolation and isinstance(value, Interpolation) {
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
    if kind == ast_kind.JoinedStr and isinstance(value, JoinedStr) {
        if visitor.visit_field(value, "values") {
            for index in range(len(value.values)) {
                value.values[index] = visitor.transform(value.values[index]) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.TemplateStr and isinstance(value, TemplateStr) {
        if visitor.visit_field(value, "values") {
            for index in range(len(value.values)) {
                value.values[index] = visitor.transform(value.values[index]) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.Attribute and isinstance(value, Attribute) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if kind == ast_kind.Subscript and isinstance(value, Subscript) {
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
    if kind == ast_kind.Starred and isinstance(value, Starred) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if kind == ast_kind.Name and isinstance(value, Name) {
        if visitor.visit_field(value, "ctx") {
            value.ctx = visitor.transform(value.ctx) as expr_context;
        }
        return;
    }
    if kind == ast_kind.List and isinstance(value, List) {
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
    if kind == ast_kind.Tuple and isinstance(value, Tuple) {
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
    if kind == ast_kind.Slice and isinstance(value, Slice) {
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
    if kind == ast_kind.comprehension and isinstance(value, comprehension) {
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
    if kind == ast_kind.ExceptHandler and isinstance(value, ExceptHandler) {
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
    if kind == ast_kind.arguments and isinstance(value, arguments) {
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
    if kind == ast_kind.arg and isinstance(value, arg) {
        if visitor.visit_field(value, "annotation") {
            if value.annotation is not None {
                value.annotation = visitor.transform(value.annotation) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.keyword and isinstance(value, keyword) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if kind == ast_kind.withitem and isinstance(value, withitem) {
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
    if kind == ast_kind.match_case and isinstance(value, match_case) {
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
    if kind == ast_kind.MatchValue and isinstance(value, MatchValue) {
        if visitor.visit_field(value, "value") {
            value.value = visitor.transform(value.value) as expr;
        }
        return;
    }
    if kind == ast_kind.MatchSequence and isinstance(value, MatchSequence) {
        if visitor.visit_field(value, "patterns") {
            for index in range(len(value.patterns)) {
                value.patterns[index] = visitor.transform(
                    value.patterns[index]
                ) as pattern;
            }
        }
        return;
    }
    if kind == ast_kind.MatchMapping and isinstance(value, MatchMapping) {
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
    if kind == ast_kind.MatchClass and isinstance(value, MatchClass) {
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
    if kind == ast_kind.MatchAs and isinstance(value, MatchAs) {
        if visitor.visit_field(value, "pattern") {
            if value.pattern is not None {
                value.pattern = visitor.transform(value.pattern) as pattern;
            }
        }
        return;
    }
    if kind == ast_kind.MatchOr and isinstance(value, MatchOr) {
        if visitor.visit_field(value, "patterns") {
            for index in range(len(value.patterns)) {
                value.patterns[index] = visitor.transform(
                    value.patterns[index]
                ) as pattern;
            }
        }
        return;
    }
    if kind == ast_kind.TypeVar and isinstance(value, TypeVar) {
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
    if kind == ast_kind.ParamSpec and isinstance(value, ParamSpec) {
        if visitor.visit_field(value, "default_value") {
            if value.default_value is not None {
                value.default_value = visitor.transform(value.default_value) as expr;
            }
        }
        return;
    }
    if kind == ast_kind.TypeVarTuple and isinstance(value, TypeVarTuple) {
        if visitor.visit_field(value, "default_value") {
            if value.default_value is not None {
                value.default_value = visitor.transform(value.default_value) as expr;
            }
        }
        return;
    }
}
