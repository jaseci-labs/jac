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
}
