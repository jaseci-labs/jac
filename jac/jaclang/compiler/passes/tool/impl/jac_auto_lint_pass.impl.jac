"""Initialize the JacAutoLintPass."""
impl JacAutoLintPass.init(ir_in: uni.Module, prog: Any) -> None {
    super.init(ir_in, prog);
}

"""Remove empty parentheses from function signatures with no parameters."""
impl JacAutoLintPass.exit_ability(ability_node: uni.Ability) -> None {
    if not self.lint_enabled {
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
    # First pass: check if static keyword already exists and find @staticmethod location
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

        # Check for @ followed by staticmethod Name
        if (isinstance(kid, uni.Token) and kid.value == "@" and (i + 1) < len(kids)) {
            next_kid = kids[i + 1];
            if isinstance(next_kid, uni.Name) and next_kid.value == "staticmethod" {
                # Skip both @ and staticmethod
                i += 2;
                skip_next_ws = True;
                continue;
            }
        }

        # Skip whitespace/newline after removed decorator
        if skip_next_ws and isinstance(kid, uni.Token) {
            if kid.name in ("WS", "NL", "NEWLINE") or kid.value in ("\n", " ", "") {
                i += 1;
                skip_next_ws = False;
                continue;
            }
        }
        skip_next_ws = False;

        # Insert static keyword before def/can if not already present
        if (
            not has_static_kw
            and isinstance(kid, uni.Token)
            and kid.name in (Tok.KW_DEF, Tok.KW_CAN)
        ) {
            static_kw = ability_node.gen_token(Tok.KW_STATIC);
            # Copy location from @staticmethod for comment association
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
    # Handle @staticmethod decorator conversion
    if ability_node.decorators {
        has_staticmethod = False;
        for dec in ability_node.decorators {
            if isinstance(dec, uni.Name) and dec.value == "staticmethod" {
                has_staticmethod = True;
                break;
            }
        }
        if has_staticmethod {
            # Set static flag if not already set
            if not ability_node.is_static {
                ability_node.is_static = True;
            }
            # Remove @staticmethod from decorators list
            new_decorators: list[uni.Expr] = [
                dec
                for dec in ability_node.decorators
                if not (isinstance(dec, uni.Name) and dec.value == "staticmethod")
            ];
            ability_node.decorators = new_decorators or None;
        }
    }
    # Surgically remove @staticmethod tokens from kids list
    # (preserves original tokens for comment associations)
    if ability_node.is_static {
        self._remove_staticmethod_from_kids(ability_node);
    }
    # Combine consecutive has statements in ability body (applies to both methods and functions)
    if ability_node.body is not None and isinstance(ability_node.body, list) {
        old_body = list(ability_node.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body) {
            ability_node.body = new_body;
            self.recalculate_parents(ability_node);
            # Update kid list: remove merged-away statements, keep everything else
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
    # Handle __init__ and __post_init__ conversion (only for methods)
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
impl JacAutoLintPass.enter_impl_def(node: uni.ImplDef) -> None {
    if not self.lint_enabled {
        return;
    }
    impl_node = node;
    # Fix signature mismatch between decl and impl
    self._fix_impl_signature_mismatch(impl_node);
    # Combine consecutive has statements
    if impl_node.body is not None and isinstance(impl_node.body, list) {
        new_body = self.combine_consecutive_has(list(impl_node.body));
        if len(new_body) != len(impl_node.body) {
            impl_node.body = new_body;
            self.recalculate_parents(impl_node);
        }
    }
}

"""Remove empty parentheses from impl signatures with no parameters."""
impl JacAutoLintPass.exit_impl_def(<>node: uni.ImplDef) -> None {
    if not self.lint_enabled {
        return;
    }
    spec = <>node.spec;
    if not isinstance(spec, uni.FuncSignature) {
        return;
    }
    self._remove_empty_parens_from_sig(<>node, spec, "spec");
}

"""Process Enum to combine consecutive has statements.

This implementation avoids calling normalize() to preserve comment associations.
We update the kid list by removing merged statements and keeping the combined ones.
"""
impl JacAutoLintPass.enter_enum(node: uni.Enum) -> None {
    if not self.lint_enabled {
        return;
    }
    enum_node = node;
    if enum_node.body is not None and isinstance(enum_node.body, list) {
        old_body = list(enum_node.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body) {
            enum_node.body = new_body;
            self.recalculate_parents(enum_node);
            # Update kid list: remove merged-away statements, keep everything else
            # The merged statements are those in old_body but not in new_body
            new_body_set = set(id(s) for s in new_body);
            new_kid: list[uni.UniNode] = [];
            for kid in enum_node.kid {
                # Keep kid if it's not a body item, or if it's in the new body
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
impl JacAutoLintPass.enter_archetype(node: uni.Archetype) -> None {
    if not self.lint_enabled {
        return;
    }
    arch = node;
    if arch.body is not None and isinstance(arch.body, list) {
        old_body = list(arch.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body) {
            arch.body = new_body;
            self.recalculate_parents(arch);
            # Update kid list: remove merged-away statements, keep everything else
            # The merged statements are those in old_body but not in new_body
            new_body_set = set(id(s) for s in new_body);
            new_kid: list[uni.UniNode] = [];
            for kid in arch.kid {
                # Keep kid if it's not an ArchHas body item, or if it's in the new body
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
            # Start collecting consecutive compatible glob statements
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
            # If we combined multiple glob statements, merge them without normalize
            if len(merged_globs) > 1 {
                # Collect all assignments
                combined_assignments: list[uni.Assignment] = [];
                for glob in merged_globs {
                    combined_assignments.extend(glob.assignments);
                }
                # Build new kid list preserving tokens from base_glob
                # Structure: [doc?] [client?] glob [access?] assign1, assign2, ...
                new_kid: list[uni.UniNode] = [];
                # Copy prefix tokens from base_glob (everything before first assignment)
                for kid in base_glob.kid {
                    if kid in base_glob.assignments {
                        break;
                    }
                    new_kid.append(kid);
                }
                # Add all assignments with commas between them
                # Note: Assignments from entry blocks may have trailing semicolons in their
                # kid lists - we need to strip those before combining
                for (idx, assign) in enumerate(combined_assignments) {
                    if idx > 0 {
                        new_kid.append(base_glob.gen_token(Tok.COMMA));
                    }
                    # Strip trailing semicolon from assignment if present
                    if assign.kid and isinstance(assign.kid[-1], uni.Semi) {
                        # Create a copy of kids without the trailing semicolon
                        assign_kids = list(assign.kid[:-1]);
                        assign.set_kids(nodes=assign_kids);
                    }
                    new_kid.append(assign);
                }
                # Add semicolon at the end (required by grammar)
                new_kid.append(base_glob.gen_token(Tok.SEMI));
                # Update base_glob in place (no normalize call)
                base_glob.assignments = combined_assignments;
                base_glob.set_kids(nodes=new_kid);
                new_body.append(base_glob);
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
            # Start collecting consecutive compatible has statements
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
            # If we combined multiple has statements, merge them without normalize
            if len(merged_has_list) > 1 {
                # Collect all vars
                combined_vars: list[uni.HasVar] = [];
                for has_stmt in merged_has_list {
                    combined_vars.extend(has_stmt.vars);
                }
                # Build new kid list preserving tokens from base_has
                # Structure: [doc?] [static?] has [access?] var1, var2, ... varN;
                new_kid: list[uni.UniNode] = [];
                # Copy prefix tokens from base_has (everything before first var)
                for kid in base_has.kid {
                    if kid in base_has.vars {
                        break;
                    }
                    new_kid.append(kid);
                }
                # Add all vars with commas between them
                for (idx, var) in enumerate(combined_vars) {
                    if idx > 0 {
                        new_kid.append(base_has.gen_token(Tok.COMMA));
                    }
                    new_kid.append(var);
                }
                # Add semicolon at the end
                new_kid.append(base_has.gen_token(Tok.SEMI));
                # Update base_has in place (no normalize call)
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

"""Check if two GlobalVars nodes can be combined (same access, frozen)."""
impl JacAutoLintPass.can_combine_glob(
    glob1: uni.GlobalVars, glob2: uni.GlobalVars
) -> bool {
    # Must have same frozen modifier
    if glob1.is_frozen != glob2.is_frozen {
        return False;
    }
    # Must have same access modifier
    access1 = glob1.access.tag.name if glob1.access else None;
    access2 = glob2.access.tag.name if glob2.access else None;
    if access1 != access2 {
        return False;
    }
    return True;
}

"""Check if two ArchHas nodes can be combined (same static, access, frozen)."""
impl JacAutoLintPass.can_combine_has(has1: uni.ArchHas, has2: uni.ArchHas) -> bool {
    # Must have same static modifier
    if has1.is_static != has2.is_static {
        return False;
    }
    # Must have same frozen modifier
    if has1.is_frozen != has2.is_frozen {
        return False;
    }
    # Must have same access modifier
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
    # Build kid list manually: with entry { stmts... }
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
    # Build kid list manually: glob assignment
    new_kid: list[uni.UniNode] = [];
    new_kid.append(glob_node.gen_token(Tok.KW_GLOBAL));
    new_kid.append(assignment);
    glob_node.set_kids(nodes=new_kid);
    return glob_node;
}

"""Check if a statement is a module-level construct that can be extracted."""
impl JacAutoLintPass.is_module_level_construct(stmt: uni.UniNode) -> bool {
    # These types can exist at module level and should be extracted
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
    # Must have a value (not just declaration)
    if assignment.value is None {
        return False;
    }
    # Must not be an augmented assignment (+=, -= etc.)
    if assignment.aug_op is not None {
        return False;
    }
    # All targets must be simple names
    for target in assignment.target {
        if not isinstance(target, uni.Name) {
            return False;
        }
    }
    return True;
}

"""Process module to transform with entry blocks in-place."""
impl JacAutoLintPass.enter_module(node: uni.Module) -> None {
    if not self.lint_enabled {
        return;
    }
    module = node;
    # Store main module reference (first module, not impl modules)
    if self.main_module is None {
        self.main_module = module;
        # Process impl modules after setting main_module
        for impl_mod in module.impl_mod {
            self.traverse(impl_mod);
        }
    }
    # Transform module body in-place
    new_body: list[uni.UniNode] = [];
    for stmt in module.body {
        # Remove `import from __future__ { annotations }` - not needed in Jac
        if self._is_future_annotations_import(stmt) {
            continue;
        }
        if isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            # Unnamed with entry block - extract module-level constructs
            # while preserving order for correctness
            pending_entry_stmts: list[uni.UniNode] = [];
            for inner_stmt in stmt.body {
                # Check if this statement should be extracted to module level
                extracted_stmt: uni.UniNode | None = None;
                if isinstance(inner_stmt, uni.Assignment)
                and self.can_convert_to_glob(inner_stmt) {
                    extracted_stmt = self.create_glob_from_assignment(inner_stmt);
                } elif self.is_module_level_construct(inner_stmt) {
                    extracted_stmt = inner_stmt;
                }

                if extracted_stmt is not None {
                    # Flush pending entry statements first to preserve order
                    if pending_entry_stmts {
                        new_body.append(self.create_entry_block(pending_entry_stmts));
                        pending_entry_stmts = [];
                    }
                    new_body.append(extracted_stmt);
                } elif not isinstance(inner_stmt, uni.Semi) {
                    # Accumulate non-module-level statements for with entry
                    pending_entry_stmts.append(inner_stmt);
                }
            }
            # Flush any remaining pending entry statements
            if pending_entry_stmts {
                new_body.append(self.create_entry_block(pending_entry_stmts));
            }
        } else {
            new_body.append(stmt);
        }
    }
    # Combine consecutive glob statements with same modifiers
    new_body = self.combine_consecutive_glob(new_body);
    module.body = new_body;
    self.recalculate_parents(module);
    # Build kid list manually to avoid normalize() and preserve comment associations
    # Module structure: [doc?] body...
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(new_body);
    module.set_kids(nodes=new_kid if len(new_kid) else [uni.EmptyToken()]);
}

"""Remove unnecessary angle bracket escaping from names that are not actual keywords.

Names only need angle bracket escaping if they conflict with:
- Python keywords (and, or, if, else, etc.)
- Jac reserved keywords from the grammar

This also handles SpecialVarRef where the underlying name should
never have angle bracket escaping since it's already recognized as a special keyword.
"""
impl JacAutoLintPass.enter_name(<>node: uni.Name) -> None {
    if not self.lint_enabled {
        return;
    }
    # Skip if not escaped or if it's a SpecialVarRef (handled separately)
    if not <>node.is_kwesc or isinstance(<>node, uni.SpecialVarRef) {
        return;
    }
    jac_keywords = set(TOKEN_MAP.values());
    python_keywords = set(keyword.kwlist);
    reserved = jac_keywords | python_keywords;
    # If the name value is NOT a reserved keyword, remove the angle bracket escape
    if <>node.value not in reserved {
        <>node.is_kwesc = False;
        # Also update the token name from KWESC_NAME to NAME
        if <>node.name == Tok.KWESC_NAME {
            <>node.name = Tok.NAME;
        }
    }
}

"""Remove angle bracket escaping from SpecialVarRef's underlying name.

SpecialVarRef wraps special keywords like init, postinit, self, super,
root, here, visitor. The underlying Name should never have angle bracket escaping
since these are already recognized as special tokens in the grammar.
"""
impl JacAutoLintPass.enter_special_var_ref(<>node: uni.SpecialVarRef) -> None {
    if not self.lint_enabled {
        return;
    }
    if <>node.orig.is_kwesc {
        <>node.orig.is_kwesc = False;
        if <>node.orig.name == Tok.KWESC_NAME {
            <>node.orig.name = Tok.NAME;
        }
    }
    # Also check if the SpecialVarRef itself has is_kwesc set (it inherits from Name)
    if <>node.is_kwesc {
        <>node.is_kwesc = False;
    }
}

"""Remove angle bracket escaping from BuiltinType nodes.

BuiltinType represents built-in types like str, int, float, bool, etc.
These should never have angle bracket escaping since they are recognized as
built-in type tokens in the grammar.
"""
impl JacAutoLintPass.enter_builtin_type(<>node: uni.BuiltinType) -> None {
    if not self.lint_enabled {
        return;
    }
    # BuiltinType inherits from Name, so it has is_kwesc
    # Built-in types should never be escaped
    if <>node.is_kwesc {
        <>node.is_kwesc = False;
        if <>node.name == Tok.KWESC_NAME {
            <>node.name = Tok.NAME;
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
    node: uni.FuncCall
) -> (uni.AtomTrailer | None) {
    # Check if target is a Name with value "hasattr"
    if not isinstance(node.target, uni.Name) {
        return None;
    }
    if node.target.value != "hasattr" {
        return None;
    }
    # Must have exactly 2 parameters
    if len(node.params) != 2 {
        return None;
    }
    obj_expr = node.params[0];
    attr_expr = node.params[1];
    # Second parameter must be a string literal
    # Handle both String and MultiString (which wraps String)
    attr_value: str | None = None;
    string_node: uni.String | None = None;
    if isinstance(attr_expr, uni.String) {
        attr_value = attr_expr.value;
        string_node = attr_expr;
    } elif isinstance(attr_expr, uni.MultiString) {
        # MultiString contains a list of String/FString
        # For hasattr, we only handle simple single strings
        if len(attr_expr.strings) == 1 and isinstance(attr_expr.strings[0], uni.String) {
            attr_value = attr_expr.strings[0].value;
            string_node = attr_expr.strings[0];
        }
    }
    if attr_value is None or string_node is None {
        return None;
    }
    # Extract attribute name from string (remove quotes)
    if (attr_value.startswith('"') and attr_value.endswith('"'))
    or (attr_value.startswith("'") and attr_value.endswith("'")) {
        attr_name = attr_value[1:-1];
    } else {
        return None;
    }
    # Create a Name node for the attribute using the string node's location info
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
    # Create the null-safe AtomTrailer (obj null-safe attr)
    # Build kid list manually to avoid normalize() and preserve comment associations
    # Structure: target ? . right
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
    # Must be an attribute access (not subscript)
    if not trailer.is_attr {
        return False;
    }
    # The right side must be a Name matching the attribute
    if not isinstance(trailer.right, uni.Name) {
        return False;
    }
    if trailer.right.value != attr_name {
        return False;
    }
    # The target must match the object expression
    # Use structural comparison to avoid corrupting locations via unparse()
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
        # Surgically insert NULL_OK token after the target
        # Original structure: target [.] right
        # New structure: target ? [.] right
        new_kid: list[uni.UniNode] = [];
        inserted_null_ok = False;
        for kid in trailer.kid {
            new_kid.append(kid);
            # Insert NULL_OK token right after the target
            if kid is trailer.target and not inserted_null_ok {
                new_kid.append(trailer.gen_token(Tok.NULL_OK));
                inserted_null_ok = True;
            }
        }
        trailer.set_kids(nodes=new_kid);
    }
}

"""Process FuncCall to convert hasattr(obj, "attr") to null-safe access.

This replaces hasattr calls in the parent node's children with
the equivalent null-safe access expression.

For IfElseExpr patterns like obj.attr if hasattr(obj, "attr") else default,
this also converts the value expression to use null-safe access.
"""
impl JacAutoLintPass.exit_func_call(node: uni.FuncCall) -> None {
    if not self.lint_enabled {
        return;
    }
    # Try to convert hasattr to null-safe access
    replacement = self._convert_hasattr_to_null_ok(node);
    if replacement is None {
        return;
    }
    # Extract obj and attr from the hasattr call for pattern matching
    obj_expr = node.params[0];
    attr_expr = node.params[1];
    attr_name = self._extract_string_literal_value(attr_expr);
    # Replace this node in its parent
    parent = node.parent;
    if parent is None {
        return;
    }
    replacement.parent = parent;
    # Find and replace in parent's children
    # We avoid calling normalize() to preserve comment associations.
    # Instead, we update the semantic field AND directly update the kid list.
    # Handle different parent types that might contain this FuncCall
    if isinstance(parent, uni.IfElseExpr) {
        if parent.condition is node {
            parent.condition = replacement;
            # Also check if value is obj.attr matching the hasattr pattern
            # Pattern: obj.attr if hasattr(obj, "attr") else default
            # Convert to: null-safe access if null-safe access else default
            if attr_name is not None and isinstance(parent.value, uni.AtomTrailer) {
                if self._is_matching_attr_access(parent.value, obj_expr, attr_name) {
                    self._make_null_ok(parent.value);
                }
            }
        } elif parent.value is node {
            parent.value = replacement;
        } elif parent.else_value is node {
            parent.else_value = replacement;
        }
    } elif isinstance(parent, uni.BinaryExpr) {
        if parent.left is node {
            parent.left = replacement;
        } elif parent.right is node {
            parent.right = replacement;
        }
    } elif isinstance(parent, uni.BoolExpr) {
        # BoolExpr has a values list (for 'and'/'or' expressions)
        new_values: list[uni.Expr] = [];
        for val in parent.values {
            if val is node {
                new_values.append(replacement);
            } else {
                new_values.append(val);
            }
        }
        parent.values = new_values;
    } elif isinstance(parent, uni.UnaryExpr) {
        if parent.operand is node {
            parent.operand = replacement;
        }
    } elif isinstance(parent, uni.IfStmt) {
        if parent.condition is node {
            parent.condition = replacement;
        }
    } elif isinstance(parent, uni.WhileStmt) {
        if parent.condition is node {
            parent.condition = replacement;
        }
    }
    # For all parent types, update the kid list directly to reflect the replacement
    # This preserves comment associations since we're reusing the original kid structure
    new_kids: list[uni.UniNode] = [];
    for kid in parent.kid {
        if kid is node {
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
    # For other expression types, return None (too complex)
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
    # Build key from target without calling unparse()
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
    # Same object reference
    if expr1 is expr2 {
        return True;
    }
    # Must be same type
    if type(expr1) != type(expr2) {
        return False;
    }
    # Compare Names by value
    if isinstance(expr1, uni.Name) and isinstance(expr2, uni.Name) {
        return expr1.value == expr2.value;
    }
    # Compare AtomTrailers recursively
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
    # Compare SpecialVarRef
    if isinstance(expr1, uni.SpecialVarRef) and isinstance(expr2, uni.SpecialVarRef) {
        if expr1.name and expr2.name {
            return expr1.name.value == expr2.name.value;
        }
        return expr1.name is None and expr2.name is None;
    }
    # For other types, use key comparison as fallback
    key1 = self._expr_to_key(expr1);
    key2 = self._expr_to_key(expr2);
    if key1 is not None and key2 is not None {
        return key1 == key2;
    }
    # Cannot safely compare - assume not identical
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
    # Check if value and condition are identical
    if not self._exprs_are_identical(if_else_node.value, if_else_node.condition) {
        return False;
    }
    parent = if_else_node.parent;
    if parent is None {
        return False;
    }
    # Check if else_value is None literal (only uni.Null, not the string "None")
    if isinstance(if_else_node.else_value, uni.Null) {
        # Special case: x?.attr if x?.attr else None -> x?.attr
        # Just replace with the value expression
        replacement = if_else_node.value;
        replacement.parent = parent;
    } else {
        # Normal case: x?.attr if x?.attr else default -> x?.attr or default
        # Create the 'or' token
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
        # Create a BoolExpr with 'or' operator: value or else_value
        # Build kid list manually: value1 or value2
        replacement = uni.BoolExpr(
            op=or_token,
            values=[if_else_node.value, if_else_node.else_value],
            kid=[if_else_node.value, or_token, if_else_node.else_value]
        );
        replacement.parent = parent;
    }
    # Update parent's reference to this node
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
    # Also update specific parent attributes that might reference this node
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
    # Try to convert/simplify ternary when value equals condition
    # Handles both None case and or conversion
    if self._convert_ternary_to_or(if_else_node) {
        return;
    }
    # Collect all AtomTrailers in this expression
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(if_else_node, trailers);
    if len(trailers) < 2 {
        return;
    }
    # Find null-safe accesses and their keys
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
    # Convert matching non-null-safe accesses
    # Note: _make_null_ok() already updates the kid list for each trailer,
    # so we don't need to call normalize() on the parent node.
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
    if not self.lint_enabled {
        return;
    }
    # Collect all AtomTrailers in this expression
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(bool_node, trailers);
    if len(trailers) < 2 {
        return;
    }
    # Find null-safe accesses and their keys
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
    # Convert matching non-null-safe accesses
    # Note: _make_null_ok() already updates the kid list for each trailer,
    # so we don't need to call normalize() on the parent node.
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
    # Must be a "from X import Y" style import (has from_loc)
    if import_node.from_loc is None {
        return False;
    }
    # Check if from_loc path is "__future__"
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
    # Check if items contain "annotations"
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
    # First try decl_link (if DeclImplMatchPass has already run)
    decl: uni.Ability | None = None;
    if isinstance(impl_node.decl_link, uni.Ability) {
        decl = impl_node.decl_link;
    } else {
        # Look up the declaration via symbol table
        # impl_node.target is a sequence like [Calculator, add] or
        # [OuterClass, InnerClass, method] for nested classes
        if not impl_node.target or len(impl_node.target) < 2 {
            return;
        }
        # Get the root archetype name and ability name (last element)
        root_arch_name = impl_node.target[0].sym_name if impl_node.target[0] else None;
        ability_name = impl_node.target[-1].sym_name if impl_node.target[-1] else None;
        if not root_arch_name or not ability_name {
            return;
        }
        # Use the stored main_module reference
        if self.main_module is None {
            return;
        }
        # Look up root archetype - try symbol table first, then fall back to body scan
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
        # Fallback: scan module body directly (for formatting without sym_tab)
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
        # Navigate through nested classes if target has more than 2 elements
        # e.g., [OuterClass, InnerClass, method] -> navigate OuterClass -> InnerClass
        for i in range(1, len(impl_node.target) - 1) {
            nested_name = impl_node.target[i].sym_name if impl_node.target[i] else None;
            if not nested_name {
                return;
            }
            # Find the nested class in the current archetype's body
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
        # Find the ability in the (possibly nested) archetype
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
    # Compare signatures structurally without calling unparse/normalize
    # (unparse triggers normalize which corrupts token locations)
    decl_sig = decl.signature;
    impl_sig = impl_node.spec;
    # Check if signatures match (if they do, return early)
    if self._signatures_match(decl_sig, impl_sig) {
        return;
    }
    # Copy the declaration's signature to the impl
    import copy;
    new_sig = copy.deepcopy(decl.signature);
    new_sig.parent = impl_node;
    # Update impl_node's spec and kid list
    old_spec = impl_node.spec;
    impl_node.spec = new_sig;
    # Replace old spec in kid list with new sig
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
    # Compare parameter counts first
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
    # Check parameter names match
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
    # Find if this import is followed by a Semi statement
    body = parent.body;
    try {
        idx = body.index(import_node);
    } except ValueError {
        return;
    }
    if idx + 1 < len(body) and isinstance(body[idx + 1], uni.Semi) {
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
    # Check if signature has any parameters
    has_params = bool(
        sig.posonly_params or sig.params or sig.varargs or sig.kwonlyargs or sig.kwargs
    );
    if has_params {
        return;
    }
    # No parameters - handle based on whether there's a return type
    if sig.return_type is None {
        # No params and no return type - remove signature entirely
        setattr(target_node, sig_attr, None);
        # Remove signature from target_node's kid list
        new_kid: list[uni.UniNode] = [];
        for kid in target_node.kid {
            if kid is not sig {
                new_kid.append(kid);
            }
        }
        target_node.kid = new_kid;
    } else {
        # Has return type - remove just the parentheses tokens
        new_kid: list[uni.UniNode] = [];
        for kid in sig.kid {
            if isinstance(kid, uni.Token) and kid.name in (Tok.LPAREN, Tok.RPAREN) {
                continue;
            }
            new_kid.append(kid);
        }
        if len(new_kid) != len(sig.kid) and len(new_kid) > 0 {
            sig.set_kids(nodes=new_kid);
        }
    }
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
        # MultiString contains a list of String/FString
        # For hasattr, we only handle simple single strings
        if len(expr.strings) == 1 and isinstance(expr.strings[0], uni.String) {
            attr_value = expr.strings[0].value;
        }
    }
    if attr_value is None {
        return None;
    }
    # Remove quotes from string value
    if (attr_value.startswith('"') and attr_value.endswith('"'))
    or (attr_value.startswith("'") and attr_value.endswith("'")) {
        return attr_value[1:-1];
    }
    return None;
}
