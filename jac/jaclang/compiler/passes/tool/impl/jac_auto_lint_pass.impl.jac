"""Remove empty parentheses from function signatures with no parameters.

This handles both cases:
- No params, no return type: Remove the entire signature from the ability
- No params, with return type: Remove just LPAREN/RPAREN, keep return type
"""
impl JacAutoLintPass.exit_ability(
    self: JacAutoLintPass, ability_node: uni.Ability
) -> None {
    if not self.lint_enabled {
        return;
    }
    sig = ability_node.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return;
    }
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
        ability_node.signature = None;
        # Remove signature from ability's kid list
        new_kid: list = [];
        for kid in ability_node.kid {
            if kid is not sig {
                new_kid.append(kid);
            }
        }
        ability_node.kid = new_kid;
    } else {
        # Has return type - remove just the parentheses tokens
        new_kid: list = [];
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

"""Remove @staticmethod decorator tokens and add static keyword to ability's kid list.

This preserves original token objects (for comment associations) while
removing only the @staticmethod decorator tokens and inserting the static keyword.
"""
impl JacAutoLintPass._remove_staticmethod_from_kids(
    self: JacAutoLintPass, ability_node: uni.Ability
) -> None {
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

"""Process ability to convert @staticmethod decorator to static keyword and __init__/__post_init__ to init/postinit."""
impl JacAutoLintPass.enter_ability(
    self: JacAutoLintPass, ability_node: uni.Ability
) -> None {
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
    # Handle __init__ and __post_init__ conversion
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
impl JacAutoLintPass.enter_impl_def(self: JacAutoLintPass, node: uni.ImplDef) -> None {
    if not self.lint_enabled {
        return;
    }
    impl_node = node;
    if impl_node.body is not None and isinstance(impl_node.body, list) {
        new_body = self.combine_consecutive_has(list(impl_node.body));
        if len(new_body) != len(impl_node.body) {
            impl_node.body = new_body;
            self.recalculate_parents(impl_node);
            impl_node.normalize(deep=False);
        }
    }
}

"""Process Enum to combine consecutive has statements."""
impl JacAutoLintPass.enter_enum(self: JacAutoLintPass, node: uni.Enum) -> None {
    if not self.lint_enabled {
        return;
    }
    enum_node = node;
    if enum_node.body is not None and isinstance(enum_node.body, list) {
        new_body = self.combine_consecutive_has(list(enum_node.body));
        if len(new_body) != len(enum_node.body) {
            enum_node.body = new_body;
            self.recalculate_parents(enum_node);
            enum_node.normalize(deep=False);
        }
    }
}

"""Process Archetype to combine consecutive has statements."""
impl JacAutoLintPass.enter_archetype(
    self: JacAutoLintPass, node: uni.Archetype
) -> None {
    if not self.lint_enabled {
        return;
    }
    arch = node;
    if arch.body is not None and isinstance(arch.body, list) {
        new_body = self.combine_consecutive_has(list(arch.body));
        if len(new_body) != len(arch.body) {
            arch.body = new_body;
            self.recalculate_parents(arch);
            arch.normalize(deep=False);
        }
    }
}

"""Combine consecutive glob statements in a body list."""
impl JacAutoLintPass.combine_consecutive_glob(
    self: JacAutoLintPass, body: list
) -> list {
    if len(body) <= 1 {
        return body;
    }
    new_body: list = [];
    i = 0;
    while i < len(body) {
        stmt = body[i];

        if isinstance(stmt, uni.GlobalVars) {
            # Start collecting consecutive compatible glob statements
            combined_assignments: list = list(stmt.assignments);
            combined_doc = stmt.doc;
            base_glob = stmt;
            j = i + 1;
            while j < len(body) {
                next_stmt = body[j];
                if isinstance(next_stmt, uni.GlobalVars)
                and self.can_combine_glob(base_glob, next_stmt) {
                    # Combine the assignments
                    combined_assignments.extend(next_stmt.assignments);
                    j += 1;
                } else {
                    break;
                }
            }
            # If we combined multiple glob statements, create new one
            if j > i + 1 {
                new_glob = uni.GlobalVars(
                    access=base_glob.access,
                    assignments=combined_assignments,
                    is_frozen=base_glob.is_frozen,
                    kid=combined_assignments,
                    doc=combined_doc
                );
                new_glob.normalize(deep=True);
                new_body.append(new_glob);
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

"""Combine consecutive has statements in a body list."""
impl JacAutoLintPass.combine_consecutive_has(self: JacAutoLintPass, body: list) -> list {
    if len(body) <= 1 {
        return body;
    }
    new_body: list = [];
    i = 0;
    while i < len(body) {
        stmt = body[i];

        if isinstance(stmt, uni.ArchHas) {
            # Start collecting consecutive compatible has statements
            combined_vars: list = list(stmt.vars);
            combined_doc = stmt.doc;
            base_has = stmt;
            j = i + 1;
            while j < len(body) {
                next_stmt = body[j];
                if isinstance(next_stmt, uni.ArchHas)
                and self.can_combine_has(base_has, next_stmt) {
                    # Combine the vars
                    combined_vars.extend(next_stmt.vars);
                    j += 1;
                } else {
                    break;
                }
            }
            # If we combined multiple has statements, create new one
            if j > i + 1 {
                new_has = uni.ArchHas(
                    is_static=base_has.is_static,
                    access=base_has.access,
                    vars=combined_vars,
                    is_frozen=base_has.is_frozen,
                    kid=combined_vars,
                    doc=combined_doc
                );
                new_has.normalize(deep=True);
                new_body.append(new_has);
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
    self: JacAutoLintPass, glob1: uni.GlobalVars, glob2: uni.GlobalVars
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
impl JacAutoLintPass.can_combine_has(
    self: JacAutoLintPass, has1: uni.ArchHas, has2: uni.ArchHas
) -> bool {
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

"""Create a new ModuleCode (with entry) block from a list of statements."""
impl JacAutoLintPass.create_entry_block(
    self: JacAutoLintPass, stmts: list
) -> uni.ModuleCode {
    entry_block = uni.ModuleCode(name=None, body=stmts, kid=stmts, doc=None);
    # Normalize shallowly - generates with entry tokens but preserves child loc info
    entry_block.normalize(deep=False);
    return entry_block;
}

"""Create a GlobalVars node from an assignment."""
impl JacAutoLintPass.create_glob_from_assignment(
    self: JacAutoLintPass, assignment: uni.Assignment
) -> uni.GlobalVars {
    glob_node = uni.GlobalVars(
        access=None,
        assignments=[assignment],
        is_frozen=False,
        kid=[assignment],
        doc=None
    );
    # Normalize shallowly - generates glob keyword but preserves child loc info
    glob_node.normalize(deep=False);
    return glob_node;
}

"""Check if a statement is a module-level construct that can be extracted."""
impl JacAutoLintPass.is_module_level_construct(
    self: JacAutoLintPass, stmt: uni.UniNode
) -> bool {
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
impl JacAutoLintPass.can_convert_to_glob(
    self: JacAutoLintPass, assignment: uni.Assignment
) -> bool {
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
impl JacAutoLintPass.enter_module(self: JacAutoLintPass, node: uni.Module) -> None {
    if not self.lint_enabled {
        return;
    }
    module = node;
    # Transform module body in-place
    new_body: list = [];
    for stmt in module.body {
        # Remove `import from __future__ { annotations }` - not needed in Jac
        if self._is_future_annotations_import(stmt) {
            continue;
        }
        if isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            # Unnamed with entry block - extract module-level constructs
            # while preserving order for correctness
            pending_entry_stmts: list = [];
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
    module.normalize(deep=False);
}

"""Remove unnecessary angle bracket escaping from names that are not actual keywords.

Names only need angle bracket escaping if they conflict with:
- Python keywords (and, or, if, else, etc.)
- Jac reserved keywords from the grammar

This also handles SpecialVarRef where the underlying name should
never have angle bracket escaping since it's already recognized as a special keyword.
"""
impl JacAutoLintPass.enter_name(self: JacAutoLintPass, <>node: uni.Name) -> None {
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
impl JacAutoLintPass.enter_special_var_ref(
    self: JacAutoLintPass, <>node: uni.SpecialVarRef
) -> None {
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
impl JacAutoLintPass.enter_builtin_type(
    self: JacAutoLintPass, <>node: uni.BuiltinType
) -> None {
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
    self: JacAutoLintPass, node: uni.FuncCall
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
    null_ok_access = uni.AtomTrailer(
        target=obj_expr,
        right=attr_name_node,
        is_attr=True,
        is_null_ok=True,
        kid=[obj_expr, attr_name_node]
    );
    null_ok_access.normalize(deep=False);
    return null_ok_access;
}

"""Check if an AtomTrailer matches an object and attribute name.

Returns True if the AtomTrailer represents obj.attr where obj matches
the given object expression and attr matches the given attribute name.
"""
impl JacAutoLintPass._is_matching_attr_access(
    self: JacAutoLintPass, trailer: uni.AtomTrailer, obj_expr: uni.Expr, attr_name: str
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
    # For simple names, compare the values
    if isinstance(obj_expr, uni.Name) and isinstance(trailer.target, uni.Name) {
        return obj_expr.value == trailer.target.value;
    }
    # For more complex expressions, we'd need deeper comparison
    # For now, use string comparison of unparsed expressions
    try {
        return obj_expr.unparse() == trailer.target.unparse();
    } except Exception {
        return False;
    }
}

"""Convert an AtomTrailer to use null-safe access.

Takes an existing obj.attr AtomTrailer and converts it to use null-safe access
by setting is_null_ok=True and re-normalizing.
"""
impl JacAutoLintPass._make_null_ok(
    self: JacAutoLintPass, trailer: uni.AtomTrailer
) -> None {
    if not trailer.is_null_ok {
        trailer.is_null_ok = True;
        trailer.normalize(deep=False);
    }
}

"""Process FuncCall to convert hasattr(obj, "attr") to null-safe access.

This replaces hasattr calls in the parent node's children with
the equivalent null-safe access expression.

For IfElseExpr patterns like obj.attr if hasattr(obj, "attr") else default,
this also converts the value expression to use null-safe access.
"""
impl JacAutoLintPass.exit_func_call(self: JacAutoLintPass, node: uni.FuncCall) -> None {
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
    attr_name: str | None = None;
    if isinstance(attr_expr, uni.String) {
        attr_val = attr_expr.value;
        if (attr_val.startswith('"') and attr_val.endswith('"'))
        or (attr_val.startswith("'") and attr_val.endswith("'")) {
            attr_name = attr_val[1:-1];
        }
    } elif isinstance(attr_expr, uni.MultiString) {
        if len(attr_expr.strings) == 1 and isinstance(attr_expr.strings[0], uni.String) {
            attr_val = attr_expr.strings[0].value;
            if (attr_val.startswith('"') and attr_val.endswith('"'))
            or (attr_val.startswith("'") and attr_val.endswith("'")) {
                attr_name = attr_val[1:-1];
            }
        }
    }
    # Replace this node in its parent
    parent = node.parent;
    if parent is None {
        return;
    }
    replacement.parent = parent;
    # Find and replace in parent's children
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
        parent.normalize(deep=False);
    } elif isinstance(parent, uni.BinaryExpr) {
        if parent.left is node {
            parent.left = replacement;
        } elif parent.right is node {
            parent.right = replacement;
        }
        parent.normalize(deep=False);
    } elif isinstance(parent, uni.BoolExpr) {
        # BoolExpr has a values list (for 'and'/'or' expressions)
        new_values: list = [];
        for val in parent.values {
            if val is node {
                new_values.append(replacement);
            } else {
                new_values.append(val);
            }
        }
        parent.values = new_values;
        parent.normalize(deep=False);
    } elif isinstance(parent, uni.UnaryExpr) {
        if parent.operand is node {
            parent.operand = replacement;
        }
        parent.normalize(deep=False);
    } elif isinstance(parent, uni.IfStmt) {
        if parent.condition is node {
            parent.condition = replacement;
        }
        parent.normalize(deep=False);
    } elif isinstance(parent, uni.WhileStmt) {
        if parent.condition is node {
            parent.condition = replacement;
        }
        parent.normalize(deep=False);
    } else {
        # For other parent types, update kid list manually
        new_kids: list = [];
        for kid in parent.kid {
            if kid is node {
                new_kids.append(replacement);
            } else {
                new_kids.append(kid);
            }
        }
        parent.kid = new_kids;
    }
}

"""Recursively collect all AtomTrailer nodes from a subtree."""
impl JacAutoLintPass._collect_atom_trailers(
    self: JacAutoLintPass, uni_node: uni.UniNode, results: list
) -> None {
    if isinstance(uni_node, uni.AtomTrailer) {
        results.append(uni_node);
    }
    if uni_node?.kid and uni_node?.kid {
        for kid in uni_node.kid {
            if kid is not None {
                self._collect_atom_trailers(kid, results);
            }
        }
    }
}

"""Get a unique key for an AtomTrailer based on its target and attribute.

Returns a string like "obj.attr" that can be used to identify matching accesses.
Returns None if the trailer is not a simple attribute access.
"""
impl JacAutoLintPass._get_trailer_key(
    self: JacAutoLintPass, trailer: uni.AtomTrailer
) -> (str | None) {
    if not trailer.is_attr {
        return None;
    }
    if not isinstance(trailer.right, uni.Name) {
        return None;
    }
    attr_name = trailer.right.value;
    # Get the target as a string
    try {
        target_str = trailer.target.unparse();
        return f"{target_str}.{attr_name}";
    } except Exception {
        return None;
    }
}

"""Check if two expressions are structurally identical by comparing their unparsed form."""
impl JacAutoLintPass._exprs_are_identical(
    self: JacAutoLintPass, expr1: uni.Expr, expr2: uni.Expr
) -> bool {
    try {
        return expr1.unparse() == expr2.unparse();
    } except Exception {
        return False;
    }
}

"""Convert IfElseExpr to BoolExpr with or when value equals condition.

Transforms: x?.attr if x?.attr else default -> x?.attr or default
This only applies when the value and condition are identical expressions.
"""
impl JacAutoLintPass._convert_ternary_to_or(
    self: JacAutoLintPass, if_else_node: uni.IfElseExpr
) -> bool {
    # Check if value and condition are identical
    if not self._exprs_are_identical(if_else_node.value, if_else_node.condition) {
        return False;
    }
    # Create a BoolExpr with 'or' operator: value or else_value
    or_expr = uni.BoolExpr(
        op=uni.Token(
            orig_src=if_else_node.loc.orig_src,
            name=Tok.KW_OR,
            value="or",
            line=if_else_node.loc.first_line,
            end_line=if_else_node.loc.first_line,
            col_start=0,
            col_end=2,
            pos_start=0,
            pos_end=2
        ),
        values=[if_else_node.value, if_else_node.else_value],
        kid=[if_else_node.value, if_else_node.else_value]
    );
    or_expr.normalize(deep=False);
    # Replace in parent
    parent = if_else_node.parent;
    if parent is None {
        return False;
    }
    or_expr.parent = parent;
    # Update parent's reference to this node
    if parent?.kid and parent?.kid {
        new_kids: list = [];
        for kid in parent.kid {
            if kid is if_else_node {
                new_kids.append(or_expr);
            } else {
                new_kids.append(kid);
            }
        }
        parent.kid = new_kids;
    }
    # Also update specific parent attributes that might reference this node
    if isinstance(parent, uni.Assignment) {
        if parent.value is if_else_node {
            parent.value = or_expr;
        }
    } elif isinstance(parent, uni.IfElseExpr) {
        if parent.value is if_else_node {
            parent.value = or_expr;
        } elif parent.condition is if_else_node {
            parent.condition = or_expr;
        } elif parent.else_value is if_else_node {
            parent.else_value = or_expr;
        }
    } elif isinstance(parent, uni.BoolExpr) {
        new_values: list = [];
        for val in parent.values {
            if val is if_else_node {
                new_values.append(or_expr);
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

Also converts patterns like: x?.attr if x?.attr else default -> x?.attr or default
"""
impl JacAutoLintPass.exit_if_else_expr(
    self: JacAutoLintPass, if_else_node: uni.IfElseExpr
) -> None {
    if not self.lint_enabled {
        return;
    }
    # First, try to convert identical ternary to or expression
    # Pattern: x?.attr if x?.attr else default -> x?.attr or default
    if self._convert_ternary_to_or(if_else_node) {
        return;
    }
    # Collect all AtomTrailers in this expression
    trailers: list = [];
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
    changed = False;
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and not trailer.is_null_ok {
            key = self._get_trailer_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
                changed = True;
            }
        }
    }
    if changed {
        if_else_node.normalize(deep=True);
    }
}

"""Propagate null-safe access within BoolExpr (and/or expressions).

When an expression contains both null-safe and regular accesses for the same
object and attribute, convert the regular accesses to null-safe.
"""
impl JacAutoLintPass.exit_bool_expr(
    self: JacAutoLintPass, bool_node: uni.BoolExpr
) -> None {
    if not self.lint_enabled {
        return;
    }
    # Collect all AtomTrailers in this expression
    trailers: list = [];
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
    changed = False;
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and not trailer.is_null_ok {
            key = self._get_trailer_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
                changed = True;
            }
        }
    }
    if changed {
        bool_node.normalize(deep=True);
    }
}

"""Check if a statement is an `import from __future__ { annotations }` import.

This import is not needed in Jac since Jac already uses deferred annotation
evaluation by default. Removing it cleans up code converted from Python.
"""
impl JacAutoLintPass._is_future_annotations_import(
    self: JacAutoLintPass, stmt: uni.UniNode
) -> bool {
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
