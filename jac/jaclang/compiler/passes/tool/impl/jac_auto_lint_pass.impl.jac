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
    if not self.lint_enabled or self._is_suppressed(W3005) {
        return;
    }
    sig = ability_node.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return;
    }
    self._remove_empty_parens_from_sig(ability_node, sig, "signature");
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
    if not self.lint_enabled {
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
    if not self.lint_enabled {
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
    if not self.lint_enabled or self._is_suppressed(W3005) {
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
    if not self.lint_enabled {
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
    if not self.lint_enabled {
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
    if not self.lint_enabled {
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
    if not self.lint_enabled {
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
    if not self.lint_enabled {
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
    if not self.lint_enabled {
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
    parent: uni.BoolExpr,
    hasattr_node: uni.FuncCall,
    obj_expr: uni.Expr,
    attr_name: str
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

"""Process FuncCall to convert hasattr(obj, "attr") to null-safe access.

This replaces hasattr calls in the parent node's children with
the equivalent null-safe access expression.

Only converts in semantically safe patterns:
- IfElseExpr: obj.attr if hasattr(obj, "attr") else default
- BoolExpr: hasattr(obj, "attr") and obj.attr (guard-then-use with matching access)

Does NOT convert standalone boolean checks (IfStmt, WhileStmt, UnaryExpr, BinaryExpr,
or BoolExpr without matching attr access) because hasattr() returns True/False
while obj?.attr returns the attribute value which may be falsy ([], 0, "", None).
"""
impl JacAutoLintPass.exit_func_call(nd: uni.FuncCall) -> None {
    if not self.lint_enabled {
        return;
    }
    self._check_no_print(nd);
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
    parent = nd.parent;
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
    if not self._exprs_are_identical(if_else_node.value, if_else_node.condition) {
        return False;
    }
    parent = if_else_node.parent;
    if parent is None {
        return False;
    }
    if not self.emit(W3008, node_override=if_else_node) {
        return False;
    }
    if isinstance(if_else_node.else_value, uni.Null) {
        replacement = if_else_node.value;
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
        replacement = uni.BoolExpr(
            op=or_token,
            values=[if_else_node.value, if_else_node.else_value],
            kid=[if_else_node.value, or_token, if_else_node.else_value]
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
        if parent.value is if_else_node {
            parent.value = replacement;
        } elif parent.condition is if_else_node {
            parent.condition = replacement;
        } elif parent.else_value is if_else_node {
            parent.else_value = replacement;
        }
    } elif isinstance(parent, uni.BoolExpr) {
        new_values: list[uni.Expr] = [];
        for val in parent.values {
            if val is if_else_node {
                new_values.append(replacement);
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
    if not self.lint_enabled {
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
    if not self.lint_enabled or self._is_suppressed(W3007) {
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
    def _fix_token_positions(nd: uni.UniNode) -> None {
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
    if not self.lint_enabled or import_node.from_loc is None {
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
"""Build a structural key from a body for comparison (identical branch check)."""
impl JacAutoLintPass._body_to_key(body: list) -> str {
    parts: list[str] = [];
    for stmt in body {
        if isinstance(stmt, uni.Semi) {
            continue;
        }
        parts.append(type(stmt).__name__);
        if isinstance(stmt, uni.ExprStmt) and isinstance(stmt.expr, uni.FuncCall) {
            if isinstance(stmt.expr.target, uni.Name) {
                parts.append(stmt.expr.target.value);
            }
            if stmt.expr.params {
                for p in stmt.expr.params {
                    if isinstance(p, uni.String) {
                        parts.append(p.value);
                    } elif isinstance(p, uni.Name) {
                        parts.append(p.value);
                    } elif isinstance(p, uni.Int) {
                        parts.append(p.value);
                    }
                }
            }
        } elif isinstance(stmt, uni.Assignment) {
            for t in stmt.target {
                if isinstance(t, uni.Name) {
                    parts.append(t.value);
                }
            }
            if stmt.value and isinstance(stmt.value, uni.Name) {
                parts.append(stmt.value.value);
            }
        } elif isinstance(stmt, uni.ReturnStmt) {
            if stmt.expr {
                if isinstance(stmt.expr, uni.Bool) {
                    parts.append(stmt.expr.value);
                } elif isinstance(stmt.expr, uni.Name) {
                    parts.append(stmt.expr.value);
                }
            }
        }
    }
    return "|".join(parts);
}

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
    if_key = self._body_to_key(list(nd.body));
    else_key = self._body_to_key(list(nd.else_body.body));
    if if_key and else_key and if_key == else_key {
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
    if nd.body is not None {
        self._check_unnecessary_pass(list(nd.body), nd);
    }
}

"""Visitor: check ability bodies for unnecessary pass."""
impl JacAutoLintPass.exit_ability(ability_node: uni.Ability) -> None {
    if not self.lint_enabled {
        return;
    }
    if ability_node.body is not None {
        self._check_unnecessary_pass(list(ability_node.body), ability_node);
    }
}
