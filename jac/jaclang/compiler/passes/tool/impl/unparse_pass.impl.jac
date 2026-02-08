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
impl UnparsePass.exit_node(<>node: uni.UniNode) -> None {
    # Ensure all Token-type semantic fields have gen.jac set.
    # This handles tokens not in the kid list (e.g. py2jac-produced nodes).
    for attr in vars(<>node).values() {
        if isinstance(attr, uni.Token) and not attr.gen.jac {
            attr.gen.jac = attr.value;
        }
    }
    method_name = "exit_" + pascal_to_snake(type(<>node).__name__);
    if hasattr(self, method_name) {
        getattr(self, method_name)(<>node);
    } elif isinstance(<>node, uni.Token) {
        <>node.gen.jac = <>node.value;
    } else {
        <>node.gen.jac = " ".join(
            [
                k.gen.jac
                for k in <>node.kid
                if k and k.gen.jac
            ]
        );
    }
}

# ── Token Types ──────────────────────────────────────────────────────
"""Token: return raw value."""
impl UnparsePass.exit_token(<>node: uni.Token) -> None {
    <>node.gen.jac = <>node.value;
}

"""Name: handle keyword-escaped names and enum suffixes."""
impl UnparsePass.exit_name(<>node: uni.Name) -> None {
    prefix = "<>" if <>node.is_kwesc else "";
    suffix = ",\n" if <>node.is_enum_stmt else "";
    <>node.gen.jac = prefix + <>node.value + suffix;
}

"""String: handle f-string literal escaping."""
impl UnparsePass.exit_string(<>node: uni.String) -> None {
    if <>node.parent and isinstance(<>node.parent, uni.FString) {
        escaped = <>node.lit_value.replace("{", "{{").replace("}", "}}");
        <>node.gen.jac = escaped.replace("#", "\\#");
    } else {
        <>node.gen.jac = <>node.value;
    }
}

"""Semi token."""
impl UnparsePass.exit_semi(<>node: uni.Semi) -> None {
    <>node.gen.jac = <>node.value;
}

"""Int literal."""
impl UnparsePass.exit_int(<>node: uni.Int) -> None {
    <>node.gen.jac = <>node.value;
}

"""Float literal."""
impl UnparsePass.exit_float(<>node: uni.Float) -> None {
    <>node.gen.jac = <>node.value;
}

"""Bool literal."""
impl UnparsePass.exit_bool(<>node: uni.Bool) -> None {
    <>node.gen.jac = <>node.value;
}

"""Null literal."""
impl UnparsePass.exit_null(<>node: uni.Null) -> None {
    <>node.gen.jac = <>node.value;
}

"""Ellipsis literal."""
impl UnparsePass.exit_ellipsis(<>node: uni.Ellipsis) -> None {
    <>node.gen.jac = <>node.value;
}

"""BuiltinType token."""
impl UnparsePass.exit_builtin_type(<>node: uni.BuiltinType) -> None {
    <>node.gen.jac = <>node.value;
}

"""SpecialVarRef token."""
impl UnparsePass.exit_special_var_ref(<>node: uni.SpecialVarRef) -> None {
    <>node.gen.jac = <>node.value;
}

# ── Module Level ─────────────────────────────────────────────────────
"""Module: join doc and body."""
impl UnparsePass.exit_module(<>node: uni.Module) -> None {
    parts: list = [];
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
    }
    for stmt in <>node.body {
        parts.append(stmt.gen.jac);
    }
    <>node.gen.jac = " ".join(parts);
}

"""SubTag: colon prefix."""
impl UnparsePass.exit_sub_tag(<>node: uni.SubTag) -> None {
    <>node.gen.jac = ": " + <>node.tag.gen.jac;
}

"""GlobalVars statement."""
impl UnparsePass.exit_global_vars(<>node: uni.GlobalVars) -> None {
    parts: list = [];
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
    }
    parts.append("global");
    if <>node.access {
        parts.append(<>node.access.gen.jac);
    }
    parts.append(self._comma_sep(<>node.assignments));
    <>node.gen.jac = " ".join(parts);
}

"""Test block."""
impl UnparsePass.exit_test(<>node: uni.Test) -> None {
    parts: list = [];
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
    }
    parts.append("test");
    parts.append(<>node.name.gen.jac);
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append("{ " + body + " }");
    <>node.gen.jac = " ".join(parts);
}

# ── Blocks ───────────────────────────────────────────────────────────
"""ModuleCode block."""
impl UnparsePass.exit_module_code(<>node: uni.ModuleCode) -> None {
    parts: list = ["with entry"];
    if <>node.name {
        parts.append(":");
        parts.append(<>node.name.gen.jac);
    }
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append("{ " + body + " }");
    <>node.gen.jac = " ".join(parts);
}

"""ClientBlock."""
impl UnparsePass.exit_client_block(<>node: uni.ClientBlock) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "client { " + body + " }";
}

"""ServerBlock."""
impl UnparsePass.exit_server_block(<>node: uni.ServerBlock) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "server { " + body + " }";
}

