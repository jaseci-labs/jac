"""Initialize the JacAutoLintPass."""
impl JacAutoLintPass.postinit -> None {
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is not None and config.check?.lint {
        self._exclude_patterns = config.check.lint.exclude;
        self._project_root = str(config.project_root) if config.project_root else "";
    }
    super.postinit();
}

"""Check if a file path matches any exclude pattern."""
impl JacAutoLintPass._is_file_excluded(file_path: str) -> bool {
    import fnmatch;
    import os;
    if not self._exclude_patterns {
        return False;
    }
    rel_path = file_path;
    if self._project_root and file_path.startswith(self._project_root) {
        rel_path = file_path[len(self._project_root):].lstrip(os.sep);
    }
    for pattern in self._exclude_patterns {
        if fnmatch.fnmatch(rel_path, pattern)
        or fnmatch.fnmatch(os.path.basename(file_path), pattern) {
            return True;
        }
    }
    return False;
}

"""Remove empty parentheses from function signatures with no parameters."""
impl JacAutoLintPass.exit_ability(ability_node: uni.Ability) -> None {
    if not self.lint_enabled {
        return;
    }
    # Pop setter map pushed by _convert_usestate_vars.
    # Only pops when not report_only — matches the push guard in enter_ability.
    if not self.report_only and self._pending_setters {
        self._pending_setters.pop();
    }
    if not self.report_only and not self._is_suppressed(W3005) {
        sig = ability_node.signature;
        if isinstance(sig, uni.FuncSignature) {
            self._remove_empty_parens_from_sig(ability_node, sig, "signature");
        }
    }
    if ability_node.body is not None and isinstance(ability_node.body, list) {
        self._check_unnecessary_pass(list(ability_node.body), ability_node);
    }
    name = ability_node.name_spec.sym_name if ability_node.name_spec else "<anonymous>";
    self._check_unnecessary_none_return(
        ability_node, ability_node.body, ability_node.signature, name
    );
}

"""Remove @staticmethod decorator tokens and add static keyword to ability's kid list.

This preserves original token objects (for comment associations) while
removing only the @staticmethod decorator tokens and inserting the static keyword.
"""
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
    ability_node.kid = new_kids;
}

"""Process ability to convert @staticmethod decorator to static keyword, __init__/__post_init__ to init/postinit,
and combine consecutive has statements in function bodies."""
impl JacAutoLintPass.enter_ability(ability_node: uni.Ability) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if ability_node.decorators {
        has_staticmethod = False;
        for dec in ability_node.decorators {
            if isinstance(dec, uni.Name) and dec.value == "staticmethod" {
                has_staticmethod = True;
                break;
            }
        }
        if has_staticmethod and self.emit(W3001, node_override=ability_node) {
            if not ability_node.is_static {
                ability_node.is_static = True;
            }
            new_decorators: list[uni.Expr] = [
                dec
                for dec in ability_node.decorators
                if not (isinstance(dec, uni.Name) and dec.value == "staticmethod")
            ];
            ability_node.decorators = new_decorators or None;
        }
    }
    if not self._is_suppressed(W3001) and ability_node.is_static {
        self._remove_staticmethod_from_kids(ability_node);
    }
    # W3038: Convert useState hooks to has declarations before combining has statements
    if not self._is_suppressed(W3038) {
        self._convert_usestate_vars(ability_node);
    }
    if ability_node.body is not None and isinstance(ability_node.body, list) {
        old_body = list(ability_node.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body)
        and self.emit(W3002, node_override=ability_node) {
            ability_node.body = new_body;
            self.recalculate_parents(ability_node);
            new_body_set = set(id(s) for s in new_body);
            new_kid: list[uni.UniNode] = [];
            for kid in ability_node.kid {
                if not isinstance(kid, uni.ArchHas) or id(kid) in new_body_set {
                    new_kid.append(kid);
                }
            }
            ability_node.kid = new_kid;
        }
    }
    if not ability_node.is_method {
        return;
    }
    if not isinstance(ability_node.name_ref, uni.Name)
    or isinstance(ability_node.name_ref, uni.SpecialVarRef) {
        return;
    }
    new_tok: Tok | None = None;
    if ability_node.name_ref.value == "__init__" {
        new_tok = Tok.KW_INIT;
    } elif ability_node.name_ref.value == "__post_init__" {
        new_tok = Tok.KW_POST_INIT;
    }
    if new_tok is not None {
        init_name = ability_node.name_ref.value;
        if not self.emit(W3004, node_override=ability_node, name=init_name) {
            return;
        }
        old_ref = ability_node.name_ref;
        old_ref.name = new_tok.value;
        old_ref.value = new_tok.value;
        special_ref = uni.SpecialVarRef(var=old_ref);
        special_ref.parent = ability_node;
        ability_node.name_ref = special_ref;
        ability_node.name_spec = special_ref;
        for (idx, kid) in enumerate(ability_node.kid) {
            if kid is old_ref {
                ability_node.kid[idx] = special_ref;
                break;
            }
        }
    }
}

"""Process ImplDef to combine consecutive has statements."""
impl JacAutoLintPass.enter_impl_def(nd: uni.ImplDef) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    impl_node = nd;
    if not self._is_suppressed(W3010) {
        self._fix_impl_signature_mismatch(impl_node);
    }
    if impl_node.body is not None and isinstance(impl_node.body, list) {
        new_body = self.combine_consecutive_has(list(impl_node.body));
        if len(new_body) != len(impl_node.body)
        and self.emit(W3002, node_override=impl_node) {
            impl_node.body = new_body;
            self.recalculate_parents(impl_node);
        }
    }
}

