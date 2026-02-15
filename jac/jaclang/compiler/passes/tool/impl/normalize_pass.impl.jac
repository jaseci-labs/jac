"""NormalizePass implementation - rebuilds kid lists from semantic fields."""

"""Initialize the NormalizePass."""
impl NormalizePass.init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Normalize SubTag kid list."""
impl NormalizePass.enter_sub_tag(`node: uni.SubTag) -> None {
    `node.set_kids(nodes=[`node.gen_token(Tok.COLON), `node.tag]);
}

"""Normalize Module kid list."""
impl NormalizePass.enter_module(`node: uni.Module) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    new_kid.extend(`node.body);
    `node.set_kids(nodes=new_kid if len(new_kid) else [EmptyToken()]);
}

"""Normalize GlobalVars kid list."""
impl NormalizePass.enter_global_vars(`node: uni.GlobalVars) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    client_tok = `node._source_context_token();
    if `node.code_context == CodeContext.CLIENT
    and (client_tok is not None or not `node.in_client_context()) {
        new_kid.append(client_tok or `node.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(`node.gen_token(Tok.KW_GLOBAL));
    if `node.access {
        new_kid.append(`node.access);
    }
    for i in range(len(`node.assignments)) {
        new_kid.append(`node.assignments[i]);
        if i < len(`node.assignments) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize Test kid list."""
