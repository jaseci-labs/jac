"""NormalizePass implementation - rebuilds kid lists from semantic fields."""

"""Initialize the NormalizePass."""
impl NormalizePass.init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Normalize SubTag kid list."""
impl NormalizePass.enter_sub_tag(nd: uni.SubTag) -> None {
    nd.set_kids(nodes=[nd.gen_token(Tok.COLON), nd.tag]);
}

"""Normalize Module kid list."""
impl NormalizePass.enter_module(nd: uni.Module) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    new_kid.extend(nd.body);
    nd.set_kids(nodes=new_kid if len(new_kid) else [EmptyToken()]);
}

"""Normalize TypeParam kid list."""
impl NormalizePass.enter_type_param(nd: uni.TypeParam) -> None {
    new_kid: list[uni.UniNode] = [nd.name];
    if nd.bound {
        new_kid.append(nd.gen_token(Tok.COLON));
        new_kid.append(nd.bound);
    }
    if nd.default_val {
        new_kid.append(nd.gen_token(Tok.EQ));
        new_kid.append(nd.default_val);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize TypeAlias kid list."""
impl NormalizePass.enter_type_alias(nd: uni.TypeAlias) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    new_kid.append(nd.gen_token(Tok.TYP_TYPE));
    if nd.access {
        new_kid.append(nd.access);
    }
    new_kid.append(nd.name);
    if nd.type_params {
        new_kid.append(nd.gen_token(Tok.LSQUARE));
        for idx in range(len(nd.type_params)) {
            new_kid.append(nd.type_params[idx]);
            if idx < len(nd.type_params) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(nd.gen_token(Tok.RSQUARE));
    }
    new_kid.append(nd.gen_token(Tok.EQ));
    new_kid.append(nd.value);
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize GlobalVars kid list."""
impl NormalizePass.enter_global_vars(nd: uni.GlobalVars) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    client_tok = nd._source_context_token();
    if nd.code_context == CodeContext.CLIENT
    and (client_tok is not None or not nd.in_client_context()) {
        new_kid.append(client_tok or nd.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(nd.gen_token(Tok.KW_GLOBAL));
    if nd.access {
        new_kid.append(nd.access);
    }
    for i in range(len(nd.assignments)) {
        new_kid.append(nd.assignments[i]);
        if i < len(nd.assignments) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize Test kid list."""
impl NormalizePass.enter_test(nd: uni.Test) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    client_tok = nd._source_context_token();
    if nd.code_context == CodeContext.CLIENT
    and (client_tok is not None or not nd.in_client_context()) {
        new_kid.append(client_tok or nd.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(nd.gen_token(Tok.KW_TEST));
    if nd.description {
        new_kid.append(nd.description);
    } else {
        new_kid.append(nd.name);
    }
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize ModuleCode kid list."""
impl NormalizePass.enter_module_code(nd: uni.ModuleCode) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    client_tok = nd._source_context_token();
    if nd.code_context == CodeContext.CLIENT
    and (client_tok is not None or not nd.in_client_context()) {
        new_kid.append(client_tok or nd.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(nd.gen_token(Tok.KW_WITH));
    new_kid.append(nd.gen_token(Tok.KW_ENTRY));
    if nd.name {
        new_kid.append(nd.gen_token(Tok.COLON));
        new_kid.append(nd.name);
    }
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize ClientBlock kid list."""
impl NormalizePass.enter_client_block(nd: uni.ClientBlock) -> None {
    new_kid: list[uni.UniNode] = [];
    parent_mod = nd.find_parent_of_type(uni.Module);
    is_implicit_top_level_cl_module = (
        nd.implicit
        and parent_mod is not None
        and parent_mod.loc.mod_path.endswith(".cl.jac")
        and parent_mod.body == [nd]
    );
    if is_implicit_top_level_cl_module {
        if nd.body {
            new_kid.extend(nd.body);
        } else {
            new_kid.append(EmptyToken());
        }
    } else {
        new_kid.append(nd.gen_token(Tok.KW_CLIENT));
        new_kid.append(nd.gen_token(Tok.LBRACE));
        for stmt in nd.body {
            new_kid.append(stmt);
        }
        new_kid.append(nd.gen_token(Tok.RBRACE));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ServerBlock kid list."""
impl NormalizePass.enter_server_block(nd: uni.ServerBlock) -> None {
    new_kid: list[uni.UniNode] = [];
    parent_mod = nd.find_parent_of_type(uni.Module);
    is_implicit_top_level_sv_module = (
        nd.implicit
        and parent_mod is not None
        and parent_mod.loc.mod_path.endswith(".sv.jac")
        and parent_mod.body == [nd]
    );
    if is_implicit_top_level_sv_module {
        if nd.body {
            new_kid.extend(nd.body);
        } else {
            new_kid.append(EmptyToken());
        }
    } else {
        new_kid.append(nd.gen_token(Tok.KW_SERVER));
        new_kid.append(nd.gen_token(Tok.LBRACE));
        for stmt in nd.body {
            new_kid.append(stmt);
        }
        new_kid.append(nd.gen_token(Tok.RBRACE));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize NativeBlock kid list."""
impl NormalizePass.enter_native_block(nd: uni.NativeBlock) -> None {
    new_kid: list[uni.UniNode] = [];
    parent_mod = nd.find_parent_of_type(uni.Module);
    is_implicit_top_level_na_module = (
        nd.implicit
        and parent_mod is not None
        and parent_mod.loc.mod_path.endswith(".na.jac")
        and parent_mod.body == [nd]
    );
    if is_implicit_top_level_na_module {
        if nd.body {
            new_kid.extend(nd.body);
        } else {
            new_kid.append(EmptyToken());
        }
    } else {
        new_kid.append(nd.gen_token(Tok.KW_NATIVE));
        new_kid.append(nd.gen_token(Tok.LBRACE));
        for stmt in nd.body {
            new_kid.append(stmt);
        }
        new_kid.append(nd.gen_token(Tok.RBRACE));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize PyInlineCode kid list."""
impl NormalizePass.enter_py_inline_code(nd: uni.PyInlineCode) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    new_kid.append(nd.code);
    nd.set_kids(nodes=new_kid);
}

"""Normalize Import kid list."""
impl NormalizePass.enter_import(nd: uni.Import) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    ctx_tok = nd._source_context_token();
    if nd.code_context == CodeContext.CLIENT
    and (ctx_tok is not None or not nd.in_client_context()) {
        new_kid.append(ctx_tok or nd.gen_token(Tok.KW_CLIENT));
    } elif nd.code_context == CodeContext.SERVER
    and (ctx_tok is not None or nd.in_client_context()) {
        new_kid.append(ctx_tok or nd.gen_token(Tok.KW_SERVER));
    }
    if nd.is_absorb {
        new_kid.append(nd.gen_token(Tok.KW_INCLUDE));
    } else {
        new_kid.append(nd.gen_token(Tok.KW_IMPORT));
    }
    if nd.from_loc {
        new_kid.append(nd.gen_token(Tok.KW_FROM));
        new_kid.append(nd.from_loc);
        new_kid.append(nd.gen_token(Tok.LBRACE));
    }
    for idx in range(len(nd.items)) {
        new_kid.append(nd.items[idx]);
        if idx < len(nd.items) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    if nd.from_loc {
        new_kid.append(nd.gen_token(Tok.RBRACE));
    } else {
        new_kid.append(nd.gen_token(Tok.SEMI));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ModulePath kid list."""
impl NormalizePass.enter_module_path(nd: uni.ModulePath) -> None {
    new_kid: list[uni.UniNode] = [];
    for _ in range(nd.level) {
        new_kid.append(nd.gen_token(Tok.DOT));
    }
    if nd.path {
        for idx in range(len(nd.path)) {
            new_kid.append(nd.path[idx]);
            if idx < len(nd.path) - 1 {
                new_kid.append(nd.gen_token(Tok.DOT));
            }
        }
    }
    if nd.alias {
        new_kid.append(nd.gen_token(Tok.KW_AS));
        new_kid.append(nd.alias);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ModuleItem kid list."""
impl NormalizePass.enter_module_item(nd: uni.ModuleItem) -> None {
    new_kid: list[uni.UniNode] = [nd.name];
    if nd.alias {
        new_kid.append(nd.gen_token(Tok.KW_AS));
        new_kid.append(nd.alias);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize Archetype kid list."""
impl NormalizePass.enter_archetype(nd: uni.Archetype) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
        # When defining a class inside code blocks (not at module/class level),
        # make the docstring a standalone statement so it doesn't merge with code.
        if not isinstance(nd.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            new_kid.append(nd.gen_token(Tok.SEMI));
        }
    }
    client_tok = nd._source_context_token();
    if nd.code_context == CodeContext.CLIENT
    and (client_tok is not None or not nd.in_client_context()) {
        new_kid.append(client_tok or nd.gen_token(Tok.KW_CLIENT));
    }
    if nd.decorators {
        new_kid.append(nd.gen_token(Tok.DECOR_OP));
        for idx in range(len(nd.decorators)) {
            new_kid.append(nd.decorators[idx]);
            if idx < len(nd.decorators) - 1 {
                new_kid.append(nd.gen_token(Tok.DECOR_OP));
            }
        }
    }
    if nd.is_async {
        new_kid.append(nd.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(nd.arch_type);
    if nd.access {
        new_kid.append(nd.access);
    }
    new_kid.append(nd.name);
    if nd.type_params {
        new_kid.append(nd.gen_token(Tok.LSQUARE));
        for idx in range(len(nd.type_params)) {
            new_kid.append(nd.type_params[idx]);
            if idx < len(nd.type_params) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(nd.gen_token(Tok.RSQUARE));
    }
    if nd.base_classes {
        new_kid.append(nd.gen_token(Tok.LPAREN));
        for idx in range(len(nd.base_classes)) {
            new_kid.append(nd.base_classes[idx]);
            if idx < len(nd.base_classes) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(nd.gen_token(Tok.RPAREN));
    }
    if nd.body {
        if isinstance(nd.body, uni.ImplDef) {
            new_kid.append(nd.gen_token(Tok.SEMI));
        } else {
            new_kid.append(nd.gen_token(Tok.LBRACE));
            for stmt in nd.body {
                new_kid.append(stmt);
            }
            new_kid.append(nd.gen_token(Tok.RBRACE));
        }
    } else {
        new_kid.append(nd.gen_token(Tok.LBRACE));
        new_kid.append(nd.gen_token(Tok.RBRACE));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ImplDef kid list."""
impl NormalizePass.enter_impl_def(nd: uni.ImplDef) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    if nd.decorators {
        new_kid.append(nd.gen_token(Tok.DECOR_OP));
        for i in range(len(nd.decorators)) {
            new_kid.append(nd.decorators[i]);
            if i < len(nd.decorators) - 1 {
                new_kid.append(nd.gen_token(Tok.DECOR_OP));
            }
        }
    }
    new_kid.append(nd.gen_token(Tok.KW_IMPL));
    for idx in range(len(nd.target)) {
        new_kid.append(nd.target[idx]);
        if idx < len(nd.target) - 1 {
            new_kid.append(nd.gen_token(Tok.DOT));
        }
    }
    if nd.spec {
        if isinstance(nd.spec, Sequence) {
            new_kid.append(nd.gen_token(Tok.LPAREN));
            for idx in range(len(nd.spec)) {
                new_kid.append(nd.spec[idx]);
                if idx < len(nd.spec) - 1 {
                    new_kid.append(nd.gen_token(Tok.COMMA));
                }
            }
            new_kid.append(nd.gen_token(Tok.RPAREN));
        } else {
            new_kid.append(nd.spec);
        }
    }
    if isinstance(nd.body, uni.Expr) {
        new_kid.append(nd.body);
    } else {
        new_kid.append(nd.gen_token(Tok.LBRACE));
        prev_stmt = None;
        for stmt in nd.body {
            if isinstance(prev_stmt, uni.EnumBlockStmt) and prev_stmt.is_enum_stmt {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
            new_kid.append(stmt);
            prev_stmt = stmt;
        }
        new_kid.append(nd.gen_token(Tok.RBRACE));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize SemDef kid list."""
impl NormalizePass.enter_sem_def(nd: uni.SemDef) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_SEM), ];
    for idx in range(len(nd.target)) {
        new_kid.append(nd.target[idx]);
        if idx < len(nd.target) - 1 {
            new_kid.append(nd.gen_token(Tok.DOT));
        }
    }
    new_kid.append(nd.gen_token(Tok.EQ));
    new_kid.append(nd.value);
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize Enum kid list."""
impl NormalizePass.enter_enum(nd: uni.Enum) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.decorators {
        new_kid.append(nd.gen_token(Tok.DECOR_OP));
        for idx in range(len(nd.decorators)) {
            new_kid.append(nd.decorators[idx]);
            if idx < len(nd.decorators) - 1 {
                new_kid.append(nd.gen_token(Tok.DECOR_OP));
            }
        }
    }
    if nd.doc {
        new_kid.append(nd.doc);
    }
    client_tok = nd._source_context_token();
    if nd.code_context == CodeContext.CLIENT
    and (client_tok is not None or not nd.in_client_context()) {
        new_kid.append(client_tok or nd.gen_token(Tok.KW_CLIENT));
    }
    new_kid.append(nd.gen_token(Tok.KW_ENUM));
    if nd.access {
        new_kid.append(nd.access);
    }
    new_kid.append(nd.name);
    if nd.base_classes {
        new_kid.append(nd.gen_token(Tok.LPAREN));
        for idx in range(len(nd.base_classes)) {
            new_kid.append(nd.base_classes[idx]);
            if idx < len(nd.base_classes) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(nd.gen_token(Tok.RPAREN));
    }
    if nd.body {
        if isinstance(nd.body, uni.ImplDef) {
            new_kid.append(nd.gen_token(Tok.SEMI));
        } else {
            new_kid.append(nd.gen_token(Tok.LBRACE));
            prev_stmt = None;
            for stmt in nd.body {
                if isinstance(prev_stmt, uni.EnumBlockStmt) and prev_stmt.is_enum_stmt {
                    new_kid.append(nd.gen_token(Tok.COMMA));
                }
                new_kid.append(stmt);
                prev_stmt = stmt;
            }
            new_kid.append(nd.gen_token(Tok.RBRACE));
        }
    } else {
        new_kid.append(nd.gen_token(Tok.SEMI));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize Ability kid list."""
impl NormalizePass.enter_ability(nd: uni.Ability) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
        # When defining an ability inside code blocks (not at module/class level),
        # make the docstring a standalone statement so it doesn't merge with code.
        if not isinstance(nd.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            new_kid.append(nd.gen_token(Tok.SEMI));
        }
    }
    client_tok = nd._source_context_token();
    if nd.code_context == CodeContext.CLIENT
    and (client_tok is not None or not nd.in_client_context()) {
        new_kid.append(client_tok or nd.gen_token(Tok.KW_CLIENT));
    }
    if nd.decorators {
        new_kid.append(nd.gen_token(Tok.DECOR_OP));
        for idx in range(len(nd.decorators)) {
            new_kid.append(nd.decorators[idx]);
            if idx < len(nd.decorators) - 1 {
                new_kid.append(nd.gen_token(Tok.DECOR_OP));
            }
        }
        new_kid.append(nd.gen_token(Tok.WS));
    }
    if nd.is_async {
        new_kid.append(nd.gen_token(Tok.KW_ASYNC));
    }
    if nd.is_override {
        new_kid.append(nd.gen_token(Tok.KW_OVERRIDE));
    }
    if nd.is_static {
        new_kid.append(nd.gen_token(Tok.KW_STATIC));
    }
    new_kid.append(
        nd.gen_token(Tok.KW_CAN) if not nd.is_def else nd.gen_token(Tok.KW_DEF)
    );
    if nd.access {
        new_kid.append(nd.access);
    }
    if nd.name_ref {
        new_kid.append(nd.name_ref);
    }
    if nd.signature {
        new_kid.append(nd.signature);
    }
    if nd.is_genai_ability {
        new_kid.append(nd.gen_token(Tok.KW_BY));
    }
    if nd.is_abstract {
        new_kid.append(nd.gen_token(Tok.KW_ABSTRACT));
    }
    if nd.body is not None {
        if isinstance(nd.body, uni.ImplDef) {
            new_kid.append(nd.gen_token(Tok.SEMI));
        } elif isinstance(nd.body, Sequence) {
            new_kid.append(nd.gen_token(Tok.LBRACE));
            for stmt in nd.body {
                new_kid.append(stmt);
            }
            new_kid.append(nd.gen_token(Tok.RBRACE));
        } else {
            new_kid.append(nd.body);
            if nd.is_genai_ability {
                new_kid.append(nd.gen_token(Tok.SEMI));
            }
        }
    } else {
        new_kid.append(nd.gen_token(Tok.SEMI));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize FuncSignature kid list."""
impl NormalizePass.enter_func_signature(nd: uni.FuncSignature) -> None {
    is_lambda = nd.parent and isinstance(nd.parent, uni.LambdaExpr);
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LPAREN)] if not is_lambda else [];
    if nd.posonly_params {
        for prm in nd.posonly_params {
            new_kid.append(prm);
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
        new_kid.append(nd.gen_token(Tok.DIV));
        new_kid.append(nd.gen_token(Tok.COMMA));
    }
    if nd.params {
        for prm in nd.params {
            new_kid.append(prm);
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    if nd.varargs {
        new_kid.append(nd.varargs);
        new_kid.append(nd.gen_token(Tok.COMMA));
    } elif nd.kwonlyargs {
        new_kid.append(nd.gen_token(Tok.STAR_MUL));
        new_kid.append(nd.gen_token(Tok.COMMA));
    }
    for prm in nd.kwonlyargs {
        new_kid.append(prm);
        new_kid.append(nd.gen_token(Tok.COMMA));
    }
    if nd.kwargs {
        new_kid.append(nd.kwargs);
        new_kid.append(nd.gen_token(Tok.COMMA));
    }
    if new_kid and isinstance(new_kid[-1], Token) and new_kid[-1].name == Tok.COMMA {
        new_kid = new_kid[:-1];
    }
    if not is_lambda {
        new_kid.append(nd.gen_token(Tok.RPAREN));
    } elif not new_kid {
        new_kid.extend([nd.gen_token(Tok.LPAREN), nd.gen_token(Tok.RPAREN)]);
    }
    if nd.return_type {
        new_kid.append(nd.gen_token(Tok.RETURN_HINT));
        new_kid.append(nd.return_type);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize EventSignature kid list."""
impl NormalizePass.enter_event_signature(nd: uni.EventSignature) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_WITH)];
    if nd.arch_tag_info {
        new_kid.append(nd.arch_tag_info);
    }
    new_kid.append(nd.event);
    nd.set_kids(nodes=new_kid);
}

"""Normalize ParamVar kid list."""
impl NormalizePass.enter_param_var(nd: uni.ParamVar) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.unpack {
        new_kid.append(nd.unpack);
    }
    new_kid.append(nd.name);
    if nd.type_tag {
        new_kid.append(nd.type_tag);
    }
    if nd.value {
        new_kid.append(nd.gen_token(Tok.EQ));
        new_kid.append(nd.value);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ArchHas kid list."""
impl NormalizePass.enter_arch_has(nd: uni.ArchHas) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.doc {
        new_kid.append(nd.doc);
    }
    if nd.is_static {
        new_kid.append(nd.gen_token(Tok.KW_STATIC));
    }
    new_kid.append(nd.gen_token(Tok.KW_HAS));
    if nd.access {
        new_kid.append(nd.access);
    }
    for i in range(len(nd.vars)) {
        new_kid.append(nd.vars[i]);
        if i < len(nd.vars) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize HasVar kid list."""
impl NormalizePass.enter_has_var(nd: uni.HasVar) -> None {
    new_kid: list[uni.UniNode] = [nd.name];
    if nd.type_tag {
        new_kid.append(nd.type_tag);
    }
    if nd.value {
        new_kid.append(nd.gen_token(Tok.EQ));
        new_kid.append(nd.value);
    }
    if nd.defer {
        new_kid.append(nd.gen_token(Tok.KW_BY));
        new_kid.append(nd.gen_token(Tok.KW_POST_INIT));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize TypedCtxBlock kid list."""
impl NormalizePass.enter_typed_ctx_block(nd: uni.TypedCtxBlock) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.RETURN_HINT),
        nd.type_ctx,
        nd.gen_token(Tok.LBRACE),

    ];
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize IfStmt kid list."""
impl NormalizePass.enter_if_stmt(nd: uni.IfStmt) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_IF),
        nd.condition,
        nd.gen_token(Tok.LBRACE),

    ];
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    if nd.else_body {
        new_kid.append(nd.else_body);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ElseIf kid list."""
impl NormalizePass.enter_else_if(nd: uni.ElseIf) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_ELIF),
        nd.condition,
        nd.gen_token(Tok.LBRACE),

    ];
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    if nd.else_body {
        new_kid.append(nd.else_body);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ElseStmt kid list."""
impl NormalizePass.enter_else_stmt(nd: uni.ElseStmt) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_ELSE),
        nd.gen_token(Tok.LBRACE),

    ];
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize ExprStmt kid list."""
impl NormalizePass.enter_expr_stmt(nd: uni.ExprStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.in_fstring {
        new_kid.append(nd.expr);
    } else {
        new_kid.append(nd.expr);
        new_kid.append(nd.gen_token(Tok.SEMI));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize TryStmt kid list."""
impl NormalizePass.enter_try_stmt(nd: uni.TryStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_TRY), nd.gen_token(Tok.LBRACE), ];
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    for exc in nd.excepts {
        new_kid.append(exc);
    }
    if nd.else_body {
        new_kid.append(nd.else_body);
    }
    if nd.finally_body {
        new_kid.append(nd.finally_body);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize Except kid list."""
impl NormalizePass.enter_except(nd: uni.Except) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_EXCEPT), nd.ex_type, ];
    if nd.name {
        new_kid.append(nd.gen_token(Tok.KW_AS));
        new_kid.append(nd.name);
    }
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize FinallyStmt kid list."""
impl NormalizePass.enter_finally_stmt(nd: uni.FinallyStmt) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_FINALLY),
        nd.gen_token(Tok.LBRACE),

    ];
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize IterForStmt kid list."""
impl NormalizePass.enter_iter_for_stmt(nd: uni.IterForStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.is_async {
        new_kid.append(nd.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(nd.gen_token(Tok.KW_FOR));
    new_kid.append(nd.iter);
    new_kid.append(nd.gen_token(Tok.KW_TO));
    new_kid.append(nd.condition);
    new_kid.append(nd.gen_token(Tok.KW_BY));
    new_kid.append(nd.count_by);
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    if nd.else_body {
        new_kid.append(nd.else_body);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize InForStmt kid list."""
impl NormalizePass.enter_in_for_stmt(nd: uni.InForStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.is_async {
        new_kid.append(nd.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(nd.gen_token(Tok.KW_FOR));
    new_kid.append(nd.target);
    new_kid.append(nd.gen_token(Tok.KW_IN));
    new_kid.append(nd.collection);
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    if nd.else_body {
        new_kid.append(nd.else_body);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize WhileStmt kid list."""
impl NormalizePass.enter_while_stmt(nd: uni.WhileStmt) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_WHILE),
        nd.condition,
        nd.gen_token(Tok.LBRACE),

    ];
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    if nd.else_body {
        new_kid.append(nd.else_body);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize WithStmt kid list."""
impl NormalizePass.enter_with_stmt(nd: uni.WithStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.is_async {
        new_kid.append(nd.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(nd.gen_token(Tok.KW_WITH));
    for idx in range(len(nd.exprs)) {
        new_kid.append(nd.exprs[idx]);
        if idx < len(nd.exprs) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize ExprAsItem kid list."""
impl NormalizePass.enter_expr_as_item(nd: uni.ExprAsItem) -> None {
    new_kid: list[uni.UniNode] = [nd.expr];
    if nd.alias {
        new_kid.append(nd.gen_token(Tok.KW_AS));
        new_kid.append(nd.alias);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize RaiseStmt kid list."""
impl NormalizePass.enter_raise_stmt(nd: uni.RaiseStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_RAISE)];
    if nd.cause {
        new_kid.append(nd.cause);
    }
    if nd.from_target {
        new_kid.append(nd.gen_token(Tok.KW_FROM));
        new_kid.append(nd.from_target);
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize AssertStmt kid list."""
impl NormalizePass.enter_assert_stmt(nd: uni.AssertStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_ASSERT), nd.condition, ];
    if nd.error_msg {
        new_kid.append(nd.gen_token(Tok.COMMA));
        new_kid.append(nd.error_msg);
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize CtrlStmt kid list."""
impl NormalizePass.enter_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.ctrl, nd.gen_token(Tok.SEMI)];
    nd.set_kids(nodes=new_kid);
}

"""Normalize DeleteStmt kid list."""
impl NormalizePass.enter_delete_stmt(nd: uni.DeleteStmt) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_DELETE),
        nd.target,
        nd.gen_token(Tok.SEMI),

    ];
    nd.set_kids(nodes=new_kid);
}

"""Normalize ReportStmt kid list."""
impl NormalizePass.enter_report_stmt(nd: uni.ReportStmt) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_REPORT),
        nd.expr,
        nd.gen_token(Tok.SEMI),

    ];
    nd.set_kids(nodes=new_kid);
}

"""Normalize ReturnStmt kid list."""
impl NormalizePass.enter_return_stmt(nd: uni.ReturnStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_RETURN), ];
    if nd.expr {
        new_kid.append(nd.expr);
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize VisitStmt kid list."""
impl NormalizePass.enter_visit_stmt(nd: uni.VisitStmt) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(nd.gen_token(Tok.KW_VISIT));
    if nd.insert_loc {
        new_kid.append(nd.gen_token(Tok.COLON));
        new_kid.append(nd.insert_loc);
        new_kid.append(nd.gen_token(Tok.COLON));
    }
    new_kid.append(nd.target);
    if nd.else_body {
        new_kid.append(nd.else_body);
    } else {
        new_kid.append(nd.gen_token(Tok.SEMI));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize DisengageStmt kid list."""
impl NormalizePass.enter_disengage_stmt(nd: uni.DisengageStmt) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_DISENGAGE),
        nd.gen_token(Tok.SEMI),

    ];
    nd.set_kids(nodes=new_kid);
}

"""Normalize AwaitExpr kid list."""
impl NormalizePass.enter_await_expr(nd: uni.AwaitExpr) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_AWAIT), nd.target, ];
    nd.set_kids(nodes=new_kid);
}

