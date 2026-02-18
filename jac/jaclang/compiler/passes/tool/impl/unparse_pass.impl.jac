"""UnparsePass implementation - serializes Jac AST to source strings."""

"""Initialize the UnparsePass."""
impl UnparsePass.init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Comma-separated join of nodes' gen.jac values."""
impl UnparsePass._comma_sep(nodes: list) -> str {
    return ", ".join(
        [
            n.gen.jac
            for n in nodes
            if n
        ]
    );
}

"""Default exit handler with dispatch and fallbacks."""
impl UnparsePass.exit_node(nd: uni.UniNode) -> None
# Ensure all Token-type semantic fields have gen.jac set.
# This handles tokens not in the kid list (e.g. py2jac-produced nodes).
{
    for attr in vars(nd).values() {
        if isinstance(attr, uni.Token) and not attr.gen.jac {
            attr.gen.jac = attr.value;
        }
    }
    method_name = "exit_" + pascal_to_snake(type(nd).__name__);
    if hasattr(self, method_name) {
        getattr(self, method_name)(nd);
    } elif isinstance(nd, uni.Token) {
        nd.gen.jac = nd.value;
    } else {
        nd.gen.jac = " ".join(
            [
                k.gen.jac
                for k in nd.kid
                if k and k.gen.jac
            ]
        );
    }
    # ── Token Types ──────────────────────────────────────────────────────
}

"""Token: return raw value."""
impl UnparsePass.exit_token(nd: uni.Token) -> None {
    nd.gen.jac = nd.value;
}

"""Name: handle keyword-escaped names and enum suffixes."""
impl UnparsePass.exit_name(nd: uni.Name) -> None {
    prefix = "`" if nd.is_kwesc else "";
    suffix = ",\n" if nd.is_enum_stmt else "";
    nd.gen.jac = prefix + nd.value + suffix;
}

"""String: handle f-string literal escaping."""
impl UnparsePass.exit_string(nd: uni.String) -> None {
    if nd.parent and isinstance(nd.parent, uni.FString) {
        escaped = nd.lit_value.replace("{", "{{").replace("}", "}}");
        nd.gen.jac = escaped.replace("#", "\\#");
    } else {
        nd.gen.jac = nd.value;
    }
}

"""Semi token."""
impl UnparsePass.exit_semi(nd: uni.Semi) -> None {
    nd.gen.jac = nd.value;
}

"""Int literal."""
impl UnparsePass.exit_int(nd: uni.Int) -> None {
    nd.gen.jac = nd.value;
}

"""Float literal."""
impl UnparsePass.exit_float(nd: uni.Float) -> None {
    nd.gen.jac = nd.value;
}

"""Bool literal."""
impl UnparsePass.exit_bool(nd: uni.Bool) -> None {
    nd.gen.jac = nd.value;
}

"""Null literal."""
impl UnparsePass.exit_null(nd: uni.Null) -> None {
    nd.gen.jac = nd.value;
}

"""Ellipsis literal."""
impl UnparsePass.exit_ellipsis(nd: uni.Ellipsis) -> None {
    nd.gen.jac = nd.value;
}

"""BuiltinType token."""
impl UnparsePass.exit_builtin_type(nd: uni.BuiltinType) -> None {
    nd.gen.jac = nd.value;
}

"""SpecialVarRef token."""
impl UnparsePass.exit_special_var_ref(nd: uni.SpecialVarRef) -> None {
    nd.gen.jac = nd.value;
    # ── Module Level ─────────────────────────────────────────────────────
}

"""Module: join doc and body."""
impl UnparsePass.exit_module(nd: uni.Module) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
    }
    for stmt in nd.body {
        parts.append(stmt.gen.jac);
    }
    nd.gen.jac = " ".join(parts);
}

"""SubTag: colon prefix."""
impl UnparsePass.exit_sub_tag(nd: uni.SubTag) -> None {
    nd.gen.jac = ": " + nd.tag.gen.jac;
}

"""TypeParam."""
impl UnparsePass.exit_type_param(nd: uni.TypeParam) -> None {
    parts: list = [nd.name.gen.jac];
    if nd.bound {
        parts.append(": " + nd.bound.gen.jac);
    }
    if nd.default_val {
        parts.append(" = " + nd.default_val.gen.jac);
    }
    nd.gen.jac = "".join(parts);
}

"""TypeAlias statement."""
impl UnparsePass.exit_type_alias(nd: uni.TypeAlias) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
    }
    parts.append("type");
    if nd.access {
        parts.append(nd.access.gen.jac);
    }
    parts.append(nd.name.gen.jac);
    if nd.type_params {
        tp_str = ", ".join([tp.gen.jac for tp in nd.type_params]);
        parts.append("[" + tp_str + "]");
    }
    parts.append("=");
    parts.append(nd.value.gen.jac);
    nd.gen.jac = " ".join(parts);
}

"""GlobalVars statement."""
impl UnparsePass.exit_global_vars(nd: uni.GlobalVars) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
    }
    parts.append("global");
    if nd.access {
        parts.append(nd.access.gen.jac);
    }
    parts.append(self._comma_sep(nd.assignments));
    nd.gen.jac = " ".join(parts);
}