"""Remove empty parentheses from impl signatures with no parameters."""
impl JacAutoLintPass.exit_impl_def(nd: uni.ImplDef) -> None {
    if not self.lint_enabled or self.report_only or self._is_suppressed(W3005) {
        return;
    }
    spec = nd.spec;
    if not isinstance(spec, uni.FuncSignature) {
        return;
    }
    self._remove_empty_parens_from_sig(nd, spec, "spec");
}

"""Process Enum to combine consecutive has statements.

This implementation avoids calling normalize() to preserve comment associations.
We update the kid list by removing merged statements and keeping the combined ones.
"""
impl JacAutoLintPass.enter_enum(nd: uni.Enum) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    enum_node = nd;
    if enum_node.body is not None and isinstance(enum_node.body, list) {
        old_body = list(enum_node.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body)
        and self.emit(W3002, node_override=enum_node) {
            enum_node.body = new_body;
            self.recalculate_parents(enum_node);
            new_body_set = set(id(s) for s in new_body);
            new_kid: list[uni.UniNode] = [];
            for kid in enum_node.kid {
                if not isinstance(kid, uni.ArchHas) or id(kid) in new_body_set {
                    new_kid.append(kid);
                }
            }
            enum_node.kid = new_kid;
        }
    }
}

"""Process Archetype to combine consecutive has statements.

This implementation avoids calling normalize() to preserve comment associations.
We update the kid list by removing merged statements and keeping the combined ones.
"""
impl JacAutoLintPass.enter_archetype(nd: uni.Archetype) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    arch = nd;
    if arch.body is not None and isinstance(arch.body, list) {
        old_body = list(arch.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body) and self.emit(W3002, node_override=arch) {
            arch.body = new_body;
            self.recalculate_parents(arch);
            new_body_set = set(id(s) for s in new_body);
            new_kid: list[uni.UniNode] = [];
            for kid in arch.kid {
                if not isinstance(kid, uni.ArchHas) or id(kid) in new_body_set {
                    new_kid.append(kid);
                }
            }
            arch.kid = new_kid;
        }
    }
}

"""Combine consecutive glob statements in a body list.

This implementation avoids calling normalize() to preserve comment associations.
Instead of creating a new node, we modify the first statement in place and
manually build the kid list to include assignments from merged statements.
"""
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
                for glob in merged_globs {
                    combined_assignments.extend(glob.assignments);
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
                base_glob.assignments = combined_assignments;
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

"""Combine consecutive has statements in a body list.

This implementation avoids calling normalize() to preserve comment associations.
Instead of creating a new node, we modify the first statement in place and
manually build the kid list to include vars from merged statements.
"""
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
                base_has.vars = combined_vars;
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

"""Check if two GlobalVars nodes can be combined (same access, frozen, no docstrings)."""
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

"""Check if two ArchHas nodes can be combined (same static, access, frozen)."""
impl JacAutoLintPass.can_combine_has(has1: uni.ArchHas, has2: uni.ArchHas) -> bool {
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

"""Create a new ModuleCode (with entry) block from a list of statements.

This implementation avoids calling normalize() to preserve comment associations.
We manually build the kid list with required tokens.
"""
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

"""Create a GlobalVars node from an assignment.

This implementation avoids calling normalize() to preserve comment associations.
We manually build the kid list with required tokens.
"""
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

"""Check if a statement is a module-level construct that can be extracted."""
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

"""Check if an assignment can be converted to glob."""
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
    return True;
}

"""Process module to transform with entry blocks in-place."""
impl JacAutoLintPass.enter_module(nd: uni.Module) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    module = nd;
    if self.main_module is None {
        self.main_module = module;
        for impl_mod in module.impl_mod {
            self.traverse(impl_mod);
        }
    }
    new_body: list[uni.UniNode] = [];
    for stmt in module.body {
        if self._is_future_annotations_import(stmt)
        and self.emit(W3009, node_override=stmt) {
            continue;
        }

        if isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            pending_entry_stmts: list[uni.UniNode] = [];
            for inner_stmt in stmt.body {
                extracted_stmt: uni.UniNode | None = None;

                if isinstance(inner_stmt, uni.Assignment)
                and self.can_convert_to_glob(inner_stmt) {
                    extracted_stmt = self.create_glob_from_assignment(inner_stmt);
                } elif self.is_module_level_construct(inner_stmt) {
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
    module.body = new_body;
    self.recalculate_parents(module);
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(new_body);
    module.set_kids(nodes=new_kid if len(new_kid) else [uni.EmptyToken()]);
}

"""Remove unnecessary backtick escaping from names that are not actual keywords.

Names only need backtick escaping if they conflict with:
- Python keywords (and, or, if, else, etc.)
- Jac reserved keywords from the grammar

This also handles SpecialVarRef where the underlying name should
never have backtick escaping since it's already recognized as a special keyword.
"""
impl JacAutoLintPass.enter_name(nd: uni.Name) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if not nd.is_kwesc or isinstance(nd, uni.SpecialVarRef) {
        return;
    }
    jac_keywords = set(TOKEN_MAP.values());
    python_keywords = set(keyword.kwlist);
    reserved = jac_keywords | python_keywords;
    raw_value = nd.value[1:] if nd.value.startswith("`") else nd.value;
    if raw_value not in reserved
    and self.emit(W3006, node_override=nd, name=raw_value) {
        nd.is_kwesc = False;
        if nd.name == Tok.KWESC_NAME {
            nd.name = Tok.NAME;
        }
    }
}

"""Remove backtick escaping from SpecialVarRef's underlying name.

SpecialVarRef wraps special keywords like init, postinit, self, super,
here, visitor. The underlying Name should never have backtick escaping
since these are already recognized as special tokens in the grammar.
"""
impl JacAutoLintPass.enter_special_var_ref(nd: uni.SpecialVarRef) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if nd.orig.is_kwesc and self.emit(W3006, node_override=nd, name=nd.orig.value) {
        nd.orig.is_kwesc = False;
        if nd.orig.name == Tok.KWESC_NAME {
            nd.orig.name = Tok.NAME;
        }
    }
    if nd.is_kwesc {
        nd.is_kwesc = False;
    }
}

"""Remove backtick escaping from BuiltinType nodes.

BuiltinType represents built-in types like str, int, float, bool, etc.
These should never have backtick escaping since they are recognized as
built-in type tokens in the grammar.
"""
impl JacAutoLintPass.enter_builtin_type(nd: uni.BuiltinType) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if nd.is_kwesc and self.emit(W3006, node_override=nd, name=nd.value) {
        nd.is_kwesc = False;
        if nd.name == Tok.KWESC_NAME {
            nd.name = Tok.NAME;
        }
    }
}

