"""Jac Auto Linting Pass for automatic code pattern corrections.

This pass applies automatic linting corrections to Jac code, including:
- Converting `with entry` blocks to `glob` declarations (in-place)
- Combining consecutive `has` statements with same modifiers into single statement
- Combining consecutive `glob` statements with same modifiers into single statement
- Converting `def __init__` to `can init` (Jac style)
- Converting `def __post_init__` to `can postinit` (Jac style)
- Removing empty parentheses from function/method declarations (def foo() -> def foo)
- (Future) Import organization
- (Future) Redundant code removal
"""

import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { UniPass }
import from jaclang.pycore.constant { Tokens as Tok }

"""Auto linting pass that applies code style corrections to Jac AST."""
class JacAutoLintPass(UniPass) {
    """Initialize the pass with linting options."""
    with entry {
        lint_enabled: bool = True;
    }

    """Process module to transform with entry blocks in-place."""
    def enter_module(self: JacAutoLintPass, node: uni.Module) -> None {
        if not self.lint_enabled {
            return;
        }

        module = node;

        # Transform module body in-place
        new_body: list = [];

        for stmt in module.body {
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
                            new_body.append(
                                self.create_entry_block(pending_entry_stmts)
                            );
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

    """Check if an assignment can be converted to glob."""
    def can_convert_to_glob(self: JacAutoLintPass, assignment: uni.Assignment) -> bool {
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

    """Check if a statement is a module-level construct that can be extracted."""
    def is_module_level_construct(self: JacAutoLintPass, stmt: uni.UniNode) -> bool {
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

    """Create a GlobalVars node from an assignment."""
    def create_glob_from_assignment(
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

    """Create a new ModuleCode (with entry) block from a list of statements."""
    def create_entry_block(self: JacAutoLintPass, stmts: list) -> uni.ModuleCode {
        entry_block = uni.ModuleCode(name=None, body=stmts, kid=stmts, doc=None);
        # Normalize shallowly - generates with entry tokens but preserves child loc info
        entry_block.normalize(deep=False);
        return entry_block;
    }

    """Check if two ArchHas nodes can be combined (same static, access, frozen)."""
    def can_combine_has(
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

    """Check if two GlobalVars nodes can be combined (same access, frozen)."""
    def can_combine_glob(
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

    """Combine consecutive has statements in a body list."""
    def combine_consecutive_has(self: JacAutoLintPass, body: list) -> list {
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

    """Combine consecutive glob statements in a body list."""
    def combine_consecutive_glob(self: JacAutoLintPass, body: list) -> list {
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

    """Process Archetype to combine consecutive has statements."""
    def enter_archetype(self: JacAutoLintPass, node: uni.Archetype) -> None {
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

    """Process Enum to combine consecutive has statements."""
    def enter_enum(self: JacAutoLintPass, node: uni.Enum) -> None {
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

    """Process ImplDef to combine consecutive has statements."""
    def enter_impl_def(self: JacAutoLintPass, node: uni.ImplDef) -> None {
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

    """Process ability nodes to convert __init__/__post_init__ to init/postinit."""
    def enter_ability(self: JacAutoLintPass, ability_node: uni.Ability) -> None {
        if not self.lint_enabled or not ability_node.is_method {
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

    """Remove empty parentheses from function signatures with no parameters.

    This handles both cases:
    - No params, no return type: Remove the entire signature from the ability
    - No params, with return type: Remove just LPAREN/RPAREN, keep return type
    """
    def exit_ability(self: JacAutoLintPass, ability_node: uni.Ability) -> None {
        if not self.lint_enabled {
            return;
        }
        sig = ability_node.signature;
        if not isinstance(sig, uni.FuncSignature) {
            return;
        }
        # Check if signature has any parameters
        has_params = bool(
            sig.posonly_params
            or sig.params
            or sig.varargs
            or sig.kwonlyargs
            or sig.kwargs
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
}