impl NormalizePass.enter_test(`node: uni.Test) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    client_tok = `node._source_context_token();
    if `node.code_context == CodeContext.CLIENT
    and (client_tok is not None or not `node.in_client_context()) {
        new_kid.append(client_tok or `node.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(`node.gen_token(Tok.KW_TEST));
    new_kid.append(`node.name);
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize ModuleCode kid list."""
impl NormalizePass.enter_module_code(`node: uni.ModuleCode) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    client_tok = `node._source_context_token();
    if `node.code_context == CodeContext.CLIENT
    and (client_tok is not None or not `node.in_client_context()) {
        new_kid.append(client_tok or `node.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(`node.gen_token(Tok.KW_WITH));
    new_kid.append(`node.gen_token(Tok.KW_ENTRY));
    if `node.name {
        new_kid.append(`node.gen_token(Tok.COLON));
        new_kid.append(`node.name);
    }
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize ClientBlock kid list."""
impl NormalizePass.enter_client_block(`node: uni.ClientBlock) -> None {
    new_kid: list[uni.UniNode] = [];
    parent_mod = `node.find_parent_of_type(uni.Module);
    is_implicit_top_level_cl_module = (
        `node.implicit
        and parent_mod is not None
        and parent_mod.loc.mod_path.endswith(".cl.jac")
        and parent_mod.body == [`node]
    );
    if is_implicit_top_level_cl_module {
        if `node.body {
            new_kid.extend(`node.body);
        } else {
            new_kid.append(EmptyToken());
        }
    } else {
        new_kid.append(`node.gen_token(Tok.KW_CLIENT));
        new_kid.append(`node.gen_token(Tok.LBRACE));
        for stmt in `node.body {
            new_kid.append(stmt);
        }
        new_kid.append(`node.gen_token(Tok.RBRACE));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ServerBlock kid list."""
impl NormalizePass.enter_server_block(`node: uni.ServerBlock) -> None {
    new_kid: list[uni.UniNode] = [];
    parent_mod = `node.find_parent_of_type(uni.Module);
    is_implicit_top_level_sv_module = (
        `node.implicit
        and parent_mod is not None
        and parent_mod.loc.mod_path.endswith(".sv.jac")
        and parent_mod.body == [`node]
    );
    if is_implicit_top_level_sv_module {
        if `node.body {
            new_kid.extend(`node.body);
        } else {
            new_kid.append(EmptyToken());
        }
    } else {
        new_kid.append(`node.gen_token(Tok.KW_SERVER));
        new_kid.append(`node.gen_token(Tok.LBRACE));
        for stmt in `node.body {
            new_kid.append(stmt);
        }
        new_kid.append(`node.gen_token(Tok.RBRACE));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize NativeBlock kid list."""
impl NormalizePass.enter_native_block(`node: uni.NativeBlock) -> None {
    new_kid: list[uni.UniNode] = [];
    parent_mod = `node.find_parent_of_type(uni.Module);
    is_implicit_top_level_na_module = (
        `node.implicit
        and parent_mod is not None
        and parent_mod.loc.mod_path.endswith(".na.jac")
        and parent_mod.body == [`node]
    );
    if is_implicit_top_level_na_module {
        if `node.body {
            new_kid.extend(`node.body);
        } else {
            new_kid.append(EmptyToken());
        }
    } else {
        new_kid.append(`node.gen_token(Tok.KW_NATIVE));
        new_kid.append(`node.gen_token(Tok.LBRACE));
        for stmt in `node.body {
            new_kid.append(stmt);
        }
        new_kid.append(`node.gen_token(Tok.RBRACE));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize PyInlineCode kid list."""
impl NormalizePass.enter_py_inline_code(`node: uni.PyInlineCode) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    new_kid.append(`node.code);
    `node.set_kids(nodes=new_kid);
}

"""Normalize Import kid list."""
impl NormalizePass.enter_import(`node: uni.Import) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    ctx_tok = `node._source_context_token();
    if `node.code_context == CodeContext.CLIENT
    and (ctx_tok is not None or not `node.in_client_context()) {
        new_kid.append(ctx_tok or `node.gen_token(Tok.KW_CLIENT));
    } elif `node.code_context == CodeContext.SERVER
    and (ctx_tok is not None or `node.in_client_context()) {
        new_kid.append(ctx_tok or `node.gen_token(Tok.KW_SERVER));
    }
    if `node.is_absorb {
        new_kid.append(`node.gen_token(Tok.KW_INCLUDE));
    } else {
        new_kid.append(`node.gen_token(Tok.KW_IMPORT));
    }
    if `node.from_loc {
        new_kid.append(`node.gen_token(Tok.KW_FROM));
        new_kid.append(`node.from_loc);
        new_kid.append(`node.gen_token(Tok.LBRACE));
    }
    for idx in range(len(`node.items)) {
        new_kid.append(`node.items[idx]);
        if idx < len(`node.items) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    if `node.from_loc {
        new_kid.append(`node.gen_token(Tok.RBRACE));
    } else {
        new_kid.append(`node.gen_token(Tok.SEMI));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ModulePath kid list."""
impl NormalizePass.enter_module_path(`node: uni.ModulePath) -> None {
    new_kid: list[uni.UniNode] = [];
    for _ in range(`node.level) {
        new_kid.append(`node.gen_token(Tok.DOT));
    }
    if `node.path {
        for idx in range(len(`node.path)) {
            new_kid.append(`node.path[idx]);
            if idx < len(`node.path) - 1 {
                new_kid.append(`node.gen_token(Tok.DOT));
            }
        }
    }
    if `node.alias {
        new_kid.append(`node.gen_token(Tok.KW_AS));
        new_kid.append(`node.alias);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ModuleItem kid list."""
impl NormalizePass.enter_module_item(`node: uni.ModuleItem) -> None {
    new_kid: list[uni.UniNode] = [`node.name];
    if `node.alias {
        new_kid.append(`node.gen_token(Tok.KW_AS));
        new_kid.append(`node.alias);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize Archetype kid list."""
impl NormalizePass.enter_archetype(`node: uni.Archetype) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
        # When defining a class inside code blocks (not at module/class level),
        # make the docstring a standalone statement so it doesn't merge with code.
        if not isinstance(`node.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            new_kid.append(`node.gen_token(Tok.SEMI));
        }
    }
    client_tok = `node._source_context_token();
    if `node.code_context == CodeContext.CLIENT
    and (client_tok is not None or not `node.in_client_context()) {
        new_kid.append(client_tok or `node.gen_token(Tok.KW_CLIENT));
    }
    if `node.decorators {
        new_kid.append(`node.gen_token(Tok.DECOR_OP));
        for idx in range(len(`node.decorators)) {
            new_kid.append(`node.decorators[idx]);
            if idx < len(`node.decorators) - 1 {
                new_kid.append(`node.gen_token(Tok.DECOR_OP));
            }
        }
    }
    if `node.is_async {
        new_kid.append(`node.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(`node.arch_type);
    if `node.access {
        new_kid.append(`node.access);
    }
    new_kid.append(`node.name);
    if `node.base_classes {
        new_kid.append(`node.gen_token(Tok.LPAREN));
        for idx in range(len(`node.base_classes)) {
            new_kid.append(`node.base_classes[idx]);
            if idx < len(`node.base_classes) - 1 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(`node.gen_token(Tok.RPAREN));
    }
    if `node.body {
        if isinstance(`node.body, uni.ImplDef) {
            new_kid.append(`node.gen_token(Tok.SEMI));
        } else {
            new_kid.append(`node.gen_token(Tok.LBRACE));
            for stmt in `node.body {
                new_kid.append(stmt);
            }
            new_kid.append(`node.gen_token(Tok.RBRACE));
        }
    } else {
        new_kid.append(`node.gen_token(Tok.LBRACE));
        new_kid.append(`node.gen_token(Tok.RBRACE));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ImplDef kid list."""
impl NormalizePass.enter_impl_def(`node: uni.ImplDef) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    if `node.decorators {
        new_kid.append(`node.gen_token(Tok.DECOR_OP));
        for i in range(len(`node.decorators)) {
            new_kid.append(`node.decorators[i]);
            if i < len(`node.decorators) - 1 {
                new_kid.append(`node.gen_token(Tok.DECOR_OP));
            }
        }
    }
    new_kid.append(`node.gen_token(Tok.KW_IMPL));
    for idx in range(len(`node.target)) {
        new_kid.append(`node.target[idx]);
        if idx < len(`node.target) - 1 {
            new_kid.append(`node.gen_token(Tok.DOT));
        }
    }
    if `node.spec {
        if isinstance(`node.spec, Sequence) {
            new_kid.append(`node.gen_token(Tok.LPAREN));
            for idx in range(len(`node.spec)) {
                new_kid.append(`node.spec[idx]);
                if idx < len(`node.spec) - 1 {
                    new_kid.append(`node.gen_token(Tok.COMMA));
                }
            }
            new_kid.append(`node.gen_token(Tok.RPAREN));
        } else {
            new_kid.append(`node.spec);
        }
    }
    if isinstance(`node.body, uni.Expr) {
        new_kid.append(`node.body);
    } else {
        new_kid.append(`node.gen_token(Tok.LBRACE));
        prev_stmt = None;
        for stmt in `node.body {
            if isinstance(prev_stmt, uni.EnumBlockStmt) and prev_stmt.is_enum_stmt {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
            new_kid.append(stmt);
            prev_stmt = stmt;
        }
        new_kid.append(`node.gen_token(Tok.RBRACE));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize SemDef kid list."""
impl NormalizePass.enter_sem_def(`node: uni.SemDef) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_SEM), ];
    for idx in range(len(`node.target)) {
        new_kid.append(`node.target[idx]);
        if idx < len(`node.target) - 1 {
            new_kid.append(`node.gen_token(Tok.DOT));
        }
    }
    new_kid.append(`node.gen_token(Tok.EQ));
    new_kid.append(`node.value);
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize Enum kid list."""
impl NormalizePass.enter_enum(`node: uni.Enum) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.decorators {
        new_kid.append(`node.gen_token(Tok.DECOR_OP));
        for idx in range(len(`node.decorators)) {
            new_kid.append(`node.decorators[idx]);
            if idx < len(`node.decorators) - 1 {
                new_kid.append(`node.gen_token(Tok.DECOR_OP));
            }
        }
    }
    if `node.doc {
        new_kid.append(`node.doc);
    }
    client_tok = `node._source_context_token();
    if `node.code_context == CodeContext.CLIENT
    and (client_tok is not None or not `node.in_client_context()) {
        new_kid.append(client_tok or `node.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(`node.gen_token(Tok.KW_ENUM));
    if `node.access {
        new_kid.append(`node.access);
    }
    new_kid.append(`node.name);
    if `node.base_classes {
        new_kid.append(`node.gen_token(Tok.LPAREN));
        for idx in range(len(`node.base_classes)) {
            new_kid.append(`node.base_classes[idx]);
            if idx < len(`node.base_classes) - 1 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(`node.gen_token(Tok.RPAREN));
    }
    if `node.body {
        if isinstance(`node.body, uni.ImplDef) {
            new_kid.append(`node.gen_token(Tok.SEMI));
        } else {
            new_kid.append(`node.gen_token(Tok.LBRACE));
            prev_stmt = None;
            for stmt in `node.body {
                if isinstance(prev_stmt, uni.EnumBlockStmt) and prev_stmt.is_enum_stmt {
                    new_kid.append(`node.gen_token(Tok.COMMA));
                }
                new_kid.append(stmt);
                prev_stmt = stmt;
            }
            new_kid.append(`node.gen_token(Tok.RBRACE));
        }
    } else {
        new_kid.append(`node.gen_token(Tok.SEMI));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize Ability kid list."""
impl NormalizePass.enter_ability(`node: uni.Ability) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
        # When defining an ability inside code blocks (not at module/class level),
        # make the docstring a standalone statement so it doesn't merge with code.
        if not isinstance(`node.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            new_kid.append(`node.gen_token(Tok.SEMI));
        }
    }
    client_tok = `node._source_context_token();
    if `node.code_context == CodeContext.CLIENT
    and (client_tok is not None or not `node.in_client_context()) {
        new_kid.append(client_tok or `node.gen_token(Tok.KW_CLIENT));
    }
    if `node.decorators {
        new_kid.append(`node.gen_token(Tok.DECOR_OP));
        for idx in range(len(`node.decorators)) {
            new_kid.append(`node.decorators[idx]);
            if idx < len(`node.decorators) - 1 {
                new_kid.append(`node.gen_token(Tok.DECOR_OP));
            }
        }
        new_kid.append(`node.gen_token(Tok.WS));
    }
    if `node.is_async {
        new_kid.append(`node.gen_token(Tok.KW_ASYNC));
    }
    if `node.is_override {
        new_kid.append(`node.gen_token(Tok.KW_OVERRIDE));
    }
    if `node.is_static {
        new_kid.append(`node.gen_token(Tok.KW_STATIC));
    }
    new_kid.append(
        `node.gen_token(Tok.KW_CAN)
        if not `node.is_def
        else `node.gen_token(Tok.KW_DEF)
    );
    if `node.access {
        new_kid.append(`node.access);
    }
    if `node.name_ref {
        new_kid.append(`node.name_ref);
    }
    if `node.signature {
        new_kid.append(`node.signature);
    }
    if `node.is_genai_ability {
        new_kid.append(`node.gen_token(Tok.KW_BY));
    }
    if `node.is_abstract {
        new_kid.append(`node.gen_token(Tok.KW_ABSTRACT));
    }
    if `node.body is not None {
        if isinstance(`node.body, uni.ImplDef) {
            new_kid.append(`node.gen_token(Tok.SEMI));
        } elif isinstance(`node.body, Sequence) {
            new_kid.append(`node.gen_token(Tok.LBRACE));
            for stmt in `node.body {
                new_kid.append(stmt);
            }
            new_kid.append(`node.gen_token(Tok.RBRACE));
        } else {
            new_kid.append(`node.body);
            if `node.is_genai_ability {
                new_kid.append(`node.gen_token(Tok.SEMI));
            }
        }
    } else {
        new_kid.append(`node.gen_token(Tok.SEMI));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize FuncSignature kid list."""
impl NormalizePass.enter_func_signature(`node: uni.FuncSignature) -> None {
    is_lambda = `node.parent and isinstance(`node.parent, uni.LambdaExpr);
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LPAREN)] if not is_lambda else [];
    if `node.posonly_params {
        for prm in `node.posonly_params {
            new_kid.append(prm);
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
        new_kid.append(`node.gen_token(Tok.DIV));
        new_kid.append(`node.gen_token(Tok.COMMA));
    }
    if `node.params {
        for prm in `node.params {
            new_kid.append(prm);
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    if `node.varargs {
        new_kid.append(`node.varargs);
        new_kid.append(`node.gen_token(Tok.COMMA));
    } elif `node.kwonlyargs {
        new_kid.append(`node.gen_token(Tok.STAR_MUL));
        new_kid.append(`node.gen_token(Tok.COMMA));
    }
    for prm in `node.kwonlyargs {
        new_kid.append(prm);
        new_kid.append(`node.gen_token(Tok.COMMA));
    }
    if `node.kwargs {
        new_kid.append(`node.kwargs);
        new_kid.append(`node.gen_token(Tok.COMMA));
    }
    if new_kid and isinstance(new_kid[-1], Token) and new_kid[-1].name == Tok.COMMA {
        new_kid = new_kid[:-1];
    }
    if not is_lambda {
        new_kid.append(`node.gen_token(Tok.RPAREN));
    } elif not new_kid {
        new_kid.extend([`node.gen_token(Tok.LPAREN), `node.gen_token(Tok.RPAREN)]);
    }
    if `node.return_type {
        new_kid.append(`node.gen_token(Tok.RETURN_HINT));
        new_kid.append(`node.return_type);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize EventSignature kid list."""
impl NormalizePass.enter_event_signature(`node: uni.EventSignature) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_WITH)];
    if `node.arch_tag_info {
        new_kid.append(`node.arch_tag_info);
    }
    new_kid.append(`node.event);
    `node.set_kids(nodes=new_kid);
}

"""Normalize ParamVar kid list."""
impl NormalizePass.enter_param_var(`node: uni.ParamVar) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.unpack {
        new_kid.append(`node.unpack);
    }
    new_kid.append(`node.name);
    if `node.type_tag {
        new_kid.append(`node.type_tag);
    }
    if `node.value {
        new_kid.append(`node.gen_token(Tok.EQ));
        new_kid.append(`node.value);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ArchHas kid list."""
impl NormalizePass.enter_arch_has(`node: uni.ArchHas) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.doc {
        new_kid.append(`node.doc);
    }
    if `node.is_static {
        new_kid.append(`node.gen_token(Tok.KW_STATIC));
    }
    new_kid.append(`node.gen_token(Tok.KW_HAS));
    if `node.access {
        new_kid.append(`node.access);
    }
    for i in range(len(`node.vars)) {
        new_kid.append(`node.vars[i]);
        if i < len(`node.vars) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize HasVar kid list."""
impl NormalizePass.enter_has_var(`node: uni.HasVar) -> None {
    new_kid: list[uni.UniNode] = [`node.name];
    if `node.type_tag {
        new_kid.append(`node.type_tag);
    }
    if `node.value {
        new_kid.append(`node.gen_token(Tok.EQ));
        new_kid.append(`node.value);
    }
    if `node.defer {
        new_kid.append(`node.gen_token(Tok.KW_BY));
        new_kid.append(`node.gen_token(Tok.KW_POST_INIT));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize TypedCtxBlock kid list."""
impl NormalizePass.enter_typed_ctx_block(`node: uni.TypedCtxBlock) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.RETURN_HINT),
        `node.type_ctx,
        `node.gen_token(Tok.LBRACE),

    ];
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize IfStmt kid list."""
impl NormalizePass.enter_if_stmt(`node: uni.IfStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_IF),
        `node.condition,
        `node.gen_token(Tok.LBRACE),

    ];
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    if `node.else_body {
        new_kid.append(`node.else_body);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ElseIf kid list."""
impl NormalizePass.enter_else_if(`node: uni.ElseIf) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_ELIF),
        `node.condition,
        `node.gen_token(Tok.LBRACE),

    ];
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    if `node.else_body {
        new_kid.append(`node.else_body);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ElseStmt kid list."""
impl NormalizePass.enter_else_stmt(`node: uni.ElseStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_ELSE),
        `node.gen_token(Tok.LBRACE),

    ];
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize ExprStmt kid list."""
impl NormalizePass.enter_expr_stmt(`node: uni.ExprStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.in_fstring {
        new_kid.append(`node.expr);
    } else {
        new_kid.append(`node.expr);
        new_kid.append(`node.gen_token(Tok.SEMI));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize TryStmt kid list."""
impl NormalizePass.enter_try_stmt(`node: uni.TryStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_TRY),
        `node.gen_token(Tok.LBRACE),

    ];
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    for exc in `node.excepts {
        new_kid.append(exc);
    }
    if `node.else_body {
        new_kid.append(`node.else_body);
    }
    if `node.finally_body {
        new_kid.append(`node.finally_body);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize Except kid list."""
impl NormalizePass.enter_except(`node: uni.Except) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_EXCEPT), `node.ex_type, ];
    if `node.name {
        new_kid.append(`node.gen_token(Tok.KW_AS));
        new_kid.append(`node.name);
    }
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize FinallyStmt kid list."""
impl NormalizePass.enter_finally_stmt(`node: uni.FinallyStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_FINALLY),
        `node.gen_token(Tok.LBRACE),

    ];
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize IterForStmt kid list."""
impl NormalizePass.enter_iter_for_stmt(`node: uni.IterForStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.is_async {
        new_kid.append(`node.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(`node.gen_token(Tok.KW_FOR));
    new_kid.append(`node.iter);
    new_kid.append(`node.gen_token(Tok.KW_TO));
    new_kid.append(`node.condition);
    new_kid.append(`node.gen_token(Tok.KW_BY));
    new_kid.append(`node.count_by);
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    if `node.else_body {
        new_kid.append(`node.else_body);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize InForStmt kid list."""
impl NormalizePass.enter_in_for_stmt(`node: uni.InForStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.is_async {
        new_kid.append(`node.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(`node.gen_token(Tok.KW_FOR));
    new_kid.append(`node.target);
    new_kid.append(`node.gen_token(Tok.KW_IN));
    new_kid.append(`node.collection);
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    if `node.else_body {
        new_kid.append(`node.else_body);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize WhileStmt kid list."""
impl NormalizePass.enter_while_stmt(`node: uni.WhileStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_WHILE),
        `node.condition,
        `node.gen_token(Tok.LBRACE),

    ];
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    if `node.else_body {
        new_kid.append(`node.else_body);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize WithStmt kid list."""
impl NormalizePass.enter_with_stmt(`node: uni.WithStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.is_async {
        new_kid.append(`node.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(`node.gen_token(Tok.KW_WITH));
    for idx in range(len(`node.exprs)) {
        new_kid.append(`node.exprs[idx]);
        if idx < len(`node.exprs) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for stmt in `node.body {
        new_kid.append(stmt);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize ExprAsItem kid list."""
impl NormalizePass.enter_expr_as_item(`node: uni.ExprAsItem) -> None {
    new_kid: list[uni.UniNode] = [`node.expr];
    if `node.alias {
        new_kid.append(`node.gen_token(Tok.KW_AS));
        new_kid.append(`node.alias);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize RaiseStmt kid list."""
impl NormalizePass.enter_raise_stmt(`node: uni.RaiseStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_RAISE)];
    if `node.cause {
        new_kid.append(`node.cause);
    }
    if `node.from_target {
        new_kid.append(`node.gen_token(Tok.KW_FROM));
        new_kid.append(`node.from_target);
    }
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize AssertStmt kid list."""
impl NormalizePass.enter_assert_stmt(`node: uni.AssertStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_ASSERT), `node.condition, ];
    if `node.error_msg {
        new_kid.append(`node.gen_token(Tok.COMMA));
        new_kid.append(`node.error_msg);
    }
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize CtrlStmt kid list."""
impl NormalizePass.enter_ctrl_stmt(`node: uni.CtrlStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.ctrl, `node.gen_token(Tok.SEMI)];
    `node.set_kids(nodes=new_kid);
}

"""Normalize DeleteStmt kid list."""
impl NormalizePass.enter_delete_stmt(`node: uni.DeleteStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_DELETE),
        `node.target,
        `node.gen_token(Tok.SEMI),

    ];
    `node.set_kids(nodes=new_kid);
}

"""Normalize ReportStmt kid list."""
impl NormalizePass.enter_report_stmt(`node: uni.ReportStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_REPORT),
        `node.expr,
        `node.gen_token(Tok.SEMI),

    ];
    `node.set_kids(nodes=new_kid);
}

"""Normalize ReturnStmt kid list."""
impl NormalizePass.enter_return_stmt(`node: uni.ReturnStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_RETURN), ];
    if `node.expr {
        new_kid.append(`node.expr);
    }
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize VisitStmt kid list."""
impl NormalizePass.enter_visit_stmt(`node: uni.VisitStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(`node.gen_token(Tok.KW_VISIT));
    if `node.insert_loc {
        new_kid.append(`node.gen_token(Tok.COLON));
        new_kid.append(`node.insert_loc);
        new_kid.append(`node.gen_token(Tok.COLON));
    }
    new_kid.append(`node.target);
    if `node.else_body {
        new_kid.append(`node.else_body);
    } else {
        new_kid.append(`node.gen_token(Tok.SEMI));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize DisengageStmt kid list."""
impl NormalizePass.enter_disengage_stmt(`node: uni.DisengageStmt) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.KW_DISENGAGE),
        `node.gen_token(Tok.SEMI),

    ];
    `node.set_kids(nodes=new_kid);
}

"""Normalize AwaitExpr kid list."""
impl NormalizePass.enter_await_expr(`node: uni.AwaitExpr) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_AWAIT), `node.target, ];
    `node.set_kids(nodes=new_kid);
}

"""Normalize GlobalStmt kid list."""
impl NormalizePass.enter_global_stmt(`node: uni.GlobalStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.GLOBAL_OP)];
    for idx in range(len(`node.target)) {
        new_kid.append(`node.target[idx]);
        if idx < len(`node.target) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize NonLocalStmt kid list."""
impl NormalizePass.enter_non_local_stmt(`node: uni.NonLocalStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.NONLOCAL_OP)];
    for idx in range(len(`node.target)) {
        new_kid.append(`node.target[idx]);
        if idx < len(`node.target) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize Assignment kid list."""
impl NormalizePass.enter_assignment(`node: uni.Assignment) -> None {
    new_kid: list[uni.UniNode] = [];
    for idx in range(len(`node.target)) {
        new_kid.append(`node.target[idx]);
        if idx < len(`node.target) - 1 {
            new_kid.append(`node.gen_token(Tok.EQ));
        }
    }
    if `node.type_tag {
        new_kid.append(`node.type_tag);
    }
    if `node.aug_op {
        new_kid.append(`node.aug_op);
    }
    if `node.value {
        if not `node.aug_op {
            new_kid.append(`node.gen_token(Tok.EQ));
        }
        new_kid.append(`node.value);
    }
    if isinstance(`node.parent, uni.GlobalVars) {
        if `node.parent.assignments.index(`node) == len(`node.parent.assignments) - 1 {
            new_kid.append(`node.gen_token(Tok.SEMI));
        }
    } elif (not `node.is_enum_stmt)
    and not (
        isinstance(`node.parent, uni.IterForStmt)
        and `node in [`node.parent.iter, `node.parent.count_by]
    ) {
        new_kid.append(`node.gen_token(Tok.SEMI));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ConcurrentExpr kid list."""
impl NormalizePass.enter_concurrent_expr(`node: uni.ConcurrentExpr) -> None {
    new_kid: list[uni.UniNode] = [];
    if isinstance(`node.tok, Token) and `node.tok.value == "flow" {
        new_kid.append(`node.gen_token(Tok.KW_FLOW));
    } elif isinstance(`node.tok, Token) and `node.tok.value == "wait" {
        new_kid.append(`node.gen_token(Tok.KW_WAIT));
    }
    new_kid.append(`node.target);
    `node.set_kids(nodes=new_kid);
}

"""Normalize BinaryExpr kid list."""
impl NormalizePass.enter_binary_expr(`node: uni.BinaryExpr) -> None {
    new_kid: list[uni.UniNode] = [`node.left, `node.op, `node.right];
    `node.set_kids(nodes=new_kid);
}

"""Normalize CompareExpr kid list."""
impl NormalizePass.enter_compare_expr(`node: uni.CompareExpr) -> None {
    new_kid: list[uni.UniNode] = [`node.left];
    for i in range(len(`node.rights)) {
        new_kid.append(`node.ops[i]);
        new_kid.append(`node.rights[i]);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize BoolExpr kid list."""
impl NormalizePass.enter_bool_expr(`node: uni.BoolExpr) -> None {
    new_kid: list[uni.UniNode] = [];
    for i in range(len(`node.values)) {
        if i > 0 {
            new_kid.append(`node.op);
        }
        new_kid.append(`node.values[i]);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize LambdaExpr kid list."""
impl NormalizePass.enter_lambda_expr(`node: uni.LambdaExpr) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_LAMBDA)];
    if `node.signature {
        new_kid.append(`node.signature);
    }
    # For code block lambdas, we add LBRACE, statements, RBRACE
    if isinstance(`node.body, list) {
        new_kid.append(`node.gen_token(Tok.LBRACE));
        new_kid.extend(`node.body);
        new_kid.append(`node.gen_token(Tok.RBRACE));
    } elif isinstance(`node.body, uni.Expr) {
        new_kid += [`node.gen_token(Tok.COLON), `node.body];
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize UnaryExpr kid list."""
impl NormalizePass.enter_unary_expr(`node: uni.UnaryExpr) -> None {
    new_kid: list[uni.UniNode] = [`node.op, `node.operand];
    `node.set_kids(nodes=new_kid);
}

"""Normalize IfElseExpr kid list."""
impl NormalizePass.enter_if_else_expr(`node: uni.IfElseExpr) -> None {
    new_kid: list[uni.UniNode] = [
        `node.value,
        `node.gen_token(Tok.KW_IF),
        `node.condition,
        `node.gen_token(Tok.KW_ELSE),
        `node.else_value,

    ];
    `node.set_kids(nodes=new_kid);
}

"""Normalize MultiString kid list."""
impl NormalizePass.enter_multi_string(`node: uni.MultiString) -> None {
    new_kid: list[uni.UniNode] = [];
    for string in `node.strings {
        new_kid.append(string);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize FString kid list."""
impl NormalizePass.enter_f_string(`node: uni.FString) -> None {
    new_kid: list[uni.UniNode] = [`node.start] if `node.start is not None else [];
    for part in `node.parts {
        new_kid.append(part);
    }
    if `node.end is not None {
        new_kid.append(`node.end);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize FormattedValue kid list."""
impl NormalizePass.enter_formatted_value(`node: uni.FormattedValue) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LBRACE)];
    new_kid.append(`node.format_part);
    if `node.conversion != -1 {
        new_kid.append(`node.gen_token(Tok.CONV, value="!" + chr(`node.conversion)));
    }
    if `node.format_spec {
        new_kid.append(`node.gen_token(Tok.COLON));
        new_kid.append(`node.format_spec);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize ListVal kid list."""
impl NormalizePass.enter_list_val(`node: uni.ListVal) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LSQUARE)];
    for idx in range(len(`node.values)) {
        new_kid.append(`node.values[idx]);
        if idx < len(`node.values) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(`node.gen_token(Tok.RSQUARE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize SetVal kid list."""
impl NormalizePass.enter_set_val(`node: uni.SetVal) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LBRACE)];
    for idx in range(len(`node.values)) {
        new_kid.append(`node.values[idx]);
        if idx < len(`node.values) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize TupleVal kid list."""
impl NormalizePass.enter_tuple_val(`node: uni.TupleVal) -> None {
    in_ret_type = (
        `node.parent
        and isinstance(`node.parent, uni.IndexSlice)
        and `node.parent
        and isinstance(`node.parent.parent, uni.AtomTrailer)
        and `node.parent.parent
        and isinstance(`node.parent.parent.parent, uni.FuncSignature)
    );
    new_kid: list[uni.UniNode] = (
        [`node.gen_token(Tok.LPAREN), ] if not in_ret_type else []
    );
    for idx in range(len(`node.values)) {
        new_kid.append(`node.values[idx]);
        if idx < len(`node.values) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    if len(`node.values) == 1 {
        new_kid.append(`node.gen_token(Tok.COMMA));
    }
    if not in_ret_type {
        new_kid.append(`node.gen_token(Tok.RPAREN));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize DictVal kid list."""
impl NormalizePass.enter_dict_val(`node: uni.DictVal) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LBRACE), ];
    for i in range(len(`node.kv_pairs)) {
        new_kid.append(`node.kv_pairs[i]);
        if i < len(`node.kv_pairs) - 1 {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize KVPair kid list."""
impl NormalizePass.enter_k_v_pair(`node: uni.KVPair) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.key {
        new_kid.append(`node.key);
        new_kid.append(`node.gen_token(Tok.COLON));
    } else {
        new_kid.append(`node.gen_token(Tok.STAR_POW));
    }
    new_kid.append(`node.value);
    `node.set_kids(nodes=new_kid);
}

"""Normalize KWPair kid list."""
impl NormalizePass.enter_k_w_pair(`node: uni.KWPair) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.key {
        new_kid.append(`node.key);
        new_kid.append(`node.gen_token(Tok.EQ));
    } else {
        new_kid.append(`node.gen_token(Tok.STAR_POW));
    }
    new_kid.append(`node.value);
    `node.set_kids(nodes=new_kid);
}

"""Normalize InnerCompr kid list."""
impl NormalizePass.enter_inner_compr(`node: uni.InnerCompr) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.is_async {
        new_kid.append(`node.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(`node.gen_token(Tok.KW_FOR));
    new_kid.append(`node.target);
    new_kid.append(`node.gen_token(Tok.KW_IN));
    new_kid.append(`node.collection);
    for cond in `node.conditional or [] {
        new_kid.append(`node.gen_token(Tok.KW_IF));
        new_kid.append(cond);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize ListCompr kid list."""
impl NormalizePass.enter_list_compr(`node: uni.ListCompr) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LSQUARE), `node.out_expr, ];
    for comp in `node.compr {
        new_kid.append(comp);
    }
    new_kid.append(`node.gen_token(Tok.RSQUARE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize GenCompr kid list."""
impl NormalizePass.enter_gen_compr(`node: uni.GenCompr) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LPAREN), `node.out_expr, ];
    for comp in `node.compr {
        new_kid.append(comp);
    }
    new_kid.append(`node.gen_token(Tok.RPAREN));
    `node.set_kids(nodes=new_kid);
}

"""Normalize SetCompr kid list."""
impl NormalizePass.enter_set_compr(`node: uni.SetCompr) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LBRACE), `node.out_expr, ];
    for comp in `node.compr {
        new_kid.append(comp);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize DictCompr kid list."""
impl NormalizePass.enter_dict_compr(`node: uni.DictCompr) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LBRACE), `node.kv_pair, ];
    for comp in `node.compr {
        new_kid.append(comp);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize AtomTrailer kid list."""
impl NormalizePass.enter_atom_trailer(`node: uni.AtomTrailer) -> None {
    new_kid: list[uni.UniNode] = [`node.target];
    if `node.is_null_ok {
        new_kid.append(`node.gen_token(Tok.NULL_OK));
    }
    if `node.is_attr {
        new_kid.append(`node.gen_token(Tok.DOT));
    }
    if `node.right {
        new_kid.append(`node.right);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize AtomUnit kid list."""
impl NormalizePass.enter_atom_unit(`node: uni.AtomUnit) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(`node.gen_token(Tok.LPAREN));
    new_kid.append(`node.value);
    new_kid.append(`node.gen_token(Tok.RPAREN));
    `node.set_kids(nodes=new_kid);
}

"""Normalize YieldExpr kid list."""
impl NormalizePass.enter_yield_expr(`node: uni.YieldExpr) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_YIELD)];
    if `node.with_from {
        new_kid.append(`node.gen_token(Tok.KW_FROM));
    }
    if `node.expr {
        new_kid.append(`node.expr);
    }
    new_kid.append(`node.gen_token(Tok.SEMI));
    `node.set_kids(nodes=new_kid);
}

"""Normalize FuncCall kid list."""
impl NormalizePass.enter_func_call(`node: uni.FuncCall) -> None {
    new_kids: list[uni.UniNode] = [`node.target];
    is_gencompr = len(`node.params) == 1 and isinstance(`node.params[0], uni.GenCompr);
    if not is_gencompr {
        new_kids.append(`node.gen_token(Tok.LPAREN));
    }
    for i in range(len(`node.params)) {
        new_kids.append(`node.params[i]);
        if i < len(`node.params) - 1 {
            new_kids.append(`node.gen_token(Tok.COMMA));
        }
    }
    if `node.genai_call {
        new_kids.append(`node.gen_token(Tok.KW_BY));
        new_kids.append(`node.genai_call);
    }
    if not is_gencompr {
        new_kids.append(`node.gen_token(Tok.RPAREN, ")"));
    }
    `node.set_kids(nodes=new_kids);
}

"""Normalize IndexSlice kid list."""
impl NormalizePass.enter_index_slice(`node: uni.IndexSlice) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(`node.gen_token(Tok.LSQUARE));
    if `node.is_range {
        for i in range(len(`node.slices)) {
            if i > 0 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
            if `node.slices[i].start {
                new_kid.append(`node.slices[i].start);
            }
            new_kid.append(`node.gen_token(Tok.COLON));
            if `node.slices[i].stop {
                new_kid.append(`node.slices[i].stop);
            }
            if `node.slices[i].step {
                new_kid.append(`node.gen_token(Tok.COLON));
                new_kid.append(`node.slices[i].step);
            }
        }
    } elif len(`node.slices) == 1 and `node.slices[0].start {
        new_kid.append(`node.slices[0].start);
    }
    new_kid.append(`node.gen_token(Tok.RSQUARE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize EdgeRefTrailer kid list."""
impl NormalizePass.enter_edge_ref_trailer(`node: uni.EdgeRefTrailer) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(`node.gen_token(Tok.LSQUARE));
    if `node.is_async {
        new_kid.append(`node.gen_token(Tok.KW_ASYNC));
    }
    if `node.edges_only {
        new_kid.append(`node.gen_token(Tok.KW_EDGE));
    }
    new_kid.extend(`node.chain);
    new_kid.append(`node.gen_token(Tok.RSQUARE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize EdgeOpRef kid list."""
impl NormalizePass.enter_edge_op_ref(`node: uni.EdgeOpRef) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.edge_dir == EdgeDir.IN {
        if not `node.filter_cond {
            new_kid.append(`node.gen_token(Tok.ARROW_L));
        } else {
            new_kid.append(`node.gen_token(Tok.ARROW_L_P1));
            new_kid.append(`node.filter_cond);
            new_kid.append(`node.gen_token(Tok.ARROW_L_P2));
        }
    } elif `node.edge_dir == EdgeDir.OUT {
        if not `node.filter_cond {
            new_kid.append(`node.gen_token(Tok.ARROW_R));
        } else {
            new_kid.append(`node.gen_token(Tok.ARROW_R_P1));
            new_kid.append(`node.filter_cond);
            new_kid.append(`node.gen_token(Tok.ARROW_R_P2));
        }
    } else {
        if not `node.filter_cond {
            new_kid.append(`node.gen_token(Tok.ARROW_BI));
        } else {
            new_kid.append(`node.gen_token(Tok.ARROW_L_P1));
            new_kid.append(`node.filter_cond);
            new_kid.append(`node.gen_token(Tok.ARROW_R_P2));
        }
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize DisconnectOp kid list."""
impl NormalizePass.enter_disconnect_op(`node: uni.DisconnectOp) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_DELETE), `node.edge_spec];
    `node.set_kids(nodes=new_kid);
}

"""Normalize ConnectOp kid list."""
impl NormalizePass.enter_connect_op(`node: uni.ConnectOp) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.edge_dir == EdgeDir.IN {
        if not `node.conn_assign and not `node.conn_type {
            new_kid.append(`node.gen_token(Tok.CARROW_L));
        } else {
            new_kid.append(`node.gen_token(Tok.CARROW_L_P1));
            if `node.conn_type {
                new_kid.append(`node.conn_type);
            }
            if `node.conn_assign {
                new_kid.append(`node.gen_token(Tok.COLON));
                new_kid.append(`node.conn_assign);
            }
            new_kid.append(`node.gen_token(Tok.CARROW_L_P2));
        }
    } elif `node.edge_dir == EdgeDir.OUT {
        if not `node.conn_assign and not `node.conn_type {
            new_kid.append(`node.gen_token(Tok.CARROW_R));
        } else {
            new_kid.append(`node.gen_token(Tok.CARROW_R_P1));
            if `node.conn_type {
                new_kid.append(`node.conn_type);
            }
            if `node.conn_assign {
                new_kid.append(`node.gen_token(Tok.COLON));
                new_kid.append(`node.conn_assign);
            }
            new_kid.append(`node.gen_token(Tok.CARROW_R_P2));
        }
    } else {
        if not `node.conn_assign and not `node.conn_type {
            new_kid.append(`node.gen_token(Tok.CARROW_BI));
        } else {
            new_kid.append(`node.gen_token(Tok.CARROW_L_P1));
            if `node.conn_type {
                new_kid.append(`node.conn_type);
            }
            if `node.conn_assign {
                new_kid.append(`node.gen_token(Tok.COLON));
                new_kid.append(`node.conn_assign);
            }
            new_kid.append(`node.gen_token(Tok.CARROW_R_P2));
        }
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize FilterCompr kid list."""
impl NormalizePass.enter_filter_compr(`node: uni.FilterCompr) -> None {
    new_kid: list[uni.UniNode] = [];
    if not isinstance(`node.parent, uni.EdgeOpRef) {
        new_kid.append(`node.gen_token(Tok.LPAREN));
        new_kid.append(`node.gen_token(Tok.NULL_OK));
    }
    if `node.f_type {
        if not isinstance(`node.parent, uni.EdgeOpRef) {
            new_kid.append(`node.gen_token(Tok.COLON));
        }
        new_kid.append(`node.f_type);
    }
    if `node.compares {
        if `node.f_type {
            if isinstance(`node.parent, uni.EdgeOpRef) {
                new_kid.append(`node.gen_token(Tok.COLON));
            } else {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
        for i in range(len(`node.compares)) {
            new_kid.append(`node.compares[i]);
            if i < len(`node.compares) - 1 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
    }
    if not isinstance(`node.parent, uni.EdgeOpRef) {
        new_kid.append(`node.gen_token(Tok.RPAREN));
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize AssignCompr kid list."""
impl NormalizePass.enter_assign_compr(`node: uni.AssignCompr) -> None {
    new_kid: list[uni.UniNode] = [];
    if isinstance(`node.parent, uni.ConnectOp) {
        for i in range(len(`node.assigns)) {
            new_kid.append(`node.assigns[i]);
            if i < len(`node.assigns) - 1 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
    } else {
        new_kid.append(`node.gen_token(Tok.LPAREN));
        new_kid.append(`node.gen_token(Tok.EQ));
        for i in range(len(`node.assigns)) {
            new_kid.append(`node.assigns[i]);
            if i < len(`node.assigns) - 1 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(`node.gen_token(Tok.RPAREN));
    }
    `node.set_kids(nodes=new_kid);
}

"""JsxAttribute base - no-op."""
impl NormalizePass.enter_jsx_attribute(`node: uni.JsxAttribute) -> None { }

"""JsxChild base - no-op."""
impl NormalizePass.enter_jsx_child(`node: uni.JsxChild) -> None { }

"""Normalize JsxElement kid list.  Unlike most normalize methods, JSX elements don't need to rebuild their kid structure since the parser already creates it correctly. """
impl NormalizePass.enter_jsx_element(`node: uni.JsxElement) -> None { }

"""Normalize JsxElementName kid list."""
impl NormalizePass.enter_jsx_element_name(`node: uni.JsxElementName) -> None {
    new_kid: list[uni.UniNode] = [];
    for i in range(len(`node.parts)) {
        new_kid.append(`node.parts[i]);
        if i < len(`node.parts) - 1 {
            new_kid.append(`node.gen_token(Tok.DOT));
        }
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize JsxSpreadAttribute kid list."""
impl NormalizePass.enter_jsx_spread_attribute(`node: uni.JsxSpreadAttribute) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.LBRACE),
        `node.gen_token(Tok.ELLIPSIS),
        `node.expr,
        `node.gen_token(Tok.RBRACE),

    ];
    `node.set_kids(nodes=new_kid);
}

"""Normalize JsxNormalAttribute kid list."""
impl NormalizePass.enter_jsx_normal_attribute(`node: uni.JsxNormalAttribute) -> None {
    new_kid: list[uni.UniNode] = [`node.name];
    if `node.value {
        new_kid.append(`node.gen_token(Tok.EQ));
        if isinstance(`node.value, uni.String) {
            new_kid.append(`node.value);
        } else {
            # Expression in braces
            new_kid.extend(
                [
                    `node.gen_token(Tok.LBRACE),
                    `node.value,
                    `node.gen_token(Tok.RBRACE),

                ]
            );
        }
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize JsxText kid list."""
impl NormalizePass.enter_jsx_text(`node: uni.JsxText) -> None {
    # Value is always a Token now (parser stores raw token)
    if isinstance(`node.value, uni.Token) {
        `node.set_kids(nodes=[`node.value]);
    } else {
        `node.set_kids(nodes=[`node.gen_token(Tok.JSX_TEXT, value=str(`node.value))]);
    }
}

"""Normalize JsxExpression kid list."""
impl NormalizePass.enter_jsx_expression(`node: uni.JsxExpression) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.LBRACE),
        `node.expr,
        `node.gen_token(Tok.RBRACE),

    ];
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchStmt kid list."""
impl NormalizePass.enter_match_stmt(`node: uni.MatchStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_MATCH), `node.target, ];
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for case in `node.cases {
        new_kid.append(case);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchCase kid list."""
impl NormalizePass.enter_match_case(`node: uni.MatchCase) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_CASE), `node.pattern];
    if `node.guard {
        new_kid.append(`node.gen_token(Tok.KW_IF));
        new_kid.append(`node.guard);
    }
    new_kid.append(`node.gen_token(Tok.COLON));
    if `node.body {
        new_kid.extend([*`node.body]);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize SwitchStmt kid list."""
impl NormalizePass.enter_switch_stmt(`node: uni.SwitchStmt) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_SWITCH), `node.target, ];
    new_kid.append(`node.gen_token(Tok.LBRACE));
    for case in `node.cases {
        new_kid.append(case);
    }
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize SwitchCase kid list."""
impl NormalizePass.enter_switch_case(`node: uni.SwitchCase) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.KW_CASE)];
    if `node.pattern is not None {
        new_kid.append(`node.pattern);
    } else {
        new_kid.pop();
        new_kid.append(`node.gen_token(Tok.KW_DEFAULT));
    }
    new_kid.append(`node.gen_token(Tok.COLON));
    if `node.body {
        new_kid.extend([*`node.body]);
    }
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchOr kid list."""
impl NormalizePass.enter_match_or(`node: uni.MatchOr) -> None {
    new_kid: list[uni.UniNode] = [];
    for pattern in `node.patterns {
        new_kid.append(pattern);
        new_kid.append(`node.gen_token(Tok.KW_OR));
    }
    new_kid.pop();
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchAs kid list."""
impl NormalizePass.enter_match_as(`node: uni.MatchAs) -> None {
    new_kid: list[uni.UniNode] = [];
    if `node.pattern {
        new_kid.append(`node.pattern);
        new_kid.append(`node.gen_token(Tok.KW_AS));
    }
    new_kid.append(`node.name);
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchWild kid list."""
impl NormalizePass.enter_match_wild(`node: uni.MatchWild) -> None {
    `node.set_kids(
        nodes=[
            uni.Name(
                orig_src=`node.loc.orig_src,
                name=Tok.NAME,
                value="_",
                col_start=`node.loc.col_start,
                col_end=`node.loc.col_end,
                line=`node.loc.first_line,
                end_line=`node.loc.last_line,
                pos_start=`node.loc.pos_start,
                pos_end=`node.loc.pos_end,
            )
        ],
    );
}

"""Normalize MatchValue kid list."""
impl NormalizePass.enter_match_value(`node: uni.MatchValue) -> None {
    `node.set_kids(nodes=[`node.value]);
}

"""Normalize MatchSingleton kid list."""
impl NormalizePass.enter_match_singleton(`node: uni.MatchSingleton) -> None {
    `node.set_kids(nodes=[`node.value]);
}

"""Normalize MatchSequence kid list."""
impl NormalizePass.enter_match_sequence(`node: uni.MatchSequence) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LSQUARE)];
    for value in `node.values {
        new_kid.append(value);
        new_kid.append(`node.gen_token(Tok.COMMA));
    }
    new_kid.pop();
    new_kid.append(`node.gen_token(Tok.RSQUARE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchMapping kid list."""
impl NormalizePass.enter_match_mapping(`node: uni.MatchMapping) -> None {
    new_kid: list[uni.UniNode] = [`node.gen_token(Tok.LBRACE)];
    for value in `node.values {
        new_kid.append(value);
        new_kid.append(`node.gen_token(Tok.COMMA));
    }
    new_kid.pop();
    new_kid.append(`node.gen_token(Tok.RBRACE));
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchKVPair kid list."""
impl NormalizePass.enter_match_k_v_pair(`node: uni.MatchKVPair) -> None {
    op = Tok.EQ if isinstance(`node.key, uni.Name) else Tok.COLON;
    new_kid: list[uni.UniNode] = [`node.key, `node.gen_token(op), `node.value];
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchStar kid list."""
impl NormalizePass.enter_match_star(`node: uni.MatchStar) -> None {
    new_kid: list[uni.UniNode] = [
        `node.gen_token(Tok.STAR_MUL if `node.is_list else Tok.STAR_POW)
    ];
    new_kid.append(`node.name);
    `node.set_kids(nodes=new_kid);
}

"""Normalize MatchArch kid list."""
impl NormalizePass.enter_match_arch(`node: uni.MatchArch) -> None {
    new_kid: list[uni.UniNode] = [`node.name];
    new_kid.append(`node.gen_token(Tok.LPAREN));
    if `node.arg_patterns {
        for idx in range(len(`node.arg_patterns)) {
            new_kid.append(`node.arg_patterns[idx]);
            if idx < len(`node.arg_patterns) - 1 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
        if `node.kw_patterns {
            new_kid.append(`node.gen_token(Tok.COMMA));
        }
    }
    if `node.kw_patterns {
        for idx in range(len(`node.kw_patterns)) {
            new_kid.append(`node.kw_patterns[idx]);
            if idx < len(`node.kw_patterns) - 1 {
                new_kid.append(`node.gen_token(Tok.COMMA));
            }
        }
    }
    new_kid.append(`node.gen_token(Tok.RPAREN));
    `node.set_kids(nodes=new_kid);
}

"""Token normalize is a no-op (leaf node)."""
impl NormalizePass.enter_token(`node: uni.Token) -> None { }

"""Normalize string value."""
impl NormalizePass.enter_string(`node: uni.String) -> None {
    `node.value = f"{`node.value}";
}
