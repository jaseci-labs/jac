def _join_kids(nd: uni.UniNode, sep: str = " ") -> str {
    return sep.join(
        [
            k.gen.jac
            for k in nd.kid
            if k and k.gen.jac
        ]
    );
}

impl UnparsePass._comma_sep(nodes: Sequence[uni.UniNode]) -> str {
    return ", ".join(
        [
            n.gen.jac
            for n in nodes
            if n
        ]
    );
}

impl UnparsePass.unparse_prepare_exit with uni.UniNode exit {
    for attr in vars(here).values() {
        if isinstance(attr, uni.Token) and not attr.gen.jac {
            attr.gen.jac = attr.value;
        }
    }
}

impl UnparsePass.unparse_default_exit with uni.UniNode exit {
    if isinstance(here, uni.Token) {
        here.gen.jac = here.value;
    } else {
        here.gen.jac = " ".join(
            [
                k.gen.jac
                for k in here.kid
                if k and k.gen.jac
            ]
        );
    }
}

impl UnparsePass.exit_token with uni.Token exit {
    if here.__class__ is not uni.Token {
        return;
    }
    here.gen.jac = here.value;
}

impl UnparsePass.exit_name with uni.Name exit {
    if here.__class__ is not uni.Name {
        return;
    }
    prefix = "`" if here.is_kwesc else "";
    suffix = ",\n" if here.is_enum_stmt else "";
    here.gen.jac = prefix + here.value + suffix;
}

impl UnparsePass.exit_string with uni.String exit {
    if here.parent and isinstance(here.parent, uni.FString) {
        escaped = here.value.replace("{", "{{").replace("}", "}}");
        here.gen.jac = escaped.replace("#", "\\#");
    } else {
        here.gen.jac = here.value;
    }
}

impl UnparsePass.exit_semi with uni.Semi exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_int with uni.Int exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_float with uni.Float exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_bool with uni.Bool exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_null with uni.Null exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_ellipsis with uni.Ellipsis exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_builtin_type with uni.BuiltinType exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_special_var_ref with uni.SpecialVarRef exit {
    here.gen.jac = here.value;
}

impl UnparsePass.exit_module with uni.Module exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
    }
    for stmt in here.body {
        parts.append(stmt.gen.jac);
    }
    here.gen.jac = " ".join(parts);
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
    here.gen.jac = ": " + prefix + here.tag.gen.jac;
}

impl UnparsePass.exit_type_param with uni.TypeParam exit {
    parts: list = [("comptime " if here.is_comptime else "") + here.name.gen.jac];
    if here.bound {
        parts.append(": " + here.bound.gen.jac);
    }
    if here.default_val {
        parts.append(" = " + here.default_val.gen.jac);
    }
    here.gen.jac = "".join(parts);
}