"""NativeBlock."""
impl UnparsePass.exit_native_block(<>node: uni.NativeBlock) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "native { " + body + " }";
}

"""PyInlineCode block."""
impl UnparsePass.exit_py_inline_code(<>node: uni.PyInlineCode) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "code { " + body + " }";
}

# ── Imports ──────────────────────────────────────────────────────────
"""Import statement."""
impl UnparsePass.exit_import(<>node: uni.Import) -> None {
    parts: list = [];
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
    }
    if <>node.is_absorb {
        parts.append("include");
    } else {
        parts.append("import");
    }
    items = self._comma_sep(<>node.items);
    if <>node.from_loc {
        parts.append("from");
        parts.append(<>node.from_loc.gen.jac);
        parts.append("{ " + items + " }");
    } else {
        parts.append(items);
        parts.append(";");
    }
    <>node.gen.jac = " ".join(parts);
}

"""ModulePath."""
impl UnparsePass.exit_module_path(<>node: uni.ModulePath) -> None {
    path = ".".join([p.gen.jac for p in <>node.path]);
    if <>node.alias {
        path = path + " as " + <>node.alias.gen.jac;
    }
    <>node.gen.jac = path;
}

"""ModuleItem."""
impl UnparsePass.exit_module_item(<>node: uni.ModuleItem) -> None {
    result = <>node.name.gen.jac;
    if <>node.alias {
        result = result + " as " + <>node.alias.gen.jac;
    }
    <>node.gen.jac = result;
}