"""Test block."""
impl UnparsePass.exit_test(nd: uni.Test) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
    }
    parts.append("test");
    if nd.description {
        parts.append(nd.description.gen.jac);
    } elif nd.name.value and not nd.name.value.startswith('_jac_gen_') {
        parts.append(nd.name.gen.jac);
    }
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append("{ " + body + " }");
    nd.gen.jac = " ".join(parts);
    # ── Blocks ───────────────────────────────────────────────────────────
}

"""ModuleCode block."""
impl UnparsePass.exit_module_code(nd: uni.ModuleCode) -> None {
    parts: list = ["with entry"];
    if nd.name {
        parts.append(":");
        parts.append(nd.name.gen.jac);
    }
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append("{ " + body + " }");
    nd.gen.jac = " ".join(parts);
}

"""ClientBlock."""
impl UnparsePass.exit_client_block(nd: uni.ClientBlock) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    nd.gen.jac = "client { " + body + " }";
}

"""ServerBlock."""
impl UnparsePass.exit_server_block(nd: uni.ServerBlock) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    nd.gen.jac = "server { " + body + " }";
}

"""NativeBlock."""
impl UnparsePass.exit_native_block(nd: uni.NativeBlock) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    nd.gen.jac = "native { " + body + " }";
}

"""PyInlineCode block."""
impl UnparsePass.exit_py_inline_code(nd: uni.PyInlineCode) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    nd.gen.jac = "code { " + body + " }";
    # ── Imports ──────────────────────────────────────────────────────────
}

"""Import statement."""
impl UnparsePass.exit_import(nd: uni.Import) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
    }
    if nd.is_absorb {
        parts.append("include");
    } else {
        parts.append("import");
    }
    items = self._comma_sep(nd.items);
    if nd.from_loc {
        parts.append("from");
        parts.append(nd.from_loc.gen.jac);
        parts.append("{ " + items + " }");
    } else {
        parts.append(items);
        parts.append(";");
    }
    nd.gen.jac = " ".join(parts);
}

"""ModulePath."""
impl UnparsePass.exit_module_path(nd: uni.ModulePath) -> None {
    path = ".".join([p.gen.jac for p in nd.path]);
    if nd.alias {
        path = path + " as " + nd.alias.gen.jac;
    }
    nd.gen.jac = path;
}

"""ModuleItem."""
impl UnparsePass.exit_module_item(nd: uni.ModuleItem) -> None {
    result = nd.name.gen.jac;
    if nd.alias {
        result = result + " as " + nd.alias.gen.jac;
    }
    nd.gen.jac = result;
    # ── Definitions ──────────────────────────────────────────────────────
}