impl UnparsePass.exit_type_alias with uni.TypeAlias exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
    }
    parts.append("type");
    if here.access {
        parts.append(here.access.gen.jac);
    }
    parts.append(here.name.gen.jac);
    if here.type_params {
        tp_str = ", ".join([tp.gen.jac for tp in here.type_params]);
        parts.append("[" + tp_str + "]");
    }
    parts.append(":=" if here.is_distinct else "=");
    parts.append(here.value.gen.jac);
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_global_vars with uni.GlobalVars exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
    }
    parts.append("comptime" if here.is_frozen else "glob");
    if here.access {
        parts.append(here.access.gen.jac);
    }
    parts.append(self._comma_sep(here.assignments));
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_test with uni.Test exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
    }
    if here.decorators {
        decs = " @".join([d.gen.jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    parts.append("test");
    if here.description {
        parts.append(here.description.gen.jac);
    } elif here.name.value and not here.name.value.startswith('_jac_gen_') {
        parts.append(here.name.gen.jac);
    }
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append("{ " + body + " }");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_module_code with uni.ModuleCode exit {
    parts: list = ["with entry"];
    if here.name {
        parts.append(":");
        parts.append(here.name.gen.jac);
    }
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append("{ " + body + " }");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_py_inline_code with uni.PyInlineCode exit {
    here.gen.jac = "::py::" + here.code.value + "::py::";
}

impl UnparsePass.exit_import with uni.Import exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
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
        parts.append(here.from_loc.gen.jac);
        parts.append("{ " + items + " }");
    } else {
        parts.append(items);
        parts.append(";");
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_module_path with uni.ModulePath exit {
    path = ".".join([p.gen.jac for p in here.path] if here.path else []);
    if here.alias {
        path = path + " as " + here.alias.gen.jac;
    }
    here.gen.jac = path;
}

impl UnparsePass.exit_module_item with uni.ModuleItem exit {
    result = here.name.gen.jac;
    if here.alias {
        result = result + " as " + here.alias.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_archetype with uni.Archetype exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
        if not isinstance(here.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if here.decorators {
        decs = " @".join([d.gen.jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    if here.is_async {
        parts.append("async");
    }
    parts.append(here.arch_type.gen.jac);
    if here.access {
        parts.append(here.access.gen.jac);
    }
    parts.append(here.name.gen.jac);
    if here.type_params {
        tp_str = ", ".join([tp.gen.jac for tp in here.type_params]);
        parts.append("[" + tp_str + "]");
    }
    if here.base_classes or here.keywords {
        inherit = [b.gen.jac for b in here.base_classes]
            + [k.gen.jac for k in here.keywords];
        parts.append("(" + ", ".join(inherit) + ")");
    }
    if here.src_endpoint and here.tgt_endpoint {
        parts.append(
            ": " + here.src_endpoint.gen.jac + " --> " + here.tgt_endpoint.gen.jac
        );
    }
    if here.body {
        if isinstance(here.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([s.gen.jac for s in here.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append("{ }");
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_impl_def with uni.ImplDef exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
    }
    if here.decorators {
        decs = " @".join([d.gen.jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    parts.append("impl");
    target_str = ".".join([t.gen.jac for t in here.target]);
    parts.append(target_str);
    if here.spec {
        if isinstance(here.spec, (uni.FuncSignature, uni.EventSignature)) {
            parts.append(here.spec.gen.jac);
        } else {
            parts.append("(" + self._comma_sep(here.spec) + ")");
        }
    }
    if isinstance(here.body, uni.Expr) {
        parts.append(here.body.gen.jac);
    } else {
        body = " ".join([s.gen.jac for s in here.body]);
        parts.append("{ " + body + " }");
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_sem_def with uni.SemDef exit {
    target_str = ".".join([t.gen.jac for t in here.target]);
    here.gen.jac = "sem " + target_str + " = " + here.value.gen.jac + ";";
}

impl UnparsePass.exit_enum with uni.Enum exit {
    parts: list = [];
    if here.decorators {
        decs = " @".join([d.gen.jac for d in here.decorators]);
        parts.append("@" + decs);
    }
    if here.doc {
        parts.append(here.doc.gen.jac);
    }
    parts.append("enum");
    if here.access {
        parts.append(here.access.gen.jac);
    }
    parts.append(here.name.gen.jac);
    if here.value_type {
        parts.append(": " + here.value_type.gen.jac);
    } elif here.base_classes {
        parts.append("(" + self._comma_sep(here.base_classes) + ")");
    }
    if here.body {
        if isinstance(here.body, uni.ImplDef) {
            parts.append(";");
        } else {
            body = " ".join([s.gen.jac for s in here.body]);
            parts.append("{ " + body + " }");
        }
    } else {
        parts.append(";");
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_ability with uni.Ability exit {
    parts: list = [];
    if here.doc {
        parts.append(here.doc.gen.jac);
        if not isinstance(here.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            parts.append(";");
        }
    }
    if here.decorators {
        decs = " @".join([d.gen.jac for d in here.decorators]);
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
        parts.append(here.access.gen.jac);
    }
    if here.name_ref {
        parts.append(here.name_ref.gen.jac);
    }
    if here.signature {
        parts.append(here.signature.gen.jac);
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
            body = " ".join([s.gen.jac for s in here.body]);
            parts.append("{ " + body + " }");
        } else {
            parts.append(here.body.gen.jac);
            if here.is_genai_ability {
                parts.append(";");
            }
        }
    } else {
        parts.append(";");
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_func_signature with uni.FuncSignature exit {
    param_parts: list = [];
    if here.posonly_params {
        for prm in here.posonly_params {
            param_parts.append(prm.gen.jac);
        }
        param_parts.append("/");
    }
    for prm in here.params {
        param_parts.append(prm.gen.jac);
    }
    if here.varargs {
        param_parts.append(here.varargs.gen.jac);
    } elif here.kwonlyargs {
        param_parts.append("*");
    }
    for prm in here.kwonlyargs {
        param_parts.append(prm.gen.jac);
    }
    if here.kwargs {
        param_parts.append(here.kwargs.gen.jac);
    }
    params_str = ", ".join(param_parts);
    result = "(" + params_str + ")";
    if here.return_type {
        result = result + " -> " + here.return_type.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_event_signature with uni.EventSignature exit {
    parts: list = ["with"];
    if here.arch_tag_info {
        parts.append(here.arch_tag_info.gen.jac);
    }
    parts.append(here.event.gen.jac);
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_param_var with uni.ParamVar exit {
    result = "comptime " if here.is_comptime else "";
    if here.unpack {
        result = here.unpack.gen.jac;
    }
    result = result + here.name.gen.jac;
    if here.type_tag {
        result = result + here.type_tag.gen.jac;
    }
    if here.value {
        result = result + " = " + here.value.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_arch_has with uni.ArchHas exit {
    parts: list = [];
    if here.access {
        parts.append(here.access.gen.jac);
    }
    parts.append("has");
    for v in here.vars {
        parts.append(v.gen.jac);
    }
    parts.append(";");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_has_var with uni.HasVar exit {
    result = here.name.gen.jac;
    if here.type_tag {
        result = result + here.type_tag.gen.jac;
    }
    if here.value {
        result = result + " = " + here.value.gen.jac;
    }
    result = result + " ,";
    here.gen.jac = result;
}

impl UnparsePass.exit_typed_ctx_block with uni.TypedCtxBlock exit {
    parts: list = [":"];
    if here.type_ctx {
        parts.append(here.type_ctx.gen.jac);
    }
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append("{ " + body + " }");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_open_stmt with uni.OpenStmt exit {
    body = " ".join([s.gen.jac for s in here.body]);
    here.gen.jac = "in " + here.target.gen.jac + " { " + body + " }";
}

impl UnparsePass.exit_if_stmt with uni.IfStmt exit {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    body = " ".join([s.gen.jac for s in here.body]);
    result = ("comptime " if here.is_comptime else "")
        + "if "
        + here.condition.gen.jac
        + " { "
        + body
        + " }";
    if here.else_body {
        result = result + " " + here.else_body.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_else_if with uni.ElseIf exit {
    body = " ".join([s.gen.jac for s in here.body]);
    result = "elif " + here.condition.gen.jac + " { " + body + " }";
    if here.else_body {
        result = result + " " + here.else_body.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_else_stmt with uni.ElseStmt exit {
    body = " ".join([s.gen.jac for s in here.body]);
    here.gen.jac = "else { " + body + " }";
}

impl UnparsePass.exit_expr_stmt with uni.ExprStmt exit {
    result = "";
    if here.expr {
        result = here.expr.gen.jac;
    }
    here.gen.jac = result + ";";
}

impl UnparsePass.exit_try_stmt with uni.TryStmt exit {
    body = " ".join([s.gen.jac for s in here.body]);
    result = "try { " + body + " }";
    for exc in here.excepts {
        result = result + " " + exc.gen.jac;
    }
    if here.else_body {
        result = result + " " + here.else_body.gen.jac;
    }
    if here.finally_body {
        result = result + " " + here.finally_body.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_except with uni.Except exit {
    parts: list = ["except"];
    if here.ex_type {
        parts.append(here.ex_type.gen.jac);
        if here.name {
            parts.append("as");
            parts.append(here.name.gen.jac);
        }
    }
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append("{ " + body + " }");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_finally_stmt with uni.FinallyStmt exit {
    body = " ".join([s.gen.jac for s in here.body]);
    here.gen.jac = "finally { " + body + " }";
}

impl UnparsePass.exit_iter_for_stmt with uni.IterForStmt exit {
    parts: list = ["async for" if here.is_async else "for"];
    parts.append(here.iter.gen.jac);
    if here.condition {
        parts.append("while");
        parts.append(here.condition.gen.jac);
    }
    if here.count_by {
        parts.append("with");
        parts.append(here.count_by.gen.jac);
    }
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append("{ " + body + " }");
    if here.else_body {
        parts.append(here.else_body.gen.jac);
    }
    here.gen.jac = " ".join(parts);
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
    parts.append(here.target.gen.jac);
    parts.append("in");
    parts.append(here.collection.gen.jac);
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append("{ " + body + " }");
    if here.else_body {
        parts.append(here.else_body.gen.jac);
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_while_stmt with uni.WhileStmt exit {
    body = " ".join([s.gen.jac for s in here.body]);
    result = "while " + here.condition.gen.jac + " { " + body + " }";
    if here.else_body {
        result = result + " " + here.else_body.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_forever_stmt with uni.ForeverStmt exit {
    body = " ".join([s.gen.jac for s in here.body]);
    here.gen.jac = "forever { " + body + " }";
}

impl UnparsePass.exit_with_stmt with uni.WithStmt exit {
    parts: list = ["with"];
    if here.is_async {
        parts.append("async");
    }
    if here.exprs {
        parts.append(self._comma_sep(here.exprs));
    }
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append("{ " + body + " }");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_expr_as_item with uni.ExprAsItem exit {
    result = here.expr.gen.jac;
    if here.alias {
        result = result + " as " + here.alias.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_raise_stmt with uni.RaiseStmt exit {
    parts: list = ["raise"];
    if here.cause {
        parts.append(here.cause.gen.jac);
    }
    if here.from_target {
        parts.append("from");
        parts.append(here.from_target.gen.jac);
    }
    here.gen.jac = " ".join(parts) + ";";
}

impl UnparsePass.exit_assert_stmt with uni.AssertStmt exit {
    parts: list = [];
    if here.is_comptime {
        parts.append("comptime");
    }
    parts.extend(["assert", here.condition.gen.jac]);
    if here.error_msg {
        parts.append(",");
        parts.append(here.error_msg.gen.jac);
    }
    here.gen.jac = " ".join(parts) + ";";
}

impl UnparsePass.exit_ctrl_stmt with uni.CtrlStmt exit {
    here.gen.jac = str(here.ctrl.value) + ";";
}

impl UnparsePass.exit_delete_stmt with uni.DeleteStmt exit {
    here.gen.jac = "delete " + ", ".join([t.gen.jac for t in here.targets]) + ";";
}

impl UnparsePass.exit_report_stmt with uni.ReportStmt exit {
    here.gen.jac = "report " + here.expr.gen.jac + ";";
}

impl UnparsePass.exit_return_stmt with uni.ReturnStmt exit {
    if here.is_implicit and here.expr {
        here.gen.jac = here.expr.gen.jac;
        return;
    }
    parts: list = ["return"];
    if here.expr {
        parts.append(here.expr.gen.jac);
    }
    parts.append(";");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_visit_stmt with uni.VisitStmt exit {
    parts: list = ["visit"];
    if here.insert_loc {
        parts.append(here.insert_loc.gen.jac);
    }
    parts.append(here.target.gen.jac);
    if here.else_body {
        parts.append(here.else_body.gen.jac);
    }
    parts.append(";");
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_disengage_stmt with uni.DisengageStmt exit {
    here.gen.jac = "disengage ;";
}

impl UnparsePass.exit_await_expr with uni.AwaitExpr exit {
    here.gen.jac = "await " + here.target.gen.jac;
}

impl UnparsePass.exit_cast_expr with uni.CastExpr exit {
    here.gen.jac = here.value.gen.jac + " as " + here.cast_type.gen.jac;
}

impl UnparsePass.exit_assignment with uni.Assignment exit {
    parts: list = [];
    if here.is_comptime and not isinstance(here.parent, uni.GlobalVars) {
        parts.append("comptime");
    }
    targets = " = ".join([t.gen.jac for t in here.target]);
    parts.append(targets);
    if here.type_tag {
        parts.append(here.type_tag.gen.jac);
    }
    if here.aug_op {
        parts.append(here.aug_op.gen.jac);
    }
    if here.value {
        if not here.aug_op {
            parts.append("=");
        }
        parts.append(here.value.gen.jac);
    }
    result = " ".join(parts);

    if not here.is_enum_stmt
        and not (
            isinstance(here.parent, uni.IterForStmt)
            and (here == here.parent.iter or here == here.parent.count_by)
        ) {
        result = result + ";";
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_concurrent_expr with uni.ConcurrentExpr exit {
    parts: list = [];
    if isinstance(here.tok, uni.Token) and here.tok.value {
        parts.append(here.tok.gen.jac);
    }
    parts.append(here.target.gen.jac);
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_binary_expr with uni.BinaryExpr exit {
    here.gen.jac = here.left.gen.jac + " " + here.op.gen.jac + " " + here.right.gen.jac;
}

impl UnparsePass.exit_compare_expr with uni.CompareExpr exit {
    result = here.left.gen.jac;
    for i in range(len(here.rights)) {
        result = result + " " + here.ops[i].gen.jac + " " + here.rights[i].gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_cfg_expr with uni.CfgExpr exit {
    here.gen.jac = here.expr.gen.jac;
}

impl UnparsePass.exit_bool_expr with uni.BoolExpr exit {
    sep = " " + here.op.gen.jac + " ";
    here.gen.jac = sep.join([v.gen.jac for v in here.values]);
}

impl UnparsePass.exit_lambda_expr with uni.LambdaExpr exit {
    parts: list = ["lambda"];
    if here.signature {
        parts.append(here.signature.gen.jac);
    }
    if isinstance(here.body, uni.Expr) {
        parts.append("{ " + here.body.gen.jac + " }");
    } else {
        body = " ".join([s.gen.jac for s in here.body]);
        parts.append("{ " + body + " }");
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_unary_expr with uni.UnaryExpr exit {
    if is_mut_kind(here.ownership) {
        here.gen.jac = here.op.gen.jac + "mut " + here.operand.gen.jac;
    } else {
        here.gen.jac = here.op.gen.jac + " " + here.operand.gen.jac;
    }
}

impl UnparsePass.exit_if_else_expr with uni.IfElseExpr exit {
    here.gen.jac = here.value.gen.jac
        + " if "
        + here.condition.gen.jac
        + " else "
        + here.else_value.gen.jac;
}

impl UnparsePass.exit_multi_string with uni.MultiString exit {
    here.gen.jac = " ".join([s.gen.jac for s in here.strings]);
}

impl UnparsePass.exit_f_string with uni.FString exit {
    parts: list = [];
    if here.start is not None {
        parts.append(here.start.gen.jac);
    }
    for part in here.parts {
        parts.append(part.gen.jac);
    }
    if here.end is not None {
        parts.append(here.end.gen.jac);
    }
    here.gen.jac = "".join(parts);
}

impl UnparsePass.exit_formatted_value with uni.FormattedValue exit {
    result = "{" + here.format_part.gen.jac;
    if here.conversion != -1 {
        result = result + "!" + chr(here.conversion);
    }
    if here.format_spec {
        result = result + ":" + here.format_spec.gen.jac;
    }
    here.gen.jac = result + "}";
}

impl UnparsePass.exit_list_val with uni.ListVal exit {
    here.gen.jac = "[" + self._comma_sep(here.values) + "]";
}

impl UnparsePass.exit_set_val with uni.SetVal exit {
    vals: Sequence[uni.Expr] = here.values if here.values is not None else [];
    here.gen.jac = "{" + self._comma_sep(vals) + "}";
}

impl UnparsePass.exit_tuple_val with uni.TupleVal exit {
    inner = self._comma_sep(here.values);
    if len(here.values) == 1 {
        inner = inner + ",";
    }
    here.gen.jac = "(" + inner + ")";
}

impl UnparsePass.exit_dict_val with uni.DictVal exit {
    here.gen.jac = "{" + self._comma_sep(here.kv_pairs) + "}";
}

impl UnparsePass.exit_k_v_pair with uni.KVPair exit {
    if here.key {
        here.gen.jac = here.key.gen.jac + " : " + here.value.gen.jac;
    } else {
        here.gen.jac = "**" + here.value.gen.jac;
    }
}

impl UnparsePass.exit_k_w_pair with uni.KWPair exit {
    if here.key {
        here.gen.jac = here.key.gen.jac + " = " + here.value.gen.jac;
    } else {
        here.gen.jac = "**" + here.value.gen.jac;
    }
}

impl UnparsePass.exit_inner_compr with uni.InnerCompr exit {
    parts: list = ["for"];
    if here.is_async {
        parts.append("async");
    }
    parts.append(here.target.gen.jac);
    parts.append("in");
    parts.append(here.collection.gen.jac);
    if here.conditional {
        for cond in here.conditional {
            parts.append("if");
            parts.append(cond.gen.jac);
        }
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_list_compr with uni.ListCompr exit {
    if here.__class__ is not uni.ListCompr {
        return;
    }
    comprs = " ".join([c.gen.jac for c in here.compr]);
    here.gen.jac = "[" + here.out_expr.gen.jac + " " + comprs + "]";
}

impl UnparsePass.exit_gen_compr with uni.GenCompr exit {
    comprs = " ".join([c.gen.jac for c in here.compr]);
    inner = here.out_expr.gen.jac + " " + comprs;

    here.gen.jac = "(" + inner + ")";
}

impl UnparsePass.exit_set_compr with uni.SetCompr exit {
    comprs = " ".join([c.gen.jac for c in here.compr]);
    here.gen.jac = "{" + here.out_expr.gen.jac + " " + comprs + "}";
}

impl UnparsePass.exit_dict_compr with uni.DictCompr exit {
    comprs = " ".join([c.gen.jac for c in here.compr]);
    here.gen.jac = "{" + here.kv_pair.gen.jac + " " + comprs + "}";
}

impl UnparsePass.exit_atom_trailer with uni.AtomTrailer exit {
    result = here.target.gen.jac;
    if here.is_null_ok {
        result = result + "?";
    }
    if here.is_attr {
        result = result + ".";
    }
    if here.right {
        result = result + here.right.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_atom_unit with uni.AtomUnit exit {
    here.gen.jac = "(" + here.value.gen.jac + ")";
}

impl UnparsePass.exit_graph_expr with uni.GraphExpr exit {
    here.gen.jac = "graph { "
        + " ".join([expr.gen.jac + ";" for expr in here.exprs])
        + " }";
}

impl UnparsePass.exit_yield_expr with uni.YieldExpr exit {
    parts: list = ["yield"];
    if here.with_from {
        parts.append("from");
    }
    if here.expr {
        parts.append(here.expr.gen.jac);
    }
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_func_call with uni.FuncCall exit {
    call_params: Sequence[(uni.Expr | uni.KWPair)] = here.params
        if here.params is not None
        else [];
    is_gencompr = len(call_params) == 1 and isinstance(call_params[0], uni.GenCompr);
    params_str = self._comma_sep(call_params);
    if is_gencompr {
        result = here.target.gen.jac + params_str;
    } else {
        result = here.target.gen.jac + "(" + params_str;
        if here.genai_call {
            result = result + " by " + here.genai_call.gen.jac;
        }
        result = result + ")";
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_index_slice with uni.IndexSlice exit {
    result = "[";
    if here.is_range {
        slice_parts: list = [];
        for s in here.slices {
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
    } elif len(here.slices) == 1 and here.slices[0].start {
        result = result + here.slices[0].start.gen.jac;
    }
    here.gen.jac = result + "]";
}

impl UnparsePass.exit_edge_ref_trailer with uni.EdgeRefTrailer exit {
    here.gen.jac = _join_kids(here);
}

impl UnparsePass.exit_edge_op_ref with uni.EdgeOpRef exit {
    here.gen.jac = _join_kids(here);
}

impl UnparsePass.exit_disconnect_op with uni.DisconnectOp exit {
    here.gen.jac = "delete " + here.edge_spec.gen.jac;
}

impl UnparsePass.exit_connect_op with uni.ConnectOp exit {
    here.gen.jac = _join_kids(here);
}

impl UnparsePass.exit_filter_compr with uni.FilterCompr exit {
    parts: list[str] = [];
    is_edge_inline = isinstance(here.parent, uni.EdgeOpRef);
    if is_edge_inline {
        if here.f_type {
            parts.append(here.f_type.gen.jac);
        }
        if here.compares {
            if here.f_type {
                parts.append(":");
            }
            parts.append(", ".join([c.gen.jac for c in here.compares]));
        }
    } else {
        parts.append("[?");
        if here.f_type {
            parts.append(":");
            parts.append(here.f_type.gen.jac);
        }
        if here.compares {
            if here.f_type {
                parts.append(", ");
            }
            parts.append(", ".join([c.gen.jac for c in here.compares]));
        }
        parts.append("]");
    }
    here.gen.jac = "".join(parts);
}

impl UnparsePass.exit_assign_compr with uni.AssignCompr exit {
    here.gen.jac = _join_kids(here);
}

impl UnparsePass.exit_jsx_element with uni.JsxElement exit {
    here.gen.jac = _join_kids(here, sep="");
}

impl UnparsePass.exit_jsx_element_name with uni.JsxElementName exit {
    if here.parts {
        here.gen.jac = ".".join(
            [
                p.gen.jac
                for p in here.parts
                if p
            ]
        );
    } else {
        here.gen.jac = "";
    }
}

impl UnparsePass.exit_jsx_spread_attribute with uni.JsxSpreadAttribute exit {
    here.gen.jac = here.expr.gen.jac;
}

impl UnparsePass.exit_jsx_normal_attribute with uni.JsxNormalAttribute exit {
    if here.is_shorthand {
        here.gen.jac = "{" + here.name.gen.jac + "}";
        return;
    }
    result = here.name.gen.jac;
    if here.value {
        result = result + " = " + here.value.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_jsx_text with uni.JsxText exit {
    here.gen.jac = _join_kids(here, sep="");
}

impl UnparsePass.exit_jsx_expression with uni.JsxExpression exit {
    here.gen.jac = here.expr.gen.jac;
}

impl UnparsePass.exit_jsx_slot with uni.JsxSlot exit {
    parts: list[str] = [];
    for k in here.kid {
        s = k.gen.jac;
        if s is not None {
            parts.append(s);
        }
    }
    here.gen.jac = "".join(parts);
}

impl UnparsePass.exit_jsx_comment with uni.JsxComment exit {
    here.gen.jac = here.value.value
        if isinstance(here.value, uni.Token)
        else str(here.value);
}

impl UnparsePass.exit_match_stmt with uni.MatchStmt exit {
    cases = " ".join([c.gen.jac for c in here.cases]);
    here.gen.jac = "match " + here.target.gen.jac + " { " + cases + " }";
}

impl UnparsePass.exit_match_case with uni.MatchCase exit {
    parts: list = ["case", here.pattern.gen.jac];
    if here.guard {
        parts.append("if");
        parts.append(here.guard.gen.jac);
    }
    parts.append(":");
    body = " ".join([s.gen.jac for s in here.body]);
    parts.append(body);
    here.gen.jac = " ".join(parts);
}

impl UnparsePass.exit_switch_stmt with uni.SwitchStmt exit {
    cases = " ".join([c.gen.jac for c in here.cases]);
    here.gen.jac = "switch " + here.target.gen.jac + " { " + cases + " }";
}

impl UnparsePass.exit_switch_case with uni.SwitchCase exit {
    if here.pattern is not None {
        result = "case " + here.pattern.gen.jac;
    } else {
        result = "default";
    }
    result = result + ":";
    body = " ".join([s.gen.jac for s in here.body]);
    result = result + " " + body;
    here.gen.jac = result;
}

impl UnparsePass.exit_match_or with uni.MatchOr exit {
    here.gen.jac = " | ".join([p.gen.jac for p in here.patterns]);
}

impl UnparsePass.exit_match_as with uni.MatchAs exit {
    if here.pattern {
        here.gen.jac = here.pattern.gen.jac + " as " + here.name.gen.jac;
    } else {
        here.gen.jac = here.name.gen.jac;
    }
}

impl UnparsePass.exit_match_wild with uni.MatchWild exit {
    here.gen.jac = "_";
}

impl UnparsePass.exit_match_value with uni.MatchValue exit {
    here.gen.jac = here.value.gen.jac;
}

impl UnparsePass.exit_match_singleton with uni.MatchSingleton exit {
    here.gen.jac = here.value.gen.jac;
}

impl UnparsePass.exit_match_sequence with uni.MatchSequence exit {
    here.gen.jac = "[" + self._comma_sep(here.values) + "]";
}

impl UnparsePass.exit_match_mapping with uni.MatchMapping exit {
    here.gen.jac = "{" + self._comma_sep(here.values) + "}";
}

impl UnparsePass.exit_match_k_v_pair with uni.MatchKVPair exit {
    here.gen.jac = here.key.gen.jac
        + " "
        + here.kid[1].gen.jac
        + " "
        + here.value.gen.jac;
}

impl UnparsePass.exit_match_star with uni.MatchStar exit {
    result = "*";
    if here.name {
        result = result + here.name.gen.jac;
    }
    here.gen.jac = result;
}

impl UnparsePass.exit_match_arch with uni.MatchArch exit {
    parts: list = [];
    if here.arg_patterns {
        parts.extend([a.gen.jac for a in here.arg_patterns]);
    }
    if here.kw_patterns {
        parts.extend([k.gen.jac for k in here.kw_patterns]);
    }
    here.gen.jac = here.name.gen.jac + "(" + ", ".join(parts) + ")";
}
