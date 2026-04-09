"""Regression: parenthesized BoolExpr conditions must wire short-circuit CFG.

`if (a and b):` and `if a and b:` must produce the same control-flow
graph. Before the fix, wrapping the condition in parentheses wrapped the
BoolExpr in an AtomUnit; `exit_if_stmt` checked `isinstance(condition,
BoolExpr)` directly, missed the match, and fell back to a simple
edge from the IfStmt straight to body[0]. That left the CfgExpr
operands (one per `and`/`or` operand) with an empty `bb_in`, so the
backward narrowing walker starting from `expr.strings` inside the `and`
could never find the upstream match-case narrowing and would widen to
the declared type.

This fixture pins all three parenthesis shapes and an enclosing match
case so narrowing must flow through both the parens and the `and`.
"""

class UniNode {
    has parent: UniNode | None = None;
}

class Expr(UniNode) {}

class MultiString(Expr) {
    has strings: list[str] = [];
}

class SubTag(UniNode) {}
class FuncSignature(UniNode) {}

obj Checker {
    def check_bare(expr: Expr) {
        match expr {
            case MultiString():
                # No parens — baseline, must narrow.
                if isinstance(expr.parent, (SubTag, FuncSignature)) and expr.strings {
                    expr.strings;
                }

        }
    }

    def check_parens(expr: Expr) {
        match expr {
            case MultiString():
                # Parenthesized condition — must narrow exactly like the
                # bare form above.
                if (isinstance(expr.parent, (SubTag, FuncSignature)) and expr.strings) {
                    expr.strings;
                }

        }
    }

    def check_while_parens(expr: Expr) {
        match expr {
            case MultiString():
                # Parenthesized while condition — same fix applies.
                while (
                    isinstance(expr.parent, (SubTag, FuncSignature)) and expr.strings
                ) {
                    expr.strings;
                    break;
                }

        }
    }
}
