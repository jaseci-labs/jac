"""Jac Auto Linting Pass for automatic code pattern corrections.

This pass applies automatic linting corrections to Jac code, including:
- Converting `with entry` blocks to `glob` declarations (in-place)
- Converting `@staticmethod` decorator to `static` keyword
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

    """Process ability to convert @staticmethod decorator to static keyword."""
    def enter_ability(self: JacAutoLintPass, <>node: uni.Ability) -> None {
        if not self.lint_enabled {
            return;
        }

        # Check if @staticmethod decorator is present in decorators list
        if <>node.decorators {
            has_staticmethod = False;
            for dec in <>node.decorators {
                if isinstance(dec, uni.Name) and dec.value == "staticmethod" {
                    has_staticmethod = True;
                    break;
                }
            }
            if has_staticmethod {
                # Set static flag if not already set
                if not <>node.is_static {
                    <>node.is_static = True;
                }
                # Remove @staticmethod from decorators list
                new_decorators: list[uni.Expr] = [
                    dec
                    for dec in <>node.decorators
                    if not (isinstance(dec, uni.Name) and dec.value == "staticmethod")
                ];
                <>node.decorators = new_decorators if new_decorators else None;
            }
        }

        # Surgically remove @staticmethod tokens from kids list
        # (preserves original tokens for comment associations)
        if <>node.is_static {
            self._remove_staticmethod_from_kids(<>node);
        }
    }

    """Remove @staticmethod decorator tokens and add static keyword to ability's kid list.

    This preserves original token objects (for comment associations) while
    removing only the @staticmethod decorator tokens and inserting the static keyword.
    """
    def _remove_staticmethod_from_kids(
        self: JacAutoLintPass, <>node: uni.Ability
    ) -> None {
        new_kids: list[uni.UniNode] = [];
        i = 0;
        kids = <>node.kid;
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
            if (
                isinstance(kid, uni.Token) and kid.value == "@" and (i + 1) < len(kids)
            ) {
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
                static_kw = <>node.gen_token(Tok.KW_STATIC);
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

        <>node.kid = new_kids;
    }
}
