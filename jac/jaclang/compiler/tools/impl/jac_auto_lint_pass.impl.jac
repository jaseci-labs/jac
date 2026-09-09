import from jaclang.compiler.tools.unparse_pass { unparse_node }

impl JacAutoLintPass.postinit -> None {
    import from jaclang.compiler.driver.pass_driver { diagnostic_policy_for }
    import from jaclang.project.config {
        JacConfig,
        get_config_for_path,
        get_explicit_config
    }
    import from pathlib { Path }

    mod_path = self.ir_in.loc.mod_path if self.ir_in?.loc else None;
    config = (
        get_config_for_path(Path(mod_path)) if mod_path else get_explicit_config()
    )
        or JacConfig();
    if mod_path {
        _app = config.app_for_path(str(Path(mod_path).resolve()));
        if _app is not None and not _app.implicit and _app.name in config.apps {
            config = config.effective_for_app(_app.name);
        }
    }
    _opts = self.prog.options;
    _extra: list[str] = (
        list(_opts.suppress_codes)
            if (_opts is not None and _opts.suppress_codes)
            else []
    );
    self.policy = diagnostic_policy_for(config, _extra);
    if config.check?.lint {
        self._exclude_patterns = config.check.lint.exclude;
        self._project_root = str(config.project_root) if config.project_root else "";
    }
    super.postinit();
}

impl JacAutoLintPass._is_file_excluded(file_path: str) -> bool {
    import from jaclang.compiler.frontend.helpers { path_matches_exclude }
    return path_matches_exclude(file_path, self._exclude_patterns, self._project_root);
}

impl JacAutoLintPass.exit_ability with uni.Ability exit {
    if not self.lint_enabled {
        return;
    }

    if not self.report_only and self._pending_setters {
        self._pending_setters.pop();
    }
    if not self._is_suppressed(W3005) {
        sig = here.signature;
        if isinstance(sig, uni.FuncSignature) {
            self._remove_empty_parens_from_sig(here, sig, "signature");
        }
    }
    if here.body is not None and isinstance(here.body, list) {
        self._check_unnecessary_pass(list(here.body));
    }
    name = here.name_spec.sym_name if here.name_spec else "<anonymous>";
    self._check_unnecessary_none_return(here, here.body, here.signature, name);
    self._check_stale_has_read(here);
}

impl JacAutoLintPass._remove_staticmethod_from_kids(ability_node: uni.Ability) -> None {
    new_kids: list[uni.UniNode] = [];
    i = 0;
    kids = ability_node.kid;
    skip_next_ws = False;
    has_static_kw = False;
    staticmethod_loc: (uni.Name | None) = None;
    for kid in kids {
        if isinstance(kid, uni.Token) and kid.name == Tok.KW_STATIC {
            has_static_kw = True;
        }

        if isinstance(kid, uni.Name) and kid.value == "staticmethod" {
            staticmethod_loc = kid;
        }
    }
    while i < len(kids) {
        kid = kids[i];

        if (isinstance(kid, uni.Token) and kid.value == "@" and (i + 1) < len(kids)) {
            next_kid = kids[i + 1];
            if isinstance(next_kid, uni.Name) and next_kid.value == "staticmethod" {
                i += 2;
                skip_next_ws = True;
                continue;
            }
        }

        if skip_next_ws and isinstance(kid, uni.Token) {
            if kid.name in ("WS", "NL", "NEWLINE") or kid.value in ("\n", " ", "") {
                i += 1;
                skip_next_ws = False;
                continue;
            }
        }
        skip_next_ws = False;

        if (
            not has_static_kw
            and isinstance(kid, uni.Token)
            and kid.name in (Tok.KW_DEF, Tok.KW_CAN)
        ) {
            static_kw = ability_node.gen_token(Tok.KW_STATIC);
            if staticmethod_loc {
                static_kw.line_no = staticmethod_loc.loc.first_line;
                static_kw.c_start = staticmethod_loc.loc.col_start;
                static_kw.c_end = static_kw.c_start + len("static");
            }
            new_kids.append(static_kw);
            has_static_kw = True;
        }
        new_kids.append(kid);
        i += 1;
    }
    ability_node.set_kids(new_kids);
}

impl JacAutoLintPass.enter_ability with uni.Ability entry {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if here.decorators {
        has_staticmethod = False;
        for dec in here.decorators {
            if isinstance(dec, uni.Name) and dec.value == "staticmethod" {
                has_staticmethod = True;
                break;
            }
        }
        if has_staticmethod and self.emit(W3001, node_override=here) {
            if not here.is_static {
                here.is_static = True;
            }
            new_decorators: list[uni.Expr] = [
                dec
                for dec in here.decorators
                if not (isinstance(dec, uni.Name) and dec.value == "staticmethod")
            ];
            here._role_set(DecoratorsRole, new_decorators or None);
        }
    }
    if not self._is_suppressed(W3001) and here.is_static {
        self._remove_staticmethod_from_kids(here);
    }

    if not self._is_suppressed(W3038) {
        self._convert_usestate_vars(here);
    }
    self._combine_has_in_node(here);
    if not here.is_method {
        return;
    }
    if not isinstance(here.name_ref, uni.Name)
        or isinstance(here.name_ref, uni.SpecialVarRef) {
        return;
    }
    new_tok_name: (str | None) = None;
    if here.name_ref.value == "__init__" {
        new_tok_name = Tok.KW_INIT.value;
    } elif here.name_ref.value == "__post_init__" {
        new_tok_name = Tok.KW_POST_INIT.value;
    }
    if new_tok_name is not None {
        init_name = here.name_ref.value;
        if not self.emit(W3004, node_override=here, name=init_name) {
            return;
        }
        old_ref = here.name_ref;
        old_ref.name = new_tok_name;
        old_ref.value = new_tok_name;
        special_ref = uni.SpecialVarRef(var=old_ref);
        here._role_set(NameRefRole, special_ref);
        here.name_spec = special_ref;
        for (idx, kid) in enumerate(here.kid) {
            if kid is old_ref {
                here.replace_kid(here.kid[idx], special_ref);
                break;
            }
        }
    }
}

impl JacAutoLintPass.enter_impl_def with uni.ImplDef entry {
    if not self.lint_enabled {
        return;
    }
    impl_node = here;

    if not self._is_suppressed(W3043) {
        self._convert_property_impl(impl_node);
    }
    if self.report_only {
        return;
    }
    if not self._is_suppressed(W3010) {
        self._fix_impl_signature_mismatch(impl_node);
    }
    if impl_node.body is not None and isinstance(impl_node.body, list) {
        new_body = self.combine_consecutive_has(list(impl_node.body));
        if len(new_body) != len(impl_node.body)
            and self.emit(W3002, node_override=impl_node) {
            impl_node._role_set(BodyRole, new_body);
            self.recalculate_parents(impl_node);
        }
    }
}

impl JacAutoLintPass.exit_impl_def with uni.ImplDef exit {
    if not self.lint_enabled or self._is_suppressed(W3005) {
        return;
    }
    spec = here.spec;
    if not isinstance(spec, uni.FuncSignature) {
        return;
    }
    self._remove_empty_parens_from_sig(here, spec, "spec");
}

impl JacAutoLintPass.enter_enum with uni.Enum entry {
    if not self.lint_enabled or self.report_only {
        return;
    }
    enum_node = here;
    self._combine_has_in_node(enum_node);
}

impl JacAutoLintPass.enter_archetype with uni.Archetype entry {
    if not self.lint_enabled {
        return;
    }
    arch = here;

    if not self._is_suppressed(W3043)
        and arch.body is not None
        and isinstance(arch.body, list) {
        self._convert_properties(arch);
    }
    if self.report_only {
        return;
    }
    self._combine_has_in_node(arch);
}

impl JacAutoLintPass.combine_consecutive_glob(body: list) -> list {
    if len(body) <= 1 {
        return body;
    }
    new_body: list[uni.UniNode] = [];
    i = 0;
    while i < len(body) {
        stmt = body[i];

        if isinstance(stmt, uni.GlobalVars) {
            base_glob = stmt;
            merged_globs: list[uni.GlobalVars] = [base_glob];
            j = i + 1;
            while j < len(body) {
                next_stmt = body[j];

                if isinstance(next_stmt, uni.GlobalVars)
                    and self.can_combine_glob(base_glob, next_stmt) {
                    merged_globs.append(next_stmt);
                    j += 1;
                } else {
                    break;
                }
            }
            all_single = all(len(g.assignments) == 1 for g in merged_globs);
            if len(merged_globs) > 1
                and all_single
                and self.emit(W3003, node_override=base_glob) {
                combined_assignments: list[uni.Assignment] = [];
                for `glob in merged_globs {
                    combined_assignments.extend(`glob.assignments);
                }
                new_kid: list[uni.UniNode] = [];
                for kid in base_glob.kid {
                    if kid in base_glob.assignments {
                        break;
                    }
                    new_kid.append(kid);
                }
                for (idx, assign) in enumerate(combined_assignments) {
                    if idx > 0 {
                        new_kid.append(base_glob.gen_token(Tok.COMMA));
                    }

                    if assign.kid and isinstance(assign.kid[-1], uni.Semi) {
                        assign_kids = list(assign.kid[:-1]);
                        assign.set_kids(nodes=assign_kids);
                    }
                    new_kid.append(assign);
                }
                new_kid.append(base_glob.gen_token(Tok.SEMI));
                base_glob._role_set(AssignmentsRole, combined_assignments);
                base_glob.set_kids(nodes=new_kid);
                new_body.append(base_glob);
            } else {
                for g in merged_globs {
                    new_body.append(g);
                }
            }
            i = j;
        } else {
            new_body.append(stmt);
            i += 1;
        }
    }
    return new_body;
}

impl JacAutoLintPass.combine_consecutive_has(body: list) -> list {
    if len(body) <= 1 {
        return body;
    }
    new_body: list[uni.UniNode] = [];
    i = 0;
    while i < len(body) {
        stmt = body[i];

        if isinstance(stmt, uni.ArchHas) {
            base_has = stmt;
            merged_has_list: list[uni.ArchHas] = [base_has];
            j = i + 1;
            while j < len(body) {
                next_stmt = body[j];

                if isinstance(next_stmt, uni.ArchHas)
                    and self.can_combine_has(base_has, next_stmt) {
                    merged_has_list.append(next_stmt);
                    j += 1;
                } else {
                    break;
                }
            }
            if len(merged_has_list) > 1 {
                combined_vars: list[uni.HasVar] = [];
                for has_stmt in merged_has_list {
                    combined_vars.extend(has_stmt.vars);
                }
                new_kid: list[uni.UniNode] = [];
                for kid in base_has.kid {
                    if kid in base_has.vars {
                        break;
                    }
                    new_kid.append(kid);
                }
                for (idx, var) in enumerate(combined_vars) {
                    if idx > 0 {
                        new_kid.append(base_has.gen_token(Tok.COMMA));
                    }
                    new_kid.append(var);
                }
                new_kid.append(base_has.gen_token(Tok.SEMI));
                base_has._role_set(VarsRole, combined_vars);
                base_has.set_kids(nodes=new_kid);
                new_body.append(base_has);
            } else {
                new_body.append(stmt);
            }
            i = j;
        } else {
            new_body.append(stmt);
            i += 1;
        }
    }
    return new_body;
}