"""Archetype definition."""
impl UnparsePass.exit_archetype(nd: uni.Archetype) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
        if not isinstance(nd.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if nd.decorators {
        decs = " @".join([d.gen.jac for d in nd.decorators]);
        parts.append("@" + decs);
    }
    if nd.is_async {
        parts.append("async");
    }
    parts.append(nd.arch_type.gen.jac);
    if nd.access {
        parts.append(nd.access.gen.jac);
    }
    parts.append(nd.name.gen.jac);
    if nd.type_params {
        tp_str = ", ".join([tp.gen.jac for tp in nd.type_params]);
        parts.append("[" + tp_str + "]");
    }
    if nd.base_classes {
        parts.append("(" + self._comma_sep(nd.base_classes) + ")");
    }
    if nd.body {
        if isinstance(nd.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([s.gen.jac for s in nd.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append("{ }");
    }
    nd.gen.jac = " ".join(parts);
}

"""ImplDef definition."""
impl UnparsePass.exit_impl_def(nd: uni.ImplDef) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
    }
    if nd.decorators {
        decs = " @".join([d.gen.jac for d in nd.decorators]);
        parts.append("@" + decs);
    }
    parts.append("impl");
    target_str = ".".join([t.gen.jac for t in nd.target]);
    parts.append(target_str);
    if nd.spec {
        if isinstance(nd.spec, list) {
            parts.append("(" + self._comma_sep(nd.spec) + ")");
        } else {
            parts.append(nd.spec.gen.jac);
        }
    }
    if isinstance(nd.body, uni.Expr) {
        parts.append(nd.body.gen.jac);
    } else {
        body = " ".join([s.gen.jac for s in nd.body]);
        parts.append("{ " + body + " }");
    }
    nd.gen.jac = " ".join(parts);
}

"""SemDef definition."""
impl UnparsePass.exit_sem_def(nd: uni.SemDef) -> None {
    target_str = ".".join([t.gen.jac for t in nd.target]);
    nd.gen.jac = "sem " + target_str + " = " + nd.value.gen.jac + " ;";
}

"""Enum definition."""
impl UnparsePass.exit_enum(nd: uni.Enum) -> None {
    parts: list = [];
    if nd.decorators {
        decs = " @".join([d.gen.jac for d in nd.decorators]);
        parts.append("@" + decs);
    }
    if nd.doc {
        parts.append(nd.doc.gen.jac);
    }
    parts.append("enum");
    if nd.access {
        parts.append(nd.access.gen.jac);
    }
    parts.append(nd.name.gen.jac);
    if nd.base_classes {
        parts.append("(" + self._comma_sep(nd.base_classes) + ")");
    }
    if nd.body {
        if isinstance(nd.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([s.gen.jac for s in nd.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append(";");
    }
    nd.gen.jac = " ".join(parts);
}

"""Ability definition."""
impl UnparsePass.exit_ability(nd: uni.Ability) -> None {
    parts: list = [];
    if nd.doc {
        parts.append(nd.doc.gen.jac);
        if not isinstance(nd.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if nd.decorators {
        decs = " @".join([d.gen.jac for d in nd.decorators]);
        parts.append("@" + decs);
    }
    if nd.is_async {
        parts.append("async");
    }
    if nd.is_override {
        parts.append("override");
    }
    if nd.is_static {
        parts.append("static");
    }
    keyword = "def" if nd.is_def else "can";
    parts.append(keyword);
    if nd.access {
        parts.append(nd.access.gen.jac);
    }
    if nd.name_ref {
        parts.append(nd.name_ref.gen.jac);
    }
    if nd.signature {
        parts.append(nd.signature.gen.jac);
    }
    if nd.is_genai_ability {
        parts.append("by");
    }
    if nd.is_abstract {
        parts.append("abstract");
    }
    if nd.body is not None {
        if isinstance(nd.body, uni.ImplDef) {
            parts.append(";");
        } elif isinstance(nd.body, Sequence) and not isinstance(nd.body, uni.Expr) {
            body = " ".join([s.gen.jac for s in nd.body]);
            parts.append("{ " + body + " }");
        } else {
            parts.append(nd.body.gen.jac);
            if nd.is_genai_ability {
                parts.append(";");
            }
        }
    } else {
        parts.append(";");
    }
    nd.gen.jac = " ".join(parts);
}

"""FuncSignature: (params) -> return_type."""
impl UnparsePass.exit_func_signature(nd: uni.FuncSignature) -> None {
    is_lambda = nd.parent and isinstance(nd.parent, uni.LambdaExpr);
    param_parts: list = [];
    if nd.posonly_params {
        for prm in nd.posonly_params {
            param_parts.append(prm.gen.jac);
        }
        param_parts.append("/");
    }
    for prm in nd.params {
        param_parts.append(prm.gen.jac);
    }
    if nd.varargs {
        param_parts.append(nd.varargs.gen.jac);
    } elif nd.kwonlyargs {
        param_parts.append("*");
    }
    for prm in nd.kwonlyargs {
        param_parts.append(prm.gen.jac);
    }
    if nd.kwargs {
        param_parts.append(nd.kwargs.gen.jac);
    }
    params_str = ", ".join(param_parts);
    if not is_lambda {
        result = "(" + params_str + ")";
    } elif not param_parts {
        result = "()";
    } else {
        result = params_str;
    }
    if nd.return_type {
        result = result + " -> " + nd.return_type.gen.jac;
    }
    nd.gen.jac = result;
}

"""EventSignature: with [arch_info] event."""
impl UnparsePass.exit_event_signature(nd: uni.EventSignature) -> None {
    parts: list = ["with"];
    if nd.arch_tag_info {
        parts.append(nd.arch_tag_info.gen.jac);
    }
    parts.append(nd.event.gen.jac);
    nd.gen.jac = " ".join(parts);
}

"""ParamVar: [unpack]name[:type][=default]."""
impl UnparsePass.exit_param_var(nd: uni.ParamVar) -> None {
    result = "";
    if nd.unpack {
        result = nd.unpack.gen.jac;
    }
    result = result + nd.name.gen.jac;
    if nd.type_tag {
        result = result + " " + nd.type_tag.gen.jac;
    }
    if nd.value {
        result = result + " = " + nd.value.gen.jac;
    }
    nd.gen.jac = result;
}

"""ArchHas: has vars ;"""
impl UnparsePass.exit_arch_has(nd: uni.ArchHas) -> None {
    parts: list = [];
    if nd.access {
        parts.append(nd.access.gen.jac);
    }
    parts.append("has");
    for v in nd.vars {
        parts.append(v.gen.jac);
    }
    parts.append(";");
    nd.gen.jac = " ".join(parts);
}

"""HasVar: name[:type][=default],"""
impl UnparsePass.exit_has_var(nd: uni.HasVar) -> None {
    result = nd.name.gen.jac;
    if nd.type_tag {
        result = result + " " + nd.type_tag.gen.jac;
    }
    if nd.value {
        result = result + " = " + nd.value.gen.jac;
    }
    result = result + " ,";
    nd.gen.jac = result;
}

"""TypedCtxBlock: :type { body }."""
impl UnparsePass.exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None {
    parts: list = [":"];
    if nd.type_ctx {
        parts.append(nd.type_ctx.gen.jac);
    }
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append("{ " + body + " }");
    nd.gen.jac = " ".join(parts);
    # ── Control Flow ─────────────────────────────────────────────────────
}

"""IfStmt: if cond { body }."""
impl UnparsePass.exit_if_stmt(nd: uni.IfStmt) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    result = "if " + nd.condition.gen.jac + " { " + body + " }";
    if nd.else_body {
        result = result + " " + nd.else_body.gen.jac;
    }
    nd.gen.jac = result;
}

"""ElseIf: elif cond { body } [else_body]."""
impl UnparsePass.exit_else_if(nd: uni.ElseIf) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    result = "elif " + nd.condition.gen.jac + " { " + body + " }";
    if nd.else_body {
        result = result + " " + nd.else_body.gen.jac;
    }
    nd.gen.jac = result;
}

"""ElseStmt: else { body }."""
impl UnparsePass.exit_else_stmt(nd: uni.ElseStmt) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    nd.gen.jac = "else { " + body + " }";
}

"""ExprStmt: expr ;"""
impl UnparsePass.exit_expr_stmt(nd: uni.ExprStmt) -> None {
    result = "";
    if nd.expr {
        result = nd.expr.gen.jac;
    }
    nd.gen.jac = result + " ;";
}

"""TryStmt: try { body }."""
impl UnparsePass.exit_try_stmt(nd: uni.TryStmt) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    result = "try { " + body + " }";
    for exc in nd.excepts {
        result = result + " " + exc.gen.jac;
    }
    if nd.else_body {
        result = result + " " + nd.else_body.gen.jac;
    }
    if nd.finally_body {
        result = result + " " + nd.finally_body.gen.jac;
    }
    nd.gen.jac = result;
}

"""Except: except [exception [as name]] { body }."""
impl UnparsePass.exit_except(nd: uni.Except) -> None {
    parts: list = ["except"];
    if nd.ex_type {
        parts.append(nd.ex_type.gen.jac);
        if nd.name {
            parts.append("as");
            parts.append(nd.name.gen.jac);
        }
    }
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append("{ " + body + " }");
    nd.gen.jac = " ".join(parts);
}

"""FinallyStmt: finally { body }."""
impl UnparsePass.exit_finally_stmt(nd: uni.FinallyStmt) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    nd.gen.jac = "finally { " + body + " }";
}

"""IterForStmt: for [async] iter cond count_by { body }."""
impl UnparsePass.exit_iter_for_stmt(nd: uni.IterForStmt) -> None {
    parts: list = ["for"];
    if nd.is_async {
        parts.append("async");
    }
    parts.append(nd.iter.gen.jac);
    if nd.condition {
        parts.append(nd.condition.gen.jac);
    }
    if nd.count_by {
        parts.append(nd.count_by.gen.jac);
    }
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append("{ " + body + " }");
    if nd.else_body {
        parts.append(nd.else_body.gen.jac);
    }
    nd.gen.jac = " ".join(parts);
}

"""InForStmt: for [async] target in condition { body }."""
impl UnparsePass.exit_in_for_stmt(nd: uni.InForStmt) -> None {
    parts: list = ["for"];
    if nd.is_async {
        parts.append("async");
    }
    parts.append(nd.target.gen.jac);
    parts.append("in");
    parts.append(nd.collection.gen.jac);
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append("{ " + body + " }");
    if nd.else_body {
        parts.append(nd.else_body.gen.jac);
    }
    nd.gen.jac = " ".join(parts);
}

"""WhileStmt: while cond { body }."""
impl UnparsePass.exit_while_stmt(nd: uni.WhileStmt) -> None {
    body = " ".join([s.gen.jac for s in nd.body]);
    result = "while " + nd.condition.gen.jac + " { " + body + " }";
    if nd.else_body {
        result = result + " " + nd.else_body.gen.jac;
    }
    nd.gen.jac = result;
}

"""WithStmt: with [async] [context] { body }."""
impl UnparsePass.exit_with_stmt(nd: uni.WithStmt) -> None {
    parts: list = ["with"];
    if nd.is_async {
        parts.append("async");
    }
    if nd.exprs {
        parts.append(self._comma_sep(nd.exprs));
    }
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append("{ " + body + " }");
    nd.gen.jac = " ".join(parts);
}

"""ExprAsItem: expr [as alias]."""
impl UnparsePass.exit_expr_as_item(nd: uni.ExprAsItem) -> None {
    result = nd.expr.gen.jac;
    if nd.alias {
        result = result + " as " + nd.alias.gen.jac;
    }
    nd.gen.jac = result;
}

"""RaiseStmt: raise [exception] ;"""
impl UnparsePass.exit_raise_stmt(nd: uni.RaiseStmt) -> None {
    parts: list = ["raise"];
    if nd.cause {
        parts.append(nd.cause.gen.jac);
    }
    if nd.from_target {
        parts.append("from");
        parts.append(nd.from_target.gen.jac);
    }
    parts.append(";");
    nd.gen.jac = " ".join(parts);
}

"""AssertStmt: assert expr [, msg] ;"""
impl UnparsePass.exit_assert_stmt(nd: uni.AssertStmt) -> None {
    parts: list = ["assert", nd.condition.gen.jac];
    if nd.error_msg {
        parts.append(",");
        parts.append(nd.error_msg.gen.jac);
    }
    parts.append(";");
    nd.gen.jac = " ".join(parts);
}

"""CtrlStmt: break/continue ;"""
impl UnparsePass.exit_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    nd.gen.jac = str(nd.ctrl.value) + " ;";
}

