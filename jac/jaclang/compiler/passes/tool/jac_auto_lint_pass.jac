"""Jac Auto Linting Pass for automatic code pattern corrections.

This pass applies automatic linting corrections to Jac code, including:
- Converting `with entry` blocks to `glob` declarations (in-place)
- (Future) Import organization
- (Future) Redundant code removal
"""

import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { UniPass }

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
}
