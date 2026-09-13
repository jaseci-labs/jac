def _join_kids(nd: uni.UniNode, sep: str = " ") -> str {
    return sep.join(
        [
            artifact_for(k).jac
            for k in nd.kid
            if k and artifact_for(k).jac
        ]
    );
}

impl UnparsePass._comma_sep(nodes: Sequence[uni.UniNode]) -> str {
    return ", ".join(
        [
            artifact_for(n).jac
            for n in nodes
            if n
        ]
    );
}

impl UnparsePass.unparse_prepare_exit with uni.UniNode exit {
    for attr in vars(here).values() {
        if isinstance(attr, uni.Token) and not artifact_for(attr).jac {
            artifact_for(attr).jac = attr.value;
        }
    }
}

impl UnparsePass.unparse_default_exit with uni.UniNode exit {
    if isinstance(here, uni.Token) {
        artifact_for(here).jac = here.value;
    } else {
        artifact_for(here).jac = " ".join(
            [
                artifact_for(k).jac
                for k in here.kid
                if k and artifact_for(k).jac
            ]
        );
    }
}

impl UnparsePass.exit_token with uni.Token exit {
    if here.__class__ is not uni.Token {
        return;
    }
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_name with uni.Name exit {
    if here.__class__ is not uni.Name {
        return;
    }
    prefix = "`" if here.is_kwesc else "";
    suffix = ",\n" if here.is_enum_stmt else "";
    artifact_for(here).jac = prefix + here.value + suffix;
}

impl UnparsePass.exit_string with uni.String exit {
    if here.parent and isinstance(here.parent, uni.FString) {
        escaped = here.value.replace("{", "{{").replace("}", "}}");
        artifact_for(here).jac = escaped.replace("#", "\\#");
    } else {
        artifact_for(here).jac = here.value;
    }
}

impl UnparsePass.exit_semi with uni.Semi exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_int with uni.Int exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_float with uni.Float exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_bool with uni.Bool exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_null with uni.Null exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_ellipsis with uni.Ellipsis exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_builtin_type with uni.BuiltinType exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_special_var_ref with uni.SpecialVarRef exit {
    artifact_for(here).jac = here.value;
}

impl UnparsePass.exit_module with uni.Module exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
    }
    for stmt in here.body {
        parts.append(artifact_for(stmt).jac);
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_sub_tag with uni.SubTag exit {
    prefix = "";
    if here.ownership == OwnershipKind.OWN {
        prefix = "own ";
    } elif here.ownership == OwnershipKind.MUT_BORROW {
        prefix = "&mut ";
    } elif here.ownership == OwnershipKind.BORROW {
        prefix = "&";
    } elif here.ownership == OwnershipKind.IMM {
        prefix = "imm ";
    }
    artifact_for(here).jac = ": " + prefix + artifact_for(here.tag).jac;
}

impl UnparsePass.exit_type_param with uni.TypeParam exit {
    parts: list = [
        ("comptime " if here.is_comptime else "") + artifact_for(here.name).jac
    ];
    if here.bound {
        parts.append(": " + artifact_for(here.bound).jac);
    }
    if here.default_val {
        parts.append(" = " + artifact_for(here.default_val).jac);
    }
    artifact_for(here).jac = "".join(parts);
}

impl UnparsePass.exit_type_alias with uni.TypeAlias exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
    }
    parts.append("type");
    if here.access {
        parts.append(artifact_for(here.access).jac);
    }
    parts.append(artifact_for(here.name).jac);
    if here.type_params {
        tp_str = ", ".join([artifact_for(tp).jac for tp in here.type_params]);
        parts.append("[" + tp_str + "]");
    }
    parts.append(":=" if here.is_distinct else "=");
    parts.append(artifact_for(here.value).jac);
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_global_vars with uni.GlobalVars exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
    }
    parts.append("comptime" if here.is_frozen else "glob");
    if here.access {
        parts.append(artifact_for(here.access).jac);
    }
    parts.append(self._comma_sep(here.assignments));
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_test with uni.Test exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
    }
    if here.decorators {
        decs = " @".join([artifact_for(d).jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    parts.append("test");
    if here.description {
        parts.append(artifact_for(here.description).jac);
    } elif here.name.value and not here.name.value.startswith('_jac_gen_') {
        parts.append(artifact_for(here.name).jac);
    }
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append("{ " + body + " }");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_module_code with uni.ModuleCode exit {
    parts: list = ["with entry"];
    if here.name {
        parts.append(":");
        parts.append(artifact_for(here.name).jac);
    }
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append("{ " + body + " }");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_py_inline_code with uni.PyInlineCode exit {
    artifact_for(here).jac = "::py::" + here.code.value + "::py::";
}

impl UnparsePass.exit_import with uni.Import exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
    }
    if here.is_comptime {
        parts.append("comptime");
    }
    if here.is_absorb {
        parts.append("include");
    } else {
        parts.append("import");
    }
    if here.is_typed {
        parts.append("type");
    }
    items = self._comma_sep(here.items);
    if here.from_loc {
        parts.append("from");
        parts.append(artifact_for(here.from_loc).jac);
        parts.append("{ " + items + " }");
    } else {
        parts.append(items);
        parts.append(";");
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_module_path with uni.ModulePath exit {
    path = ".".join([artifact_for(p).jac for p in here.path] if here.path else []);
    if here.alias {
        path = path + " as " + artifact_for(here.alias).jac;
    }
    artifact_for(here).jac = path;
}

impl UnparsePass.exit_module_item with uni.ModuleItem exit {
    result = artifact_for(here.name).jac;
    if here.alias {
        result = result + " as " + artifact_for(here.alias).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_archetype with uni.Archetype exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
        if not isinstance(here.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if here.decorators {
        decs = " @".join([artifact_for(d).jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    if here.is_async {
        parts.append("async");
    }
    parts.append(artifact_for(here.arch_type).jac);
    if here.access {
        parts.append(artifact_for(here.access).jac);
    }
    parts.append(artifact_for(here.name).jac);
    if here.type_params {
        tp_str = ", ".join([artifact_for(tp).jac for tp in here.type_params]);
        parts.append("[" + tp_str + "]");
    }
    if here.base_classes or here.keywords {
        inherit = [artifact_for(b).jac for b in here.base_classes]
            + [artifact_for(k).jac for k in here.keywords];
        parts.append("(" + ", ".join(inherit) + ")");
    }
    if here.src_endpoint and here.tgt_endpoint {
        parts.append(
            ": "
                + artifact_for(here.src_endpoint).jac
                + " --> "
                + artifact_for(here.tgt_endpoint).jac
        );
    }
    if here.body {
        if isinstance(here.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([artifact_for(s).jac for s in here.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append("{ }");
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_impl_def with uni.ImplDef exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
    }
    if here.decorators {
        decs = " @".join([artifact_for(d).jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    parts.append("impl");
    target_str = ".".join([artifact_for(t).jac for t in here.target]);
    parts.append(target_str);
    if here.spec {
        if isinstance(here.spec, (uni.FuncSignature, uni.EventSignature)) {
            parts.append(artifact_for(here.spec).jac);
        } else {
            parts.append("(" + self._comma_sep(here.spec) + ")");
        }
    }
    if isinstance(here.body, uni.Expr) {
        parts.append(artifact_for(here.body).jac);
    } else {
        body = " ".join([artifact_for(s).jac for s in here.body]);
        parts.append("{ " + body + " }");
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_sem_def with uni.SemDef exit {
    target_str = ".".join([artifact_for(t).jac for t in here.target]);
    artifact_for(here).jac = "sem "
        + target_str
        + " = "
        + artifact_for(here.value).jac
        + ";";
}

impl UnparsePass.exit_enum with uni.Enum exit {
    parts: list = [];
    if here.decorators {
        decs = " @".join([artifact_for(d).jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
    }
    parts.append("enum");
    if here.access {
        parts.append(artifact_for(here.access).jac);
    }
    parts.append(artifact_for(here.name).jac);
    if here.value_type {
        parts.append(": " + artifact_for(here.value_type).jac);
    } elif here.base_classes {
        parts.append("(" + self._comma_sep(here.base_classes) + ")");
    }
    if here.body {
        if isinstance(here.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([artifact_for(s).jac for s in here.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append(";");
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_ability with uni.Ability exit {
    parts: list = [];
    if here.doc {
        parts.append(artifact_for(here.doc).jac);
        if not isinstance(here.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if here.decorators {
        decs = " @".join([artifact_for(d).jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    if here.is_comptime {
        parts.append("comptime");
    }
    if here.is_async {
        parts.append("async");
    }
    if here.is_override {
        parts.append("override");
    }
    if here.is_classmethod {
        parts.append("class");
    }
    if here.is_static {
        parts.append("static");
    }
    keyword = "def" if here.is_def else "can";
    parts.append(keyword);
    if here.access {
        parts.append(artifact_for(here.access).jac);
    }
    if here.name_ref {
        parts.append(artifact_for(here.name_ref).jac);
    }
    if here.signature {
        parts.append(artifact_for(here.signature).jac);
    }
    if here.is_genai_ability {
        parts.append("by");
    }
    if here.is_abstract {
        parts.append("abstract");
    }
    if here.body is not None {
        if isinstance(here.body, uni.ImplDef) {
            parts.append(";");
        } elif isinstance(here.body, Sequence)
            and not isinstance(here.body, uni.Expr) {
            body = " ".join([artifact_for(s).jac for s in here.body]);
            parts.append("{ " + body + " }");
        } else {
            parts.append(artifact_for(here.body).jac);
            if here.is_genai_ability {
                parts.append(";");
            }
        }
    } else {
        parts.append(";");
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_func_signature with uni.FuncSignature exit {
    param_parts: list = [];
    if here.posonly_params {
        for prm in here.posonly_params {
            param_parts.append(artifact_for(prm).jac);
        }
        param_parts.append("/");
    }
    for prm in here.params {
        param_parts.append(artifact_for(prm).jac);
    }
    if here.varargs {
        param_parts.append(artifact_for(here.varargs).jac);
    } elif here.kwonlyargs {
        param_parts.append("*");
    }
    for prm in here.kwonlyargs {
        param_parts.append(artifact_for(prm).jac);
    }
    if here.kwargs {
        param_parts.append(artifact_for(here.kwargs).jac);
    }
    params_str = ", ".join(param_parts);
    result = "(" + params_str + ")";
    if here.return_type {
        result = result + " -> " + artifact_for(here.return_type).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_event_signature with uni.EventSignature exit {
    parts: list = ["with"];
    if here.arch_tag_info {
        parts.append(artifact_for(here.arch_tag_info).jac);
    }
    parts.append(artifact_for(here.event).jac);
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_param_var with uni.ParamVar exit {
    result = "comptime " if here.is_comptime else "";
    if here.unpack {
        result = artifact_for(here.unpack).jac;
    }
    result = result + artifact_for(here.name).jac;
    if here.type_tag {
        result = result + artifact_for(here.type_tag).jac;
    }
    if here.value {
        result = result + " = " + artifact_for(here.value).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_arch_has with uni.ArchHas exit {
    parts: list = [];
    if here.access {
        parts.append(artifact_for(here.access).jac);
    }
    parts.append("has");
    for v in here.vars {
        parts.append(artifact_for(v).jac);
    }
    parts.append(";");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_has_var with uni.HasVar exit {
    result = artifact_for(here.name).jac;
    if here.type_tag {
        result = result + artifact_for(here.type_tag).jac;
    }
    if here.value {
        result = result + " = " + artifact_for(here.value).jac;
    }
    result = result + " ,";
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_typed_ctx_block with uni.TypedCtxBlock exit {
    parts: list = [":"];
    if here.type_ctx {
        parts.append(artifact_for(here.type_ctx).jac);
    }
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append("{ " + body + " }");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_open_stmt with uni.OpenStmt exit {
    body = " ".join([artifact_for(s).jac for s in here.body]);
    artifact_for(here).jac = "in "
        + artifact_for(here.target).jac
        + " { "
        + body
        + " }";
}

impl UnparsePass.exit_if_stmt with uni.IfStmt exit {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    body = " ".join([artifact_for(s).jac for s in here.body]);
    result = ("comptime " if here.is_comptime else "")
        + "if "
        + artifact_for(here.condition).jac
        + " { "
        + body
        + " }";
    if here.else_body {
        result = result + " " + artifact_for(here.else_body).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_else_if with uni.ElseIf exit {
    body = " ".join([artifact_for(s).jac for s in here.body]);
    result = "elif " + artifact_for(here.condition).jac + " { " + body + " }";
    if here.else_body {
        result = result + " " + artifact_for(here.else_body).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_else_stmt with uni.ElseStmt exit {
    body = " ".join([artifact_for(s).jac for s in here.body]);
    artifact_for(here).jac = "else { " + body + " }";
}

impl UnparsePass.exit_expr_stmt with uni.ExprStmt exit {
    result = "";
    if here.expr {
        result = artifact_for(here.expr).jac;
    }
    artifact_for(here).jac = result + ";";
}

impl UnparsePass.exit_try_stmt with uni.TryStmt exit {
    body = " ".join([artifact_for(s).jac for s in here.body]);
    result = "try { " + body + " }";
    for exc in here.excepts {
        result = result + " " + artifact_for(exc).jac;
    }
    if here.else_body {
        result = result + " " + artifact_for(here.else_body).jac;
    }
    if here.finally_body {
        result = result + " " + artifact_for(here.finally_body).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_except with uni.Except exit {
    parts: list = ["except"];
    if here.ex_type {
        parts.append(artifact_for(here.ex_type).jac);
        if here.name {
            parts.append("as");
            parts.append(artifact_for(here.name).jac);
        }
    }
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append("{ " + body + " }");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_finally_stmt with uni.FinallyStmt exit {
    body = " ".join([artifact_for(s).jac for s in here.body]);
    artifact_for(here).jac = "finally { " + body + " }";
}

impl UnparsePass.exit_iter_for_stmt with uni.IterForStmt exit {
    parts: list = ["async for" if here.is_async else "for"];
    parts.append(artifact_for(here.iter).jac);
    if here.condition {
        parts.append("while");
        parts.append(artifact_for(here.condition).jac);
    }
    if here.count_by {
        parts.append("with");
        parts.append(artifact_for(here.count_by).jac);
    }
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append("{ " + body + " }");
    if here.else_body {
        parts.append(artifact_for(here.else_body).jac);
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_in_for_stmt with uni.InForStmt exit {
    parts: list = [];
    if here.is_comptime {
        parts.append("comptime");
    }
    parts.append("for");
    if here.is_async {
        parts.append("async");
    }
    parts.append(artifact_for(here.target).jac);
    parts.append("in");
    parts.append(artifact_for(here.collection).jac);
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append("{ " + body + " }");
    if here.else_body {
        parts.append(artifact_for(here.else_body).jac);
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_while_stmt with uni.WhileStmt exit {
    body = " ".join([artifact_for(s).jac for s in here.body]);
    result = "while " + artifact_for(here.condition).jac + " { " + body + " }";
    if here.else_body {
        result = result + " " + artifact_for(here.else_body).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_forever_stmt with uni.ForeverStmt exit {
    body = " ".join([artifact_for(s).jac for s in here.body]);
    artifact_for(here).jac = "forever { " + body + " }";
}

impl UnparsePass.exit_with_stmt with uni.WithStmt exit {
    parts: list = ["with"];
    if here.is_async {
        parts.append("async");
    }
    if here.exprs {
        parts.append(self._comma_sep(here.exprs));
    }
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append("{ " + body + " }");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_expr_as_item with uni.ExprAsItem exit {
    result = artifact_for(here.expr).jac;
    if here.alias {
        result = result + " as " + artifact_for(here.alias).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_raise_stmt with uni.RaiseStmt exit {
    parts: list = ["raise"];
    if here.cause {
        parts.append(artifact_for(here.cause).jac);
    }
    if here.from_target {
        parts.append("from");
        parts.append(artifact_for(here.from_target).jac);
    }
    artifact_for(here).jac = " ".join(parts) + ";";
}

impl UnparsePass.exit_assert_stmt with uni.AssertStmt exit {
    parts: list = [];
    if here.is_comptime {
        parts.append("comptime");
    }
    parts.extend(["assert", artifact_for(here.condition).jac]);
    if here.error_msg {
        parts.append(",");
        parts.append(artifact_for(here.error_msg).jac);
    }
    artifact_for(here).jac = " ".join(parts) + ";";
}

impl UnparsePass.exit_ctrl_stmt with uni.CtrlStmt exit {
    artifact_for(here).jac = str(here.ctrl.value) + ";";
}

impl UnparsePass.exit_delete_stmt with uni.DeleteStmt exit {
    artifact_for(here).jac = "delete "
        + ", ".join([artifact_for(t).jac for t in here.targets])
        + ";";
}

impl UnparsePass.exit_report_stmt with uni.ReportStmt exit {
    artifact_for(here).jac = "report " + artifact_for(here.expr).jac + ";";
}

impl UnparsePass.exit_return_stmt with uni.ReturnStmt exit {
    if here.is_implicit and here.expr {
        artifact_for(here).jac = artifact_for(here.expr).jac;
        return;
    }
    parts: list = ["return"];
    if here.expr {
        parts.append(artifact_for(here.expr).jac);
    }
    parts.append(";");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_visit_stmt with uni.VisitStmt exit {
    parts: list = ["visit"];
    if here.insert_loc {
        parts.append(artifact_for(here.insert_loc).jac);
    }
    parts.append(artifact_for(here.target).jac);
    if here.else_body {
        parts.append(artifact_for(here.else_body).jac);
    }
    parts.append(";");
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_disengage_stmt with uni.DisengageStmt exit {
    artifact_for(here).jac = "disengage ;";
}

impl UnparsePass.exit_await_expr with uni.AwaitExpr exit {
    artifact_for(here).jac = "await " + artifact_for(here.target).jac;
}

impl UnparsePass.exit_cast_expr with uni.CastExpr exit {
    artifact_for(here).jac = artifact_for(here.value).jac
        + " as "
        + artifact_for(here.cast_type).jac;
}

impl UnparsePass.exit_assignment with uni.Assignment exit {
    parts: list = [];
    if here.is_comptime and not isinstance(here.parent, uni.GlobalVars) {
        parts.append("comptime");
    }
    targets = " = ".join([artifact_for(t).jac for t in here.target]);
    parts.append(targets);
    if here.type_tag {
        parts.append(artifact_for(here.type_tag).jac);
    }
    if here.aug_op {
        parts.append(artifact_for(here.aug_op).jac);
    }
    if here.value {
        if not here.aug_op {
            parts.append("=");
        }
        parts.append(artifact_for(here.value).jac);
    }
    result = " ".join(parts);

    if not here.is_enum_stmt
        and not (
            isinstance(here.parent, uni.IterForStmt)
            and (here == here.parent.iter or here == here.parent.count_by)
        ) {
        result = result + ";";
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_concurrent_expr with uni.ConcurrentExpr exit {
    parts: list = [];
    if isinstance(here.tok, uni.Token) and here.tok.value {
        parts.append(artifact_for(here.tok).jac);
    }
    parts.append(artifact_for(here.target).jac);
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_binary_expr with uni.BinaryExpr exit {
    artifact_for(here).jac = artifact_for(here.left).jac
        + " "
        + artifact_for(here.op).jac
        + " "
        + artifact_for(here.right).jac;
}

impl UnparsePass.exit_compare_expr with uni.CompareExpr exit {
    result = artifact_for(here.left).jac;
    for i in range(len(here.rights)) {
        result = result
            + " "
            + artifact_for(here.ops[i]).jac
            + " "
            + artifact_for(here.rights[i]).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_cfg_expr with uni.CfgExpr exit {
    artifact_for(here).jac = artifact_for(here.expr).jac;
}

impl UnparsePass.exit_bool_expr with uni.BoolExpr exit {
    sep = " " + artifact_for(here.op).jac + " ";
    artifact_for(here).jac = sep.join([artifact_for(v).jac for v in here.values]);
}

impl UnparsePass.exit_lambda_expr with uni.LambdaExpr exit {
    parts: list = ["lambda"];
    if here.signature {
        parts.append(artifact_for(here.signature).jac);
    }
    if isinstance(here.body, uni.Expr) {
        parts.append("{ " + artifact_for(here.body).jac + " }");
    } else {
        body = " ".join([artifact_for(s).jac for s in here.body]);
        parts.append("{ " + body + " }");
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_unary_expr with uni.UnaryExpr exit {
    if is_mut_kind(here.ownership) {
        artifact_for(here).jac = artifact_for(here.op).jac
            + "mut "
            + artifact_for(here.operand).jac;
    } else {
        artifact_for(here).jac = artifact_for(here.op).jac
            + " "
            + artifact_for(here.operand).jac;
    }
}

impl UnparsePass.exit_if_else_expr with uni.IfElseExpr exit {
    artifact_for(here).jac = artifact_for(here.value).jac
        + " if "
        + artifact_for(here.condition).jac
        + " else "
        + artifact_for(here.else_value).jac;
}

impl UnparsePass.exit_multi_string with uni.MultiString exit {
    artifact_for(here).jac = " ".join([artifact_for(s).jac for s in here.strings]);
}

impl UnparsePass.exit_f_string with uni.FString exit {
    parts: list = [];
    if here.start is not None {
        parts.append(artifact_for(here.start).jac);
    }
    for part in here.parts {
        parts.append(artifact_for(part).jac);
    }
    if here.end is not None {
        parts.append(artifact_for(here.end).jac);
    }
    artifact_for(here).jac = "".join(parts);
}

impl UnparsePass.exit_formatted_value with uni.FormattedValue exit {
    result = "{" + artifact_for(here.format_part).jac;
    if here.conversion != -1 {
        result = result + "!" + chr(here.conversion);
    }
    if here.format_spec {
        result = result + ":" + artifact_for(here.format_spec).jac;
    }
    artifact_for(here).jac = result + "}";
}

impl UnparsePass.exit_list_val with uni.ListVal exit {
    artifact_for(here).jac = "[" + self._comma_sep(here.values) + "]";
}

impl UnparsePass.exit_set_val with uni.SetVal exit {
    vals: Sequence[uni.Expr] = here.values if here.values is not None else [];
    artifact_for(here).jac = "{" + self._comma_sep(vals) + "}";
}

impl UnparsePass.exit_tuple_val with uni.TupleVal exit {
    inner = self._comma_sep(here.values);
    if len(here.values) == 1 {
        inner = inner + ",";
    }
    artifact_for(here).jac = "(" + inner + ")";
}

impl UnparsePass.exit_dict_val with uni.DictVal exit {
    artifact_for(here).jac = "{" + self._comma_sep(here.kv_pairs) + "}";
}

impl UnparsePass.exit_k_v_pair with uni.KVPair exit {
    if here.key {
        artifact_for(here).jac = artifact_for(here.key).jac
            + " : "
            + artifact_for(here.value).jac;
    } else {
        artifact_for(here).jac = "**" + artifact_for(here.value).jac;
    }
}

impl UnparsePass.exit_k_w_pair with uni.KWPair exit {
    if here.key {
        artifact_for(here).jac = artifact_for(here.key).jac
            + " = "
            + artifact_for(here.value).jac;
    } else {
        artifact_for(here).jac = "**" + artifact_for(here.value).jac;
    }
}

impl UnparsePass.exit_inner_compr with uni.InnerCompr exit {
    parts: list = ["for"];
    if here.is_async {
        parts.append("async");
    }
    parts.append(artifact_for(here.target).jac);
    parts.append("in");
    parts.append(artifact_for(here.collection).jac);
    if here.conditional {
        for cond in here.conditional {
            parts.append("if");
            parts.append(artifact_for(cond).jac);
        }
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_list_compr with uni.ListCompr exit {
    if here.__class__ is not uni.ListCompr {
        return;
    }
    comprs = " ".join([artifact_for(c).jac for c in here.compr]);
    artifact_for(here).jac = "[" + artifact_for(here.out_expr).jac + " " + comprs + "]";
}

impl UnparsePass.exit_gen_compr with uni.GenCompr exit {
    comprs = " ".join([artifact_for(c).jac for c in here.compr]);
    inner = artifact_for(here.out_expr).jac + " " + comprs;

    artifact_for(here).jac = "(" + inner + ")";
}

impl UnparsePass.exit_set_compr with uni.SetCompr exit {
    comprs = " ".join([artifact_for(c).jac for c in here.compr]);
    artifact_for(here).jac = "{" + artifact_for(here.out_expr).jac + " " + comprs + "}";
}

impl UnparsePass.exit_dict_compr with uni.DictCompr exit {
    comprs = " ".join([artifact_for(c).jac for c in here.compr]);
    artifact_for(here).jac = "{" + artifact_for(here.kv_pair).jac + " " + comprs + "}";
}

impl UnparsePass.exit_atom_trailer with uni.AtomTrailer exit {
    result = artifact_for(here.target).jac;
    if here.is_null_ok {
        result = result + "?";
    }
    if here.is_attr {
        result = result + ".";
    }
    if here.right {
        result = result + artifact_for(here.right).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_atom_unit with uni.AtomUnit exit {
    artifact_for(here).jac = "(" + artifact_for(here.value).jac + ")";
}

impl UnparsePass.exit_graph_expr with uni.GraphExpr exit {
    artifact_for(here).jac = "graph { "
        + " ".join([artifact_for(expr).jac + ";" for expr in here.exprs])
        + " }";
}

impl UnparsePass.exit_yield_expr with uni.YieldExpr exit {
    parts: list = ["yield"];
    if here.with_from {
        parts.append("from");
    }
    if here.expr {
        parts.append(artifact_for(here.expr).jac);
    }
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_func_call with uni.FuncCall exit {
    call_params: Sequence[(uni.Expr | uni.KWPair)] = here.params
        if here.params is not None
        else [];
    is_gencompr = len(call_params) == 1 and isinstance(call_params[0], uni.GenCompr);
    params_str = self._comma_sep(call_params);
    if is_gencompr {
        result = artifact_for(here.target).jac + params_str;
    } else {
        result = artifact_for(here.target).jac + "(" + params_str;
        if here.genai_call {
            result = result + " by " + artifact_for(here.genai_call).jac;
        }
        result = result + ")";
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_index_slice with uni.IndexSlice exit {
    result = "[";
    if here.is_range {
        slice_parts: list = [];
        for s in here.slices {
            part = "";
            if s.start {
                part = artifact_for(s.start).jac;
            }
            part = part + ":";
            if s.stop {
                part = part + artifact_for(s.stop).jac;
            }
            if s.step {
                part = part + ":" + artifact_for(s.step).jac;
            }
            slice_parts.append(part);
        }
        result = result + ", ".join(slice_parts);
    } elif len(here.slices) == 1 and here.slices[0].start {
        result = result + artifact_for(here.slices[0].start).jac;
    }
    artifact_for(here).jac = result + "]";
}

impl UnparsePass.exit_edge_ref_trailer with uni.EdgeRefTrailer exit {
    artifact_for(here).jac = _join_kids(here);
}

impl UnparsePass.exit_edge_op_ref with uni.EdgeOpRef exit {
    artifact_for(here).jac = _join_kids(here);
}

impl UnparsePass.exit_disconnect_op with uni.DisconnectOp exit {
    artifact_for(here).jac = "delete " + artifact_for(here.edge_spec).jac;
}

impl UnparsePass.exit_connect_op with uni.ConnectOp exit {
    artifact_for(here).jac = _join_kids(here);
}

impl UnparsePass.exit_filter_compr with uni.FilterCompr exit {
    parts: list[str] = [];
    is_edge_inline = isinstance(here.parent, uni.EdgeOpRef);
    if is_edge_inline {
        if here.f_type {
            parts.append(artifact_for(here.f_type).jac);
        }
        if here.compares {
            if here.f_type {
                parts.append(":");
            }
            parts.append(", ".join([artifact_for(c).jac for c in here.compares]));
        }
    } else {
        parts.append("[?");
        if here.f_type {
            parts.append(":");
            parts.append(artifact_for(here.f_type).jac);
        }
        if here.compares {
            if here.f_type {
                parts.append(", ");
            }
            parts.append(", ".join([artifact_for(c).jac for c in here.compares]));
        }
        parts.append("]");
    }
    artifact_for(here).jac = "".join(parts);
}

impl UnparsePass.exit_assign_compr with uni.AssignCompr exit {
    artifact_for(here).jac = _join_kids(here);
}

impl UnparsePass.exit_jsx_element with uni.JsxElement exit {
    artifact_for(here).jac = _join_kids(here, sep="");
}

impl UnparsePass.exit_jsx_element_name with uni.JsxElementName exit {
    if here.parts {
        artifact_for(here).jac = ".".join(
            [
                artifact_for(p).jac
                for p in here.parts
                if p
            ]
        );
    } else {
        artifact_for(here).jac = "";
    }
}

impl UnparsePass.exit_jsx_spread_attribute with uni.JsxSpreadAttribute exit {
    artifact_for(here).jac = artifact_for(here.expr).jac;
}

impl UnparsePass.exit_jsx_normal_attribute with uni.JsxNormalAttribute exit {
    if here.is_shorthand {
        artifact_for(here).jac = "{" + artifact_for(here.name).jac + "}";
        return;
    }
    result = artifact_for(here.name).jac;
    if here.value {
        result = result + " = " + artifact_for(here.value).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_jsx_text with uni.JsxText exit {
    artifact_for(here).jac = _join_kids(here, sep="");
}

impl UnparsePass.exit_jsx_expression with uni.JsxExpression exit {
    artifact_for(here).jac = artifact_for(here.expr).jac;
}

impl UnparsePass.exit_jsx_slot with uni.JsxSlot exit {
    parts: list[str] = [];
    for k in here.kid {
        s = artifact_for(k).jac;
        if s is not None {
            parts.append(s);
        }
    }
    artifact_for(here).jac = "".join(parts);
}

impl UnparsePass.exit_jsx_comment with uni.JsxComment exit {
    artifact_for(here).jac = here.value.value
        if isinstance(here.value, uni.Token)
        else str(here.value);
}

impl UnparsePass.exit_match_stmt with uni.MatchStmt exit {
    cases = " ".join([artifact_for(c).jac for c in here.cases]);
    artifact_for(here).jac = "match "
        + artifact_for(here.target).jac
        + " { "
        + cases
        + " }";
}

impl UnparsePass.exit_match_case with uni.MatchCase exit {
    parts: list = ["case", artifact_for(here.pattern).jac];
    if here.guard {
        parts.append("if");
        parts.append(artifact_for(here.guard).jac);
    }
    parts.append(":");
    body = " ".join([artifact_for(s).jac for s in here.body]);
    parts.append(body);
    artifact_for(here).jac = " ".join(parts);
}

impl UnparsePass.exit_switch_stmt with uni.SwitchStmt exit {
    cases = " ".join([artifact_for(c).jac for c in here.cases]);
    artifact_for(here).jac = "switch "
        + artifact_for(here.target).jac
        + " { "
        + cases
        + " }";
}

impl UnparsePass.exit_switch_case with uni.SwitchCase exit {
    if here.pattern is not None {
        result = "case " + artifact_for(here.pattern).jac;
    } else {
        result = "default";
    }
    result = result + ":";
    body = " ".join([artifact_for(s).jac for s in here.body]);
    result = result + " " + body;
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_match_or with uni.MatchOr exit {
    artifact_for(here).jac = " | ".join([artifact_for(p).jac for p in here.patterns]);
}

impl UnparsePass.exit_match_as with uni.MatchAs exit {
    if here.pattern {
        artifact_for(here).jac = artifact_for(here.pattern).jac
            + " as "
            + artifact_for(here.name).jac;
    } else {
        artifact_for(here).jac = artifact_for(here.name).jac;
    }
}

impl UnparsePass.exit_match_wild with uni.MatchWild exit {
    artifact_for(here).jac = "_";
}

impl UnparsePass.exit_match_value with uni.MatchValue exit {
    artifact_for(here).jac = artifact_for(here.value).jac;
}

impl UnparsePass.exit_match_singleton with uni.MatchSingleton exit {
    artifact_for(here).jac = artifact_for(here.value).jac;
}

impl UnparsePass.exit_match_sequence with uni.MatchSequence exit {
    artifact_for(here).jac = "[" + self._comma_sep(here.values) + "]";
}

impl UnparsePass.exit_match_mapping with uni.MatchMapping exit {
    artifact_for(here).jac = "{" + self._comma_sep(here.values) + "}";
}

impl UnparsePass.exit_match_k_v_pair with uni.MatchKVPair exit {
    artifact_for(here).jac = artifact_for(here.key).jac
        + " "
        + artifact_for(here.kid[1]).jac
        + " "
        + artifact_for(here.value).jac;
}

impl UnparsePass.exit_match_star with uni.MatchStar exit {
    result = "*";
    if here.name {
        result = result + artifact_for(here.name).jac;
    }
    artifact_for(here).jac = result;
}

impl UnparsePass.exit_match_arch with uni.MatchArch exit {
    parts: list = [];
    if here.arg_patterns {
        parts.extend([artifact_for(a).jac for a in here.arg_patterns]);
    }
    if here.kw_patterns {
        parts.extend([artifact_for(k).jac for k in here.kw_patterns]);
    }
    artifact_for(here).jac = artifact_for(here.name).jac + "(" + ", ".join(parts) + ")";
}