impl JacAutoLintPass._combine_has_in_node(
    nd: uni.Archetype | uni.Enum | uni.Ability
) -> None {
    if nd.body is not None and isinstance(nd.body, list) {
        old_body = list(nd.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body) and self.emit(W3002, node_override=nd) {
            nd._role_set(BodyRole, new_body);
            self.recalculate_parents(nd);
            new_body_set = set(id(s) for s in new_body);
            new_kid: list[uni.UniNode] = [];
            for kid in nd.kid {
                if not isinstance(kid, uni.ArchHas) or id(kid) in new_body_set {
                    new_kid.append(kid);
                }
            }
            nd.set_kids(new_kid);
            nd._invalidate_sub_node_tab();
        }
    }
}

impl JacAutoLintPass.can_combine_glob(
    glob1: uni.GlobalVars, glob2: uni.GlobalVars
) -> bool {
    if glob1.doc or glob2.doc {
        return False;
    }
    if glob1.is_frozen != glob2.is_frozen {
        return False;
    }
    access1 = glob1.access.tag.name if glob1.access else None;
    access2 = glob2.access.tag.name if glob2.access else None;
    if access1 != access2 {
        return False;
    }
    return True;
}

impl JacAutoLintPass.can_combine_has(has1: uni.ArchHas, has2: uni.ArchHas) -> bool {
    for hv in list(has1.vars) + list(has2.vars) {
        if hv.accessors is not None {
            return False;
        }
    }
    if has1.is_static != has2.is_static {
        return False;
    }
    if has1.is_frozen != has2.is_frozen {
        return False;
    }
    access1 = has1.access.tag.name if has1.access else None;
    access2 = has2.access.tag.name if has2.access else None;
    if access1 != access2 {
        return False;
    }
    return True;
}

impl JacAutoLintPass.create_entry_block(stmts: list) -> uni.ModuleCode {
    entry_block = uni.ModuleCode(name=None, body=stmts, kid=stmts, doc=None);
    new_kid: list[uni.UniNode] = [];
    new_kid.append(entry_block.gen_token(Tok.KW_WITH));
    new_kid.append(entry_block.gen_token(Tok.KW_ENTRY));
    new_kid.append(entry_block.gen_token(Tok.LBRACE));
    for stmt in stmts {
        new_kid.append(stmt);
    }
    new_kid.append(entry_block.gen_token(Tok.RBRACE));
    entry_block.set_kids(nodes=new_kid);
    return entry_block;
}

impl JacAutoLintPass.create_glob_from_assignment(
    assignment: uni.Assignment
) -> uni.GlobalVars {
    glob_node = uni.GlobalVars(
        access=None,
        assignments=[assignment],
        is_frozen=False,
        kid=[assignment],
        doc=None
    );
    new_kid: list[uni.UniNode] = [];
    new_kid.append(glob_node.gen_token(Tok.KW_GLOBAL));
    new_kid.append(assignment);
    glob_node.set_kids(nodes=new_kid);
    return glob_node;
}

impl JacAutoLintPass.is_module_level_construct(stmt: uni.UniNode) -> bool {
    return isinstance(
        stmt,
        (
            uni.Import,
            uni.Archetype,
            uni.Ability,
            uni.Enum,
            uni.GlobalVars,
            uni.Test,
            uni.PyInlineCode
        )
    );
}

impl JacAutoLintPass.can_convert_to_glob(assignment: uni.Assignment) -> bool {
    if assignment.value is None {
        return False;
    }
    if assignment.aug_op is not None {
        return False;
    }
    for target in assignment.target {
        if not isinstance(target, uni.Name) {
            return False;
        }
    }
    if isinstance(assignment.value, uni.FuncCall)
        or len(assignment.value.get_all_sub_nodes(uni.FuncCall)) > 0 {
        return False;
    }
    return True;
}

impl JacAutoLintPass.names_unsafe_to_globalize(module: uni.Module) -> set[str] {
    counts: dict[str, int] = {};
    for stmt in module.body {
        target_lists: list = [];
        if isinstance(stmt, uni.GlobalVars) {
            for assign in stmt.assignments {
                target_lists.append(assign.target);
            }
        } elif isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            for inner_stmt in stmt.body {
                for assign in inner_stmt.get_all_sub_nodes(uni.Assignment) {
                    target_lists.append(assign.target);
                }
                if isinstance(inner_stmt, uni.Assignment) {
                    target_lists.append(inner_stmt.target);
                }
            }
        }
        for targets in target_lists {
            for target in targets {
                if isinstance(target, uni.Name) {
                    counts[target.value] = counts.get(target.value, 0) + 1;
                }
            }
        }
    }
    return {
        name
        for (name, count) in counts.items()
        if count > 1
    };
}

impl JacAutoLintPass.entry_written_names(module: uni.Module) -> set[str] {
    written: set[str] = set();
    for stmt in module.body {
        if isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            for assign in stmt.get_all_sub_nodes(uni.Assignment) {
                for target in assign.target {
                    if isinstance(target, uni.Name) {
                        written.add(target.value);
                    }
                }
            }
        }
    }
    return written;
}

impl JacAutoLintPass.enter_module with uni.Module entry {
    if not self.lint_enabled or self.report_only {
        return;
    }
    module = here;
    if self.main_module is None {
        self.main_module = module;
    }
    unsafe_globalize = self.names_unsafe_to_globalize(module);
    entry_written = self.entry_written_names(module);
    new_body: list[(uni.ElementStmt | uni.String | uni.EmptyToken)] = [];
    for stmt in module.body {
        if self._is_future_annotations_import(stmt)
            and self.emit(W3009, node_override=stmt) {
            continue;
        }

        if isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            pending_entry_stmts: list[uni.UniNode] = [];
            for inner_stmt in stmt.body {
                extracted_stmt: (uni.ElementStmt | None) = None;
                assign_value: (uni.Expr | uni.YieldExpr | None) = (
                    inner_stmt.value if isinstance(inner_stmt, uni.Assignment) else None
                );
                if isinstance(inner_stmt, uni.Assignment)
                    and (assign_value is not None)
                    and self.can_convert_to_glob(inner_stmt)
                    and not any(
                        isinstance(target, uni.Name)
                            and (target.value in unsafe_globalize)
                        for target in inner_stmt.target
                    )
                    and not (
                        isinstance(assign_value, uni.Name)
                        and (assign_value.value in entry_written)
                    )
                    and not any(
                        nm.value in entry_written
                        for nm in assign_value.get_all_sub_nodes(uni.Name)
                    ) {
                    extracted_stmt = self.create_glob_from_assignment(inner_stmt);
                } elif isinstance(inner_stmt, uni.ElementStmt)
                    and self.is_module_level_construct(inner_stmt) {
                    extracted_stmt = inner_stmt;
                }

                if extracted_stmt is not None {
                    if pending_entry_stmts {
                        new_body.append(self.create_entry_block(pending_entry_stmts));
                        pending_entry_stmts = [];
                    }
                    new_body.append(extracted_stmt);
                } elif not isinstance(inner_stmt, uni.Semi) {
                    pending_entry_stmts.append(inner_stmt);
                }
            }
            if pending_entry_stmts {
                new_body.append(self.create_entry_block(pending_entry_stmts));
            }
        } else {
            new_body.append(stmt);
        }
    }
    if not self._is_suppressed(W3003) {
        new_body = self.combine_consecutive_glob(new_body);
    }
    module._role_set(BodyRole, new_body);
    self.recalculate_parents(module);
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(new_body);
    module.set_kids(nodes=new_kid if len(new_kid) else [uni.EmptyToken()]);
}

impl JacAutoLintPass.enter_special_var_ref with uni.SpecialVarRef entry {
    if not self.lint_enabled {
        return;
    }
    if self.report_only {
        return;
    }
    if here.is_kwesc {
        here.is_kwesc = False;
    }
}

impl JacAutoLintPass._convert_hasattr_to_null_ok(
    nd: uni.FuncCall
) -> (uni.AtomTrailer | None) {
    if not isinstance(nd.target, uni.Name) {
        return None;
    }
    if nd.target.value != "hasattr" {
        return None;
    }
    if nd.params is None or len(nd.params) != 2 {
        return None;
    }
    return self._funccall_to_null_safe(nd, False);
}

impl JacAutoLintPass._is_matching_attr_access(
    trailer: uni.AtomTrailer, obj_expr: uni.Expr, attr_name: str
) -> bool {
    if not trailer.is_attr {
        return False;
    }
    if not isinstance(trailer.right, uni.Name) {
        return False;
    }
    if trailer.right.value != attr_name {
        return False;
    }
    return self._exprs_are_identical(obj_expr, trailer.target);
}

impl JacAutoLintPass._make_null_ok(trailer: uni.AtomTrailer) -> None {
    if not trailer.is_null_ok {
        trailer.is_null_ok = True;
        new_kid: list[uni.UniNode] = [];
        inserted_null_ok = False;
        for kid in trailer.kid {
            new_kid.append(kid);

            if kid is trailer.target and not inserted_null_ok {
                new_kid.append(trailer.gen_token(Tok.NULL_OK));
                inserted_null_ok = True;
            }
        }
        trailer.set_kids(nodes=new_kid);
    }
}

impl JacAutoLintPass._bool_expr_has_matching_access(
    parent: uni.BoolExpr, hasattr_node: uni.FuncCall, obj_expr: uni.Expr, attr_name: str
) -> bool {
    for val in parent.values {
        if val is hasattr_node {
            continue;
        }
        trailers: list[uni.AtomTrailer] = [];
        self._collect_atom_trailers(val, trailers);
        for trailer in trailers {
            if self._is_matching_attr_access(trailer, obj_expr, attr_name) {
                return True;
            }
        }
    }
    return False;
}

impl JacAutoLintPass._convert_getattr_to_null_ok(
    nd: uni.FuncCall
) -> (uni.AtomTrailer | None) {
    if not isinstance(nd.target, uni.Name) {
        return None;
    }
    if nd.target.value != "getattr" {
        return None;
    }
    if nd.params is None or len(nd.params) != 3 {
        return None;
    }
    obj_expr = nd.params[0];
    attr_expr = nd.params[1];
    default_expr = nd.params[2];
    if isinstance(obj_expr, uni.KWPair)
        or isinstance(attr_expr, uni.KWPair)
        or isinstance(default_expr, uni.KWPair) {
        return None;
    }
    if not isinstance(default_expr, uni.Null) {
        return None;
    }
    return self._funccall_to_null_safe(nd, True);
}