"""Convert hasattr(obj, "attr") to null-safe access.

This helper checks if a FuncCall is a hasattr call with exactly two arguments:
- First arg: any expression (the object)
- Second arg: a string literal (the attribute name)

If valid, creates and returns an AtomTrailer with is_null_ok=True.
Returns None if the call doesn't match the hasattr pattern.
"""
impl JacAutoLintPass._convert_hasattr_to_null_ok(
    nd: uni.FuncCall
) -> (uni.AtomTrailer | None) {
    if not isinstance(nd.target, uni.Name) {
        return None;
    }
    if nd.target.value != "hasattr" {
        return None;
    }
    if len(nd.params) != 2 {
        return None;
    }
    obj_expr = nd.params[0];
    attr_expr = nd.params[1];
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

"""Check if an AtomTrailer matches an object and attribute name.

Returns True if the AtomTrailer represents obj.attr where obj matches
the given object expression and attr matches the given attribute name.
"""
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

"""Convert an AtomTrailer to use null-safe access.

Takes an existing obj.attr AtomTrailer and converts it to use null-safe access
by setting is_null_ok=True. We surgically insert the NULL_OK token instead of
calling normalize() to preserve comment associations.
"""
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

"""Check if a BoolExpr has a matching obj.attr access in any operand other than the hasattr call.

This determines whether hasattr is being used as a guard before accessing the attribute
(safe to convert) vs a standalone existence check (not safe to convert).
"""
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

"""Convert getattr(obj, "attr", None) to null-safe access.

Matches the 3-arg form with explicit `None` default, which is exactly the
runtime behavior of `obj?.attr` (missing attribute or None base both yield
None). The 2-arg form `getattr(obj, "attr")` raises AttributeError on miss,
so it is not rewritten.

Requirements:
- First arg: any expression (the object)
- Second arg: a string literal that is a valid Python identifier and not a keyword
- Third arg: the literal `None`

Unlike hasattr, getattr(obj, "attr", None) returns the attribute value (not
a bool), so `obj?.attr` is a drop-in replacement in every expression context.
No parent-type guard is needed.
"""
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
    if not attr_name.isidentifier() or keyword.iskeyword(attr_name) {
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

"""Replace child `old` with `new` inside `parent`.

Updates both `parent.kid` (authoritative for pretty-printing and DocIR) and
the typed fields for common parent node types so later passes that read the
typed fields see the rewrite. Parent types not covered here fall through to
just the kid update, which is sufficient for formatter output.
"""
impl JacAutoLintPass._replace_child_in_parent(
    parent: uni.UniNode, old: uni.UniNode, new: uni.Expr
) -> None {
    new_kid: list[uni.UniNode] = [];
    for k in parent.kid {
        new_kid.append(new if k is old else k);
    }
    parent.kid = new_kid;
    if isinstance(parent, uni.CfgExpr) {
        if parent.expr is old {
            parent.expr = new;
        }
    } elif isinstance(parent, uni.Assignment) {
        if parent.value is old {
            parent.value = new;
        }
        new_targets: list[uni.Expr] = [];
        for t in parent.target {
            new_targets.append(new if t is old else t);
        }
        parent.target = new_targets;
    } elif isinstance(parent, uni.ExprStmt) {
        if parent.expr is old {
            parent.expr = new;
        }
    } elif isinstance(parent, uni.ReturnStmt) {
        if parent.expr is old {
            parent.expr = new;
        }
    } elif isinstance(parent, uni.BinaryExpr) {
        if parent.left is old {
            parent.left = new;
        }
        if parent.right is old {
            parent.right = new;
        }
    } elif isinstance(parent, uni.UnaryExpr) {
        if parent.operand is old {
            parent.operand = new;
        }
    } elif isinstance(parent, uni.CompareExpr) {
        if parent.left is old {
            parent.left = new;
        }
        new_rights: list[uni.Expr] = [];
        for r in parent.rights {
            new_rights.append(new if r is old else r);
        }
        parent.rights = new_rights;
    } elif isinstance(parent, uni.AtomTrailer) {
        if parent.target is old {
            parent.target = new;
        }
        if parent.right is old {
            parent.right = new;
        }
    } elif isinstance(parent, uni.FuncCall) {
        if parent.target is old {
            parent.target = new;
        }
        if parent.params is not None {
            new_params: list[(uni.Expr | uni.KWPair)] = [];
            for p in parent.params {
                new_params.append(new if p is old else p);
            }
            parent.params = new_params;
        }
    } elif isinstance(parent, uni.KWPair) {
        if parent.value is old {
            parent.value = new;
        }
    }
}

"""Process FuncCall to convert hasattr/getattr to null-safe access.

Handles two rewrites at the FuncCall exit:
- hasattr(obj, "attr")         -> obj?.attr  (W3007; restricted to safe patterns)
- getattr(obj, "attr", None)   -> obj?.attr  (W3039; safe in any expr context)

hasattr is only safe to rewrite in IfElseExpr / BoolExpr guard patterns
because hasattr() returns bool while obj?.attr returns the value (may be
falsy). getattr's 3-arg form already returns the value, so it rewrites
unconditionally.
"""
impl JacAutoLintPass.exit_func_call(nd: uni.FuncCall) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_no_print(nd);
    if self.report_only {
        return;
    }
    if not self._is_suppressed(W3039) {
        getattr_replacement = self._convert_getattr_to_null_ok(nd);
        if getattr_replacement is not None {
            parent = nd.parent;
            if parent is not None and self.emit(W3039, node_override=nd) {
                getattr_replacement.parent = parent;
                self._replace_child_in_parent(parent, nd, getattr_replacement);
                return;
            }
        }
    }
    if self._is_suppressed(W3007) {
        return;
    }
    replacement = self._convert_hasattr_to_null_ok(nd);
    if replacement is None {
        return;
    }
    obj_expr = nd.params[0];
    attr_expr = nd.params[1];
    attr_name = self._extract_string_literal_value(attr_expr);
    # Since BoolExpr operands and IfElseExpr branches are now CfgExpr nodes,
    # the FuncCall's direct parent is the CfgExpr wrapper, not the enclosing
    # BoolExpr/IfElseExpr. Step through the wrapper to reach the semantic
    # parent so the hasattr→obj?.attr rewrite still fires.
    cfg_wrapper: uni.CfgExpr | None = None;
    parent = nd.parent;
    if isinstance(parent, uni.CfgExpr) {
        cfg_wrapper = parent;
        parent = parent.parent;
    }
    if parent is None {
        return;
    }
    # Only convert in semantically safe patterns.
    # hasattr() returns bool (existence check), obj?.attr returns the value.
    # These differ when the attribute value is falsy ([], 0, "", None).
    if isinstance(parent, uni.IfElseExpr) {
        # Safe: ternary guard pattern
    } elif isinstance(parent, uni.BoolExpr) {
        # Only safe when another operand accesses the same obj.attr (guard-then-use)
        if attr_name is None
        or not self._bool_expr_has_matching_access(parent, nd, obj_expr, attr_name) {
            return;
        }
    } else {
        # IfStmt, WhileStmt, UnaryExpr, BinaryExpr — standalone boolean check, not safe
        return;
    }
    if not self.emit(W3007, node_override=nd) {
        return;
    }
    if cfg_wrapper is not None {
        replacement.parent = cfg_wrapper;
        cfg_wrapper.expr = replacement;
        cfg_wrapper.kid = [replacement];
        if isinstance(parent, uni.IfElseExpr)
        and parent.condition is cfg_wrapper
        and attr_name is not None
        and isinstance(parent.value.expr, uni.AtomTrailer)
        and self._is_matching_attr_access(parent.value.expr, obj_expr, attr_name) {
            self._make_null_ok(parent.value.expr);
        }
        return;
    }
    replacement.parent = parent;
    if isinstance(parent, uni.IfElseExpr) {
        if parent.condition is nd {
            parent.condition = replacement;
            if attr_name is not None and isinstance(parent.value, uni.AtomTrailer) {
                if self._is_matching_attr_access(parent.value, obj_expr, attr_name) {
                    self._make_null_ok(parent.value);
                }
            }
        } elif parent.value is nd {
            parent.value = replacement;
        } elif parent.else_value is nd {
            parent.else_value = replacement;
        }
    } elif isinstance(parent, uni.BoolExpr) {
        new_values: list[uni.Expr] = [];
        for val in parent.values {
            if val is nd {
                new_values.append(replacement);
            } else {
                new_values.append(val);
            }
        }
        parent.values = new_values;
    }
    new_kids: list[uni.UniNode] = [];
    for kid in parent.kid {
        if kid is nd {
            new_kids.append(replacement);
        } else {
            new_kids.append(kid);
        }
    }
    parent.kid = new_kids;
}

"""Recursively collect all AtomTrailer nodes from a subtree."""
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

"""Build a string key from an expression without calling unparse().

This avoids triggering normalize() which corrupts token locations.
Returns None if the expression is too complex to build a key from.
"""
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
        return expr.name.value if expr.name else None;
    }
    # Literals
    if isinstance(expr, (uni.Int, uni.Float, uni.String, uni.Bool, uni.Null)) {
        return str(expr.value);
    }
    # Comparison expressions: x > 0
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
    # Binary expressions: a + b
    if isinstance(expr, uni.BinaryExpr) and expr.op is not None {
        left_key = self._expr_to_key(expr.left);
        right_key = self._expr_to_key(expr.right);
        if left_key is not None and right_key is not None {
            op_val = expr.op.value if isinstance(expr.op, uni.Token) else str(expr.op);
            return f"{left_key} {op_val} {right_key}";
        }
    }
    # Unary expressions: not x
    if isinstance(expr, uni.UnaryExpr) and expr.op is not None {
        operand_key = self._expr_to_key(expr.operand);
        if operand_key is not None {
            op_val = expr.op.value if isinstance(expr.op, uni.Token) else str(expr.op);
            return f"{op_val} {operand_key}";
        }
    }
    return None;
}