"""DeleteStmt: delete targets ;"""
impl UnparsePass.exit_delete_stmt(nd: uni.DeleteStmt) -> None {
    nd.gen.jac = "delete " + nd.target.gen.jac + " ;";
}

"""ReportStmt: report expr ;"""
impl UnparsePass.exit_report_stmt(nd: uni.ReportStmt) -> None {
    nd.gen.jac = "report " + nd.expr.gen.jac + " ;";
}

"""ReturnStmt: return [expr] ;"""
impl UnparsePass.exit_return_stmt(nd: uni.ReturnStmt) -> None {
    parts: list = ["return"];
    if nd.expr {
        parts.append(nd.expr.gen.jac);
    }
    parts.append(";");
    nd.gen.jac = " ".join(parts);
}

"""VisitStmt: visit target ;"""
impl UnparsePass.exit_visit_stmt(nd: uni.VisitStmt) -> None {
    parts: list = ["visit"];
    if nd.insert_loc {
        parts.append(nd.insert_loc.gen.jac);
    }
    parts.append(nd.target.gen.jac);
    if nd.else_body {
        body = " ".join([s.gen.jac for s in nd.else_body]);
        parts.append("else { " + body + " }");
    }
    parts.append(";");
    nd.gen.jac = " ".join(parts);
}

