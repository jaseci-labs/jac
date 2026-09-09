impl NormalizePass.enter_sub_tag with uni.SubTag entry {
    here.set_kids(nodes=[here.gen_token(Tok.COLON), here.tag]);
}

impl NormalizePass.enter_module with uni.Module entry {
    if here.is_raised_from_py {
        for imp in here.get_all_sub_nodes(typ=uni.Import) {
            if imp.from_loc is None or imp.from_loc.dot_path_str != "typing" {
                continue;
            }
            _kept = [
                i
                for i in imp.items
                if not (isinstance(i, uni.ModuleItem) and i.name.value == "Any")
            ];
            if not _kept and imp.parent is not None and imp in here.body {
                here._role_set(
                    BodyRole,
                    [
                        st
                        for st in here.body
                        if st is not imp
                    ]
                );
            } elif len(_kept) != len(imp.items) {
                imp._role_set(ItemsRole, _kept);
                imp.set_kids(
                    nodes=[
                        k
                        for k in imp.kid
                        if not (isinstance(k, uni.ModuleItem) and k.name.value == "Any")
                    ]
                );
            }
        }
        for anm in here.get_all_sub_nodes(typ=uni.Name) {
            if anm.value == "Any" {
                anm.value = "any";
            }
        }
    }
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    new_kid.extend(here.body);
    here.set_kids(nodes=new_kid if len(new_kid) else [EmptyToken()]);
}