"""Get a unique key for an AtomTrailer based on its target and attribute.

Returns a string like "obj.attr" that can be used to identify matching accesses.
Returns None if the trailer is not a simple attribute access.
"""
impl JacAutoLintPass._get_trailer_key(trailer: uni.AtomTrailer) -> (str | None) {
    if not trailer.is_attr {
        return None;
    }
    if not isinstance(trailer.right, uni.Name) {
        return None;
    }
    attr_name = trailer.right.value;
    target_key = self._expr_to_key(trailer.target);
    if target_key is not None {
        null_ok = "?" if trailer.is_null_ok else "";
        return f"{target_key}{null_ok}.{attr_name}";
    }
    return None;
}

"""Check if two expressions are structurally identical without calling unparse().

This avoids triggering normalize() which corrupts token locations.
"""
impl JacAutoLintPass._exprs_are_identical(expr1: uni.Expr, expr2: uni.Expr) -> bool {
    if expr1 is expr2 {
        return True;
    }
    if type(expr1) != type(expr2) {
        return False;
    }
    if isinstance(expr1, uni.Name) and isinstance(expr2, uni.Name) {
        return expr1.value == expr2.value;
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
    if isinstance(expr1, uni.SpecialVarRef) and isinstance(expr2, uni.SpecialVarRef) {
        if expr1.name and expr2.name {
            return expr1.name.value == expr2.name.value;
        }
        return expr1.name is None and expr2.name is None;
    }
    key1 = self._expr_to_key(expr1);
    key2 = self._expr_to_key(expr2);
    if key1 is not None and key2 is not None {
        return key1 == key2;
    }
    return False;
}

"""Convert IfElseExpr to simplified form when value equals condition.

Transforms:
- x?.attr if x?.attr else None -> x?.attr (since null-safe already returns None)
- x?.attr if x?.attr else default -> x?.attr or default

This only applies when the value and condition are identical expressions.
This implementation avoids calling normalize() to preserve comment associations.
"""
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
        replacement.parent = parent;
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
        replacement.parent = parent;
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
        parent.kid = new_kids;
    }
    if isinstance(parent, uni.Assignment) {
        if parent.value is if_else_node {
            parent.value = replacement;
        }
    } elif isinstance(parent, uni.IfElseExpr) {
        if parent.value.expr is if_else_node {
            parent.value = uni.CfgExpr(expr=replacement, kid=[replacement]);
        } elif parent.condition.expr is if_else_node {
            parent.condition = uni.CfgExpr(expr=replacement, kid=[replacement]);
        } elif parent.else_value.expr is if_else_node {
            parent.else_value = uni.CfgExpr(expr=replacement, kid=[replacement]);
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
        parent.values = new_values;
    }
    return True;
}