"""DisengageStmt: disengage ;"""
impl UnparsePass.exit_disengage_stmt(nd: uni.DisengageStmt) -> None {
    nd.gen.jac = "disengage ;";
}

"""AwaitExpr: await target ;"""
impl UnparsePass.exit_await_expr(nd: uni.AwaitExpr) -> None {
    nd.gen.jac = "await " + nd.target.gen.jac;
}

"""GlobalStmt: global names ;"""
impl UnparsePass.exit_global_stmt(nd: uni.GlobalStmt) -> None {
    nd.gen.jac = "global " + self._comma_sep(nd.target) + " ;";
}

"""NonLocalStmt: nonlocal names ;"""
impl UnparsePass.exit_non_local_stmt(nd: uni.NonLocalStmt) -> None {
    nd.gen.jac = "nonlocal " + self._comma_sep(nd.target) + " ;";
    # ── Assignments ──────────────────────────────────────────────────────
}

"""Assignment: target [op] value ;"""
impl UnparsePass.exit_assignment(nd: uni.Assignment) -> None {
    parts: list = [];
    targets = " = ".join([t.gen.jac for t in nd.target]);
    parts.append(targets);
    if nd.type_tag {
        parts.append(nd.type_tag.gen.jac);
    }
    if nd.aug_op {
        parts.append(nd.aug_op.gen.jac);
    }
    if nd.value {
        if not nd.aug_op {
            parts.append("=");
        }
        parts.append(nd.value.gen.jac);
    }
    result = " ".join(parts);
    # Add semicolon unless in enum or IterForStmt
    if not nd.is_enum_stmt
    and not (
        isinstance(nd.parent, uni.IterForStmt)
        and (nd == nd.parent.iter or nd == nd.parent.count_by)
    ) {
        result = result + " ;";
    }
    nd.gen.jac = result;
    # ── Expressions ──────────────────────────────────────────────────────
}

"""ConcurrentExpr: [flow|wait] target."""
impl UnparsePass.exit_concurrent_expr(nd: uni.ConcurrentExpr) -> None {
    parts: list = [];
    if isinstance(nd.tok, uni.Token) and nd.tok.value {
        parts.append(nd.tok.gen.jac);
    }
    parts.append(nd.target.gen.jac);
    nd.gen.jac = " ".join(parts);
}

"""BinaryExpr: left op right."""
impl UnparsePass.exit_binary_expr(nd: uni.BinaryExpr) -> None {
    nd.gen.jac = nd.left.gen.jac + " " + nd.op.gen.jac + " " + nd.right.gen.jac;
}

"""CompareExpr: left op1 right1 op2 right2 ..."""
impl UnparsePass.exit_compare_expr(nd: uni.CompareExpr) -> None {
    result = nd.left.gen.jac;
    for i in range(len(nd.rights)) {
        result = result + " " + nd.ops[i].gen.jac + " " + nd.rights[i].gen.jac;
    }
    nd.gen.jac = result;
}

"""BoolExpr: expr1 op expr2 op expr3."""
impl UnparsePass.exit_bool_expr(nd: uni.BoolExpr) -> None {
    sep = " " + nd.op.gen.jac + " ";
    nd.gen.jac = sep.join([v.gen.jac for v in nd.values]);
}

"""LambdaExpr: lambda [signature] : body | { body }."""
impl UnparsePass.exit_lambda_expr(nd: uni.LambdaExpr) -> None {
    parts: list = ["lambda"];
    if nd.signature {
        parts.append(nd.signature.gen.jac);
    }
    if isinstance(nd.body, list) {
        body = " ".join([s.gen.jac for s in nd.body]);
        parts.append("{ " + body + " }");
    } else {
        parts.append(":");
        parts.append(nd.body.gen.jac);
    }
    nd.gen.jac = " ".join(parts);
}