impl NormalizePass.enter_type_param with uni.TypeParam entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_comptime {
        new_kid.append(here.gen_token(Tok.KW_COMPTIME));
    }
    new_kid.append(here.name);
    if here.bound {
        new_kid.append(here.gen_token(Tok.COLON));
        new_kid.append(here.bound);
    }
    if here.default_val {
        new_kid.append(here.gen_token(Tok.EQ));
        new_kid.append(here.default_val);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_type_alias with uni.TypeAlias entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    new_kid.append(here.gen_token(Tok.TYP_TYPE));
    if here.access {
        new_kid.append(here.access);
    }
    new_kid.append(here.name);
    if here.type_params {
        new_kid.append(here.gen_token(Tok.LSQUARE));
        for idx in range(len(here.type_params)) {
            new_kid.append(here.type_params[idx]);
            if idx < len(here.type_params) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(here.gen_token(Tok.RSQUARE));
    }
    new_kid.append(
        here.gen_token(Tok.WALRUS_EQ) if here.is_distinct else here.gen_token(Tok.EQ)
    );
    new_kid.append(here.value);
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_global_vars with uni.GlobalVars entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    new_kid.append(
        here.gen_token(Tok.KW_COMPTIME)
            if here.is_frozen
            else here.gen_token(Tok.KW_GLOBAL)
    );
    if here.access {
        new_kid.append(here.access);
    }
    for i in range(len(here.assignments)) {
        new_kid.append(here.assignments[i]);
        if i < len(here.assignments) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_test with uni.Test entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    if here.decorators {
        new_kid.append(here.gen_token(Tok.DECOR_OP));
        for idx in range(len(here.decorators)) {
            new_kid.append(here.decorators[idx]);
            if idx < len(here.decorators) - 1 {
                new_kid.append(here.gen_token(Tok.DECOR_OP));
            }
        }
        new_kid.append(here.gen_token(Tok.WS));
    }
    new_kid.append(here.gen_token(Tok.KW_TEST));
    if here.description {
        new_kid.append(here.description);
    } else {
        new_kid.append(here.name);
    }
    new_kid.append(here.gen_token(Tok.LBRACE));
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_module_code with uni.ModuleCode entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    new_kid.append(here.gen_token(Tok.KW_WITH));
    new_kid.append(here.gen_token(Tok.KW_ENTRY));
    if here.name {
        new_kid.append(here.gen_token(Tok.COLON));
        new_kid.append(here.name);
    }
    new_kid.append(here.gen_token(Tok.LBRACE));
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_py_inline_code with uni.PyInlineCode entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    new_kid.append(here.code);
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_import with uni.Import entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    if here.is_comptime {
        new_kid.append(here.gen_token(Tok.KW_COMPTIME));
    }
    if here.is_absorb {
        new_kid.append(here.gen_token(Tok.KW_INCLUDE));
    } else {
        new_kid.append(here.gen_token(Tok.KW_IMPORT));
    }
    if here.is_typed {
        new_kid.append(here.gen_token(Tok.TYP_TYPE));
    }
    if here.from_loc {
        new_kid.append(here.gen_token(Tok.KW_FROM));
        new_kid.append(here.from_loc);
        new_kid.append(here.gen_token(Tok.LBRACE));
    }
    for idx in range(len(here.items)) {
        new_kid.append(here.items[idx]);
        if idx < len(here.items) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    if here.from_loc {
        new_kid.append(here.gen_token(Tok.RBRACE));
    } else {
        new_kid.append(here.gen_token(Tok.SEMI));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_module_path with uni.ModulePath entry {
    new_kid: list[uni.UniNode] = [];
    for _ in range(here.level) {
        new_kid.append(here.gen_token(Tok.DOT));
    }
    if here.path {
        for idx in range(len(here.path)) {
            new_kid.append(here.path[idx]);
            if idx < len(here.path) - 1 {
                new_kid.append(here.gen_token(Tok.DOT));
            }
        }
    }
    if here.alias {
        new_kid.append(here.gen_token(Tok.KW_AS));
        new_kid.append(here.alias);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_module_item with uni.ModuleItem entry {
    new_kid: list[uni.UniNode] = [here.name];
    if here.alias {
        new_kid.append(here.gen_token(Tok.KW_AS));
        new_kid.append(here.alias);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_archetype with uni.Archetype entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);

        if not isinstance(here.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            new_kid.append(here.gen_token(Tok.SEMI));
        }
    }
    if here.decorators {
        new_kid.append(here.gen_token(Tok.DECOR_OP));
        for idx in range(len(here.decorators)) {
            new_kid.append(here.decorators[idx]);
            if idx < len(here.decorators) - 1 {
                new_kid.append(here.gen_token(Tok.DECOR_OP));
            }
        }
    }
    if here.is_async {
        new_kid.append(here.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(here.arch_type);
    if here.access {
        new_kid.append(here.access);
    }
    new_kid.append(here.name);
    if here.type_params {
        new_kid.append(here.gen_token(Tok.LSQUARE));
        for idx in range(len(here.type_params)) {
            new_kid.append(here.type_params[idx]);
            if idx < len(here.type_params) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(here.gen_token(Tok.RSQUARE));
    }
    inherit: list = list(here.base_classes) + list(here.keywords);
    if inherit {
        new_kid.append(here.gen_token(Tok.LPAREN));
        for idx in range(len(inherit)) {
            new_kid.append(inherit[idx]);
            if idx < len(inherit) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(here.gen_token(Tok.RPAREN));
    }
    if here.body {
        if isinstance(here.body, uni.ImplDef) {
            new_kid.append(here.gen_token(Tok.SEMI));
        } else {
            new_kid.append(here.gen_token(Tok.LBRACE));
            for stmt in here.body {
                new_kid.append(stmt);
            }
            new_kid.append(here.gen_token(Tok.RBRACE));
        }
    } else {
        new_kid.append(here.gen_token(Tok.LBRACE));
        new_kid.append(here.gen_token(Tok.RBRACE));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_impl_def with uni.ImplDef entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    if here.decorators {
        new_kid.append(here.gen_token(Tok.DECOR_OP));
        for i in range(len(here.decorators)) {
            new_kid.append(here.decorators[i]);
            if i < len(here.decorators) - 1 {
                new_kid.append(here.gen_token(Tok.DECOR_OP));
            }
        }
    }
    new_kid.append(here.gen_token(Tok.KW_IMPL));
    for idx in range(len(here.target)) {
        new_kid.append(here.target[idx]);
        if idx < len(here.target) - 1 {
            new_kid.append(here.gen_token(Tok.DOT));
        }
    }
    if here.spec {
        if isinstance(here.spec, Sequence) {
            new_kid.append(here.gen_token(Tok.LPAREN));
            for idx in range(len(here.spec)) {
                new_kid.append(here.spec[idx]);
                if idx < len(here.spec) - 1 {
                    new_kid.append(here.gen_token(Tok.COMMA));
                }
            }
            new_kid.append(here.gen_token(Tok.RPAREN));
        } else {
            new_kid.append(here.spec);
        }
    }
    if isinstance(here.body, uni.Expr) {
        new_kid.append(here.body);
    } else {
        new_kid.append(here.gen_token(Tok.LBRACE));
        prev_stmt = None;
        for stmt in here.body {
            if isinstance(prev_stmt, uni.EnumBlockStmt) and prev_stmt.is_enum_stmt {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
            new_kid.append(stmt);
            prev_stmt = stmt;
        }
        new_kid.append(here.gen_token(Tok.RBRACE));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_sem_def with uni.SemDef entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_SEM), ];
    for idx in range(len(here.target)) {
        new_kid.append(here.target[idx]);
        if idx < len(here.target) - 1 {
            new_kid.append(here.gen_token(Tok.DOT));
        }
    }
    new_kid.append(here.gen_token(Tok.EQ));
    new_kid.append(here.value);
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_enum with uni.Enum entry {
    new_kid: list[uni.UniNode] = [];
    if here.decorators {
        new_kid.append(here.gen_token(Tok.DECOR_OP));
        for idx in range(len(here.decorators)) {
            new_kid.append(here.decorators[idx]);
            if idx < len(here.decorators) - 1 {
                new_kid.append(here.gen_token(Tok.DECOR_OP));
            }
        }
    }
    if here.doc {
        new_kid.append(here.doc);
    }
    new_kid.append(here.gen_token(Tok.KW_ENUM));
    if here.access {
        new_kid.append(here.access);
    }
    new_kid.append(here.name);
    if here.value_type {
        new_kid.append(here.gen_token(Tok.COLON));
        new_kid.append(here.value_type);
    } elif here.base_classes {
        new_kid.append(here.gen_token(Tok.LPAREN));
        for idx in range(len(here.base_classes)) {
            new_kid.append(here.base_classes[idx]);
            if idx < len(here.base_classes) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(here.gen_token(Tok.RPAREN));
    }
    if here.body {
        if isinstance(here.body, uni.ImplDef) {
            new_kid.append(here.gen_token(Tok.SEMI));
        } else {
            new_kid.append(here.gen_token(Tok.LBRACE));
            prev_stmt = None;
            for stmt in here.body {
                if isinstance(prev_stmt, uni.EnumBlockStmt)
                    and prev_stmt.is_enum_stmt {
                    new_kid.append(here.gen_token(Tok.COMMA));
                }
                new_kid.append(stmt);
                prev_stmt = stmt;
            }
            new_kid.append(here.gen_token(Tok.RBRACE));
        }
    } else {
        new_kid.append(here.gen_token(Tok.SEMI));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_ability with uni.Ability entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);

        if not isinstance(here.parent, (uni.Module, uni.Archetype, uni.Enum)) {
            new_kid.append(here.gen_token(Tok.SEMI));
        }
    }
    if here.decorators {
        new_kid.append(here.gen_token(Tok.DECOR_OP));
        for idx in range(len(here.decorators)) {
            new_kid.append(here.decorators[idx]);
            if idx < len(here.decorators) - 1 {
                new_kid.append(here.gen_token(Tok.DECOR_OP));
            }
        }
        new_kid.append(here.gen_token(Tok.WS));
    }
    if here.is_comptime {
        new_kid.append(here.gen_token(Tok.KW_COMPTIME));
    }
    if here.is_async {
        new_kid.append(here.gen_token(Tok.KW_ASYNC));
    }
    if here.is_override {
        new_kid.append(here.gen_token(Tok.KW_OVERRIDE));
    }
    if here.is_static {
        new_kid.append(here.gen_token(Tok.KW_STATIC));
    }
    new_kid.append(
        here.gen_token(Tok.KW_CAN) if not here.is_def else here.gen_token(Tok.KW_DEF)
    );
    if here.access {
        new_kid.append(here.access);
    }
    if here.name_ref {
        new_kid.append(here.name_ref);
    }
    if here.signature {
        new_kid.append(here.signature);
    }
    if here.is_genai_ability {
        new_kid.append(here.gen_token(Tok.KW_BY));
    }
    if here.is_abstract {
        new_kid.append(here.gen_token(Tok.KW_ABSTRACT));
    }
    if here.body is not None {
        if isinstance(here.body, uni.ImplDef) {
            new_kid.append(here.gen_token(Tok.SEMI));
        } elif isinstance(here.body, Sequence) {
            new_kid.append(here.gen_token(Tok.LBRACE));
            for stmt in here.body {
                new_kid.append(stmt);
            }
            new_kid.append(here.gen_token(Tok.RBRACE));
        } else {
            new_kid.append(here.body);
            if here.is_genai_ability {
                new_kid.append(here.gen_token(Tok.SEMI));
            }
        }
    } else {
        new_kid.append(here.gen_token(Tok.SEMI));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_func_signature with uni.FuncSignature entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LPAREN)];
    if here.posonly_params {
        for prm in here.posonly_params {
            new_kid.append(prm);
            new_kid.append(here.gen_token(Tok.COMMA));
        }
        new_kid.append(here.gen_token(Tok.DIV));
        new_kid.append(here.gen_token(Tok.COMMA));
    }
    if here.params {
        for prm in here.params {
            new_kid.append(prm);
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    if here.varargs {
        new_kid.append(here.varargs);
        new_kid.append(here.gen_token(Tok.COMMA));
    } elif here.kwonlyargs {
        new_kid.append(here.gen_token(Tok.STAR_MUL));
        new_kid.append(here.gen_token(Tok.COMMA));
    }
    for prm in here.kwonlyargs {
        new_kid.append(prm);
        new_kid.append(here.gen_token(Tok.COMMA));
    }
    if here.kwargs {
        new_kid.append(here.kwargs);
        new_kid.append(here.gen_token(Tok.COMMA));
    }
    if new_kid and isinstance(new_kid[-1], Token) and new_kid[-1].name == Tok.COMMA {
        new_kid = new_kid[:-1];
    }
    new_kid.append(here.gen_token(Tok.RPAREN));
    if here.return_type {
        new_kid.append(here.gen_token(Tok.RETURN_HINT));
        new_kid.append(here.return_type);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_event_signature with uni.EventSignature entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_WITH)];
    if here.arch_tag_info {
        new_kid.append(here.arch_tag_info);
    }
    new_kid.append(here.event);
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_param_var with uni.ParamVar entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_comptime {
        new_kid.append(here.gen_token(Tok.KW_COMPTIME));
    }
    if here.unpack {
        new_kid.append(here.unpack);
    }
    new_kid.append(here.name);
    if here.type_tag {
        new_kid.append(here.type_tag);
    }
    if here.value {
        new_kid.append(here.gen_token(Tok.EQ));
        new_kid.append(here.value);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_arch_has with uni.ArchHas entry {
    new_kid: list[uni.UniNode] = [];
    if here.doc {
        new_kid.append(here.doc);
    }
    if here.is_static {
        new_kid.append(here.gen_token(Tok.KW_STATIC));
    }
    new_kid.append(here.gen_token(Tok.KW_HAS));
    if here.access {
        new_kid.append(here.access);
    }
    for i in range(len(here.vars)) {
        new_kid.append(here.vars[i]);
        if i < len(here.vars) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_has_var with uni.HasVar entry {
    new_kid: list[uni.UniNode] = [here.name];
    if here.type_tag {
        new_kid.append(here.type_tag);
    }
    if here.value {
        new_kid.append(here.gen_token(Tok.EQ));
        new_kid.append(here.value);
    }
    if here.defer {
        new_kid.append(here.gen_token(Tok.KW_POST_INIT));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_typed_ctx_block with uni.TypedCtxBlock entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.RETURN_HINT),
        here.type_ctx,
        here.gen_token(Tok.LBRACE),

    ];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass._normalize_cond_block(
    nd: (uni.IfStmt | uni.WhileStmt), kw: Tok
) -> None {
    new_kid: list[uni.UniNode] = [];
    if isinstance(nd, uni.IfStmt)
        and not isinstance(nd, uni.ElseIf)
        and nd.is_comptime {
        new_kid.append(nd.gen_token(Tok.KW_COMPTIME));
    }
    new_kid.extend([nd.gen_token(kw), nd.condition, nd.gen_token(Tok.LBRACE), ]);
    for stmt in nd.body {
        new_kid.append(stmt);
    }
    new_kid.append(nd.gen_token(Tok.RBRACE));
    if nd.else_body {
        new_kid.append(nd.else_body);
    }
    nd.set_kids(nodes=new_kid);
}

impl NormalizePass._normalize_name_list_stmt(
    nd: (uni.SemDef | uni.ImplDef), op: Tok
) -> None {
    new_kid: list[uni.UniNode] = [nd.gen_token(op)];
    for idx in range(len(nd.target)) {
        new_kid.append(nd.target[idx]);
        if idx < len(nd.target) - 1 {
            new_kid.append(nd.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(nd.gen_token(Tok.SEMI));
    nd.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_if_stmt with uni.IfStmt entry {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    self._normalize_cond_block(here, Tok.KW_IF);
}

impl NormalizePass.enter_else_if with uni.ElseIf entry {
    self._normalize_cond_block(here, Tok.KW_ELIF);
}

impl NormalizePass.enter_else_stmt with uni.ElseStmt entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_ELSE),
        here.gen_token(Tok.LBRACE),

    ];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_expr_stmt with uni.ExprStmt entry {
    new_kid: list[uni.UniNode] = [];
    if here.in_fstring {
        new_kid.append(here.expr);
    } else {
        new_kid.append(here.expr);
        new_kid.append(here.gen_token(Tok.SEMI));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_try_stmt with uni.TryStmt entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_TRY),
        here.gen_token(Tok.LBRACE),

    ];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    if here.awaiting_body {
        new_kid.append(here.awaiting_body);
    }
    for exc in here.excepts {
        new_kid.append(exc);
    }
    if here.else_body {
        new_kid.append(here.else_body);
    }
    if here.finally_body {
        new_kid.append(here.finally_body);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_awaiting_clause with uni.AwaitingClause entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_AWAITING),
        here.gen_token(Tok.LBRACE),

    ];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_except with uni.Except entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_EXCEPT), here.ex_type, ];
    if here.name {
        new_kid.append(here.gen_token(Tok.KW_AS));
        new_kid.append(here.name);
    }
    new_kid.append(here.gen_token(Tok.LBRACE));
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_finally_stmt with uni.FinallyStmt entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_FINALLY),
        here.gen_token(Tok.LBRACE),

    ];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_iter_for_stmt with uni.IterForStmt entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_async {
        new_kid.append(here.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(here.gen_token(Tok.KW_FOR));
    new_kid.append(here.iter);
    new_kid.append(here.gen_token(Tok.KW_WHILE));
    new_kid.append(here.condition);
    new_kid.append(here.gen_token(Tok.KW_WITH));
    new_kid.append(here.count_by);
    new_kid.append(here.gen_token(Tok.LBRACE));
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    if here.else_body {
        new_kid.append(here.else_body);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_in_for_stmt with uni.InForStmt entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_comptime {
        new_kid.append(here.gen_token(Tok.KW_COMPTIME));
    }
    if here.is_async {
        new_kid.append(here.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(here.gen_token(Tok.KW_FOR));
    new_kid.append(here.target);
    new_kid.append(here.gen_token(Tok.KW_IN));
    new_kid.append(here.collection);
    new_kid.append(here.gen_token(Tok.LBRACE));
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    if here.else_body {
        new_kid.append(here.else_body);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_open_stmt with uni.OpenStmt entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_IN),
        here.target,
        here.gen_token(Tok.LBRACE),

    ];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_while_stmt with uni.WhileStmt entry {
    self._normalize_cond_block(here, Tok.KW_WHILE);
}

impl NormalizePass.enter_forever_stmt with uni.ForeverStmt entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_FOREVER),
        here.gen_token(Tok.LBRACE),

    ];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_with_stmt with uni.WithStmt entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_async {
        new_kid.append(here.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(here.gen_token(Tok.KW_WITH));
    for idx in range(len(here.exprs)) {
        new_kid.append(here.exprs[idx]);
        if idx < len(here.exprs) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(here.gen_token(Tok.LBRACE));
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_expr_as_item with uni.ExprAsItem entry {
    new_kid: list[uni.UniNode] = [here.expr];
    if here.alias {
        new_kid.append(here.gen_token(Tok.KW_AS));
        new_kid.append(here.alias);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_raise_stmt with uni.RaiseStmt entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_RAISE)];
    if here.cause {
        new_kid.append(here.cause);
    }
    if here.from_target {
        new_kid.append(here.gen_token(Tok.KW_FROM));
        new_kid.append(here.from_target);
    }
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_assert_stmt with uni.AssertStmt entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_comptime {
        new_kid.append(here.gen_token(Tok.KW_COMPTIME));
    }
    new_kid.extend([here.gen_token(Tok.KW_ASSERT), here.condition, ]);
    if here.error_msg {
        new_kid.append(here.gen_token(Tok.COMMA));
        new_kid.append(here.error_msg);
    }
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_ctrl_stmt with uni.CtrlStmt entry {
    new_kid: list[uni.UniNode] = [here.ctrl, here.gen_token(Tok.SEMI)];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_delete_stmt with uni.DeleteStmt entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_DELETE)];
    for i in range(len(here.targets)) {
        if i > 0 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
        new_kid.append(here.targets[i]);
    }
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_report_stmt with uni.ReportStmt entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_REPORT),
        here.expr,
        here.gen_token(Tok.SEMI),

    ];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_return_stmt with uni.ReturnStmt entry {
    if here.is_implicit and here.expr {
        here.set_kids(nodes=[here.expr]);
        return;
    }
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_RETURN), ];
    if here.expr {
        new_kid.append(here.expr);
    }
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_visit_stmt with uni.VisitStmt entry {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(here.gen_token(Tok.KW_VISIT));
    if here.insert_loc {
        new_kid.append(here.gen_token(Tok.COLON));
        new_kid.append(here.insert_loc);
        new_kid.append(here.gen_token(Tok.COLON));
    }
    new_kid.append(here.target);
    if here.else_body {
        new_kid.append(here.else_body);
    } else {
        new_kid.append(here.gen_token(Tok.SEMI));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_disengage_stmt with uni.DisengageStmt entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.KW_DISENGAGE),
        here.gen_token(Tok.SEMI),

    ];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_await_expr with uni.AwaitExpr entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_AWAIT), here.target, ];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_cast_expr with uni.CastExpr entry {
    new_kid: list[uni.UniNode] = [
        here.value,
        here.gen_token(Tok.KW_AS),
        here.cast_type
    ];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_assignment with uni.Assignment entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_comptime and not isinstance(here.parent, uni.GlobalVars) {
        new_kid.append(here.gen_token(Tok.KW_COMPTIME));
    }
    for idx in range(len(here.target)) {
        new_kid.append(here.target[idx]);
        if idx < len(here.target) - 1 {
            new_kid.append(here.gen_token(Tok.EQ));
        }
    }
    if here.type_tag {
        new_kid.append(here.type_tag);
    }
    if here.aug_op {
        new_kid.append(here.aug_op);
    }
    if here.value {
        if not here.aug_op {
            new_kid.append(here.gen_token(Tok.EQ));
        }
        new_kid.append(here.value);
    }
    if isinstance(here.parent, uni.GlobalVars) {
        if here.parent.assignments.index(here) == len(here.parent.assignments) - 1 {
            new_kid.append(here.gen_token(Tok.SEMI));
        }
    } elif (not here.is_enum_stmt)
        and not (
            isinstance(here.parent, uni.IterForStmt)
            and here in [here.parent.iter, here.parent.count_by]
        ) {
        new_kid.append(here.gen_token(Tok.SEMI));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_concurrent_expr with uni.ConcurrentExpr entry {
    new_kid: list[uni.UniNode] = [];
    if isinstance(here.tok, Token) and here.tok.value == "flow" {
        new_kid.append(here.gen_token(Tok.KW_FLOW));
    } elif isinstance(here.tok, Token) and here.tok.value == "wait" {
        new_kid.append(here.gen_token(Tok.KW_WAIT));
    }
    new_kid.append(here.target);
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_binary_expr with uni.BinaryExpr entry {
    new_kid: list[uni.UniNode] = [here.left, here.op, here.right];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_compare_expr with uni.CompareExpr entry {
    new_kid: list[uni.UniNode] = [here.left];
    for i in range(len(here.rights)) {
        new_kid.append(here.ops[i]);
        new_kid.append(here.rights[i]);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_cfg_expr with uni.CfgExpr entry {
    here.set_kids(nodes=[here.expr]);
}

impl NormalizePass.enter_bool_expr with uni.BoolExpr entry {
    new_kid: list[uni.UniNode] = [];
    for i in range(len(here.values)) {
        if i > 0 {
            new_kid.append(here.op);
        }
        new_kid.append(here.values[i]);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_lambda_expr with uni.LambdaExpr entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_LAMBDA)];
    if here.signature {
        new_kid.append(here.signature);
    }

    if isinstance(here.body, list) {
        new_kid.append(here.gen_token(Tok.LBRACE));
        new_kid.extend(here.body);
        new_kid.append(here.gen_token(Tok.RBRACE));
    } elif isinstance(here.body, uni.Expr) {
        new_kid += [here.gen_token(Tok.LBRACE), here.body, here.gen_token(Tok.RBRACE)];
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_unary_expr with uni.UnaryExpr entry {
    new_kid: list[uni.UniNode] = [here.op, here.operand];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_if_else_expr with uni.IfElseExpr entry {
    new_kid: list[uni.UniNode] = [
        here.value,
        here.gen_token(Tok.KW_IF),
        here.condition,
        here.gen_token(Tok.KW_ELSE),
        here.else_value,

    ];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_multi_string with uni.MultiString entry {
    new_kid: list[uni.UniNode] = [];
    for string in here.strings {
        new_kid.append(string);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_f_string with uni.FString entry {
    new_kid: list[uni.UniNode] = [];
    if here.start is not None {
        new_kid.append(here.start);
    }
    for part in here.parts {
        new_kid.append(part);
    }
    if here.end is not None {
        new_kid.append(here.end);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_formatted_value with uni.FormattedValue entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LBRACE)];
    new_kid.append(here.format_part);
    if here.conversion != -1 {
        new_kid.append(here.gen_token(Tok.CONV, value="!" + chr(here.conversion)));
    }
    if here.format_spec {
        new_kid.append(here.gen_token(Tok.COLON));
        new_kid.append(here.format_spec);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_list_val with uni.ListVal entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LSQUARE)];
    for idx in range(len(here.values)) {
        new_kid.append(here.values[idx]);
        if idx < len(here.values) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(here.gen_token(Tok.RSQUARE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_set_val with uni.SetVal entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LBRACE)];
    values = here.values if here.values is not None else [];
    for idx in range(len(values)) {
        new_kid.append(values[idx]);
        if idx < len(values) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_tuple_val with uni.TupleVal entry {
    index_slice_parent = (
        here.parent.parent
            if here.parent and isinstance(here.parent, uni.Slice)
            else here.parent
    );
    in_ret_type = (
        index_slice_parent
        and isinstance(index_slice_parent, uni.IndexSlice)
        and index_slice_parent
        and isinstance(index_slice_parent.parent, uni.AtomTrailer)
        and index_slice_parent.parent
        and isinstance(index_slice_parent.parent.parent, uni.FuncSignature)
    );
    new_kid: list[uni.UniNode] = [];
    if not in_ret_type {
        new_kid.append(here.gen_token(Tok.LPAREN));
    }
    for idx in range(len(here.values)) {
        new_kid.append(here.values[idx]);
        if idx < len(here.values) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    if len(here.values) == 1 {
        new_kid.append(here.gen_token(Tok.COMMA));
    }
    if not in_ret_type {
        new_kid.append(here.gen_token(Tok.RPAREN));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_dict_val with uni.DictVal entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LBRACE), ];
    for i in range(len(here.kv_pairs)) {
        new_kid.append(here.kv_pairs[i]);
        if i < len(here.kv_pairs) - 1 {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_k_v_pair with uni.KVPair entry {
    new_kid: list[uni.UniNode] = [];
    if here.key {
        new_kid.append(here.key);
        new_kid.append(here.gen_token(Tok.COLON));
    } else {
        new_kid.append(here.gen_token(Tok.STAR_POW));
    }
    new_kid.append(here.value);
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_k_w_pair with uni.KWPair entry {
    new_kid: list[uni.UniNode] = [];
    if here.key {
        new_kid.append(here.key);
        new_kid.append(here.gen_token(Tok.EQ));
    } else {
        new_kid.append(here.gen_token(Tok.STAR_POW));
    }
    new_kid.append(here.value);
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_inner_compr with uni.InnerCompr entry {
    new_kid: list[uni.UniNode] = [];
    if here.is_async {
        new_kid.append(here.gen_token(Tok.KW_ASYNC));
    }
    new_kid.append(here.gen_token(Tok.KW_FOR));
    new_kid.append(here.target);
    new_kid.append(here.gen_token(Tok.KW_IN));
    new_kid.append(here.collection);
    for cond in here.conditional or [] {
        new_kid.append(here.gen_token(Tok.KW_IF));
        new_kid.append(cond);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_list_compr with uni.ListCompr entry {
    if here.__class__ is not uni.ListCompr {
        return;
    }
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LSQUARE), here.out_expr, ];
    for comp in here.compr {
        new_kid.append(comp);
    }
    new_kid.append(here.gen_token(Tok.RSQUARE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_gen_compr with uni.GenCompr entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LPAREN), here.out_expr, ];
    for comp in here.compr {
        new_kid.append(comp);
    }
    new_kid.append(here.gen_token(Tok.RPAREN));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_set_compr with uni.SetCompr entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LBRACE), here.out_expr, ];
    for comp in here.compr {
        new_kid.append(comp);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_dict_compr with uni.DictCompr entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LBRACE), here.kv_pair, ];
    for comp in here.compr {
        new_kid.append(comp);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_atom_trailer with uni.AtomTrailer entry {
    new_kid: list[uni.UniNode] = [here.target];
    if here.is_null_ok {
        new_kid.append(here.gen_token(Tok.NULL_OK));
    }
    if here.is_attr {
        new_kid.append(here.gen_token(Tok.DOT));
    }
    if here.right {
        new_kid.append(here.right);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_atom_unit with uni.AtomUnit entry {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(here.gen_token(Tok.LPAREN));
    new_kid.append(here.value);
    new_kid.append(here.gen_token(Tok.RPAREN));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_graph_expr with uni.GraphExpr entry {
    kids: list[uni.UniNode] = [
        here.gen_token(Tok.NAME, "graph"),
        here.gen_token(Tok.LBRACE)
    ];
    for expr in here.exprs {
        kids.append(expr);
        kids.append(here.gen_token(Tok.SEMI));
    }
    kids.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=kids);
}

impl NormalizePass.enter_yield_expr with uni.YieldExpr entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_YIELD)];
    if here.with_from {
        new_kid.append(here.gen_token(Tok.KW_FROM));
    }
    if here.expr {
        new_kid.append(here.expr);
    }
    new_kid.append(here.gen_token(Tok.SEMI));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_func_call with uni.FuncCall entry {
    new_kids: list[uni.UniNode] = [here.target];
    params = here.params if here.params is not None else [];
    is_gencompr = len(params) == 1 and isinstance(params[0], uni.GenCompr);
    if not is_gencompr {
        new_kids.append(here.gen_token(Tok.LPAREN));
    }
    for i in range(len(params)) {
        new_kids.append(params[i]);
        if i < len(params) - 1 {
            new_kids.append(here.gen_token(Tok.COMMA));
        }
    }
    if here.genai_call {
        new_kids.append(here.gen_token(Tok.KW_BY));
        new_kids.append(here.genai_call);
    }
    if not is_gencompr {
        new_kids.append(here.gen_token(Tok.RPAREN, ")"));
    }
    here.set_kids(nodes=new_kids);
}

impl NormalizePass.enter_index_slice with uni.IndexSlice entry {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(here.gen_token(Tok.LSQUARE));
    if here.is_range {
        for i in range(len(here.slices)) {
            if i > 0 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
            sl = here.slices[i];
            sl_kid: list[uni.UniNode] = [];
            if sl.start {
                sl_kid.append(sl.start);
            }
            sl_kid.append(here.gen_token(Tok.COLON));
            if sl.stop {
                sl_kid.append(sl.stop);
            }
            if sl.step {
                sl_kid.append(here.gen_token(Tok.COLON));
                sl_kid.append(sl.step);
            }
            sl.set_kids(nodes=sl_kid);
            new_kid.append(sl);
        }
    } elif len(here.slices) == 1 {
        sl = here.slices[0];
        sl_kid = [sl.start] if sl.start else [];
        sl.set_kids(nodes=sl_kid);
        new_kid.append(sl);
    }
    new_kid.append(here.gen_token(Tok.RSQUARE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_slice with uni.Slice entry {}

impl NormalizePass.enter_edge_ref_trailer with uni.EdgeRefTrailer entry {
    new_kid: list[uni.UniNode] = [];
    new_kid.append(here.gen_token(Tok.LSQUARE));
    if here.is_async {
        new_kid.append(here.gen_token(Tok.KW_ASYNC));
    }
    if here.edges_only {
        new_kid.append(here.gen_token(Tok.KW_EDGE));
    }
    new_kid.extend(here.chain);
    new_kid.append(here.gen_token(Tok.RSQUARE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_edge_op_ref with uni.EdgeOpRef entry {
    new_kid: list[uni.UniNode] = [];
    if here.edge_dir == EdgeDir.IN {
        if not here.filter_cond {
            new_kid.append(here.gen_token(Tok.ARROW_L));
        } else {
            new_kid.append(here.gen_token(Tok.ARROW_L_P1));
            new_kid.append(here.filter_cond);
            new_kid.append(here.gen_token(Tok.ARROW_L_P2));
        }
    } elif here.edge_dir == EdgeDir.OUT {
        if not here.filter_cond {
            new_kid.append(here.gen_token(Tok.ARROW_R));
        } else {
            new_kid.append(here.gen_token(Tok.ARROW_R_P1));
            new_kid.append(here.filter_cond);
            new_kid.append(here.gen_token(Tok.ARROW_R_P2));
        }
    } else {
        if not here.filter_cond {
            new_kid.append(here.gen_token(Tok.ARROW_BI));
        } else {
            new_kid.append(here.gen_token(Tok.ARROW_L_P1));
            new_kid.append(here.filter_cond);
            new_kid.append(here.gen_token(Tok.ARROW_R_P2));
        }
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_disconnect_op with uni.DisconnectOp entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_DELETE), here.edge_spec];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_connect_op with uni.ConnectOp entry {
    new_kid: list[uni.UniNode] = [];
    if here.edge_dir == EdgeDir.IN {
        if not here.conn_assign and not here.conn_type {
            new_kid.append(here.gen_token(Tok.CARROW_L));
        } else {
            new_kid.append(here.gen_token(Tok.CARROW_L_P1));
            if here.conn_type {
                new_kid.append(here.conn_type);
            }
            if here.conn_assign {
                new_kid.append(here.gen_token(Tok.COLON));
                new_kid.append(here.conn_assign);
            }
            new_kid.append(here.gen_token(Tok.CARROW_L_P2));
        }
    } elif here.edge_dir == EdgeDir.OUT {
        if not here.conn_assign and not here.conn_type {
            new_kid.append(here.gen_token(Tok.CARROW_R));
        } else {
            new_kid.append(here.gen_token(Tok.CARROW_R_P1));
            if here.conn_type {
                new_kid.append(here.conn_type);
            }
            if here.conn_assign {
                new_kid.append(here.gen_token(Tok.COLON));
                new_kid.append(here.conn_assign);
            }
            new_kid.append(here.gen_token(Tok.CARROW_R_P2));
        }
    } else {
        if not here.conn_assign and not here.conn_type {
            new_kid.append(here.gen_token(Tok.CARROW_BI));
        } else {
            new_kid.append(here.gen_token(Tok.CARROW_L_P1));
            if here.conn_type {
                new_kid.append(here.conn_type);
            }
            if here.conn_assign {
                new_kid.append(here.gen_token(Tok.COLON));
                new_kid.append(here.conn_assign);
            }
            new_kid.append(here.gen_token(Tok.CARROW_R_P2));
        }
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_filter_compr with uni.FilterCompr entry {
    new_kid: list[uni.UniNode] = [];
    is_edge_inline = isinstance(here.parent, uni.EdgeOpRef);

    if not is_edge_inline {
        new_kid.append(here.gen_token(Tok.LSQUARE));
        new_kid.append(here.gen_token(Tok.NULL_OK));
    }
    if here.f_type {
        if not is_edge_inline {
            new_kid.append(here.gen_token(Tok.COLON));
        }
        new_kid.append(here.f_type);
    }
    if here.compares {
        if here.f_type {
            if is_edge_inline {
                new_kid.append(here.gen_token(Tok.COLON));
            } else {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
        for i in range(len(here.compares)) {
            new_kid.append(here.compares[i]);
            if i < len(here.compares) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
    }

    if not is_edge_inline {
        new_kid.append(here.gen_token(Tok.RSQUARE));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_assign_compr with uni.AssignCompr entry {
    new_kid: list[uni.UniNode] = [];
    if isinstance(here.parent, uni.ConnectOp) {
        for i in range(len(here.assigns)) {
            new_kid.append(here.assigns[i]);
            if i < len(here.assigns) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
    } else {
        new_kid.append(here.gen_token(Tok.LPAREN));
        new_kid.append(here.gen_token(Tok.EQ));
        for i in range(len(here.assigns)) {
            new_kid.append(here.assigns[i]);
            if i < len(here.assigns) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
        new_kid.append(here.gen_token(Tok.RPAREN));
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_jsx_attribute with uni.JsxAttribute entry {}

impl NormalizePass.enter_jsx_child with uni.JsxChild entry {}

impl NormalizePass.enter_jsx_element with uni.JsxElement entry {}

impl NormalizePass.enter_jsx_element_name with uni.JsxElementName entry {
    new_kid: list[uni.UniNode] = [];
    for i in range(len(here.parts)) {
        new_kid.append(here.parts[i]);
        if i < len(here.parts) - 1 {
            new_kid.append(here.gen_token(Tok.DOT));
        }
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_jsx_spread_attribute with uni.JsxSpreadAttribute entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.LBRACE),
        here.gen_token(Tok.ELLIPSIS),
        here.expr,
        here.gen_token(Tok.RBRACE),

    ];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_jsx_normal_attribute with uni.JsxNormalAttribute entry {
    if here.is_shorthand {
        here.set_kids(
            nodes=[here.gen_token(Tok.LBRACE), here.name, here.gen_token(Tok.RBRACE)]
        );
        return;
    }
    new_kid: list[uni.UniNode] = [here.name];
    if here.value {
        new_kid.append(here.gen_token(Tok.EQ));
        if isinstance(here.value, uni.String) {
            new_kid.append(here.value);
        } else {
            new_kid.extend(
                [here.gen_token(Tok.LBRACE), here.value, here.gen_token(Tok.RBRACE), ]
            );
        }
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_jsx_text with uni.JsxText entry {
    if isinstance(here.value, uni.Token) {
        here.set_kids(nodes=[here.value]);
    } else {
        here.set_kids(nodes=[here.gen_token(Tok.JSX_TEXT, value=str(here.value))]);
    }
}

impl NormalizePass.enter_jsx_expression with uni.JsxExpression entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.LBRACE),
        here.expr,
        here.gen_token(Tok.RBRACE),

    ];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_jsx_slot with uni.JsxSlot entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LBRACE)];
    for stmt in here.body {
        new_kid.append(stmt);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_jsx_comment with uni.JsxComment entry {
    here.set_kids(nodes=[here.value]);
}

impl NormalizePass.enter_match_stmt with uni.MatchStmt entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_MATCH), here.target, ];
    new_kid.append(here.gen_token(Tok.LBRACE));
    for `case in here.cases {
        new_kid.append(`case);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_case with uni.MatchCase entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_CASE), here.pattern];
    if here.guard {
        new_kid.append(here.gen_token(Tok.KW_IF));
        new_kid.append(here.guard);
    }
    new_kid.append(here.gen_token(Tok.COLON));
    if here.body {
        new_kid.extend([*here.body]);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_switch_stmt with uni.SwitchStmt entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_SWITCH), here.target, ];
    new_kid.append(here.gen_token(Tok.LBRACE));
    for `case in here.cases {
        new_kid.append(`case);
    }
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_switch_case with uni.SwitchCase entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.KW_CASE)];
    if here.pattern is not None {
        new_kid.append(here.pattern);
    } else {
        new_kid.pop();
        new_kid.append(here.gen_token(Tok.KW_DEFAULT));
    }
    new_kid.append(here.gen_token(Tok.COLON));
    if here.body {
        new_kid.extend([*here.body]);
    }
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_or with uni.MatchOr entry {
    new_kid: list[uni.UniNode] = [];
    for pattern in here.patterns {
        new_kid.append(pattern);
        new_kid.append(here.gen_token(Tok.KW_OR));
    }
    new_kid.pop();
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_as with uni.MatchAs entry {
    new_kid: list[uni.UniNode] = [];
    if here.pattern {
        new_kid.append(here.pattern);
        new_kid.append(here.gen_token(Tok.KW_AS));
    }
    new_kid.append(here.name);
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_wild with uni.MatchWild entry {
    here.set_kids(
        nodes=[
            uni.Name(
                orig_src=here.loc.orig_src,
                name=Tok.NAME,
                value="_",
                col_start=here.loc.col_start,
                col_end=here.loc.col_end,
                line=here.loc.first_line,
                end_line=here.loc.last_line,
                pos_start=here.loc.pos_start,
                pos_end=here.loc.pos_end,
            )
        ],
    );
}

impl NormalizePass.enter_match_value with uni.MatchValue entry {
    here.set_kids(nodes=[here.value]);
}

impl NormalizePass.enter_match_singleton with uni.MatchSingleton entry {
    here.set_kids(nodes=[here.value]);
}

impl NormalizePass.enter_match_sequence with uni.MatchSequence entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LSQUARE)];
    for value in here.values {
        new_kid.append(value);
        new_kid.append(here.gen_token(Tok.COMMA));
    }
    new_kid.pop();
    new_kid.append(here.gen_token(Tok.RSQUARE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_mapping with uni.MatchMapping entry {
    new_kid: list[uni.UniNode] = [here.gen_token(Tok.LBRACE)];
    for value in here.values {
        new_kid.append(value);
        new_kid.append(here.gen_token(Tok.COMMA));
    }
    new_kid.pop();
    new_kid.append(here.gen_token(Tok.RBRACE));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_k_v_pair with uni.MatchKVPair entry {
    op = Tok.EQ if isinstance(here.key, uni.Name) else Tok.COLON;
    new_kid: list[uni.UniNode] = [here.key, here.gen_token(op), here.value];
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_star with uni.MatchStar entry {
    new_kid: list[uni.UniNode] = [
        here.gen_token(Tok.STAR_MUL if here.is_list else Tok.STAR_POW)
    ];
    new_kid.append(here.name);
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_match_arch with uni.MatchArch entry {
    new_kid: list[uni.UniNode] = [here.name];
    new_kid.append(here.gen_token(Tok.LPAREN));
    if here.arg_patterns {
        for idx in range(len(here.arg_patterns)) {
            new_kid.append(here.arg_patterns[idx]);
            if idx < len(here.arg_patterns) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
        if here.kw_patterns {
            new_kid.append(here.gen_token(Tok.COMMA));
        }
    }
    if here.kw_patterns {
        for idx in range(len(here.kw_patterns)) {
            new_kid.append(here.kw_patterns[idx]);
            if idx < len(here.kw_patterns) - 1 {
                new_kid.append(here.gen_token(Tok.COMMA));
            }
        }
    }
    new_kid.append(here.gen_token(Tok.RPAREN));
    here.set_kids(nodes=new_kid);
}

impl NormalizePass.enter_token with uni.Token entry {}

impl NormalizePass.enter_string with uni.String entry {
    here.value = f"{here.value}";
}