impl JacAutoLintPass._funccall_to_null_safe(
    fc: uni.FuncCall, require_valid_identifier: bool
) -> (uni.AtomTrailer | None) {
    obj_expr = fc.params[0];
    attr_expr = fc.params[1];
    if isinstance(obj_expr, uni.KWPair) {
        return None;
    }
    attr_value: str | None = None;
    string_node: uni.String | None = None;
    if isinstance(attr_expr, uni.String) {
        attr_value = attr_expr.value;
        string_node = attr_expr;
    } elif isinstance(attr_expr, uni.MultiString) {
        if len(attr_expr.strings) == 1
            and isinstance(attr_expr.strings[0], uni.String) {
            attr_value = attr_expr.strings[0].value;
            string_node = attr_expr.strings[0];
        }
    }
    if attr_value is None or string_node is None {
        return None;
    }
    if (attr_value.startswith('"') and attr_value.endswith('"'))
        or (attr_value.startswith("'") and attr_value.endswith("'")) {
        attr_name = attr_value[1:-1];
    } else {
        return None;
    }
    if require_valid_identifier
        and (not attr_name.isidentifier() or keyword.iskeyword(attr_name)) {
        return None;
    }
    attr_name_node = uni.Name(
        orig_src=string_node.loc.orig_src,
        name=Tok.NAME.name,
        value=attr_name,
        line=string_node.loc.first_line,
        end_line=string_node.loc.last_line,
        col_start=string_node.loc.col_start,
        col_end=string_node.loc.col_end,
        pos_start=string_node.loc.pos_start,
        pos_end=string_node.loc.pos_end,
        is_kwesc=False
    );
    null_ok_access = uni.AtomTrailer(
        target=obj_expr,
        right=attr_name_node,
        is_attr=True,
        is_null_ok=True,
        kid=[obj_expr, attr_name_node]
    );
    new_kid: list[uni.UniNode] = [obj_expr];
    new_kid.append(null_ok_access.gen_token(Tok.NULL_OK));
    new_kid.append(null_ok_access.gen_token(Tok.DOT));
    new_kid.append(attr_name_node);
    null_ok_access.set_kids(nodes=new_kid);
    return null_ok_access;
}

impl JacAutoLintPass._replace_child_in_parent(
    parent: uni.UniNode, old: uni.UniNode, new: uni.UniNode
) -> None {
    parent.replace_kid(old, new);
}

impl JacAutoLintPass.exit_func_call with uni.FuncCall exit {
    if not self.lint_enabled {
        return;
    }
    self._check_no_print(here);

    if not self._is_suppressed(W3007) {
        replacement = self._convert_hasattr_to_null_ok(here);
        if replacement is not None {
            if here.params is None {
                return;
            }
            obj_expr = here.params[0];
            attr_expr = here.params[1];
            if isinstance(obj_expr, uni.KWPair) or isinstance(attr_expr, uni.KWPair) {
                return;
            }
            attr_name = self._extract_string_literal_value(attr_expr);

            cfg_wrapper: uni.CfgExpr | None = None;
            parent = here.parent;
            if isinstance(parent, uni.CfgExpr) {
                cfg_wrapper = parent;
                parent = parent.parent;
            }
            if parent is None {
                return;
            }

            if isinstance(parent, uni.IfElseExpr) {} elif isinstance(
                parent, uni.BoolExpr
            ) {
                if attr_name is None
                    or not self._bool_expr_has_matching_access(
                        parent, here, obj_expr, attr_name
                    ) {
                    return;
                }
            } else {
                return;
            }
            if not self.emit(W3007, node_override=here) {
                return;
            }
            if self.report_only {
                return;
            }
            if cfg_wrapper is not None {
                replacement.set_parent(cfg_wrapper);
                cfg_wrapper._role_set(ExprRole, replacement);
                cfg_wrapper.set_kids([replacement]);
                cfg_wrapper._invalidate_sub_node_tab();
                if isinstance(parent, uni.IfElseExpr)
                    and parent.condition is cfg_wrapper
                    and attr_name is not None
                    and isinstance(parent.value.expr, uni.AtomTrailer)
                    and self._is_matching_attr_access(
                        parent.value.expr, obj_expr, attr_name
                    ) {
                    self._make_null_ok(parent.value.expr);
                }
                return;
            }
            replacement.set_parent(parent);
            if isinstance(parent, uni.IfElseExpr) {
                repl_cfg = uni.CfgExpr(expr=replacement, kid=[replacement]);
                if parent.condition is here {
                    parent._role_set(ConditionRole, repl_cfg);
                    if attr_name is not None
                        and isinstance(parent.value, uni.AtomTrailer) {
                        if self._is_matching_attr_access(
                            parent.value, obj_expr, attr_name
                        ) {
                            self._make_null_ok(parent.value);
                        }
                    }
                } elif parent.value is here {
                    parent._role_set(ValueRole, repl_cfg);
                } elif parent.else_value is here {
                    parent._role_set(ElseValueRole, repl_cfg);
                }
            } elif isinstance(parent, uni.BoolExpr) {
                new_values: list[uni.CfgExpr] = [];
                for val in parent.values {
                    if val is here {
                        new_values.append(
                            uni.CfgExpr(expr=replacement, kid=[replacement])
                        );
                    } else {
                        new_values.append(val);
                    }
                }
                parent._role_set(ValuesRole, new_values);
            }
            new_kids: list[uni.UniNode] = [];
            for kid in parent.kid {
                if kid is here {
                    new_kids.append(replacement);
                } else {
                    new_kids.append(kid);
                }
            }
            parent.set_kids(new_kids);
            parent._invalidate_sub_node_tab();
            return;
        }
    }

    if self._convert_map_to_comprehension(here) {
        return;
    }
    if not self._is_suppressed(W3039) {
        getattr_replacement = self._convert_getattr_to_null_ok(here);
        if getattr_replacement is not None {
            parent = here.parent;
            if parent is not None and self.emit(W3039, node_override=here) {
                if self.report_only {
                    return;
                }
                getattr_replacement.set_parent(parent);
                self._replace_child_in_parent(parent, here, getattr_replacement);
                return;
            }
        }
    }
}

impl JacAutoLintPass._collect_atom_trailers(
    uni_node: uni.UniNode, results: list
) -> None {
    if isinstance(uni_node, uni.AtomTrailer) {
        results.append(uni_node);
    }
    if uni_node?.kid {
        for kid in uni_node.kid {
            if kid is not None {
                self._collect_atom_trailers(kid, results);
            }
        }
    }
}

impl JacAutoLintPass._expr_to_key(expr: uni.Expr) -> (str | None) {
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.AtomTrailer) {
        if expr.is_attr and isinstance(expr.right, uni.Name) {
            target_key = self._expr_to_key(expr.target);
            if target_key is not None {
                null_ok = "?" if expr.is_null_ok else "";
                return f"{target_key}{null_ok}.{expr.right.value}";
            }
        }
        return None;
    }
    if isinstance(expr, uni.SpecialVarRef) {
        return expr.value;
    }

    if isinstance(expr, (uni.Int, uni.Float, uni.String, uni.Bool, uni.Null)) {
        return str(expr.value);
    }

    if isinstance(expr, uni.CompareExpr) {
        left_key = self._expr_to_key(expr.left);
        if left_key is None {
            return None;
        }
        parts = [left_key];
        for (i, op) in enumerate(expr.ops) {
            right_key = self._expr_to_key(expr.rights[i])
                if i < len(expr.rights)
                else None;
            if right_key is None {
                return None;
            }
            parts.append(op.value);
            parts.append(right_key);
        }
        return " ".join(parts);
    }

    if isinstance(expr, uni.BinaryExpr) and expr.op is not None {
        left_key = self._expr_to_key(expr.left);
        right_key = self._expr_to_key(expr.right);
        if left_key is not None and right_key is not None {
            op_val = expr.op.value if isinstance(expr.op, uni.Token) else str(expr.op);
            return f"{left_key} {op_val} {right_key}";
        }
    }

    if isinstance(expr, uni.UnaryExpr) and expr.op is not None {
        operand_key = self._expr_to_key(expr.operand);
        if operand_key is not None {
            op_val = expr.op.value if isinstance(expr.op, uni.Token) else str(expr.op);
            return f"{op_val} {operand_key}";
        }
    }
    return None;
}

impl JacAutoLintPass._exprs_are_identical(expr1: uni.Expr, expr2: uni.Expr) -> bool {
    if expr1 is expr2 {
        return True;
    }
    if type(expr1) != type(expr2) {
        return False;
    }
    if isinstance(expr1, uni.AtomTrailer) and isinstance(expr2, uni.AtomTrailer) {
        if expr1.is_attr != expr2.is_attr {
            return False;
        }
        if expr1.is_null_ok != expr2.is_null_ok {
            return False;
        }
        if not self._exprs_are_identical(expr1.target, expr2.target) {
            return False;
        }
        if isinstance(expr1.right, uni.Name) and isinstance(expr2.right, uni.Name) {
            return expr1.right.value == expr2.right.value;
        }
        return self._exprs_are_identical(expr1.right, expr2.right);
    }
    key1 = self._expr_to_key(expr1);
    key2 = self._expr_to_key(expr2);
    if key1 is not None and key2 is not None {
        return key1 == key2;
    }
    return False;
}

impl JacAutoLintPass._convert_ternary_to_or(if_else_node: uni.IfElseExpr) -> bool {
    if not self._exprs_are_identical(
        if_else_node.value.expr, if_else_node.condition.expr
    ) {
        return False;
    }
    parent = if_else_node.parent;
    if parent is None {
        return False;
    }
    if not self.emit(W3008, node_override=if_else_node) {
        return False;
    }
    if isinstance(if_else_node.else_value.expr, uni.Null) {
        replacement: uni.Expr = if_else_node.value.expr;
        replacement.set_parent(parent);
    } else {
        or_token = uni.Token(
            orig_src=if_else_node.loc.orig_src,
            name=Tok.KW_OR,
            value="or",
            line=if_else_node.loc.first_line,
            end_line=if_else_node.loc.first_line,
            col_start=0,
            col_end=2,
            pos_start=0,
            pos_end=2
        );
        cfg_val = uni.CfgExpr(
            expr=if_else_node.value.expr, kid=[if_else_node.value.expr]
        );
        cfg_else = uni.CfgExpr(
            expr=if_else_node.else_value.expr, kid=[if_else_node.else_value.expr]
        );
        replacement = uni.BoolExpr(
            op=or_token, values=[cfg_val, cfg_else], kid=[cfg_val, or_token, cfg_else]
        );
        replacement.set_parent(parent);
    }
    if parent?.kid {
        new_kids: list[uni.UniNode] = [];
        for kid in parent.kid {
            if kid is if_else_node {
                new_kids.append(replacement);
            } else {
                new_kids.append(kid);
            }
        }
        parent.set_kids(new_kids);
        parent._invalidate_sub_node_tab();
    }
    if isinstance(parent, uni.Assignment) {
        if parent.value is if_else_node {
            parent._role_set(ValueRole, replacement);
        }
    } elif isinstance(parent, uni.IfElseExpr) {
        if parent.value.expr is if_else_node {
            parent._role_set(
                ValueRole, uni.CfgExpr(expr=replacement, kid=[replacement])
            );
        } elif parent.condition.expr is if_else_node {
            parent._role_set(
                ConditionRole, uni.CfgExpr(expr=replacement, kid=[replacement])
            );
        } elif parent.else_value.expr is if_else_node {
            parent._role_set(
                ElseValueRole, uni.CfgExpr(expr=replacement, kid=[replacement])
            );
        }
    } elif isinstance(parent, uni.BoolExpr) {
        new_values: list[uni.CfgExpr] = [];
        for val in parent.values {
            if val.expr is if_else_node {
                new_values.append(uni.CfgExpr(expr=replacement, kid=[replacement]));
            } else {
                new_values.append(val);
            }
        }
        parent._role_set(ValuesRole, new_values);
    }
    return True;
}