"""UnaryExpr: op operand."""
impl UnparsePass.exit_unary_expr(nd: uni.UnaryExpr) -> None {
    nd.gen.jac = nd.op.gen.jac + " " + nd.operand.gen.jac;
}

"""IfElseExpr: value if condition else else_value."""
impl UnparsePass.exit_if_else_expr(nd: uni.IfElseExpr) -> None {
    nd.gen.jac = nd.value.gen.jac + " if " + nd.condition.gen.jac + " else " + nd.else_value.gen.jac;
}

"""MultiString: concatenated strings."""
impl UnparsePass.exit_multi_string(nd: uni.MultiString) -> None {
    nd.gen.jac = " ".join([s.gen.jac for s in nd.strings]);
}

"""FString: no-space join of parts (custom)."""
impl UnparsePass.exit_f_string(nd: uni.FString) -> None {
    parts: list = [];
    if nd.start is not None {
        parts.append(nd.start.gen.jac);
    }
    for part in nd.parts {
        parts.append(part.gen.jac);
    }
    if nd.end is not None {
        parts.append(nd.end.gen.jac);
    }
    nd.gen.jac = "".join(parts);
}

"""FormattedValue: {expr[!conv][:spec]} (custom no-space)."""
impl UnparsePass.exit_formatted_value(nd: uni.FormattedValue) -> None {
    result = "{" + nd.format_part.gen.jac;
    if nd.conversion != -1 {
        result = result + "!" + chr(nd.conversion);
    }
    if nd.format_spec {
        result = result + ":" + nd.format_spec.gen.jac;
    }
    nd.gen.jac = result + "}";
}

"""ListVal: [items]."""
impl UnparsePass.exit_list_val(nd: uni.ListVal) -> None {
    nd.gen.jac = "[" + self._comma_sep(nd.values) + "]";
}

"""SetVal: {items}."""
impl UnparsePass.exit_set_val(nd: uni.SetVal) -> None {
    nd.gen.jac = "{" + self._comma_sep(nd.values) + "}";
}

"""TupleVal: (items) with trailing comma for single element."""
impl UnparsePass.exit_tuple_val(nd: uni.TupleVal) -> None {
    inner = self._comma_sep(nd.values);
    if len(nd.values) == 1 {
        inner = inner + ",";
    }
    nd.gen.jac = "(" + inner + ")";
}

"""DictVal: {kv_pairs}."""
impl UnparsePass.exit_dict_val(nd: uni.DictVal) -> None {
    nd.gen.jac = "{" + self._comma_sep(nd.kv_pairs) + "}";
}

"""KVPair: key: value."""
impl UnparsePass.exit_k_v_pair(nd: uni.KVPair) -> None {
    nd.gen.jac = nd.key.gen.jac + " : " + nd.value.gen.jac;
}

"""KWPair: key=value."""
impl UnparsePass.exit_k_w_pair(nd: uni.KWPair) -> None {
    if nd.key {
        nd.gen.jac = nd.key.gen.jac + " = " + nd.value.gen.jac;
    } else {
        nd.gen.jac = "**" + nd.value.gen.jac;
    }
}

"""InnerCompr: for [async] target in iter [if cond]."""
impl UnparsePass.exit_inner_compr(nd: uni.InnerCompr) -> None {
    parts: list = ["for"];
    if nd.is_async {
        parts.append("async");
    }
    parts.append(nd.target.gen.jac);
    parts.append("in");
    parts.append(nd.collection.gen.jac);
    if nd.conditional {
        for cond in nd.conditional {
            parts.append("if");
            parts.append(cond.gen.jac);
        }
    }
    nd.gen.jac = " ".join(parts);
}

"""ListCompr: [out_expr comprs]."""
impl UnparsePass.exit_list_compr(nd: uni.ListCompr) -> None {
    comprs = " ".join([c.gen.jac for c in nd.compr]);
    nd.gen.jac = "[" + nd.out_expr.gen.jac + " " + comprs + "]";
}

"""GenCompr: (out_expr comprs)."""
impl UnparsePass.exit_gen_compr(nd: uni.GenCompr) -> None {
    comprs = " ".join([c.gen.jac for c in nd.compr]);
    inner = nd.out_expr.gen.jac + " " + comprs;
    # Always wrap in parens; FuncCall strips outer parens for sole-gencompr case
    nd.gen.jac = "(" + inner + ")";
}

"""SetCompr: {out_expr comprs}."""
impl UnparsePass.exit_set_compr(nd: uni.SetCompr) -> None {
    comprs = " ".join([c.gen.jac for c in nd.compr]);
    nd.gen.jac = "{" + nd.out_expr.gen.jac + " " + comprs + "}";
}

"""DictCompr: {kv_pair comprs}."""
impl UnparsePass.exit_dict_compr(nd: uni.DictCompr) -> None {
    comprs = " ".join([c.gen.jac for c in nd.compr]);
    nd.gen.jac = "{" + nd.kv_pair.gen.jac + " " + comprs + "}";
}