"""Propagate null-safe access within IfElseExpr and simplify ternary to or.

When an expression contains both null-safe and regular accesses for the same
object and attribute, convert the regular accesses to null-safe.

Also converts patterns like:
- x?.attr if x?.attr else None -> x?.attr (since null-safe already returns None)
- x?.attr if x?.attr else default -> x?.attr or default
"""
impl JacAutoLintPass.exit_if_else_expr(if_else_node: uni.IfElseExpr) -> None {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if not self._is_suppressed(W3008) and self._convert_ternary_to_or(if_else_node) {
        return;
    }
    if self._is_suppressed(W3007) {
        return;
    }
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(if_else_node, trailers);
    if len(trailers) < 2 {
        return;
    }
    null_ok_keys: set = set();
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and trailer.is_null_ok {
            key = self._get_trailer_key(trailer);
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
            key = self._get_trailer_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
            }
        }
    }
}

"""Propagate null-safe access within BoolExpr (and/or expressions).

When an expression contains both null-safe and regular accesses for the same
object and attribute, convert the regular accesses to null-safe.
"""
impl JacAutoLintPass.exit_bool_expr(bool_node: uni.BoolExpr) -> None {
    if not self.lint_enabled or self.report_only or self._is_suppressed(W3007) {
        return;
    }
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(bool_node, trailers);
    if len(trailers) < 2 {
        return;
    }
    null_ok_keys: set = set();
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and trailer.is_null_ok {
            key = self._get_trailer_key(trailer);
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
            key = self._get_trailer_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
            }
        }
    }
}

"""Check if a statement is an `import from __future__ { annotations }` import.

This import is not needed in Jac since Jac already uses deferred annotation
evaluation by default. Removing it cleans up code converted from Python.
"""
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

