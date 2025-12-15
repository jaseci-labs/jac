"""Jac Auto Linting Pass for automatic code pattern corrections.

This pass applies automatic linting corrections to Jac code, including:
- Converting `with entry` blocks to `glob` declarations (in-place)
- Converting `def __init__` to `can init` (Jac style)
- Converting `def __post_init__` to `can postinit` (Jac style)
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
                # Unnamed with entry block - transform assignments to globs in-place
                for inner_stmt in stmt.body {
                    if isinstance(inner_stmt, uni.Assignment)
                    and self.can_convert_to_glob(inner_stmt) {
                        glob_node = self.create_glob_from_assignment(inner_stmt);
                        new_body.append(glob_node);
                    } elif not isinstance(inner_stmt, uni.Semi) {
                        # Keep non-assignment, non-empty statements as-is
                        new_body.append(inner_stmt);
                    }
                }
            } else {
                new_body.append(stmt);
            }
        }

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
        glob_node.normalize(deep=True);
        return glob_node;
    }

    """Process ability nodes to convert __init__/__post_init__ to init/postinit."""
    def enter_ability(self: JacAutoLintPass, ability_node: uni.Ability) -> None {
        if not self.lint_enabled {
            return;
        }

        # Only process if name_ref is a Name (not already a SpecialVarRef)
        if not isinstance(ability_node.name_ref, uni.Name)
        or isinstance(ability_node.name_ref, uni.SpecialVarRef) {
            return;
        }

        name_value = ability_node.name_ref.value;

        if name_value == "__init__" or name_value == "__post_init__" {
            new_tok = Tok.KW_INIT if name_value == "__init__" else Tok.KW_POST_INIT;
            tok_value = "init" if name_value == "__init__" else "postinit";
            # Create a new Name node with the init/postinit token type
            new_name = uni.Name(
                orig_src=ability_node.name_ref.orig_src,
                name=new_tok.value,
                value=tok_value,
                line=ability_node.name_ref.line_no,
                end_line=ability_node.name_ref.end_line,
                col_start=ability_node.name_ref.c_start,
                col_end=ability_node.name_ref.c_end,
                pos_start=ability_node.name_ref.pos_start,
                pos_end=ability_node.name_ref.pos_end
            );
            # Create a SpecialVarRef wrapping the new Name
            special_ref = uni.SpecialVarRef(var=new_name);
            # Save old name_ref before updating
            old_name_ref = ability_node.name_ref;
            # Replace the name_ref and update the node
            self.update_ability_name_ref(ability_node, special_ref);
            # Update the kid list to use the new name_ref
            # Find and replace the old name_ref in the kid list
            for (idx, kid) in enumerate(ability_node.kid) {
                if kid is old_name_ref {
                    ability_node.kid[idx] = special_ref;
                    break;
                }
            }
        }
    }

    """Helper to update ability name_ref with proper parent linkage."""
    def update_ability_name_ref(
        self: JacAutoLintPass, ability: uni.Ability, new_ref: uni.SpecialVarRef
    ) -> None {
        new_ref.parent = ability;
        ability.name_ref = new_ref;
        ability.name_spec = new_ref;
    }
}