"""AtomTrailer: target[?][.]right (custom no-space)."""
impl UnparsePass.exit_atom_trailer(nd: uni.AtomTrailer) -> None {
    result = nd.target.gen.jac;
    if nd.is_null_ok {
        result = result + "?";
    }
    if nd.is_attr {
        result = result + ".";
    }
    if nd.right {
        result = result + nd.right.gen.jac;
    }
    nd.gen.jac = result;
}

"""AtomUnit: (value)."""
impl UnparsePass.exit_atom_unit(nd: uni.AtomUnit) -> None {
    nd.gen.jac = "(" + nd.value.gen.jac + ")";
}

"""YieldExpr: yield [from] [expr] ;"""
impl UnparsePass.exit_yield_expr(nd: uni.YieldExpr) -> None {
    parts: list = ["yield"];
    if nd.with_from {
        parts.append("from");
    }
    if nd.expr {
        parts.append(nd.expr.gen.jac);
    }
    nd.gen.jac = " ".join(parts);
}

"""FuncCall: target(params) (custom no-space before paren)."""
impl UnparsePass.exit_func_call(nd: uni.FuncCall) -> None {
    is_gencompr = len(nd.params) == 1 and isinstance(nd.params[0], uni.GenCompr);
    params_str = self._comma_sep(nd.params);
    if is_gencompr {
        # GenCompr already wrapped in parens, use directly
        result = nd.target.gen.jac + params_str;
    } else {
        result = nd.target.gen.jac + "(" + params_str;
        if nd.genai_call {
            result = result + " by " + nd.genai_call.gen.jac;
        }
        result = result + ")";
    }
    nd.gen.jac = result;
}

"""IndexSlice: [slices] (custom no-space)."""
impl UnparsePass.exit_index_slice(nd: uni.IndexSlice) -> None {
    result = "[";
    if nd.is_range {
        slice_parts: list = [];
        for s in nd.slices {
            part = "";
            if s.start {
                part = s.start.gen.jac;
            }
            part = part + ":";
            if s.stop {
                part = part + s.stop.gen.jac;
            }
            if s.step {
                part = part + ":" + s.step.gen.jac;
            }
            slice_parts.append(part);
        }
        result = result + ", ".join(slice_parts);
    } elif len(nd.slices) == 1 and nd.slices[0].start {
        result = result + nd.slices[0].start.gen.jac;
    }
    nd.gen.jac = result + "]";
}

"""EdgeRefTrailer: join kid list (complex edge syntax)."""
impl UnparsePass.exit_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None {
    nd.gen.jac = " ".join(
        [
            k.gen.jac
            for k in nd.kid
            if k and k.gen.jac
        ]
    );
}

"""EdgeOpRef: join kid list (complex edge syntax)."""
impl UnparsePass.exit_edge_op_ref(nd: uni.EdgeOpRef) -> None {
    nd.gen.jac = " ".join(
        [
            k.gen.jac
            for k in nd.kid
            if k and k.gen.jac
        ]
    );
}

"""DisconnectOp: delete edge_spec."""
impl UnparsePass.exit_disconnect_op(nd: uni.DisconnectOp) -> None {
    nd.gen.jac = "delete " + nd.edge_spec.gen.jac;
}

"""ConnectOp: join kid list (complex edge direction syntax)."""
impl UnparsePass.exit_connect_op(nd: uni.ConnectOp) -> None {
    nd.gen.jac = " ".join(
        [
            k.gen.jac
            for k in nd.kid
            if k and k.gen.jac
        ]
    );
}

"""FilterCompr: produce (?:Type, cmp1, cmp2) or edge-inner Type:cmp syntax."""
impl UnparsePass.exit_filter_compr(nd: uni.FilterCompr) -> None {
    parts: list[str] = [];
    is_inner = isinstance(nd.parent, uni.EdgeOpRef);
    if not is_inner {
        parts.append("(?");
        if nd.f_type {
            parts.append(":");
            parts.append(nd.f_type.gen.jac);
        }
        if nd.compares {
            if nd.f_type {
                parts.append(", ");
            }
            parts.append(", ".join([c.gen.jac for c in nd.compares]));
        }
        parts.append(")");
    } else {
        if nd.f_type {
            parts.append(nd.f_type.gen.jac);
        }
        if nd.compares {
            if nd.f_type {
                parts.append(":");
            }
            parts.append(", ".join([c.gen.jac for c in nd.compares]));
        }
    }
    nd.gen.jac = "".join(parts);
}

"""AssignCompr: join kid list."""
impl UnparsePass.exit_assign_compr(nd: uni.AssignCompr) -> None {
    nd.gen.jac = " ".join(
        [
            k.gen.jac
            for k in nd.kid
            if k and k.gen.jac
        ]
    );
    # ── JSX ──────────────────────────────────────────────────────────────
}

"""JsxElement: join kid list (complex JSX syntax)."""
impl UnparsePass.exit_jsx_element(nd: uni.JsxElement) -> None {
    nd.gen.jac = "".join(
        [
            k.gen.jac
            for k in nd.kid
            if k and k.gen.jac
        ]
    );
}