"""Fix signature mismatch between declaration and implementation.

When an impl's signature doesn't match its declaration, copy the declaration's
signature to the implementation to ensure consistency.

This works by looking up the declaration via symbol table since decl_link may
not be set yet when this pass runs during formatting.

Supports nested classes: for `impl OuterClass.InnerClass.method`, it navigates
through OuterClass -> InnerClass -> method to find the correct declaration.
"""
impl JacAutoLintPass._fix_impl_signature_mismatch(impl_node: uni.ImplDef) -> None {
    decl: uni.Ability | None = None;
    if isinstance(impl_node.decl_link, uni.Ability) {
        decl = impl_node.decl_link;
    } else {
        if not impl_node.target or len(impl_node.target) < 2 {
            return;
        }
        root_arch_name = impl_node.target[0].sym_name if impl_node.target[0] else None;
        ability_name = impl_node.target[-1].sym_name if impl_node.target[-1] else None;
        if not root_arch_name or not ability_name {
            return;
        }
        if self.main_module is None {
            return;
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
        if arch_node is None or not arch_node.body {
            return;
        }
        for i in range(1, len(impl_node.target) - 1) {
            nested_name = impl_node.target[i].sym_name if impl_node.target[i] else None;

            if not nested_name {
                return;
            }
            found_nested = False;

            for member in arch_node.body {
                if isinstance(member, uni.Archetype) {
                    if member.name_spec and member.name_spec.sym_name == nested_name {
                        arch_node = member;
                        found_nested = True;
                        break;
                    }
                }
            }

            if not found_nested or not arch_node.body {
                return;
            }
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
    if decl is None or decl.signature is None {
        return;
    }
    if not isinstance(impl_node.spec, uni.FuncSignature) {
        return;
    }
    decl_sig = decl.signature;
    impl_sig = impl_node.spec;
    if self._signatures_match(decl_sig, impl_sig) {
        return;
    }
    if not self.emit(W3010, node_override=impl_node) {
        return;
    }
    import copy;
    # Temporarily detach parent to prevent deepcopy from cloning the entire AST
    saved_parent = decl.signature.parent;
    decl.signature.parent = None;
    new_sig = copy.deepcopy(decl.signature);
    decl.signature.parent = saved_parent;
    new_sig.parent = impl_node;
    old_spec = impl_node.spec;
    # Copy position info from old spec's tokens to new spec's tokens
    # so the formatter places comments correctly relative to the signature
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
    impl_node.spec = new_sig;
    new_kids: list[uni.UniNode] = [];
    for kid in impl_node.kid {
        if kid is old_spec {
            new_kids.append(new_sig);
        } else {
            new_kids.append(kid);
        }
    }
    impl_node.kid = new_kids;
}

"""Check if two FuncSignatures match structurally without calling unparse().

Compares parameter counts and names to determine if signatures are equivalent.
"""
impl JacAutoLintPass._signatures_match(
    decl_sig: uni.FuncSignature, impl_sig: uni.FuncSignature
) -> bool {
    if (
        len(decl_sig.params) != len(impl_sig.params)
        or len(decl_sig.posonly_params) != len(impl_sig.posonly_params)
        or len(decl_sig.kwonlyargs) != len(impl_sig.kwonlyargs)
        or (decl_sig.varargs is None) != (impl_sig.varargs is None)
        or (decl_sig.kwargs is None) != (impl_sig.kwargs is None)
        or (decl_sig.return_type is None) != (impl_sig.return_type is None)
    ) {
        return False;
    }
    for (i, decl_param) in enumerate(decl_sig.params) {
        impl_param = impl_sig.params[i];

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

"""Remove standalone semicolons after `import from X { ... }` inside code blocks.

When users write `import from X { ... };` inside a function/ability, the semicolon
is parsed as a separate Semi statement. This removes those unnecessary semicolons.
"""
impl JacAutoLintPass.enter_import(import_node: uni.Import) -> None {
    if not self.lint_enabled or self.report_only or import_node.from_loc is None {
        return;
    }
    parent = import_node.parent;
    if parent is None or not parent?.body or not isinstance(parent?.body, list) {
        return;
    }
    body = parent.body;
    try {
        idx = body.index(import_node);
    } except ValueError {
        return;
    }
    if idx + 1 < len(body)
    and isinstance(body[idx + 1], uni.Semi)
    and self.emit(W3011, node_override=import_node) {
        semi = body[idx + 1];
        parent.body = [
            s
            for s in body
            if s is not semi
        ];
        parent.kid = [
            k
            for k in parent.kid
            if k is not semi
        ];
    }
}

"""Remove empty parentheses from a function signature with no parameters.

This is a shared helper used by both exit_ability and exit_impl_def.
Handles both cases:
- No params, no return type: Remove the entire signature
- No params, with return type: Remove just LPAREN/RPAREN, keep return type

Args:
    target_node: The parent node (Ability or ImplDef)
    sig: The FuncSignature to modify
    sig_attr: The attribute name on the node that holds the signature
              ("signature" for Ability, "spec" for ImplDef)
"""
impl JacAutoLintPass._remove_empty_parens_from_sig(
    target_node: uni.UniNode, sig: uni.FuncSignature, sig_attr: str
) -> None {
    has_params = bool(
        sig.posonly_params or sig.params or sig.varargs or sig.kwonlyargs or sig.kwargs
    );
    if has_params {
        return;
    }
    if sig.return_type is None {
        if not self.emit(W3005, node_override=target_node) {
            return;
        }
        setattr(target_node, sig_attr, None);
        new_kid: list[uni.UniNode] = [];
        for kid in target_node.kid {
            if kid is not sig {
                new_kid.append(kid);
            }
        }
        target_node.kid = new_kid;
    } else {
        has_parens = any(
            isinstance(kid, uni.Token) and kid.name in (Tok.LPAREN, Tok.RPAREN)
            for kid in sig.kid
        );
        if not has_parens {
            return;
        }
        if not self.emit(W3005, node_override=target_node) {
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

"""Check for bare print() calls and report a warning.

Bare print() calls should use the console abstraction instead.
Only flags calls where the target is a simple Name "print" (not console.print, etc.).
"""
impl JacAutoLintPass._check_no_print(nd: uni.FuncCall) -> None {
    if self.report_only or not isinstance(nd.target, uni.Name) {
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

"""Extract the string value from a String or MultiString expression.

Returns the unquoted string value, or None if the expression is not a simple string literal.
Used by hasattr conversion to extract attribute names.
"""
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# New lint checks (W3020-W3036)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""W3020: Warn on unnecessary 'pass' in a body that has other statements."""
impl JacAutoLintPass._check_unnecessary_pass(body: list, `node: uni.UniNode) -> None {
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
        # CtrlStmt form (legacy / Python-originated AST)
        if isinstance(stmt, uni.CtrlStmt)
        and stmt.ctrl
        and isinstance(stmt.ctrl, uni.Token)
        and stmt.ctrl.value == "pass" {
            self.emit(W3020, node_override=stmt);
        }
        # ExprStmt > Name("pass") form (RD parser)
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

"""W3021: Warn when else block follows an if that always returns."""
impl JacAutoLintPass._check_unnecessary_else_after_return(nd: uni.IfStmt) -> None {
    if self._is_suppressed(W3021) {
        return;
    }
    # Check if the if-body ends with a return
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
    # Check if there's an else clause
    else_node = nd.else_body;
    if else_node is not None and isinstance(else_node, uni.ElseStmt) {
        self.emit(W3021, node_override=else_node);
    }
}

"""W3022: Warn when else contains a single if that could be elif."""
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

"""W3023: Warn on 'if cond { return True; } else { return False; }' pattern."""
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

"""W3024: Warn on repeated conditions in if/elif chain."""
impl JacAutoLintPass._check_repeated_condition(nd: uni.IfStmt) -> None {
    if self._is_suppressed(W3024) {
        return;
    }
    conditions: list[str] = [];
    cond_key = self._expr_to_key(nd.condition);
    if cond_key is not None {
        conditions.append(cond_key);
    }
    # Walk elif chain
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

"""W3025: Warn when if and else branches are identical."""
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
    # Cheap guard: bail if top-level statement kinds differ.
    for (a, b) in zip(if_body, else_body) {
        if type(a) is not type(b) {
            return;
        }
    }
    # Definitive comparison: canonical unparse of each branch must match.
    if_src = "".join(s.unparse() for s in if_body);
    else_src = "".join(s.unparse() for s in else_body);
    if if_src == else_src {
        self.emit(W3025, node_override=nd);
    }
}

"""W3030: Warn when a function has too many parameters."""
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
    # Subtract 'self' parameter if present
    all_params: list[uni.ParamVar] = list(nd.posonly_params);
    if nd.params {
        all_params.extend(nd.params);
    }
    if all_params and all_params[0].name.value == "self" {
        count -= 1;
    }
    if count > threshold {
        self.emit(W3030, node_override=nd, count=count, threshold=threshold);
    }
}

"""W3035: Warn on 'is' comparison with a literal (except None/True/False)."""
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
        # None, True, False are singletons — 'is' is correct for them
        if isinstance(right, (uni.Null, uni.Bool)) {
            continue;
        }
        if isinstance(right, (uni.Int, uni.Float, uni.String)) {
            self.emit(W3035, node_override=nd);
        }
    }
}

"""W3036: Warn on mutable default argument (list, dict, set)."""
impl JacAutoLintPass._check_mutable_default(nd: uni.ParamVar) -> None {
    if self._is_suppressed(W3036) {
        return;
    }
    if nd.value is None {
        return;
    }
    default = nd.value;
    if isinstance(default, uni.ListVal) {
        self.emit(W3036, node_override=nd, type="list");
    } elif isinstance(default, uni.DictVal) {
        self.emit(W3036, node_override=nd, type="dict");
    } elif isinstance(default, uni.SetVal) {
        self.emit(W3036, node_override=nd, type="set");
    }
}

"""Visitor: check if-statement lint rules on exit."""
impl JacAutoLintPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_pass(list(nd.body), nd);
    self._check_unnecessary_else_after_return(nd);
    self._check_return_bool_simplification(nd);
    self._check_repeated_condition(nd);
    self._check_identical_branches(nd);
}

"""Visitor: check else-statement lint rules."""
impl JacAutoLintPass.enter_else_stmt(nd: uni.ElseStmt) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_pass(list(nd.body), nd);
    self._check_nested_if_to_elif(nd);
}

"""Visitor: check compare expressions for 'is' with literal."""
impl JacAutoLintPass.exit_compare_expr(nd: uni.CompareExpr) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_is_with_literal(nd);
}

"""Visitor: check function signatures for too many params."""
impl JacAutoLintPass.exit_func_signature(nd: uni.FuncSignature) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_too_many_params(nd);
}

"""Visitor: check parameter variables for mutable defaults."""
impl JacAutoLintPass.enter_param_var(nd: uni.ParamVar) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_mutable_default(nd);
}

"""Visitor: check archetype bodies for unnecessary pass."""
impl JacAutoLintPass.exit_archetype(nd: uni.Archetype) -> None {
    if not self.lint_enabled {
        return;
    }
    if nd.body is not None and isinstance(nd.body, list) {
        self._check_unnecessary_pass(list(nd.body), nd);
    }
}

"""Visitor: check lambda bodies for unnecessary -> None."""
impl JacAutoLintPass.exit_lambda_expr(nd: uni.LambdaExpr) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_none_return(nd, nd.body, nd.signature, "lambda");
}

"""W3037: Warn on unnecessary '-> None' return type annotation."""
impl JacAutoLintPass._check_unnecessary_none_return(
    nd: (uni.Ability | uni.LambdaExpr),
    body: (list | uni.Expr),
    sig: (uni.FuncSignature | None),
    name: str
) -> None {
    if self._is_suppressed(W3037) {
        return;
    }
    # Must have a FuncSignature with an explicit return_type
    if not isinstance(sig, uni.FuncSignature) or sig.return_type is None {
        return;
    }
    # Check if return type is explicitly 'None'
    ret = sig.return_type;
    is_none_return = (
        isinstance(ret, uni.Null)
        or (isinstance(ret, uni.BuiltinType) and ret.value == "None")
        or (isinstance(ret, uni.Name) and ret.value == "None")
    );
    if not is_none_return {
        return;
    }
    # Only check block bodies (list of statements), not expression bodies
    if not isinstance(body, list) {
        return;
    }
    # If body has no return statements, -> None is unnecessary
    if not self._body_has_return_stmt(body) {
        if not self.emit(W3037, node_override=sig.return_type, name=name) {
            return;
        }
        if self.report_only {
            return;
        }
        # Auto-fix: remove '-> None' from FuncSignature
        sig.return_type = None;
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
            # Signature had only -> None (no params): remove it entirely.
            # All downstream passes (pyast_gen, esast_gen, unparse, normalize,
            # doc_ir_gen) already guard .signature access with None/isinstance checks.
            if isinstance(nd, uni.LambdaExpr) {
                nd.signature = None;
            } elif isinstance(nd, uni.Ability) {
                nd.signature = None;
            }
            nd.kid = [
                k
                for k in nd.kid
                if k is not sig
            ];
        }
    }
}

"""Check if a body contains any return statements (not in nested functions/lambdas)."""
impl JacAutoLintPass._body_has_return_stmt(body: list) -> bool {
    for stmt in body {
        if isinstance(stmt, uni.ReturnStmt) {
            return True;
        }
        # Recurse into control flow but NOT into nested Ability/LambdaExpr
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
        if isinstance(stmt, uni.InForStmt) or isinstance(stmt, uni.WhileStmt) {
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
            for case in stmt.cases {
                if self._body_has_return_stmt(list(case.body)) {
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# useState-to-has conversion (W3038)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""Check if a statement is a useState destructuring assignment.

Matches: [varName, setterName] = useState(initialValue)

Returns (var_name, setter_name, initial_value_node) tuple if matched, else None.
"""
impl JacAutoLintPass._is_usestate_assignment(
    stmt: uni.UniNode
) -> (tuple[str, str, uni.Expr | None] | None) {
    if not isinstance(stmt, uni.Assignment) {
        return None;
    }
    # Right side must be a FuncCall to useState
    rhs = stmt.value;
    if not isinstance(rhs, uni.FuncCall) {
        return None;
    }
    if not isinstance(rhs.target, uni.Name) or rhs.target.value != "useState" {
        return None;
    }
    # Left side must be a single ListVal with exactly two Name elements
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

"""Infer a Jac type string from the initial useState value.

Maps common literal types to their Jac equivalents.
Falls back to 'any' for complex expressions.
TODO: this is ad-hoc, need to do proper type inference.
"""
impl JacAutoLintPass._infer_type_from_usestate_value(value: (uni.Expr | None)) -> str {
    if value is None {
        return "Any";
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
    return "Any";
}

"""Create an ArchHas (has declaration) node from useState info.

Produces: has var_name: type_str = init_value;
Uses ref_node for source-location metadata on generated tokens.
"""
impl JacAutoLintPass._create_has_from_usestate(
    ref_node: uni.UniNode, var_name: str, type_str: str, init_value: (uni.Expr | None)
) -> uni.ArchHas {
    # Build the Name node for the variable
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
    # Build the type Name node
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
    colon_tok = ref_node.gen_token(Tok.COLON);  # Use ref_node to generate tokens
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
    # ArchHas kid: [has_kw, has_var, semi] — must be non-empty at construction
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


"""Convert useState hooks inside an ability to has declarations.

Detects useState assignments, creates has nodes in their place, and pushes
the setter→var mapping onto _pending_setters so that exit_expr_stmt can
replace setter calls as the visitor naturally walks into child nodes.
"""
impl JacAutoLintPass._convert_usestate_vars(ability_node: uni.Ability) -> None {
    if not ability_node.body or not isinstance(ability_node.body, list) {
        return;
    }
    new_body: list[uni.UniNode] = [];
    replaced: dict[int, uni.ArchHas] = {};  # old stmt id -> new ArchHas for kid rebuild
    setters: dict[str, str] = {};  # setter_name -> var_name for this ability
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
        has_node.parent = ability_node;
        new_body.append(has_node);
        replaced[id(stmt)] = has_node;
        setters[setter_name] = var_name;
    }
    if replaced {
        self._did_convert_usestate = True;
        ability_node.body = new_body;
        self.recalculate_parents(ability_node);
        ability_node.kid = [replaced.get(id(k), k) for k in ability_node.kid];
    }
    # Always push (even if empty) so exit_ability can always pop safely.
    # Without this, a nested def exiting would pop the outer ability's map.
    self._pending_setters.append(setters);
}

"""W3038: rewrite setterName(expr) → varName = expr for each ExprStmt.
_pending_setters is a per-ability stack so nested abilities don't interfere.
"""
impl JacAutoLintPass.exit_expr_stmt(nd: uni.ExprStmt) -> None {
    if not self.lint_enabled or self.report_only or not self._pending_setters {
        return;
    }
    call_node = nd.expr;
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
    parent = nd.parent;
    if parent is None {
        return;
    }
    value_expr = call_node.params[0];
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
    assign.parent = parent;
    # Swap nd -> assign in parent.body and parent.kid
    if isinstance(parent?.body, list) {
        parent.body = [assign if s is nd else s for s in parent.body];
    }
    parent.kid = [assign if k is nd else k for k in parent.kid];
}

"""Remove useState from each import statement in the module, dropping the whole statement
if useState was the only item, or rebuilding kids with correct commas if it was partial."""
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
        stmt.items = [
            item
            for item in stmt.items
            if item not in usestate_items
        ];
        if not stmt.items {
            removed.add(id(stmt));  # useState was the only import — drop whole stmt
            continue;
        }
        # Partial removal — strip useState items then fix orphaned commas.
        # Handles all 3 positions: ({ useState, X }), ({ X, useState }), ({ X, useState, Y })
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
    nd.body = new_body;
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

"""W3038: drop useState from imports after all useState hooks have been converted."""
impl JacAutoLintPass.exit_module(nd: uni.Module) -> None {
    self._strip_usestate_imports(nd);
}