impl JacAutoLintPass.exit_if_else_expr with uni.IfElseExpr exit {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if not self._is_suppressed(W3008) and self._convert_ternary_to_or(here) {
        return;
    }
    if self._is_suppressed(W3007) {
        return;
    }
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(here, trailers);
    if len(trailers) < 2 {
        return;
    }
    null_ok_keys: set = set();
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None {
                null_ok_keys.add(key);
            }
        }
    }
    if not null_ok_keys {
        return;
    }
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and not trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
            }
        }
    }
}

impl JacAutoLintPass.exit_bool_expr with uni.BoolExpr exit {
    if not self.lint_enabled or self.report_only or self._is_suppressed(W3007) {
        return;
    }
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(here, trailers);
    if len(trailers) < 2 {
        return;
    }
    null_ok_keys: set = set();
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None {
                null_ok_keys.add(key);
            }
        }
    }
    if not null_ok_keys {
        return;
    }
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and not trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
            }
        }
    }
}

impl JacAutoLintPass._is_future_annotations_import(stmt: uni.UniNode) -> bool {
    if not isinstance(stmt, uni.Import) {
        return False;
    }
    import_node = stmt;
    if import_node.from_loc is None {
        return False;
    }
    from_path = import_node.from_loc.path;
    if from_path is None or len(from_path) != 1 {
        return False;
    }
    first_path = from_path[0];
    if not isinstance(first_path, uni.Name) {
        return False;
    }
    if first_path.value != "__future__" {
        return False;
    }
    for item in import_node.items {
        if isinstance(item, uni.ModuleItem) {
            if isinstance(item.name, uni.Name) and item.name.value == "annotations" {
                return True;
            }
        }
    }
    return False;
}

impl JacAutoLintPass._fix_impl_signature_mismatch(impl_node: uni.ImplDef) -> None {
    if self._is_file_excluded(impl_node.loc.mod_path) {
        return;
    }
    decl: uni.Ability | None = None;
    if isinstance(impl_node.decl_link, uni.Ability) {
        decl = impl_node.decl_link;
    } else {
        arch_node = self._impl_owner_archetype(impl_node);
        if arch_node is None {
            return;
        }
        ability_name = impl_node.target[-1].sym_name if impl_node.target[-1] else None;
        if not ability_name {
            return;
        }
        for member in arch_node.body {
            if isinstance(member, uni.Ability) {
                if member.name_ref and member.name_ref.sym_name == ability_name {
                    decl = member;
                    break;
                }
            }
        }
    }
    if decl is None {
        return;
    }
    decl_sig = decl.signature;
    if not isinstance(decl_sig, uni.FuncSignature) {
        return;
    }
    if not isinstance(impl_node.spec, uni.FuncSignature) {
        return;
    }
    impl_sig = impl_node.spec;
    if self._signatures_match(decl_sig, impl_sig) {
        return;
    }
    if not self.emit(W3010, node_override=impl_node) {
        return;
    }
    import copy;

    new_sig = decl_sig.detached_copy();
    new_sig.set_parent(impl_node);
    old_spec = impl_node.spec;

    old_first_tok = old_spec.loc.first_tok;
    old_last_tok = old_spec.loc.last_tok;
    def _fix_token_positions(nd: uni.UniNode) {
        if isinstance(nd, uni.Token) {
            nd.orig_src = old_first_tok.orig_src;
            nd.line_no = old_first_tok.line_no;
            nd.end_line = old_first_tok.end_line;
            nd.c_start = old_first_tok.c_start;
            nd.c_end = old_first_tok.c_end;
            nd.pos_start = old_first_tok.pos_start;
            nd.pos_end = old_first_tok.pos_end;
        }
        for k in nd.kid {
            if k is not None {
                _fix_token_positions(k);
            }
        }
    }
    _fix_token_positions(new_sig);
    impl_node._role_set(SpecRole, new_sig);
    new_kids: list[uni.UniNode] = [];
    for kid in impl_node.kid {
        if kid is old_spec {
            new_kids.append(new_sig);
        } else {
            new_kids.append(kid);
        }
    }
    impl_node.set_kids(new_kids);
    impl_node._invalidate_sub_node_tab();
}

impl JacAutoLintPass._impl_owner_archetype(
    impl_node: uni.ImplDef
) -> (uni.Archetype | None) {
    if not impl_node.target or len(impl_node.target) < 2 {
        return None;
    }
    root_arch_name = impl_node.target[0].sym_name if impl_node.target[0] else None;
    if not root_arch_name or self.main_module is None {
        return None;
    }
    arch_node: uni.Archetype | None = None;
    if self.main_module.sym_tab {
        arch_sym = self.main_module.sym_tab.lookup(root_arch_name);
        if arch_sym and arch_sym.decl {
            candidate = arch_sym.decl.name_of;
            if isinstance(candidate, uni.Archetype) {
                arch_node = candidate;
            }
        }
    }
    if arch_node is None {
        for stmt in self.main_module.body {
            if isinstance(stmt, uni.Archetype) {
                if stmt.name_spec and stmt.name_spec.sym_name == root_arch_name {
                    arch_node = stmt;
                    break;
                }
            }
        }
    }

    if arch_node is None {
        for stmt in self._base_decl_archetypes(impl_node.loc.mod_path) {
            if stmt.name_spec and stmt.name_spec.sym_name == root_arch_name {
                arch_node = stmt;
                break;
            }
        }
    }
    if arch_node is None or not arch_node.body {
        return None;
    }
    for i in range(1, len(impl_node.target) - 1) {
        if arch_node is None {
            return None;
        }
        nested_name = impl_node.target[i].sym_name if impl_node.target[i] else None;

        if not nested_name {
            return None;
        }
        nested: uni.Archetype | None = None;

        for member in arch_node.body {
            if isinstance(member, uni.Archetype) {
                if member.name_spec and member.name_spec.sym_name == nested_name {
                    nested = member;
                    break;
                }
            }
        }

        if nested is None or not nested.body {
            return None;
        }
        arch_node = nested;
    }
    return arch_node;
}

impl JacAutoLintPass._base_decl_archetypes(annex_path: str) -> list[uni.Archetype] {
    if self._base_decls_loaded {
        return self._base_decl_cache;
    }
    self._base_decls_loaded = True;
    import from jaclang.compiler.driver.bccache { discover_base_file }
    import from jaclang.compiler.frontend.parser { parse as rd_parse }
    import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
    import from jaclang.compiler.driver.program { JacProgram }
    base_path = discover_base_file(annex_path);
    if base_path is None {
        return self._base_decl_cache;
    }
    try {
        source_str = read_file_with_encoding(base_path);

        (base_mod, _had_error) = rd_parse(source_str, base_path, prog=JacProgram());
    } except Exception {
        return self._base_decl_cache;
    }
    self._base_decl_cache = [
        stmt
        for stmt in base_mod.body
        if isinstance(stmt, uni.Archetype)
    ];
    return self._base_decl_cache;
}

impl JacAutoLintPass._signatures_match(
    decl_sig: uni.FuncSignature, impl_sig: uni.FuncSignature
) -> bool {
    decl_params = decl_sig.params or [];
    impl_params = impl_sig.params or [];
    if (
        len(decl_params) != len(impl_params)
        or len(decl_sig.posonly_params) != len(impl_sig.posonly_params)
        or len(decl_sig.kwonlyargs) != len(impl_sig.kwonlyargs)
        or (decl_sig.varargs is None) != (impl_sig.varargs is None)
        or (decl_sig.kwargs is None) != (impl_sig.kwargs is None)
        or (decl_sig.return_type is None) != (impl_sig.return_type is None)
    ) {
        return False;
    }
    for (i, decl_param) in enumerate(decl_params) {
        impl_param = impl_params[i];

        if decl_param.name.value != impl_param.name.value {
            return False;
        }
    }
    for (i, decl_param) in enumerate(decl_sig.posonly_params) {
        impl_param = impl_sig.posonly_params[i];

        if decl_param.name.value != impl_param.name.value {
            return False;
        }
    }
    for (i, decl_param) in enumerate(decl_sig.kwonlyargs) {
        impl_param = impl_sig.kwonlyargs[i];

        if decl_param.name.value != impl_param.name.value {
            return False;
        }
    }
    return True;
}

impl JacAutoLintPass._stmt_body_list(
    nd: uni.UniNode
) -> (Sequence[uni.UniNode] | None) {
    if isinstance(nd, uni.Module) {
        return nd.body;
    }
    if isinstance(
        nd,
        (
            uni.Test,
            uni.ModuleCode,
            uni.TypedCtxBlock,
            uni.OpenStmt,
            uni.IfStmt,
            uni.ElseStmt,
            uni.TryStmt,
            uni.AwaitingClause,
            uni.Except,
            uni.FinallyStmt,
            uni.IterForStmt,
            uni.InForStmt,
            uni.WhileStmt,
            uni.ForeverStmt,
            uni.WithStmt,
            uni.MatchCase,
            uni.SwitchCase,
            uni.JsxSlot
        )
    ) {
        return nd.body;
    }
    if isinstance(nd, (uni.AstImplNeedingNode, uni.ImplDef, uni.LambdaExpr)) {
        return nd.body if isinstance(nd.body, Sequence) else None;
    }
    return None;
}

impl JacAutoLintPass._strip_redundant_semis(nd: uni.Module) -> None {
    if not self.lint_enabled or self._is_suppressed(W3013) {
        return;
    }
    removable: list[tuple[uni.UniNode, uni.Semi]] = [];
    stack: list[uni.UniNode] = [nd];
    while stack {
        current = stack.pop();
        body = self._stmt_body_list(current);
        if isinstance(body, list) and not isinstance(current, uni.JsxSlot) {
            semis = [
                s
                for s in body
                if isinstance(s, uni.Semi)
            ];
            if len(semis) == len(body)
                and isinstance(current, (uni.MatchCase, uni.SwitchCase)) {
                semis = semis[1:];
            }
            for semi in semis {
                removable.append((current, semi));
            }
        }
        for kid in current.kid {
            if kid is not None {
                stack.append(kid);
            }
        }
    }
    removable.sort(
        key=lambda (item) { (item[1].loc.first_line, item[1].loc.col_start); }
    );
    doomed: dict[int, tuple[uni.UniNode, set[int]]] = {};
    for (container, semi) in removable {
        if not self.emit(W3013, node_override=semi) {
            continue;
        }
        if self.report_only {
            continue;
        }
        if id(container) not in doomed {
            doomed[id(container)] = (container, set());
        }
        doomed[id(container)][1].add(id(semi));
    }
    for (container, semi_ids) in doomed.values() {
        body = self._stmt_body_list(container);
        if not isinstance(body, list) {
            continue;
        }
        container._role_set(
            BodyRole,
            [
                s
                for s in body
                if id(s) not in semi_ids
            ]
        );
        container.set_kids(
            [
                k
                for k in container.kid
                if id(k) not in semi_ids
            ]
        );
        container._invalidate_sub_node_tab();
    }
}