# ── Definitions ──────────────────────────────────────────────────────
"""Archetype definition."""
impl UnparsePass.exit_archetype(<>node: uni.Archetype) -> None {
    parts: list = [];
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
        if not isinstance(<>node.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if <>node.decorators {
        decs = " @".join([d.gen.jac for d in <>node.decorators]);
        parts.append("@" + decs);
    }
    if <>node.is_async {
        parts.append("async");
    }
    parts.append(<>node.arch_type.gen.jac);
    if <>node.access {
        parts.append(<>node.access.gen.jac);
    }
    parts.append(<>node.name.gen.jac);
    if <>node.base_classes {
        parts.append("(" + self._comma_sep(<>node.base_classes) + ")");
    }
    if <>node.body {
        if isinstance(<>node.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([s.gen.jac for s in <>node.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append("{ }");
    }
    <>node.gen.jac = " ".join(parts);
}

"""ImplDef definition."""
impl UnparsePass.exit_impl_def(<>node: uni.ImplDef) -> None {
    parts: list = [];
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
    }
    if <>node.decorators {
        decs = " @".join([d.gen.jac for d in <>node.decorators]);
        parts.append("@" + decs);
    }
    parts.append("impl");
    target_str = ".".join([t.gen.jac for t in <>node.target]);
    parts.append(target_str);
    if <>node.spec {
        if isinstance(<>node.spec, list) {
            parts.append("(" + self._comma_sep(<>node.spec) + ")");
        } else {
            parts.append(<>node.spec.gen.jac);
        }
    }
    if isinstance(<>node.body, uni.Expr) {
        parts.append(<>node.body.gen.jac);
    } else {
        body = " ".join([s.gen.jac for s in <>node.body]);
        parts.append("{ " + body + " }");
    }
    <>node.gen.jac = " ".join(parts);
}

"""SemDef definition."""
impl UnparsePass.exit_sem_def(<>node: uni.SemDef) -> None {
    target_str = ".".join([t.gen.jac for t in <>node.target]);
    <>node.gen.jac = "sem " + target_str + " = " + <>node.value.gen.jac + " ;";
}

"""Enum definition."""
impl UnparsePass.exit_enum(<>node: uni.Enum) -> None {
    parts: list = [];
    if <>node.decorators {
        decs = " @".join([d.gen.jac for d in <>node.decorators]);
        parts.append("@" + decs);
    }
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
    }
    parts.append("enum");
    if <>node.access {
        parts.append(<>node.access.gen.jac);
    }
    parts.append(<>node.name.gen.jac);
    if <>node.base_classes {
        parts.append("(" + self._comma_sep(<>node.base_classes) + ")");
    }
    if <>node.body {
        if isinstance(<>node.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([s.gen.jac for s in <>node.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append(";");
    }
    <>node.gen.jac = " ".join(parts);
}

"""Ability definition."""
impl UnparsePass.exit_ability(<>node: uni.Ability) -> None {
    parts: list = [];
    if <>node.doc {
        parts.append(<>node.doc.gen.jac);
        if not isinstance(<>node.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if <>node.decorators {
        decs = " @".join([d.gen.jac for d in <>node.decorators]);
        parts.append("@" + decs);
    }
    if <>node.is_async {
        parts.append("async");
    }
    if <>node.is_override {
        parts.append("override");
    }
    if <>node.is_static {
        parts.append("static");
    }
    keyword = "def" if <>node.is_def else "can";
    parts.append(keyword);
    if <>node.access {
        parts.append(<>node.access.gen.jac);
    }
    if <>node.name_ref {
        parts.append(<>node.name_ref.gen.jac);
    }
    if <>node.signature {
        parts.append(<>node.signature.gen.jac);
    }
    if <>node.is_genai_ability {
        parts.append("by");
    }
    if <>node.is_abstract {
        parts.append("abstract");
    }
    if <>node.body is not None {
        if isinstance(<>node.body, uni.ImplDef) {
            parts.append(";");
        } elif isinstance(<>node.body, Sequence)
        and not isinstance(<>node.body, uni.Expr) {
            body = " ".join([s.gen.jac for s in <>node.body]);
            parts.append("{ " + body + " }");
        } else {
            parts.append(<>node.body.gen.jac);
            if <>node.is_genai_ability {
                parts.append(";");
            }
        }
    } else {
        parts.append(";");
    }
    <>node.gen.jac = " ".join(parts);
}

"""FuncSignature: (params) -> return_type."""
impl UnparsePass.exit_func_signature(<>node: uni.FuncSignature) -> None {
    is_lambda = <>node.parent and isinstance(<>node.parent, uni.LambdaExpr);
    param_parts: list = [];
    if <>node.posonly_params {
        for prm in <>node.posonly_params {
            param_parts.append(prm.gen.jac);
        }
        param_parts.append("/");
    }
    for prm in <>node.params {
        param_parts.append(prm.gen.jac);
    }
    if <>node.varargs {
        param_parts.append(<>node.varargs.gen.jac);
    } elif <>node.kwonlyargs {
        param_parts.append("*");
    }
    for prm in <>node.kwonlyargs {
        param_parts.append(prm.gen.jac);
    }
    if <>node.kwargs {
        param_parts.append(<>node.kwargs.gen.jac);
    }
    params_str = ", ".join(param_parts);
    if not is_lambda {
        result = "(" + params_str + ")";
    } elif not param_parts {
        result = "()";
    } else {
        result = params_str;
    }
    if <>node.return_type {
        result = result + " -> " + <>node.return_type.gen.jac;
    }
    <>node.gen.jac = result;
}

"""EventSignature: with [arch_info] event."""
impl UnparsePass.exit_event_signature(<>node: uni.EventSignature) -> None {
    parts: list = ["with"];
    if <>node.arch_tag_info {
        parts.append(<>node.arch_tag_info.gen.jac);
    }
    parts.append(<>node.event.gen.jac);
    <>node.gen.jac = " ".join(parts);
}

"""ParamVar: [unpack]name[:type][=default]."""
impl UnparsePass.exit_param_var(<>node: uni.ParamVar) -> None {
    result = "";
    if <>node.unpack {
        result = <>node.unpack.gen.jac;
    }
    result = result + <>node.name.gen.jac;
    if <>node.type_tag {
        result = result + " " + <>node.type_tag.gen.jac;
    }
    if <>node.value {
        result = result + " = " + <>node.value.gen.jac;
    }
    <>node.gen.jac = result;
}

"""ArchHas: has vars ;"""
impl UnparsePass.exit_arch_has(<>node: uni.ArchHas) -> None {
    parts: list = [];
    if <>node.access {
        parts.append(<>node.access.gen.jac);
    }
    parts.append("has");
    for v in <>node.vars {
        parts.append(v.gen.jac);
    }
    parts.append(";");
    <>node.gen.jac = " ".join(parts);
}

"""HasVar: name[:type][=default],"""
impl UnparsePass.exit_has_var(<>node: uni.HasVar) -> None {
    result = <>node.name.gen.jac;
    if <>node.type_tag {
        result = result + " " + <>node.type_tag.gen.jac;
    }
    if <>node.value {
        result = result + " = " + <>node.value.gen.jac;
    }
    result = result + " ,";
    <>node.gen.jac = result;
}

"""TypedCtxBlock: :type { body }."""
impl UnparsePass.exit_typed_ctx_block(<>node: uni.TypedCtxBlock) -> None {
    parts: list = [":"];
    if <>node.type_ctx {
        parts.append(<>node.type_ctx.gen.jac);
    }
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append("{ " + body + " }");
    <>node.gen.jac = " ".join(parts);
}

# ── Control Flow ─────────────────────────────────────────────────────
"""IfStmt: if cond { body }."""
impl UnparsePass.exit_if_stmt(<>node: uni.IfStmt) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "if " + <>node.condition.gen.jac + " { " + body + " }";
}

"""ElseIf: elif cond { body }."""
impl UnparsePass.exit_else_if(<>node: uni.ElseIf) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "elif " + <>node.condition.gen.jac + " { " + body + " }";
}

"""ElseStmt: else { body }."""
impl UnparsePass.exit_else_stmt(<>node: uni.ElseStmt) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "else { " + body + " }";
}

"""ExprStmt: expr ;"""
impl UnparsePass.exit_expr_stmt(<>node: uni.ExprStmt) -> None {
    result = "";
    if <>node.expr {
        result = <>node.expr.gen.jac;
    }
    <>node.gen.jac = result + " ;";
}

"""TryStmt: try { body }."""
impl UnparsePass.exit_try_stmt(<>node: uni.TryStmt) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "try { " + body + " }";
}

"""Except: except [exception] { body }."""
impl UnparsePass.exit_except(<>node: uni.Except) -> None {
    parts: list = ["except"];
    if <>node.ex_type {
        parts.append(<>node.ex_type.gen.jac);
    }
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append("{ " + body + " }");
    <>node.gen.jac = " ".join(parts);
}

"""FinallyStmt: finally { body }."""
impl UnparsePass.exit_finally_stmt(<>node: uni.FinallyStmt) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "finally { " + body + " }";
}

"""IterForStmt: for [async] iter cond count_by { body }."""
impl UnparsePass.exit_iter_for_stmt(<>node: uni.IterForStmt) -> None {
    parts: list = ["for"];
    if <>node.is_async {
        parts.append("async");
    }
    parts.append(<>node.iter.gen.jac);
    if <>node.condition {
        parts.append(<>node.condition.gen.jac);
    }
    if <>node.count_by {
        parts.append(<>node.count_by.gen.jac);
    }
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append("{ " + body + " }");
    <>node.gen.jac = " ".join(parts);
}

"""InForStmt: for [async] target in condition { body }."""
impl UnparsePass.exit_in_for_stmt(<>node: uni.InForStmt) -> None {
    parts: list = ["for"];
    if <>node.is_async {
        parts.append("async");
    }
    parts.append(<>node.target.gen.jac);
    parts.append("in");
    parts.append(<>node.collection.gen.jac);
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append("{ " + body + " }");
    <>node.gen.jac = " ".join(parts);
}

"""WhileStmt: while cond { body }."""
impl UnparsePass.exit_while_stmt(<>node: uni.WhileStmt) -> None {
    body = " ".join([s.gen.jac for s in <>node.body]);
    <>node.gen.jac = "while " + <>node.condition.gen.jac + " { " + body + " }";
}

"""WithStmt: with [async] [context] { body }."""
impl UnparsePass.exit_with_stmt(<>node: uni.WithStmt) -> None {
    parts: list = ["with"];
    if <>node.is_async {
        parts.append("async");
    }
    if <>node.exprs {
        parts.append(self._comma_sep(<>node.exprs));
    }
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append("{ " + body + " }");
    <>node.gen.jac = " ".join(parts);
}

"""ExprAsItem: expr [as alias]."""
impl UnparsePass.exit_expr_as_item(<>node: uni.ExprAsItem) -> None {
    result = <>node.expr.gen.jac;
    if <>node.alias {
        result = result + " as " + <>node.alias.gen.jac;
    }
    <>node.gen.jac = result;
}

"""RaiseStmt: raise [exception] ;"""
impl UnparsePass.exit_raise_stmt(<>node: uni.RaiseStmt) -> None {
    parts: list = ["raise"];
    if <>node.cause {
        parts.append(<>node.cause.gen.jac);
    }
    if <>node.from_target {
        parts.append("from");
        parts.append(<>node.from_target.gen.jac);
    }
    parts.append(";");
    <>node.gen.jac = " ".join(parts);
}

"""AssertStmt: assert expr [, msg] ;"""
impl UnparsePass.exit_assert_stmt(<>node: uni.AssertStmt) -> None {
    parts: list = ["assert", <>node.condition.gen.jac];
    if <>node.error_msg {
        parts.append(",");
        parts.append(<>node.error_msg.gen.jac);
    }
    parts.append(";");
    <>node.gen.jac = " ".join(parts);
}

"""CtrlStmt: break/continue ;"""
impl UnparsePass.exit_ctrl_stmt(<>node: uni.CtrlStmt) -> None {
    <>node.gen.jac = str(<>node.ctrl.value) + " ;";
}

"""DeleteStmt: delete targets ;"""
impl UnparsePass.exit_delete_stmt(<>node: uni.DeleteStmt) -> None {
    <>node.gen.jac = "delete " + <>node.target.gen.jac + " ;";
}

"""ReportStmt: report expr ;"""
impl UnparsePass.exit_report_stmt(<>node: uni.ReportStmt) -> None {
    <>node.gen.jac = "report " + <>node.expr.gen.jac + " ;";
}

"""ReturnStmt: return [expr] ;"""
impl UnparsePass.exit_return_stmt(<>node: uni.ReturnStmt) -> None {
    parts: list = ["return"];
    if <>node.expr {
        parts.append(<>node.expr.gen.jac);
    }
    parts.append(";");
    <>node.gen.jac = " ".join(parts);
}

"""VisitStmt: visit target ;"""
impl UnparsePass.exit_visit_stmt(<>node: uni.VisitStmt) -> None {
    parts: list = ["visit"];
    if <>node.insert_loc {
        parts.append(<>node.insert_loc.gen.jac);
    }
    parts.append(<>node.target.gen.jac);
    if <>node.else_body {
        body = " ".join([s.gen.jac for s in <>node.else_body]);
        parts.append("else { " + body + " }");
    }
    parts.append(";");
    <>node.gen.jac = " ".join(parts);
}

"""DisengageStmt: disengage ;"""
impl UnparsePass.exit_disengage_stmt(<>node: uni.DisengageStmt) -> None {
    <>node.gen.jac = "disengage ;";
}

"""AwaitExpr: await target ;"""
impl UnparsePass.exit_await_expr(<>node: uni.AwaitExpr) -> None {
    <>node.gen.jac = "await " + <>node.target.gen.jac;
}

"""GlobalStmt: global names ;"""
impl UnparsePass.exit_global_stmt(<>node: uni.GlobalStmt) -> None {
    <>node.gen.jac = "global " + self._comma_sep(<>node.target) + " ;";
}

"""NonLocalStmt: nonlocal names ;"""
impl UnparsePass.exit_non_local_stmt(<>node: uni.NonLocalStmt) -> None {
    <>node.gen.jac = "nonlocal " + self._comma_sep(<>node.target) + " ;";
}

# ── Assignments ──────────────────────────────────────────────────────
"""Assignment: target [op] value ;"""
impl UnparsePass.exit_assignment(<>node: uni.Assignment) -> None {
    parts: list = [];
    targets = " = ".join([t.gen.jac for t in <>node.target]);
    parts.append(targets);
    if <>node.type_tag {
        parts.append(<>node.type_tag.gen.jac);
    }
    if <>node.aug_op {
        parts.append(<>node.aug_op.gen.jac);
    }
    if <>node.value {
        if not <>node.aug_op {
            parts.append("=");
        }
        parts.append(<>node.value.gen.jac);
    }
    result = " ".join(parts);
    # Add semicolon unless in enum or IterForStmt
    if not <>node.is_enum_stmt
    and not (
        isinstance(<>node.parent, uni.IterForStmt)
        and (<>node == <>node.parent.iter or <>node == <>node.parent.count_by)
    ) {
        result = result + " ;";
    }
    <>node.gen.jac = result;
}

# ── Expressions ──────────────────────────────────────────────────────
"""ConcurrentExpr: [flow|wait] target."""
impl UnparsePass.exit_concurrent_expr(<>node: uni.ConcurrentExpr) -> None {
    parts: list = [];
    if isinstance(<>node.tok, uni.Token) and <>node.tok.value {
        parts.append(<>node.tok.gen.jac);
    }
    parts.append(<>node.target.gen.jac);
    <>node.gen.jac = " ".join(parts);
}

"""BinaryExpr: left op right."""
impl UnparsePass.exit_binary_expr(<>node: uni.BinaryExpr) -> None {
    <>node.gen.jac = <>node.left.gen.jac + " " + <>node.op.gen.jac + " " + <>node.right.gen.jac;
}

"""CompareExpr: left op1 right1 op2 right2 ..."""
impl UnparsePass.exit_compare_expr(<>node: uni.CompareExpr) -> None {
    result = <>node.left.gen.jac;
    for i in range(len(<>node.rights)) {
        result = result + " " + <>node.ops[i].gen.jac + " " + <>node.rights[i].gen.jac;
    }
    <>node.gen.jac = result;
}

"""BoolExpr: expr1 op expr2 op expr3."""
impl UnparsePass.exit_bool_expr(<>node: uni.BoolExpr) -> None {
    sep = " " + <>node.op.gen.jac + " ";
    <>node.gen.jac = sep.join([v.gen.jac for v in <>node.values]);
}

"""LambdaExpr: lambda [signature] : body | { body }."""
impl UnparsePass.exit_lambda_expr(<>node: uni.LambdaExpr) -> None {
    parts: list = ["lambda"];
    if <>node.signature {
        parts.append(<>node.signature.gen.jac);
    }
    if isinstance(<>node.body, list) {
        body = " ".join([s.gen.jac for s in <>node.body]);
        parts.append("{ " + body + " }");
    } else {
        parts.append(":");
        parts.append(<>node.body.gen.jac);
    }
    <>node.gen.jac = " ".join(parts);
}

"""UnaryExpr: op operand."""
impl UnparsePass.exit_unary_expr(<>node: uni.UnaryExpr) -> None {
    <>node.gen.jac = <>node.op.gen.jac + " " + <>node.operand.gen.jac;
}

"""IfElseExpr: value if condition else else_value."""
impl UnparsePass.exit_if_else_expr(<>node: uni.IfElseExpr) -> None {
    <>node.gen.jac = <>node.value.gen.jac + " if " + <>node.condition.gen.jac + " else " + <>node.else_value.gen.jac;
}

"""MultiString: concatenated strings."""
impl UnparsePass.exit_multi_string(<>node: uni.MultiString) -> None {
    <>node.gen.jac = " ".join([s.gen.jac for s in <>node.strings]);
}

"""FString: no-space join of parts (custom)."""
impl UnparsePass.exit_f_string(<>node: uni.FString) -> None {
    parts: list = [];
    if <>node.start is not None {
        parts.append(<>node.start.gen.jac);
    }
    for part in <>node.parts {
        parts.append(part.gen.jac);
    }
    if <>node.end is not None {
        parts.append(<>node.end.gen.jac);
    }
    <>node.gen.jac = "".join(parts);
}

"""FormattedValue: {expr[!conv][:spec]} (custom no-space)."""
impl UnparsePass.exit_formatted_value(<>node: uni.FormattedValue) -> None {
    result = "{" + <>node.format_part.gen.jac;
    if <>node.conversion != -1 {
        result = result + "!" + chr(<>node.conversion);
    }
    if <>node.format_spec {
        result = result + ":" + <>node.format_spec.gen.jac;
    }
    <>node.gen.jac = result + "}";
}

"""ListVal: [items]."""
impl UnparsePass.exit_list_val(<>node: uni.ListVal) -> None {
    <>node.gen.jac = "[" + self._comma_sep(<>node.values) + "]";
}

"""SetVal: {items}."""
impl UnparsePass.exit_set_val(<>node: uni.SetVal) -> None {
    <>node.gen.jac = "{" + self._comma_sep(<>node.values) + "}";
}

"""TupleVal: (items) with trailing comma for single element."""
impl UnparsePass.exit_tuple_val(<>node: uni.TupleVal) -> None {
    inner = self._comma_sep(<>node.values);
    if len(<>node.values) == 1 {
        inner = inner + ",";
    }
    <>node.gen.jac = "(" + inner + ")";
}

"""DictVal: {kv_pairs}."""
impl UnparsePass.exit_dict_val(<>node: uni.DictVal) -> None {
    <>node.gen.jac = "{" + self._comma_sep(<>node.kv_pairs) + "}";
}

"""KVPair: key: value."""
impl UnparsePass.exit_k_v_pair(<>node: uni.KVPair) -> None {
    <>node.gen.jac = <>node.key.gen.jac + " : " + <>node.value.gen.jac;
}

"""KWPair: key=value."""
impl UnparsePass.exit_k_w_pair(<>node: uni.KWPair) -> None {
    if <>node.key {
        <>node.gen.jac = <>node.key.gen.jac + " = " + <>node.value.gen.jac;
    } else {
        <>node.gen.jac = "**" + <>node.value.gen.jac;
    }
}

"""InnerCompr: for [async] target in iter [if cond]."""
impl UnparsePass.exit_inner_compr(<>node: uni.InnerCompr) -> None {
    parts: list = ["for"];
    if <>node.is_async {
        parts.append("async");
    }
    parts.append(<>node.target.gen.jac);
    parts.append("in");
    parts.append(<>node.collection.gen.jac);
    if <>node.conditional {
        for cond in <>node.conditional {
            parts.append("if");
            parts.append(cond.gen.jac);
        }
    }
    <>node.gen.jac = " ".join(parts);
}

"""ListCompr: [out_expr comprs]."""
impl UnparsePass.exit_list_compr(<>node: uni.ListCompr) -> None {
    comprs = " ".join([c.gen.jac for c in <>node.compr]);
    <>node.gen.jac = "[" + <>node.out_expr.gen.jac + " " + comprs + "]";
}

"""GenCompr: (out_expr comprs)."""
impl UnparsePass.exit_gen_compr(<>node: uni.GenCompr) -> None {
    comprs = " ".join([c.gen.jac for c in <>node.compr]);
    inner = <>node.out_expr.gen.jac + " " + comprs;
    # Always wrap in parens; FuncCall strips outer parens for sole-gencompr case
    <>node.gen.jac = "(" + inner + ")";
}

"""SetCompr: {out_expr comprs}."""
impl UnparsePass.exit_set_compr(<>node: uni.SetCompr) -> None {
    comprs = " ".join([c.gen.jac for c in <>node.compr]);
    <>node.gen.jac = "{" + <>node.out_expr.gen.jac + " " + comprs + "}";
}

"""DictCompr: {kv_pair comprs}."""
impl UnparsePass.exit_dict_compr(<>node: uni.DictCompr) -> None {
    comprs = " ".join([c.gen.jac for c in <>node.compr]);
    <>node.gen.jac = "{" + <>node.kv_pair.gen.jac + " " + comprs + "}";
}

"""AtomTrailer: target[?][.]right (custom no-space)."""
impl UnparsePass.exit_atom_trailer(<>node: uni.AtomTrailer) -> None {
    result = <>node.target.gen.jac;
    if <>node.is_null_ok {
        result = result + "?";
    }
    if <>node.is_attr {
        result = result + ".";
    }
    if <>node.right {
        result = result + <>node.right.gen.jac;
    }
    <>node.gen.jac = result;
}

"""AtomUnit: (value)."""
impl UnparsePass.exit_atom_unit(<>node: uni.AtomUnit) -> None {
    <>node.gen.jac = "(" + <>node.value.gen.jac + ")";
}

"""YieldExpr: yield [from] [expr] ;"""
impl UnparsePass.exit_yield_expr(<>node: uni.YieldExpr) -> None {
    parts: list = ["yield"];
    if <>node.with_from {
        parts.append("from");
    }
    if <>node.expr {
        parts.append(<>node.expr.gen.jac);
    }
    <>node.gen.jac = " ".join(parts);
}

"""FuncCall: target(params) (custom no-space before paren)."""
impl UnparsePass.exit_func_call(<>node: uni.FuncCall) -> None {
    is_gencompr = len(<>node.params) == 1
    and isinstance(<>node.params[0], uni.GenCompr);
    params_str = self._comma_sep(<>node.params);
    if is_gencompr {
        # GenCompr already wrapped in parens, use directly
        result = <>node.target.gen.jac + params_str;
    } else {
        result = <>node.target.gen.jac + "(" + params_str;
        if <>node.genai_call {
            result = result + " by " + <>node.genai_call.gen.jac;
        }
        result = result + ")";
    }
    <>node.gen.jac = result;
}

"""IndexSlice: [slices] (custom no-space)."""
impl UnparsePass.exit_index_slice(<>node: uni.IndexSlice) -> None {
    result = "[";
    if <>node.is_range {
        slice_parts: list = [];
        for s in <>node.slices {
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
    } elif len(<>node.slices) == 1 and <>node.slices[0].start {
        result = result + <>node.slices[0].start.gen.jac;
    }
    <>node.gen.jac = result + "]";
}

"""EdgeRefTrailer: join kid list (complex edge syntax)."""
impl UnparsePass.exit_edge_ref_trailer(<>node: uni.EdgeRefTrailer) -> None {
    <>node.gen.jac = " ".join(
        [
            k.gen.jac
            for k in <>node.kid
            if k and k.gen.jac
        ]
    );
}

"""EdgeOpRef: join kid list (complex edge syntax)."""
impl UnparsePass.exit_edge_op_ref(<>node: uni.EdgeOpRef) -> None {
    <>node.gen.jac = " ".join(
        [
            k.gen.jac
            for k in <>node.kid
            if k and k.gen.jac
        ]
    );
}

"""DisconnectOp: delete edge_spec."""
impl UnparsePass.exit_disconnect_op(<>node: uni.DisconnectOp) -> None {
    <>node.gen.jac = "delete " + <>node.edge_spec.gen.jac;
}

"""ConnectOp: join kid list (complex edge direction syntax)."""
impl UnparsePass.exit_connect_op(<>node: uni.ConnectOp) -> None {
    <>node.gen.jac = " ".join(
        [
            k.gen.jac
            for k in <>node.kid
            if k and k.gen.jac
        ]
    );
}

"""FilterCompr: produce (?:Type, cmp1, cmp2) or edge-inner Type:cmp syntax."""
impl UnparsePass.exit_filter_compr(<>node: uni.FilterCompr) -> None {
    parts: list[str] = [];
    is_inner = isinstance(<>node.parent, uni.EdgeOpRef);
    if not is_inner {
        parts.append("(?");
        if <>node.f_type {
            parts.append(":");
            parts.append(<>node.f_type.gen.jac);
        }
        if <>node.compares {
            if <>node.f_type {
                parts.append(", ");
            }
            parts.append(", ".join([c.gen.jac for c in <>node.compares]));
        }
        parts.append(")");
    } else {
        if <>node.f_type {
            parts.append(<>node.f_type.gen.jac);
        }
        if <>node.compares {
            if <>node.f_type {
                parts.append(":");
            }
            parts.append(", ".join([c.gen.jac for c in <>node.compares]));
        }
    }
    <>node.gen.jac = "".join(parts);
}

"""AssignCompr: join kid list."""
impl UnparsePass.exit_assign_compr(<>node: uni.AssignCompr) -> None {
    <>node.gen.jac = " ".join(
        [
            k.gen.jac
            for k in <>node.kid
            if k and k.gen.jac
        ]
    );
}

# ── JSX ──────────────────────────────────────────────────────────────
"""JsxElement: join kid list (complex JSX syntax)."""
impl UnparsePass.exit_jsx_element(<>node: uni.JsxElement) -> None {
    <>node.gen.jac = " ".join(
        [
            k.gen.jac
            for k in <>node.kid
            if k and k.gen.jac
        ]
    );
}

"""JsxElementName."""
impl UnparsePass.exit_jsx_element_name(<>node: uni.JsxElementName) -> None {
    if <>node.parts {
        <>node.gen.jac = ".".join(
            [
                p.gen.jac
                for p in <>node.parts
                if p
            ]
        );
    } else {
        <>node.gen.jac = "";
    }
}

"""JsxSpreadAttribute."""
impl UnparsePass.exit_jsx_spread_attribute(<>node: uni.JsxSpreadAttribute) -> None {
    <>node.gen.jac = <>node.expr.gen.jac;
}

"""JsxNormalAttribute: name[=value]."""
impl UnparsePass.exit_jsx_normal_attribute(<>node: uni.JsxNormalAttribute) -> None {
    result = <>node.name.gen.jac;
    if <>node.value {
        result = result + " = " + <>node.value.gen.jac;
    }
    <>node.gen.jac = result;
}

"""JsxText: join kid list."""
impl UnparsePass.exit_jsx_text(<>node: uni.JsxText) -> None {
    <>node.gen.jac = " ".join(
        [
            k.gen.jac
            for k in <>node.kid
            if k and k.gen.jac
        ]
    );
}

"""JsxExpression."""
impl UnparsePass.exit_jsx_expression(<>node: uni.JsxExpression) -> None {
    <>node.gen.jac = <>node.expr.gen.jac;
}

# ── Match / Switch ───────────────────────────────────────────────────
"""MatchStmt: match value { cases }."""
impl UnparsePass.exit_match_stmt(<>node: uni.MatchStmt) -> None {
    cases = " ".join([c.gen.jac for c in <>node.cases]);
    <>node.gen.jac = "match " + <>node.target.gen.jac + " { " + cases + " }";
}

"""MatchCase: case pattern { body }."""
impl UnparsePass.exit_match_case(<>node: uni.MatchCase) -> None {
    parts: list = ["case", <>node.pattern.gen.jac];
    if <>node.guard {
        parts.append("if");
        parts.append(<>node.guard.gen.jac);
    }
    parts.append(":");
    body = " ".join([s.gen.jac for s in <>node.body]);
    parts.append(body);
    <>node.gen.jac = " ".join(parts);
}

"""SwitchStmt: switch value { cases }."""
impl UnparsePass.exit_switch_stmt(<>node: uni.SwitchStmt) -> None {
    cases = " ".join([c.gen.jac for c in <>node.cases]);
    <>node.gen.jac = "switch " + <>node.target.gen.jac + " { " + cases + " }";
}

"""SwitchCase: case pattern { body }."""
impl UnparsePass.exit_switch_case(<>node: uni.SwitchCase) -> None {
    if <>node.pattern is not None {
        result = "case " + <>node.pattern.gen.jac;
    } else {
        result = "default";
    }
    result = result + ":";
    body = " ".join([s.gen.jac for s in <>node.body]);
    result = result + " " + body;
    <>node.gen.jac = result;
}

"""MatchOr: pattern1 | pattern2."""
impl UnparsePass.exit_match_or(<>node: uni.MatchOr) -> None {
    <>node.gen.jac = " | ".join([p.gen.jac for p in <>node.patterns]);
}

"""MatchAs: [pattern as] name."""
impl UnparsePass.exit_match_as(<>node: uni.MatchAs) -> None {
    if <>node.pattern {
        <>node.gen.jac = <>node.pattern.gen.jac + " as " + <>node.name.gen.jac;
    } else {
        <>node.gen.jac = <>node.name.gen.jac;
    }
}

"""MatchWild: |"""
impl UnparsePass.exit_match_wild(<>node: uni.MatchWild) -> None {
    <>node.gen.jac = "_";
}

"""MatchValue: value."""
impl UnparsePass.exit_match_value(<>node: uni.MatchValue) -> None {
    <>node.gen.jac = <>node.value.gen.jac;
}

"""MatchSingleton: value."""
impl UnparsePass.exit_match_singleton(<>node: uni.MatchSingleton) -> None {
    <>node.gen.jac = <>node.value.gen.jac;
}

"""MatchSequence: [patterns]."""
impl UnparsePass.exit_match_sequence(<>node: uni.MatchSequence) -> None {
    <>node.gen.jac = "[" + self._comma_sep(<>node.values) + "]";
}

"""MatchMapping: {values}."""
impl UnparsePass.exit_match_mapping(<>node: uni.MatchMapping) -> None {
    <>node.gen.jac = "{" + self._comma_sep(<>node.values) + "}";
}

"""MatchKVPair: key: value."""
impl UnparsePass.exit_match_k_v_pair(<>node: uni.MatchKVPair) -> None {
    <>node.gen.jac = <>node.key.gen.jac + " : " + <>node.value.gen.jac;
}

"""MatchStar: *[name]."""
impl UnparsePass.exit_match_star(<>node: uni.MatchStar) -> None {
    result = "*";
    if <>node.name {
        result = result + <>node.name.gen.jac;
    }
    <>node.gen.jac = result;
}

"""MatchArch: name(args) (custom no-space)."""
impl UnparsePass.exit_match_arch(<>node: uni.MatchArch) -> None {
    parts: list = [];
    if <>node.arg_patterns {
        parts.extend([a.gen.jac for a in <>node.arg_patterns]);
    }
    if <>node.kw_patterns {
        parts.extend([k.gen.jac for k in <>node.kw_patterns]);
    }
    <>node.gen.jac = <>node.name.gen.jac + "(" + ", ".join(parts) + ")";
}