"""JsxElementName."""
impl UnparsePass.exit_jsx_element_name(nd: uni.JsxElementName) -> None {
    if nd.parts {
        nd.gen.jac = ".".join(
            [
                p.gen.jac
                for p in nd.parts
                if p
            ]
        );
    } else {
        nd.gen.jac = "";
    }
}

"""JsxSpreadAttribute."""
impl UnparsePass.exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None {
    nd.gen.jac = nd.expr.gen.jac;
}

"""JsxNormalAttribute: name[=value]."""
impl UnparsePass.exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None {
    result = nd.name.gen.jac;
    if nd.value {
        result = result + " = " + nd.value.gen.jac;
    }
    nd.gen.jac = result;
}

"""JsxText: join kid list."""
impl UnparsePass.exit_jsx_text(nd: uni.JsxText) -> None {
    nd.gen.jac = "".join(
        [
            k.gen.jac
            for k in nd.kid
            if k and k.gen.jac
        ]
    );
}

"""JsxExpression."""
impl UnparsePass.exit_jsx_expression(nd: uni.JsxExpression) -> None {
    nd.gen.jac = nd.expr.gen.jac;
    # ── Match / Switch ───────────────────────────────────────────────────
}

"""MatchStmt: match value { cases }."""
impl UnparsePass.exit_match_stmt(nd: uni.MatchStmt) -> None {
    cases = " ".join([c.gen.jac for c in nd.cases]);
    nd.gen.jac = "match " + nd.target.gen.jac + " { " + cases + " }";
}

"""MatchCase: case pattern { body }."""
impl UnparsePass.exit_match_case(nd: uni.MatchCase) -> None {
    parts: list = ["case", nd.pattern.gen.jac];
    if nd.guard {
        parts.append("if");
        parts.append(nd.guard.gen.jac);
    }
    parts.append(":");
    body = " ".join([s.gen.jac for s in nd.body]);
    parts.append(body);
    nd.gen.jac = " ".join(parts);
}

"""SwitchStmt: switch value { cases }."""
impl UnparsePass.exit_switch_stmt(nd: uni.SwitchStmt) -> None {
    cases = " ".join([c.gen.jac for c in nd.cases]);
    nd.gen.jac = "switch " + nd.target.gen.jac + " { " + cases + " }";
}

"""SwitchCase: case pattern { body }."""
impl UnparsePass.exit_switch_case(nd: uni.SwitchCase) -> None {
    if nd.pattern is not None {
        result = "case " + nd.pattern.gen.jac;
    } else {
        result = "default";
    }
    result = result + ":";
    body = " ".join([s.gen.jac for s in nd.body]);
    result = result + " " + body;
    nd.gen.jac = result;
}

"""MatchOr: pattern1 | pattern2."""
impl UnparsePass.exit_match_or(nd: uni.MatchOr) -> None {
    nd.gen.jac = " | ".join([p.gen.jac for p in nd.patterns]);
}

"""MatchAs: [pattern as] name."""
impl UnparsePass.exit_match_as(nd: uni.MatchAs) -> None {
    if nd.pattern {
        nd.gen.jac = nd.pattern.gen.jac + " as " + nd.name.gen.jac;
    } else {
        nd.gen.jac = nd.name.gen.jac;
    }
}

"""MatchWild: |"""
impl UnparsePass.exit_match_wild(nd: uni.MatchWild) -> None {
    nd.gen.jac = "_";
}

"""MatchValue: value."""
impl UnparsePass.exit_match_value(nd: uni.MatchValue) -> None {
    nd.gen.jac = nd.value.gen.jac;
}

"""MatchSingleton: value."""
impl UnparsePass.exit_match_singleton(nd: uni.MatchSingleton) -> None {
    nd.gen.jac = nd.value.gen.jac;
}

"""MatchSequence: [patterns]."""
impl UnparsePass.exit_match_sequence(nd: uni.MatchSequence) -> None {
    nd.gen.jac = "[" + self._comma_sep(nd.values) + "]";
}

"""MatchMapping: {values}."""
impl UnparsePass.exit_match_mapping(nd: uni.MatchMapping) -> None {
    nd.gen.jac = "{" + self._comma_sep(nd.values) + "}";
}

"""MatchKVPair: key: value."""
impl UnparsePass.exit_match_k_v_pair(nd: uni.MatchKVPair) -> None {
    nd.gen.jac = nd.key.gen.jac + " : " + nd.value.gen.jac;
}

"""MatchStar: *[name]."""
impl UnparsePass.exit_match_star(nd: uni.MatchStar) -> None {
    result = "*";
    if nd.name {
        result = result + nd.name.gen.jac;
    }
    nd.gen.jac = result;
}

"""MatchArch: name(args) (custom no-space)."""
impl UnparsePass.exit_match_arch(nd: uni.MatchArch) -> None {
    parts: list = [];
    if nd.arg_patterns {
        parts.extend([a.gen.jac for a in nd.arg_patterns]);
    }
    if nd.kw_patterns {
        parts.extend([k.gen.jac for k in nd.kw_patterns]);
    }
    nd.gen.jac = nd.name.gen.jac + "(" + ", ".join(parts) + ")";
}