impl JacAutoLintPass._remove_empty_parens_from_sig(
    target_node: uni.UniNode, sig: uni.FuncSignature, sig_attr: str
) -> None {
    has_params = bool(
        sig.posonly_params or sig.params or sig.varargs or sig.kwonlyargs or sig.kwargs
    );
    if has_params {
        return;
    }
    has_parens = any(
        isinstance(kid, uni.Token) and kid.name in (Tok.LPAREN, Tok.RPAREN)
        for kid in sig.kid
    );
    if not has_parens {
        return;
    }
    if sig.return_type is None {
        if not self.emit(W3005, node_override=target_node) {
            return;
        }
        if self.report_only {
            return;
        }
        target_node._role_set(
            SignatureRole if sig_attr == "signature" else SpecRole, None
        );
        new_kid: list[uni.UniNode] = [];
        for kid in target_node.kid {
            if kid is not sig {
                new_kid.append(kid);
            }
        }
        target_node.set_kids(new_kid);
        target_node._invalidate_sub_node_tab();
    } else {
        if not self.emit(W3005, node_override=target_node) {
            return;
        }
        if self.report_only {
            return;
        }
        new_kid: list[uni.UniNode] = [];
        for kid in sig.kid {
            if isinstance(kid, uni.Token) and kid.name in (Tok.LPAREN, Tok.RPAREN) {
                continue;
            }
            new_kid.append(kid);
        }
        if len(new_kid) > 0 {
            sig.set_kids(nodes=new_kid);
        }
    }
}

impl JacAutoLintPass._check_no_print(nd: uni.FuncCall) -> None {
    if not isinstance(nd.target, uni.Name) {
        return;
    }
    if nd.target.value != "print" {
        return;
    }
    if self._is_file_excluded(nd.loc.mod_path) {
        return;
    }
    self.emit(E3012, node_override=nd);
}

impl JacAutoLintPass._extract_string_literal_value(expr: uni.Expr) -> (str | None) {
    attr_value: str | None = None;
    if isinstance(expr, uni.String) {
        attr_value = expr.value;
    } elif isinstance(expr, uni.MultiString) {
        if len(expr.strings) == 1 and isinstance(expr.strings[0], uni.String) {
            attr_value = expr.strings[0].value;
        }
    }
    if attr_value is None {
        return None;
    }
    if (attr_value.startswith('"') and attr_value.endswith('"'))
        or (attr_value.startswith("'") and attr_value.endswith("'")) {
        return attr_value[1:-1];
    }
    return None;
}

impl JacAutoLintPass._check_unnecessary_pass(body: list) -> None {
    if self._is_suppressed(W3020) {
        return;
    }
    real_stmts = [
        s
        for s in body
        if not isinstance(s, uni.Semi)
    ];
    if len(real_stmts) <= 1 {
        return;
    }
    for stmt in body {
        if isinstance(stmt, uni.CtrlStmt)
            and stmt.ctrl
            and isinstance(stmt.ctrl, uni.Token)
            and stmt.ctrl.value == "pass" {
            self.emit(W3020, node_override=stmt);
        }

        if isinstance(stmt, uni.ExprStmt) {
            for k in stmt.kid {
                if isinstance(k, uni.Name) and k.value == "pass" {
                    self.emit(W3020, node_override=stmt);
                    break;
                }
            }
        }
    }
}

impl JacAutoLintPass._check_unnecessary_else_after_return(nd: uni.IfStmt) -> None {
    if self._is_suppressed(W3021) {
        return;
    }

    if not nd.body {
        return;
    }
    real_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    if not real_body {
        return;
    }
    last_stmt = real_body[-1];
    if not isinstance(last_stmt, (uni.ReturnStmt, uni.RaiseStmt)) {
        return;
    }

    else_node = nd.else_body;
    if else_node is not None and isinstance(else_node, uni.ElseStmt) {
        self.emit(W3021, node_override=else_node);
    }
}

impl JacAutoLintPass._check_nested_if_to_elif(nd: uni.ElseStmt) -> None {
    if self._is_suppressed(W3022) {
        return;
    }
    if not nd.body {
        return;
    }
    real_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    if len(real_body) == 1 and isinstance(real_body[0], uni.IfStmt) {
        self.emit(W3022, node_override=nd);
    }
}

impl JacAutoLintPass._check_return_bool_simplification(nd: uni.IfStmt) -> None {
    if self._is_suppressed(W3023) {
        return;
    }
    if nd.else_body is None or not isinstance(nd.else_body, uni.ElseStmt) {
        return;
    }
    if_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    else_body = [
        s
        for s in nd.else_body.body
        if not isinstance(s, uni.Semi)
    ];
    if len(if_body) != 1 or len(else_body) != 1 {
        return;
    }
    if_ret = if_body[0];
    else_ret = else_body[0];
    if not isinstance(if_ret, uni.ReturnStmt)
        or not isinstance(else_ret, uni.ReturnStmt) {
        return;
    }
    if (
        isinstance(if_ret.expr, uni.Bool)
        and isinstance(else_ret.expr, uni.Bool)
        and if_ret.expr.value != else_ret.expr.value
    ) {
        self.emit(W3023, node_override=nd);
    }
}

impl JacAutoLintPass._check_repeated_condition(nd: uni.IfStmt) -> None {
    if self._is_suppressed(W3024) {
        return;
    }
    conditions: list[str] = [];
    cond_key = self._expr_to_key(nd.condition);
    if cond_key is not None {
        conditions.append(cond_key);
    }

    current = nd.else_body;
    while current is not None and isinstance(current, uni.ElseIf) {
        elif_key = self._expr_to_key(current.condition);
        if elif_key is not None {
            if elif_key in conditions {
                self.emit(W3024, node_override=current);
            }
            conditions.append(elif_key);
        }
        current = current.else_body;
    }
}

impl JacAutoLintPass._check_identical_branches(nd: uni.IfStmt) -> None {
    if self._is_suppressed(W3025) {
        return;
    }
    if nd.else_body is None or not isinstance(nd.else_body, uni.ElseStmt) {
        return;
    }
    if_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    else_body = [
        s
        for s in nd.else_body.body
        if not isinstance(s, uni.Semi)
    ];
    if not if_body or len(if_body) != len(else_body) {
        return;
    }

    for (a, b) in zip(if_body, else_body) {
        if type(a) is not type(b) {
            return;
        }
    }

    if_src = "".join(unparse_node(s) for s in if_body);
    else_src = "".join(unparse_node(s) for s in else_body);
    if if_src == else_src {
        self.emit(W3025, node_override=nd);
    }
}

impl JacAutoLintPass._check_too_many_params(nd: uni.FuncSignature) -> None {
    if self._is_suppressed(W3030) {
        return;
    }
    threshold = 7;
    count = len(nd.posonly_params);
    if nd.params {
        count += len(nd.params);
    }
    count += len(nd.kwonlyargs);
    if nd.varargs {
        count += 1;
    }
    if nd.kwargs {
        count += 1;
    }

    all_params: list[uni.ParamVar] = list(nd.posonly_params);
    if nd.params {
        all_params.extend(nd.params);
    }
    if all_params
        and isinstance(all_params[0], uni.ParamVar)
        and all_params[0].name.value == "self" {
        count -= 1;
    }
    if count > threshold {
        self.emit(W3030, node_override=nd, count=count, threshold=threshold);
    }
}

impl JacAutoLintPass._check_is_with_literal(nd: uni.CompareExpr) -> None {
    if self._is_suppressed(W3035) {
        return;
    }
    for (i, op) in enumerate(nd.ops) {
        if op.value not in ("is", "is not") {
            continue;
        }
        right = nd.rights[i] if i < len(nd.rights) else None;
        if right is None {
            continue;
        }

        if isinstance(right, (uni.Null, uni.Bool)) {
            continue;
        }
        if isinstance(right, (uni.Int, uni.Float, uni.String)) {
            self.emit(W3035, node_override=nd);
        }
    }
}

impl JacAutoLintPass._check_filter_compare_tautology(nd: uni.CompareExpr) -> None {
    import from jaclang.compiler.frontend.diagnostics { W3040 }
    if self._is_suppressed(W3040) {
        return;
    }

    if not nd.find_parent_of_type(uni.FilterCompr) {
        return;
    }
    left = nd.left;
    for (i, right) in enumerate(nd.rights) {
        if (
            isinstance(left, uni.Name)
            and isinstance(right, uni.Name)
            and left.value == right.value
        ) {
            self.emit(W3040, node_override=nd, name=left.value);
        }

        left = right;
    }
}

impl JacAutoLintPass._check_stale_has_read(ability_node: uni.Ability) -> None {
    if self._is_suppressed(W3041) {
        return;
    }
    sig = ability_node.signature;
    if not isinstance(sig, uni.EventSignature) {
        return;
    }
    if not sig.event or sig.event.name != Tok.KW_ENTRY {
        return;
    }
    if not ability_node.in_client_context() {
        return;
    }
    body = ability_node.body;
    if body is None or not isinstance(body, list) {
        return;
    }
    reactive = self._collect_reactive_has_names(ability_node);
    if not reactive {
        return;
    }
    writes: list[tuple[int, int, str]] = [];
    reads: list[tuple[int, int, str, uni.Name]] = [];
    for stmt in body {
        self._walk_for_has_uses(stmt, reactive, writes, reads);
    }
    if not writes or not reads {
        return;
    }
    flagged: set[tuple[int, int, str]] = set();
    for read_entry in reads {
        rline = read_entry[0];
        rcol = read_entry[1];
        rname = read_entry[2];
        rnode = read_entry[3];
        key = (rline, rcol, rname);
        if key in flagged {
            continue;
        }
        for write_entry in writes {
            wline = write_entry[0];
            wcol = write_entry[1];
            wname = write_entry[2];
            if wname == rname and ((wline, wcol) < (rline, rcol)) {
                self.emit(W3041, node_override=rnode, name=rname);
                flagged.add(key);
                break;
            }
        }
    }
}

impl JacAutoLintPass._collect_reactive_has_names(
    ability_node: uni.Ability
) -> set[str] {
    names: set[str] = set();
    container: (uni.UniNode | None) = ability_node.parent;
    while container is not None {
        if isinstance(container, (uni.Archetype, uni.Ability)) {
            body = container.body;
            if body is not None and isinstance(body, list) {
                for stmt in body {
                    if isinstance(stmt, uni.ArchHas) and stmt.in_client_context() {
                        for hv in stmt.vars {
                            names.add(hv.name.sym_name);
                        }
                    }
                }
            }
            break;
        }
        container = container.parent;
    }
    return names;
}

impl JacAutoLintPass._walk_for_has_uses(
    nd: uni.UniNode,
    reactive: set[str],
    writes: list[tuple[int, int, str]],
    reads: list[tuple[int, int, str, uni.Name]]
) -> None {
    import from jaclang.compiler.frontend.constant { ExprCtx }
    if isinstance(nd, (uni.LambdaExpr, uni.Ability, uni.Archetype)) {
        return;
    }
    if isinstance(nd, uni.Assignment) {
        if (
            len(nd.target) == 1
            and isinstance(nd.target[0], uni.Name)
            and nd.target[0].sym_name in reactive
        ) {
            tgt = nd.target[0];
            writes.append((tgt.loc.first_line, tgt.loc.col_start, tgt.sym_name));
        }
        if nd.value {
            self._walk_for_has_uses(nd.value, reactive, writes, reads);
        }
        return;
    }
    if isinstance(nd, uni.Name) {
        if nd.value in reactive and nd.expr_ctx == ExprCtx.LOAD {
            parent = nd.parent;
            if not (isinstance(parent, uni.AtomTrailer) and parent.is_attr) {
                reads.append((nd.loc.first_line, nd.loc.col_start, nd.value, nd));
            }
        }
        return;
    }
    for kid in nd.kid {
        self._walk_for_has_uses(kid, reactive, writes, reads);
    }
}