"""Normalize GlobalStmt kid list."""
impl NormalizePass.enter_global_stmt(nd: uni.GlobalStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.GLOBAL_OP)];
    for idx in range(len(nd.target)) {
        new_kid.append(nd.target[idx]);
        if idx < len(nd.target) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize NonLocalStmt kid list."""
impl NormalizePass.enter_non_local_stmt(nd: uni.NonLocalStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.NONLOCAL_OP)];
    for idx in range(len(nd.target)) {
        new_kid.append(nd.target[idx]);
        if idx < len(nd.target) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize Assignment kid list."""
impl NormalizePass.enter_assignment(nd: uni.Assignment) -> None {
    new_kid: list[uni.UniNode] = [];
    for idx in range(len(nd.target)) {
        new_kid.append(nd.target[idx]);
        if idx < len(nd.target) - 1 {
            new_kid.append(nd.gen_token(Tok.EQ));
        }
    }
    if nd.type_tag {
        new_kid.append(nd.type_tag);
    }
    if nd.aug_op {
        new_kid.append(nd.aug_op);
    }
    if nd.value {
        if not nd.aug_op {
            new_kid.append(nd.gen_token(Tok.EQ));
        }
        new_kid.append(nd.value);
    }
    if isinstance(nd.parent, uni.GlobalVars) {
        if nd.parent.assignments.index(nd) == len(nd.parent.assignments) - 1 {
            new_kid.append(nd.gen_token(Tok.SEMI));
        }
    } elif (not nd.is_enum_stmt)
    and not (
        isinstance(nd.parent, uni.IterForStmt)
        and nd in [nd.parent.iter, nd.parent.count_by]
    ) {
        new_kid.append(nd.gen_token(Tok.SEMI));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ConcurrentExpr kid list."""
impl NormalizePass.enter_concurrent_expr(nd: uni.ConcurrentExpr) -> None {
    new_kid: list[uni.UniNode] = [];
    if isinstance(nd.tok, Token) and nd.tok.value == "flow" {
        new_kid.append(nd.gen_token(Tok.KW_FLOW));
    } elif isinstance(nd.tok, Token) and nd.tok.value == "wait" {
        new_kid.append(nd.gen_token(Tok.KW_WAIT));
    }
    new_kid.append(nd.target);
    nd.set_kids(nodes=new_kid);
}

"""Normalize BinaryExpr kid list."""
impl NormalizePass.enter_binary_expr(nd: uni.BinaryExpr) -> None {
    new_kid: list[uni.UniNode] = [nd.left, nd.op, nd.right];
    nd.set_kids(nodes=new_kid);
}

"""Normalize CompareExpr kid list."""
impl NormalizePass.enter_compare_expr(nd: uni.CompareExpr) -> None {
    new_kid: list[uni.UniNode] = [nd.left];
    for i in range(len(nd.rights)) {
        new_kid.append(nd.ops[i]);
        new_kid.append(nd.rights[i]);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize BoolExpr kid list."""
impl NormalizePass.enter_bool_expr(nd: uni.BoolExpr) -> None {
    new_kid: list[uni.UniNode] = [];
    for i in range(len(nd.values)) {
        if i > 0 {
            new_kid.append(nd.op);
        }
        new_kid.append(nd.values[i]);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize LambdaExpr kid list."""
impl NormalizePass.enter_lambda_expr(nd: uni.LambdaExpr) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_LAMBDA)];
    if nd.signature {
        new_kid.append(nd.signature);
    }
    # For code block lambdas, we add LBRACE, statements, RBRACE
    if isinstance(nd.body, list) {
        new_kid.append(nd.gen_token(Tok.LBRACE));
        new_kid.extend(nd.body);
        new_kid.append(nd.gen_token(Tok.RBRACE));
    } elif isinstance(nd.body, uni.Expr) {
        new_kid += [nd.gen_token(Tok.COLON), nd.body];
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize UnaryExpr kid list."""
impl NormalizePass.enter_unary_expr(nd: uni.UnaryExpr) -> None {
    new_kid: list[uni.UniNode] = [nd.op, nd.operand];
    nd.set_kids(nodes=new_kid);
}

"""Normalize IfElseExpr kid list."""
impl NormalizePass.enter_if_else_expr(nd: uni.IfElseExpr) -> None {
    new_kid: list[uni.UniNode] = [
        nd.value,
        nd.gen_token(Tok.KW_IF),
        nd.condition,
        nd.gen_token(Tok.KW_ELSE),
        nd.else_value,

    ];
    nd.set_kids(nodes=new_kid);
}

"""Normalize MultiString kid list."""
impl NormalizePass.enter_multi_string(nd: uni.MultiString) -> None {
    new_kid: list[uni.UniNode] = [];
    for string in nd.strings {
        new_kid.append(string);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize FString kid list."""
impl NormalizePass.enter_f_string(nd: uni.FString) -> None {
    new_kid: list[uni.UniNode] = [nd.start] if nd.start is not None else [];
    for part in nd.parts {
        new_kid.append(part);
    }
    if nd.end is not None {
        new_kid.append(nd.end);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize FormattedValue kid list."""
impl NormalizePass.enter_formatted_value(nd: uni.FormattedValue) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LBRACE)];
    new_kid.append(nd.format_part);
    if nd.conversion != -1 {
        new_kid.append(nd.gen_token(Tok.CONV, value="!" + chr(nd.conversion)));
    }
    if nd.format_spec {
        new_kid.append(nd.gen_token(Tok.COLON));
        new_kid.append(nd.format_spec);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize ListVal kid list."""
impl NormalizePass.enter_list_val(nd: uni.ListVal) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LSQUARE)];
    for idx in range(len(nd.values)) {
        new_kid.append(nd.values[idx]);
        if idx < len(nd.values) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.RSQUARE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize SetVal kid list."""
impl NormalizePass.enter_set_val(nd: uni.SetVal) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LBRACE)];
    for idx in range(len(nd.values)) {
        new_kid.append(nd.values[idx]);
        if idx < len(nd.values) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize TupleVal kid list."""
impl NormalizePass.enter_tuple_val(nd: uni.TupleVal) -> None {
    in_ret_type = (
        nd.parent
        and isinstance(nd.parent, uni.IndexSlice)
        and nd.parent
        and isinstance(nd.parent.parent, uni.AtomTrailer)
        and nd.parent.parent
        and isinstance(nd.parent.parent.parent, uni.FuncSignature)
    );
    new_kid: list[uni.UniNode] = (
        [nd.gen_token(Tok.LPAREN), ] if not in_ret_type else []
    );
    for idx in range(len(nd.values)) {
        new_kid.append(nd.values[idx]);
        if idx < len(nd.values) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    if len(nd.values) == 1 {
        new_kid.append(nd.gen_token(Tok.COMMA));
    }
    if not in_ret_type {
        new_kid.append(nd.gen_token(Tok.RPAREN));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize DictVal kid list."""
impl NormalizePass.enter_dict_val(nd: uni.DictVal) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LBRACE), ];
    for i in range(len(nd.kv_pairs)) {
        new_kid.append(nd.kv_pairs[i]);
        if i < len(nd.kv_pairs) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize KVPair kid list."""
impl NormalizePass.enter_k_v_pair(nd: uni.KVPair) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.key {
        new_kid.append(nd.key);
        new_kid.append(nd.gen_token(Tok.COLON));
    } else {
        new_kid.append(nd.gen_token(Tok.STAR_POW));
    }
    new_kid.append(nd.value);
    nd.set_kids(nodes=new_kid);
}

"""Normalize KWPair kid list."""
impl NormalizePass.enter_k_w_pair(nd: uni.KWPair) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.key {
        new_kid.append(nd.key);
        new_kid.append(nd.gen_token(Tok.EQ));
    } else {
        new_kid.append(nd.gen_token(Tok.STAR_POW));
    }
    new_kid.append(nd.value);
    nd.set_kids(nodes=new_kid);
}

"""Normalize InnerCompr kid list."""
impl NormalizePass.enter_inner_compr(nd: uni.InnerCompr) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.is_async {
        new_kid.append(nd.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(nd.gen_token(Tok.KW_FOR));
    new_kid.append(nd.target);
    new_kid.append(nd.gen_token(Tok.KW_IN));
    new_kid.append(nd.collection);
    for cond in nd.conditional or [] {
        new_kid.append(nd.gen_token(Tok.KW_IF));
        new_kid.append(cond);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize ListCompr kid list."""
impl NormalizePass.enter_list_compr(nd: uni.ListCompr) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LSQUARE), nd.out_expr, ];
    for comp in nd.compr {
        new_kid.append(comp);
    }
    new_kid.append(nd.gen_token(Tok.RSQUARE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize GenCompr kid list."""
impl NormalizePass.enter_gen_compr(nd: uni.GenCompr) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LPAREN), nd.out_expr, ];
    for comp in nd.compr {
        new_kid.append(comp);
    }
    new_kid.append(nd.gen_token(Tok.RPAREN));
    nd.set_kids(nodes=new_kid);
}

"""Normalize SetCompr kid list."""
impl NormalizePass.enter_set_compr(nd: uni.SetCompr) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LBRACE), nd.out_expr, ];
    for comp in nd.compr {
        new_kid.append(comp);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize DictCompr kid list."""
impl NormalizePass.enter_dict_compr(nd: uni.DictCompr) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LBRACE), nd.kv_pair, ];
    for comp in nd.compr {
        new_kid.append(comp);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize AtomTrailer kid list."""
impl NormalizePass.enter_atom_trailer(nd: uni.AtomTrailer) -> None {
    new_kid: list[uni.UniNode] = [nd.target];
    if nd.is_null_ok {
        new_kid.append(nd.gen_token(Tok.NULL_OK));
    }
    if nd.is_attr {
        new_kid.append(nd.gen_token(Tok.DOT));
    }
    if nd.right {
        new_kid.append(nd.right);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize AtomUnit kid list."""
impl NormalizePass.enter_atom_unit(nd: uni.AtomUnit) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(nd.gen_token(Tok.LPAREN));
    new_kid.append(nd.value);
    new_kid.append(nd.gen_token(Tok.RPAREN));
    nd.set_kids(nodes=new_kid);
}

"""Normalize YieldExpr kid list."""
impl NormalizePass.enter_yield_expr(nd: uni.YieldExpr) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_YIELD)];
    if nd.with_from {
        new_kid.append(nd.gen_token(Tok.KW_FROM));
    }
    if nd.expr {
        new_kid.append(nd.expr);
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

"""Normalize FuncCall kid list."""
impl NormalizePass.enter_func_call(nd: uni.FuncCall) -> None {
    new_kids: list[uni.UniNode] = [nd.target];
    is_gencompr = len(nd.params) == 1 and isinstance(nd.params[0], uni.GenCompr);
    if not is_gencompr {
        new_kids.append(nd.gen_token(Tok.LPAREN));
    }
    for i in range(len(nd.params)) {
        new_kids.append(nd.params[i]);
        if i < len(nd.params) - 1 {
            new_kids.append(nd.gen_token(Tok.COMMA));
        }
    }
    if nd.genai_call {
        new_kids.append(nd.gen_token(Tok.KW_BY));
        new_kids.append(nd.genai_call);
    }
    if not is_gencompr {
        new_kids.append(nd.gen_token(Tok.RPAREN, ")"));
    }
    nd.set_kids(nodes=new_kids);
}

"""Normalize IndexSlice kid list."""
impl NormalizePass.enter_index_slice(nd: uni.IndexSlice) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(nd.gen_token(Tok.LSQUARE));
    if nd.is_range {
        for i in range(len(nd.slices)) {
            if i > 0 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
            if nd.slices[i].start {
                new_kid.append(nd.slices[i].start);
            }
            new_kid.append(nd.gen_token(Tok.COLON));
            if nd.slices[i].stop {
                new_kid.append(nd.slices[i].stop);
            }
            if nd.slices[i].step {
                new_kid.append(nd.gen_token(Tok.COLON));
                new_kid.append(nd.slices[i].step);
            }
        }
    } elif len(nd.slices) == 1 and nd.slices[0].start {
        new_kid.append(nd.slices[0].start);
    }
    new_kid.append(nd.gen_token(Tok.RSQUARE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize EdgeRefTrailer kid list."""
impl NormalizePass.enter_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(nd.gen_token(Tok.LSQUARE));
    if nd.is_async {
        new_kid.append(nd.gen_token(Tok.KW_ASYNC));
    }
    if nd.edges_only {
        new_kid.append(nd.gen_token(Tok.KW_EDGE));
    }
    new_kid.extend(nd.chain);
    new_kid.append(nd.gen_token(Tok.RSQUARE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize EdgeOpRef kid list."""
impl NormalizePass.enter_edge_op_ref(nd: uni.EdgeOpRef) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.edge_dir == EdgeDir.IN {
        if not nd.filter_cond {
            new_kid.append(nd.gen_token(Tok.ARROW_L));
        } else {
            new_kid.append(nd.gen_token(Tok.ARROW_L_P1));
            new_kid.append(nd.filter_cond);
            new_kid.append(nd.gen_token(Tok.ARROW_L_P2));
        }
    } elif nd.edge_dir == EdgeDir.OUT {
        if not nd.filter_cond {
            new_kid.append(nd.gen_token(Tok.ARROW_R));
        } else {
            new_kid.append(nd.gen_token(Tok.ARROW_R_P1));
            new_kid.append(nd.filter_cond);
            new_kid.append(nd.gen_token(Tok.ARROW_R_P2));
        }
    } else {
        if not nd.filter_cond {
            new_kid.append(nd.gen_token(Tok.ARROW_BI));
        } else {
            new_kid.append(nd.gen_token(Tok.ARROW_L_P1));
            new_kid.append(nd.filter_cond);
            new_kid.append(nd.gen_token(Tok.ARROW_R_P2));
        }
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize DisconnectOp kid list."""
impl NormalizePass.enter_disconnect_op(nd: uni.DisconnectOp) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_DELETE), nd.edge_spec];
    nd.set_kids(nodes=new_kid);
}

"""Normalize ConnectOp kid list."""
impl NormalizePass.enter_connect_op(nd: uni.ConnectOp) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.edge_dir == EdgeDir.IN {
        if not nd.conn_assign and not nd.conn_type {
            new_kid.append(nd.gen_token(Tok.CARROW_L));
        } else {
            new_kid.append(nd.gen_token(Tok.CARROW_L_P1));
            if nd.conn_type {
                new_kid.append(nd.conn_type);
            }
            if nd.conn_assign {
                new_kid.append(nd.gen_token(Tok.COLON));
                new_kid.append(nd.conn_assign);
            }
            new_kid.append(nd.gen_token(Tok.CARROW_L_P2));
        }
    } elif nd.edge_dir == EdgeDir.OUT {
        if not nd.conn_assign and not nd.conn_type {
            new_kid.append(nd.gen_token(Tok.CARROW_R));
        } else {
            new_kid.append(nd.gen_token(Tok.CARROW_R_P1));
            if nd.conn_type {
                new_kid.append(nd.conn_type);
            }
            if nd.conn_assign {
                new_kid.append(nd.gen_token(Tok.COLON));
                new_kid.append(nd.conn_assign);
            }
            new_kid.append(nd.gen_token(Tok.CARROW_R_P2));
        }
    } else {
        if not nd.conn_assign and not nd.conn_type {
            new_kid.append(nd.gen_token(Tok.CARROW_BI));
        } else {
            new_kid.append(nd.gen_token(Tok.CARROW_L_P1));
            if nd.conn_type {
                new_kid.append(nd.conn_type);
            }
            if nd.conn_assign {
                new_kid.append(nd.gen_token(Tok.COLON));
                new_kid.append(nd.conn_assign);
            }
            new_kid.append(nd.gen_token(Tok.CARROW_R_P2));
        }
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize FilterCompr kid list."""
impl NormalizePass.enter_filter_compr(nd: uni.FilterCompr) -> None {
    new_kid: list[uni.UniNode] = [];
    if not isinstance(nd.parent, uni.EdgeOpRef) {
        new_kid.append(nd.gen_token(Tok.LPAREN));
        new_kid.append(nd.gen_token(Tok.NULL_OK));
    }
    if nd.f_type {
        if not isinstance(nd.parent, uni.EdgeOpRef) {
            new_kid.append(nd.gen_token(Tok.COLON));
        }
        new_kid.append(nd.f_type);
    }
    if nd.compares {
        if nd.f_type {
            if isinstance(nd.parent, uni.EdgeOpRef) {
                new_kid.append(nd.gen_token(Tok.COLON));
            } else {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
        for i in range(len(nd.compares)) {
            new_kid.append(nd.compares[i]);
            if i < len(nd.compares) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
    }
    if not isinstance(nd.parent, uni.EdgeOpRef) {
        new_kid.append(nd.gen_token(Tok.RPAREN));
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize AssignCompr kid list."""
impl NormalizePass.enter_assign_compr(nd: uni.AssignCompr) -> None {
    new_kid: list[uni.UniNode] = [];
    if isinstance(nd.parent, uni.ConnectOp) {
        for i in range(len(nd.assigns)) {
            new_kid.append(nd.assigns[i]);
            if i < len(nd.assigns) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
    } else {
        new_kid.append(nd.gen_token(Tok.LPAREN));
        new_kid.append(nd.gen_token(Tok.EQ));
        for i in range(len(nd.assigns)) {
            new_kid.append(nd.assigns[i]);
            if i < len(nd.assigns) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(nd.gen_token(Tok.RPAREN));
    }
    nd.set_kids(nodes=new_kid);
}

"""JsxAttribute base - no-op."""
impl NormalizePass.enter_jsx_attribute(nd: uni.JsxAttribute) -> None { }

"""JsxChild base - no-op."""
impl NormalizePass.enter_jsx_child(nd: uni.JsxChild) -> None { }

"""Normalize JsxElement kid list.  Unlike most normalize methods, JSX elements don't need to rebuild their kid structure since the parser already creates it correctly. """
impl NormalizePass.enter_jsx_element(nd: uni.JsxElement) -> None { }

"""Normalize JsxElementName kid list."""
impl NormalizePass.enter_jsx_element_name(nd: uni.JsxElementName) -> None {
    new_kid: list[uni.UniNode] = [];
    for i in range(len(nd.parts)) {
        new_kid.append(nd.parts[i]);
        if i < len(nd.parts) - 1 {
            new_kid.append(nd.gen_token(Tok.DOT));
        }
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize JsxSpreadAttribute kid list."""
impl NormalizePass.enter_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.LBRACE),
        nd.gen_token(Tok.ELLIPSIS),
        nd.expr,
        nd.gen_token(Tok.RBRACE),

    ];
    nd.set_kids(nodes=new_kid);
}

"""Normalize JsxNormalAttribute kid list."""
impl NormalizePass.enter_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None {
    new_kid: list[uni.UniNode] = [nd.name];
    if nd.value {
        new_kid.append(nd.gen_token(Tok.EQ));
        if isinstance(nd.value, uni.String) {
            new_kid.append(nd.value);
        } else {
            # Expression in braces
            new_kid.extend(
                [nd.gen_token(Tok.LBRACE), nd.value, nd.gen_token(Tok.RBRACE), ]
            );
        }
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize JsxText kid list."""
impl NormalizePass.enter_jsx_text(nd: uni.JsxText) -> None {
    # Value is always a Token now (parser stores raw token)
    if isinstance(nd.value, uni.Token) {
        nd.set_kids(nodes=[nd.value]);
    } else {
        nd.set_kids(nodes=[nd.gen_token(Tok.JSX_TEXT, value=str(nd.value))]);
    }
}

"""Normalize JsxExpression kid list."""
impl NormalizePass.enter_jsx_expression(nd: uni.JsxExpression) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.LBRACE),
        nd.expr,
        nd.gen_token(Tok.RBRACE),

    ];
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchStmt kid list."""
impl NormalizePass.enter_match_stmt(nd: uni.MatchStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_MATCH), nd.target, ];
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for case in nd.cases {
        new_kid.append(case);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchCase kid list."""
impl NormalizePass.enter_match_case(nd: uni.MatchCase) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_CASE), nd.pattern];
    if nd.guard {
        new_kid.append(nd.gen_token(Tok.KW_IF));
        new_kid.append(nd.guard);
    }
    new_kid.append(nd.gen_token(Tok.COLON));
    if nd.body {
        new_kid.extend([*nd.body]);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize SwitchStmt kid list."""
impl NormalizePass.enter_switch_stmt(nd: uni.SwitchStmt) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_SWITCH), nd.target, ];
    new_kid.append(nd.gen_token(Tok.LBRACE));
    for case in nd.cases {
        new_kid.append(case);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize SwitchCase kid list."""
impl NormalizePass.enter_switch_case(nd: uni.SwitchCase) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.KW_CASE)];
    if nd.pattern is not None {
        new_kid.append(nd.pattern);
    } else {
        new_kid.pop();
        new_kid.append(nd.gen_token(Tok.KW_DEFAULT));
    }
    new_kid.append(nd.gen_token(Tok.COLON));
    if nd.body {
        new_kid.extend([*nd.body]);
    }
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchOr kid list."""
impl NormalizePass.enter_match_or(nd: uni.MatchOr) -> None {
    new_kid: list[uni.UniNode] = [];
    for pattern in nd.patterns {
        new_kid.append(pattern);
        new_kid.append(nd.gen_token(Tok.KW_OR));
    }
    new_kid.pop();
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchAs kid list."""
impl NormalizePass.enter_match_as(nd: uni.MatchAs) -> None {
    new_kid: list[uni.UniNode] = [];
    if nd.pattern {
        new_kid.append(nd.pattern);
        new_kid.append(nd.gen_token(Tok.KW_AS));
    }
    new_kid.append(nd.name);
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchWild kid list."""
impl NormalizePass.enter_match_wild(nd: uni.MatchWild) -> None {
    nd.set_kids(
        nodes=[
            uni.Name(
                orig_src=nd.loc.orig_src,
                name=Tok.NAME,
                value="_",
                col_start=nd.loc.col_start,
                col_end=nd.loc.col_end,
                line=nd.loc.first_line,
                end_line=nd.loc.last_line,
                pos_start=nd.loc.pos_start,
                pos_end=nd.loc.pos_end,
            )
        ],
    );
}

"""Normalize MatchValue kid list."""
impl NormalizePass.enter_match_value(nd: uni.MatchValue) -> None {
    nd.set_kids(nodes=[nd.value]);
}

"""Normalize MatchSingleton kid list."""
impl NormalizePass.enter_match_singleton(nd: uni.MatchSingleton) -> None {
    nd.set_kids(nodes=[nd.value]);
}

"""Normalize MatchSequence kid list."""
impl NormalizePass.enter_match_sequence(nd: uni.MatchSequence) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LSQUARE)];
    for value in nd.values {
        new_kid.append(value);
        new_kid.append(nd.gen_token(Tok.COMMA));
    }
    new_kid.pop();
    new_kid.append(nd.gen_token(Tok.RSQUARE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchMapping kid list."""
impl NormalizePass.enter_match_mapping(nd: uni.MatchMapping) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(Tok.LBRACE)];
    for value in nd.values {
        new_kid.append(value);
        new_kid.append(nd.gen_token(Tok.COMMA));
    }
    new_kid.pop();
    new_kid.append(nd.gen_token(Tok.RBRACE));
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchKVPair kid list."""
impl NormalizePass.enter_match_k_v_pair(nd: uni.MatchKVPair) -> None {
    op = Tok.EQ if isinstance(nd.key, uni.Name) else Tok.COLON;
    new_kid: list[uni.UniNode] = [nd.key, nd.gen_token(op), nd.value];
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchStar kid list."""
impl NormalizePass.enter_match_star(nd: uni.MatchStar) -> None {
    new_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.STAR_MUL if nd.is_list else Tok.STAR_POW)
    ];
    new_kid.append(nd.name);
    nd.set_kids(nodes=new_kid);
}

"""Normalize MatchArch kid list."""
impl NormalizePass.enter_match_arch(nd: uni.MatchArch) -> None {
    new_kid: list[uni.UniNode] = [nd.name];
    new_kid.append(nd.gen_token(Tok.LPAREN));
    if nd.arg_patterns {
        for idx in range(len(nd.arg_patterns)) {
            new_kid.append(nd.arg_patterns[idx]);
            if idx < len(nd.arg_patterns) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
        if nd.kw_patterns {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    if nd.kw_patterns {
        for idx in range(len(nd.kw_patterns)) {
            new_kid.append(nd.kw_patterns[idx]);
            if idx < len(nd.kw_patterns) - 1 {
                new_kid.append(nd.gen_token(Tok.COMMA));
            }
        }
    }
    new_kid.append(nd.gen_token(Tok.RPAREN));
    nd.set_kids(nodes=new_kid);
}

"""Token normalize is a no-op (leaf node)."""
impl NormalizePass.enter_token(nd: uni.Token) -> None { }

"""Normalize string value."""
impl NormalizePass.enter_string(nd: uni.String) -> None {
    nd.value = f"{nd.value}";
}
