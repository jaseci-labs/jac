"""Test for match-case type narrowing bug.

Bug: Inside match-case, expr was showing as JsxElement | AtomTrailer
instead of being narrowed to just AtomTrailer.

Root cause: CFG was incorrectly linking last statement of previous
case as predecessor to statements in subsequent cases.
"""

class Expr {}

class JsxElement(Expr) {}

class AtomTrailer(Expr) {
    has is_attr: bool;
}

obj TypeEvaluator {
    has result: str = "";

    def _get_type_of_expression_core(expr: Expr) {
        match expr {
            case JsxElement():
                self.result = "jsx";

            case AtomTrailer():
                # expr should be narrowed to AtomTrailer here, not JsxElement | AtomTrailer
                if expr.is_attr {
                    self.result = "attr";
                }

        }
    }
}