impl JacAutoLintPass._check_mutable_default(nd: uni.ParamVar) -> None {
    if self._is_suppressed(W3036) {
        return;
    }
    if nd.value is None {
        return;
    }
    `default = nd.value;
    if isinstance(`default, uni.ListVal) {
        self.emit(W3036, node_override=nd, type="list");
    } elif isinstance(`default, uni.DictVal) {
        self.emit(W3036, node_override=nd, type="dict");
    } elif isinstance(`default, uni.SetVal) {
        self.emit(W3036, node_override=nd, type="set");
    }
}

impl JacAutoLintPass.exit_if_stmt with uni.IfStmt exit {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_pass(list(here.body));
    self._check_unnecessary_else_after_return(here);
    self._check_return_bool_simplification(here);
    self._check_repeated_condition(here);
    self._check_identical_branches(here);
}

impl JacAutoLintPass.enter_else_stmt with uni.ElseStmt entry {
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_pass(list(here.body));
    self._check_nested_if_to_elif(here);
}

impl JacAutoLintPass.exit_compare_expr with uni.CompareExpr exit {
    if not self.lint_enabled {
        return;
    }
    self._check_is_with_literal(here);
    self._check_filter_compare_tautology(here);
}

impl JacAutoLintPass.exit_func_signature with uni.FuncSignature exit {
    if not self.lint_enabled {
        return;
    }
    self._check_too_many_params(here);
}

impl JacAutoLintPass.enter_param_var with uni.ParamVar entry {
    if not self.lint_enabled {
        return;
    }
    self._check_mutable_default(here);
}

impl JacAutoLintPass.exit_archetype with uni.Archetype exit {
    if not self.lint_enabled {
        return;
    }
    if here.body is not None and isinstance(here.body, list) {
        self._check_unnecessary_pass(list(here.body));
    }
}

impl JacAutoLintPass.exit_lambda_expr with uni.LambdaExpr exit {
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_none_return(here, here.body, here.signature, "lambda");
}

impl JacAutoLintPass._check_unnecessary_none_return(
    nd: (uni.Ability | uni.LambdaExpr),
    body: (uni.UniNode | Sequence[uni.UniNode] | None),
    sig: (uni.FuncSignature | uni.EventSignature | None),
    name: str
) -> None {
    if self._is_suppressed(W3037) {
        return;
    }

    if not isinstance(sig, uni.FuncSignature) or sig.return_type is None {
        return;
    }

    ret = sig.return_type;
    is_none_return = (
        isinstance(ret, uni.Null)
        or (isinstance(ret, uni.BuiltinType) and ret.value == "None")
        or (isinstance(ret, uni.Name) and ret.value == "None")
    );
    if not is_none_return {
        return;
    }

    if not isinstance(body, list) {
        return;
    }

    if not self._body_has_return_stmt(body) {
        if not self.emit(W3037, node_override=sig.return_type, name=name) {
            return;
        }
        if self.report_only {
            return;
        }

        sig._role_set(ReturnTypeRole, None);
        new_kid: list[uni.UniNode] = [];
        skip_next = False;
        for kid in sig.kid {
            if isinstance(kid, uni.Token) and kid.name == Tok.RETURN_HINT {
                skip_next = True;
                continue;
            }
            if skip_next {
                skip_next = False;
                continue;
            }
            new_kid.append(kid);
        }
        if len(new_kid) > 0 {
            sig.set_kids(nodes=new_kid);
        } else {
            if isinstance(nd, uni.LambdaExpr) {
                nd._role_set(SignatureRole, None);
            } elif isinstance(nd, uni.Ability) {
                nd._role_set(SignatureRole, None);
            }
            nd.set_kids(
                [
                    k
                    for k in nd.kid
                    if k is not sig
                ]
            );
            nd._invalidate_sub_node_tab();
        }
    }
}

impl JacAutoLintPass._body_has_return_stmt(body: list) -> bool {
    for stmt in body {
        if isinstance(stmt, uni.ReturnStmt) {
            return True;
        }

        if isinstance(stmt, uni.IfStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
            eb = stmt.else_body;
            while eb is not None {
                if isinstance(eb, uni.ElseIf) {
                    if self._body_has_return_stmt(list(eb.body)) {
                        return True;
                    }
                    eb = eb.else_body;
                } elif isinstance(eb, uni.ElseStmt) {
                    if self._body_has_return_stmt(list(eb.body)) {
                        return True;
                    }
                    break;
                } else {
                    break;
                }
            }
        }
        if isinstance(stmt, uni.InForStmt)
            or isinstance(stmt, uni.IterForStmt)
            or isinstance(stmt, uni.WhileStmt)
            or isinstance(stmt, uni.ForeverStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
        }
        if isinstance(stmt, uni.TryStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
            for handler in (stmt.excepts or []) {
                if self._body_has_return_stmt(list(handler.body)) {
                    return True;
                }
            }
            if stmt.finally_body {
                if self._body_has_return_stmt(list(stmt.finally_body.body)) {
                    return True;
                }
            }
        }
        if isinstance(stmt, uni.MatchStmt) {
            for `case in stmt.cases {
                if self._body_has_return_stmt(list(`case.body)) {
                    return True;
                }
            }
        }
        if isinstance(stmt, uni.WithStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
        }
    }
    return False;
}

impl JacAutoLintPass._is_usestate_assignment(
    stmt: uni.UniNode
) -> (tuple[str, str, uni.Expr | None] | None) {
    if not isinstance(stmt, uni.Assignment) {
        return None;
    }

    rhs = stmt.value;
    if not isinstance(rhs, uni.FuncCall) {
        return None;
    }
    if not isinstance(rhs.target, uni.Name) or rhs.target.value != "useState" {
        return None;
    }

    if len(stmt.target) != 1 {
        return None;
    }
    lhs = stmt.target[0];
    if not isinstance(lhs, (uni.ListVal, uni.TupleVal)) {
        return None;
    }
    if len(lhs.values) != 2 {
        return None;
    }
    name_node = lhs.values[0];
    setter_node = lhs.values[1];
    if not isinstance(name_node, uni.Name) or not isinstance(setter_node, uni.Name) {
        return None;
    }
    initial_value: (uni.Expr | None) = None;
    if rhs.params and len(rhs.params) > 0 {
        first_param = rhs.params[0];
        if isinstance(first_param, uni.Expr) {
            initial_value = first_param;
        }
    }
    return (name_node.value, setter_node.value, initial_value);
}

impl JacAutoLintPass._infer_type_from_usestate_value(value: (uni.Expr | None)) -> str {
    if value is None {
        return "any";
    }
    if isinstance(value, (uni.String, uni.MultiString)) {
        return "str";
    }
    if isinstance(value, uni.Int) {
        return "int";
    }
    if isinstance(value, uni.Float) {
        return "float";
    }
    if isinstance(value, uni.Bool) {
        return "bool";
    }
    if isinstance(value, uni.Null) {
        return "None";
    }
    if isinstance(value, uni.ListVal) {
        return "list";
    }
    if isinstance(value, uni.DictVal) {
        return "dict";
    }
    return "any";
}

impl JacAutoLintPass._create_has_from_usestate(
    ref_node: uni.UniNode, var_name: str, type_str: str, init_value: (uni.Expr | None)
) -> uni.ArchHas {
    name_node = uni.Name(
        orig_src=ref_node.loc.orig_src,
        name=Tok.NAME.value,
        value=var_name,
        line=ref_node.loc.first_line,
        end_line=ref_node.loc.last_line,
        col_start=ref_node.loc.col_start,
        col_end=ref_node.loc.col_start + len(var_name),
        pos_start=ref_node.loc.pos_start,
        pos_end=ref_node.loc.pos_end,
        is_kwesc=False
    );

    type_name_node = uni.Name(
        orig_src=ref_node.loc.orig_src,
        name=Tok.NAME.value,
        value=type_str,
        line=ref_node.loc.first_line,
        end_line=ref_node.loc.last_line,
        col_start=ref_node.loc.col_start,
        col_end=ref_node.loc.col_start + len(type_str),
        pos_start=ref_node.loc.pos_start,
        pos_end=ref_node.loc.pos_end,
        is_kwesc=False
    );
    colon_tok = ref_node.gen_token(Tok.COLON);
    type_tag = uni.SubTag(tag=type_name_node, kid=[colon_tok, type_name_node]);
    has_var_kids: list[uni.UniNode] = [name_node, type_tag];
    if init_value is not None {
        eq_tok = ref_node.gen_token(Tok.EQ);
        has_var_kids.append(eq_tok);
        has_var_kids.append(init_value);
    }
    has_var = uni.HasVar(
        name=name_node,
        type_tag=type_tag,
        value=init_value,
        defer=False,
        kid=has_var_kids
    );

    has_kw = ref_node.gen_token(Tok.KW_HAS);
    semi_tok = ref_node.gen_token(Tok.SEMI);
    arch_has = uni.ArchHas(
        is_static=False,
        vars=[has_var],
        is_frozen=False,
        access=None,
        doc=None,
        kid=[has_kw, has_var, semi_tok]
    );
    return arch_has;
}


impl JacAutoLintPass._convert_usestate_vars(ability_node: uni.Ability) -> None {
    if not ability_node.body or not isinstance(ability_node.body, list) {
        return;
    }
    new_body: list[uni.UniNode] = [];
    replaced: dict[int, uni.ArchHas] = {};
    setters: dict[str, str] = {};
    for stmt in ability_node.body {
        match_result = self._is_usestate_assignment(stmt);
        if match_result is None {
            new_body.append(stmt);
            continue;
        }
        (var_name, setter_name, init_value) = match_result;
        type_str = self._infer_type_from_usestate_value(init_value);
        init_repr = (
            str(getattr(init_value, "value", "...")) if init_value is not None else '""'
        );
        if not self.emit(
            W3038, node_override=stmt, name=var_name, type_name=type_str, init=init_repr
        ) {
            new_body.append(stmt);
            continue;
        }
        has_node = self._create_has_from_usestate(stmt, var_name, type_str, init_value);
        has_node.set_parent(ability_node);
        new_body.append(has_node);
        replaced[id(stmt)] = has_node;
        setters[setter_name] = var_name;
    }
    if replaced {
        self._did_convert_usestate = True;
        ability_node._role_set(BodyRole, new_body);
        self.recalculate_parents(ability_node);
        ability_node.set_kids([replaced.get(id(k), k) for k in ability_node.kid]);
        ability_node._invalidate_sub_node_tab();
    }

    self._pending_setters.append(setters);
}

impl JacAutoLintPass.exit_expr_stmt with uni.ExprStmt exit {
    if not self.lint_enabled or self.report_only or not self._pending_setters {
        return;
    }
    call_node = here.expr;
    if (
        not isinstance(call_node, uni.FuncCall)
        or not isinstance(call_node.target, uni.Name)
        or call_node.params is None
        or len(call_node.params) != 1
    ) {
        return;
    }
    var_name: (str | None) = None;
    for setter_map in self._pending_setters {
        if call_node.target.value in setter_map {
            var_name = setter_map[call_node.target.value];
            break;
        }
    }
    if var_name is None {
        return;
    }
    parent = here.parent;
    if parent is None {
        return;
    }
    value_expr = call_node.params[0];
    if isinstance(value_expr, uni.KWPair) {
        return;
    }
    lhs_name = uni.Name(
        orig_src=call_node.loc.orig_src,
        name=Tok.NAME.value,
        value=var_name,
        line=call_node.loc.first_line,
        end_line=call_node.loc.last_line,
        col_start=call_node.loc.col_start,
        col_end=call_node.loc.col_start + len(var_name),
        pos_start=call_node.loc.pos_start,
        pos_end=call_node.loc.pos_end,
        is_kwesc=False
    );
    assign = uni.Assignment(
        target=[lhs_name],
        value=value_expr,
        mutable=True,
        aug_op=None,
        kid=[
            lhs_name,
            call_node.gen_token(Tok.EQ),
            value_expr,
            call_node.gen_token(Tok.SEMI)
        ]
    );
    assign.set_parent(parent);

    parent_body = self._stmt_body_list(parent);
    if parent_body is not None and isinstance(parent_body, list) {
        for (i, s) in enumerate(parent_body) {
            if s is here {
                parent_body[i] = assign;
            }
        }
    }
    parent.set_kids([assign if k is here else k for k in parent.kid]);
    parent._invalidate_sub_node_tab();
}

impl JacAutoLintPass._strip_usestate_imports(nd: uni.Module) -> None {
    if not self.lint_enabled or self.report_only or not self._did_convert_usestate {
        return;
    }
    removed: set[int] = set();
    new_body = [];
    for stmt in nd.body {
        if not isinstance(stmt, uni.Import) or stmt.from_loc is None {
            new_body.append(stmt);
            continue;
        }
        usestate_items = {
            item
            for item in stmt.items
            if isinstance(item, uni.ModuleItem)
                and isinstance(item.name, uni.Name)
                and item.name.value == "useState"
        };
        if not usestate_items {
            new_body.append(stmt);
            continue;
        }
        stmt._role_set(
            ItemsRole,
            [
                item
                for item in stmt.items
                if item not in usestate_items
            ]
        );
        if not stmt.items {
            removed.add(id(stmt));
            continue;
        }

        new_kid = [
            kid
            for kid in stmt.kid
            if kid not in usestate_items
        ];
        commas = [
            k
            for k in new_kid
            if isinstance(k, uni.Token) and k.name == Tok.COMMA
        ];
        no_commas = [
            k
            for k in new_kid
            if not (isinstance(k, uni.Token) and k.name == Tok.COMMA)
        ];
        result: list[uni.UniNode] = [];
        ci = 0;
        for (i, kid) in enumerate(no_commas) {
            result.append(kid);
            if (
                i + 1 < len(no_commas)
                and isinstance(kid, uni.ModuleItem)
                and isinstance(no_commas[i + 1], uni.ModuleItem)
                and ci < len(commas)
            ) {
                result.append(commas[ci]);
                ci += 1;
            }
        }
        stmt.set_kids(nodes=result);
        new_body.append(stmt);
    }
    if len(new_body) == len(nd.body) {
        return;
    }
    nd._role_set(BodyRole, new_body);
    if removed {
        nd.set_kids(
            nodes=[
                k
                for k in nd.kid
                if id(k) not in removed
            ]
                or [uni.EmptyToken()]
        );
    }
    self.recalculate_parents(nd);
}

impl JacAutoLintPass.exit_module with uni.Module exit {
    self._strip_usestate_imports(here);
    self._strip_redundant_semis(here);
    self._strip_noise(here);
}

impl JacAutoLintPass._strip_noise(nd: uni.Module) -> None {
    if not self.lint_enabled {
        return;
    }

    if self._is_file_excluded(nd.loc.mod_path) {
        return;
    }

    if not self._is_suppressed(W3050) and nd.source.comments {
        kept: list = [];
        suppression_lines = nd.source.inline_suppressions;
        for comment in list(nd.source.comments) {
            if comment.line_no in suppression_lines {
                kept.append(comment);
                continue;
            }
            self.emit(W3050, node_override=comment);
        }
        if not self.report_only {
            nd.source.comments = kept;
        }
    }

    if not self._is_suppressed(W3051) {
        self._strip_docstrings(nd);
    }
}

impl JacAutoLintPass._strip_docstrings(start: uni.UniNode) -> None {
    doc_nodes: list[uni.AstDocNode] = [];
    self._collect_doc_nodes(start, doc_nodes);
    for `node in doc_nodes {
        doc_str = `node.doc;
        if doc_str is None {
            continue;
        }
        self.emit(W3051, node_override=doc_str);
        if self.report_only {
            continue;
        }
        `node._role_set(DocRole, None);
        new_kid: list[uni.UniNode] = [
            k
            for k in `node.kid
            if k is not doc_str
        ];
        `node.set_kids(nodes=new_kid if len(new_kid) else [uni.EmptyToken()]);
        `node._invalidate_sub_node_tab();
    }
}

impl JacAutoLintPass._collect_doc_nodes(
    `node: uni.UniNode, results: list[uni.AstDocNode]
) -> None {
    stack: list[uni.UniNode] = [`node];
    while stack {
        current = stack.pop();
        if isinstance(current, uni.AstDocNode) and current.doc is not None {
            results.append(current);
        }
        for kid in current.kid {
            if kid is not None {
                stack.append(kid);
            }
        }
    }
}

impl JacAutoLintPass._make_name_node(ref_node: uni.UniNode, value: str) -> uni.Name {
    return uni.Name(
        orig_src=ref_node.loc.orig_src,
        name=Tok.NAME.value,
        value=value,
        line=ref_node.loc.first_line,
        end_line=ref_node.loc.last_line,
        col_start=ref_node.loc.col_start,
        col_end=ref_node.loc.col_start + len(value),
        pos_start=ref_node.loc.pos_start,
        pos_end=ref_node.loc.pos_end,
        is_kwesc=False
    );
}

impl JacAutoLintPass._detect_map_lambda_jsx(
    nd: uni.FuncCall
) -> (tuple[str, uni.JsxElement, uni.Expr] | None) {
    if not isinstance(nd.target, uni.AtomTrailer) {
        return None;
    }
    trailer = nd.target;
    if not trailer.is_attr
        or not isinstance(trailer.right, uni.Name)
        or trailer.right.value != "map"
        or nd.params is None
        or len(nd.params) != 1
        or not isinstance(nd.params[0], uni.LambdaExpr) {
        return None;
    }
    lam: uni.LambdaExpr = nd.params[0];
    if not isinstance(lam.body, list) {
        return None;
    }
    real_stmts = [
        s
        for s in lam.body
        if not isinstance(s, uni.Semi)
    ];
    if len(real_stmts) != 1 {
        return None;
    }
    ret_stmt = real_stmts[0];
    if not isinstance(ret_stmt, uni.ReturnStmt) or ret_stmt.expr is None {
        return None;
    }
    jsx: uni.Expr = ret_stmt.expr;
    if isinstance(jsx, uni.AtomUnit) and isinstance(jsx.value, uni.JsxElement) {
        jsx = jsx.value;
    }
    if jsx is None or not isinstance(jsx, uni.JsxElement) {
        return None;
    }

    sig = lam.signature;
    if sig is None {
        return None;
    }
    all_params: list[uni.ParamVar] = list(sig.posonly_params or [])
        + list(sig.params or []);
    if len(all_params) != 1 {
        return None;
    }

    item_name: str = all_params[0].name.value;
    return (item_name, jsx, trailer.target);
}

impl JacAutoLintPass._extract_filter_cond(
    collection: uni.Expr
) -> (tuple[uni.Expr, uni.Expr] | None) {
    if not isinstance(collection, uni.FuncCall)
        or not isinstance(collection.target, uni.AtomTrailer) {
        return None;
    }
    ft = collection.target;
    if not ft.is_attr
        or not isinstance(ft.right, uni.Name)
        or ft.right.value != "filter"
        or collection.params is None
        or len(collection.params) != 1
        or not isinstance(collection.params[0], uni.LambdaExpr) {
        return None;
    }
    filter_lam: uni.LambdaExpr = collection.params[0];
    if not isinstance(filter_lam.body, list) {
        return None;
    }
    filter_stmts = [
        s
        for s in filter_lam.body
        if not isinstance(s, uni.Semi)
    ];
    if len(filter_stmts) != 1
        or not isinstance(filter_stmts[0], uni.ReturnStmt)
        or filter_stmts[0].expr is None {
        return None;
    }
    return (filter_stmts[0].expr, ft.target);
}

impl JacAutoLintPass._convert_map_to_comprehension(nd: uni.FuncCall) -> bool {
    if self._is_suppressed(W3042) {
        return False;
    }
    detected = self._detect_map_lambda_jsx(nd);
    if detected is None {
        return False;
    }
    (item_name, jsx_expr, collection) = detected;

    filter_result = self._extract_filter_cond(collection);
    filter_cond: (uni.Expr | None) = None;
    if filter_result is not None {
        (filter_cond, collection) = filter_result;
    }

    parent = nd.parent;
    if parent is None {
        return False;
    }
    if not (
        isinstance(parent, (uni.JsxExpression, uni.ExprStmt, uni.CfgExpr))
        or (isinstance(parent, uni.Assignment) and parent.value is nd)
        or (isinstance(parent, uni.ReturnStmt) and parent.expr is nd)
    ) {
        return False;
    }

    if not self.emit(W3042, node_override=nd, name=item_name) {
        return False;
    }
    if self.report_only {
        return True;
    }

    target_node: uni.Expr = self._make_name_node(nd, item_name);
    compr_kid: list = [
        nd.gen_token(Tok.KW_FOR),
        target_node,
        nd.gen_token(Tok.KW_IN),
        collection
    ];
    if filter_cond is not None {
        compr_kid.extend([nd.gen_token(Tok.KW_IF), filter_cond]);
    }
    inner_compr = uni.InnerCompr(
        is_async=False,
        target=target_node,
        collection=collection,
        conditional=[filter_cond] if filter_cond is not None else None,
        kid=compr_kid
    );
    list_compr = uni.ListCompr(
        out_expr=jsx_expr,
        compr=[inner_compr],
        kid=[
            nd.gen_token(Tok.LSQUARE),
            jsx_expr,
            inner_compr,
            nd.gen_token(Tok.RSQUARE)
        ]
    );

    jsx_expr.set_parent(list_compr);
    inner_compr.set_parent(list_compr);
    target_node.set_parent(inner_compr);
    collection.set_parent(inner_compr);
    if filter_cond is not None {
        filter_cond.set_parent(inner_compr);
    }

    list_compr.set_parent(parent);
    if isinstance(parent, (uni.JsxExpression, uni.ExprStmt, uni.CfgExpr)) {
        parent._role_set(ExprRole, list_compr);
    } elif isinstance(parent, uni.Assignment) {
        parent._role_set(ValueRole, list_compr);
    } else {
        parent._role_set(ExprRole, list_compr);
    }
    parent.set_kids([list_compr if k is nd else k for k in parent.kid]);
    parent._invalidate_sub_node_tab();
    return True;
}


impl JacAutoLintPass._property_role_of_ability(ab: uni.Ability) -> str {
    if not ab.decorators {
        return "";
    }
    own_name = ab.name_ref.value if isinstance(ab.name_ref, uni.Name) else "";
    for dec in ab.decorators {
        if isinstance(dec, uni.Name) and dec.value == "property" {
            return "property";
        }

        if isinstance(dec, uni.AtomTrailer)
            and dec.is_attr
            and isinstance(dec.right, uni.Name)
            and isinstance(dec.target, uni.Name)
            and dec.target.value == own_name {
            if dec.right.value == "getter" {
                return "property";
            }
            if dec.right.value == "setter" {
                return "setter";
            }
            if dec.right.value == "deleter" {
                return "deleter";
            }
        }
    }
    return "";
}

impl JacAutoLintPass._make_accessor_from_ability(
    src: uni.Ability, kind: str
) -> uni.Ability {
    kw = "getter" if kind == "property" else kind;
    name_node = self._make_name_node(src, kw);
    sig: (uni.FuncSignature | uni.EventSignature | None) = (
        src.signature if kind == "setter" else None
    );
    acc_kid: list[uni.UniNode] = [name_node];
    if sig is not None {
        acc_kid.append(sig);
    }
    body: (list | None) = None;
    if isinstance(src.body, list) {
        body = src.body;
        acc_kid.append(src.gen_token(Tok.LBRACE));
        for s in src.body {
            acc_kid.append(s);
        }
        acc_kid.append(src.gen_token(Tok.RBRACE));
    } else {
        acc_kid.append(src.gen_token(Tok.SEMI));
    }
    return uni.Ability(
        name_ref=name_node,
        is_async=False,
        is_override=False,
        is_static=False,
        is_classmethod=False,
        is_abstract=False,
        access=None,
        signature=sig,
        body=body,
        kid=acc_kid,
        doc=None,
        decorators=None,
        type_params=None,
        accessor_kind=kind
    );
}

impl JacAutoLintPass._build_property_has(
    ref_node: uni.UniNode, prop_name: str, type_expr: uni.Expr, accessors: list
) -> uni.ArchHas {
    name_node = self._make_name_node(ref_node, prop_name);
    colon_tok = ref_node.gen_token(Tok.COLON);
    type_tag = uni.SubTag(tag=type_expr, kid=[colon_tok, type_expr]);
    hv_kid: list[uni.UniNode] = [name_node, type_tag, ref_node.gen_token(Tok.LBRACE)];
    for acc in accessors {
        hv_kid.append(acc);
    }
    hv_kid.append(ref_node.gen_token(Tok.RBRACE));
    has_var = uni.HasVar(
        name=name_node,
        type_tag=type_tag,
        value=None,
        defer=False,
        accessors=accessors,
        kid=hv_kid
    );
    has_kw = ref_node.gen_token(Tok.KW_HAS);
    return uni.ArchHas(
        is_static=False,
        vars=[has_var],
        is_frozen=False,
        access=None,
        doc=None,
        kid=[has_kw, has_var]
    );
}

impl JacAutoLintPass._convert_properties(container: uni.Archetype) -> None {
    if self._is_file_excluded(container.loc.mod_path) {
        return;
    }
    body = container.body;
    if not isinstance(body, list) {
        return;
    }
    groups: dict[str, dict[str, uni.Ability]] = {};
    group_indices: dict[str, list[int]] = {};
    prop_types: dict[str, uni.Expr] = {};
    order: list[str] = [];
    for (idx, item) in enumerate(body) {
        if not isinstance(item, uni.Ability) {
            continue;
        }
        role = self._property_role_of_ability(item);
        if role == "" or not isinstance(item.name_ref, uni.Name) {
            continue;
        }
        pname = item.name_ref.value;
        if pname not in groups {
            groups[pname] = {};
            group_indices[pname] = [];
            order.append(pname);
        }

        if role == "property" and pname not in prop_types {
            declared = (
                item.signature.return_type
                    if isinstance(item.signature, uni.FuncSignature)
                    else None
            );
            if declared is not None {
                prop_types[pname] = declared;
            }
        }
        groups[pname][role] = item;
        group_indices[pname].append(idx);
    }
    replaced: dict[int, uni.ArchHas] = {};
    dropped_ids: set[int] = set();
    for pname in order {
        g = groups[pname];
        if "property" not in g {
            continue;
        }
        getter_ab = g["property"];
        type_expr = (
            getter_ab.signature.return_type
                if isinstance(getter_ab.signature, uni.FuncSignature)
                else None
        );
        if type_expr is None {
            type_expr = prop_types.get(pname);
        }
        if type_expr is None {
            continue;
        }
        type_name = type_expr.value if isinstance(type_expr, uni.Name) else "...";
        if not self.emit(
            W3043, node_override=getter_ab, name=pname, type_name=type_name
        ) {
            continue;
        }
        if self.report_only {
            continue;
        }
        accessors: list[uni.Ability] = [
            self._make_accessor_from_ability(getter_ab, "property")
        ];
        if "setter" in g {
            accessors.append(self._make_accessor_from_ability(g["setter"], "setter"));
        }
        if "deleter" in g {
            accessors.append(self._make_accessor_from_ability(g["deleter"], "deleter"));
        }
        arch_has = self._build_property_has(getter_ab, pname, type_expr, accessors);
        indices = sorted(group_indices[pname]);
        for i in indices {
            dropped_ids.add(id(body[i]));
        }
        replaced[indices[0]] = arch_has;
    }
    if not replaced {
        return;
    }
    first_map: dict[int, uni.ArchHas] = {};
    new_body: list[uni.UniNode] = [];
    for (idx, item) in enumerate(body) {
        if idx in replaced {
            first_map[id(item)] = replaced[idx];
            new_body.append(replaced[idx]);
        } elif id(item) in dropped_ids {
            continue;
        } else {
            new_body.append(item);
        }
    }
    container._role_set(BodyRole, new_body);
    new_kid: list[uni.UniNode] = [];
    for k in container.kid {
        if id(k) in first_map {
            new_kid.append(first_map[id(k)]);
        } elif id(k) in dropped_ids {
            continue;
        } else {
            new_kid.append(k);
        }
    }
    container.set_kids(new_kid);
    container._invalidate_sub_node_tab();
    self.recalculate_parents(container);
}

impl JacAutoLintPass._property_impl_roles(
    arch: uni.Archetype, prop_name: str
) -> dict[str, list[uni.Ability]] {
    roles: dict[str, list[uni.Ability]] = {};

    for member in arch.body {
        if not isinstance(member, uni.ArchHas) {
            continue;
        }
        for var in member.vars {
            if var.name.sym_name != prop_name or not var.accessors {
                continue;
            }
            for acc in var.accessors {
                roles.setdefault(acc.accessor_kind, []).append(acc);
            }
        }
    }
    if roles {
        return roles;
    }
    for member in arch.body {
        if not isinstance(member, uni.Ability) {
            continue;
        }
        if not member.name_ref or member.name_ref.sym_name != prop_name {
            continue;
        }
        role = self._property_role_of_ability(member);
        if role {
            roles.setdefault(role, []).append(member);
        }
    }

    for `getter in roles.get("property", []) {
        if isinstance(`getter.signature, uni.FuncSignature)
            and (`getter.signature.return_type is not None)
            and not self._is_suppressed(W3043, `getter.loc) {
            return roles;
        }
    }
    return {};
}

impl JacAutoLintPass._impl_property_kind(nd: uni.ImplDef) -> str {
    if not nd.target {
        return "";
    }
    last = nd.target[-1];
    if isinstance(last, uni.Name) and last.value in ["getter", "setter", "deleter"] {
        return "";
    }
    decl = nd.decl_link;
    if isinstance(decl, uni.Ability) {
        return self._property_role_of_ability(decl);
    }

    arch = self._impl_owner_archetype(nd);
    prop_name = last.sym_name if last else "";
    if arch is None or not prop_name {
        return "";
    }
    roles = self._property_impl_roles(arch, prop_name);
    if "property" not in roles {
        return "";
    }

    pending: dict[str, uni.Ability] = {};
    for (role, accessors) in roles.items() {
        for acc in accessors {
            if acc.body is None and role not in pending {
                pending[role] = acc;
            }
        }
    }
    if not pending {
        return "";
    }
    if len(pending) == 1 {
        return list(pending.keys())[0];
    }

    spec = nd.spec if isinstance(nd.spec, uni.FuncSignature) else None;
    for role in ["property", "setter", "deleter"] {
        acc = pending.get(role);
        acc_sig = acc.signature if acc is not None else None;
        if (
            isinstance(acc_sig, uni.FuncSignature)
            and (spec is not None)
            and self._signatures_match(acc_sig, spec)
        ) {
            return role;
        }
    }

    takes_value = (spec is not None) and len(spec.params or []) > 0;
    returns_value = (spec is not None) and (spec.return_type is not None);
    if takes_value and "setter" in pending {
        return "setter";
    }
    if not takes_value and not returns_value and "deleter" in pending {
        return "deleter";
    }
    if "property" in pending {
        return "property";
    }
    return list(pending.keys())[0];
}

impl JacAutoLintPass._convert_property_impl(nd: uni.ImplDef) -> None {
    if self._is_file_excluded(nd.loc.mod_path) {
        return;
    }
    kind = self._impl_property_kind(nd);
    if kind == "" {
        return;
    }
    last_target = nd.target[-1];
    prop_name = last_target.value if isinstance(last_target, uni.Name) else "?";
    if not self.emit(W3043, node_override=nd, name=prop_name, type_name="...") {
        return;
    }
    if self.report_only {
        return;
    }

    kw = "getter" if kind == "property" else kind;
    acc_name = self._make_name_node(last_target, kw);
    dot_tok = last_target.gen_token(Tok.DOT);

    end_col = last_target.loc.col_end;
    dot_tok.c_start = end_col;
    dot_tok.c_end = end_col;
    acc_name.c_start = end_col;
    acc_name.c_end = end_col;
    nd._role_set(TargetRole, list(nd.target) + [acc_name]);
    new_kid: list[uni.UniNode] = [];
    for k in nd.kid {
        new_kid.append(k);
        if k is last_target {
            new_kid.append(dot_tok);
            new_kid.append(acc_name);
        }
    }
    nd.set_kids(new_kid);
    nd._invalidate_sub_node_tab();

    if nd.decorators {
        drop_ids: set[int] = set();
        for dec in nd.decorators {
            is_prop = (
                isinstance(dec, uni.Name)
                and dec.value in ["property", "cached_property"]
            )
                or (
                    isinstance(dec, uni.AtomTrailer)
                    and dec.is_attr
                    and isinstance(dec.right, uni.Name)
                    and dec.right.value in ["setter", "deleter"]
                );
            if is_prop {
                drop_ids.add(id(dec));
            }
        }
        if drop_ids {
            nd._role_set(
                DecoratorsRole,
                [
                    d
                    for d in nd.decorators
                    if id(d) not in drop_ids
                ]
                    or None
            );
            stripped_kid: list[uni.UniNode] = [];
            for k in nd.kid {
                if id(k) in drop_ids {
                    if (
                        stripped_kid
                        and isinstance(stripped_kid[-1], uni.Token)
                        and (stripped_kid[-1].name == Tok.DECOR_OP)
                    ) {
                        stripped_kid.pop();
                    }
                    continue;
                }
                stripped_kid.append(k);
            }
            nd.set_kids(stripped_kid);
            nd._invalidate_sub_node_tab();
        }
    }
    self.recalculate_parents(nd);
}
