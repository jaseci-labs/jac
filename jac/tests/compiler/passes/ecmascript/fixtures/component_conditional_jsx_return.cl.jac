"""Regression fixture: nested ReturnStmt inside if/else must still trigger
props-destructure lowering for JSX components.

A component whose JSX returns live only inside conditional blocks should still
be classified as props_destructure, not direct, so that call sites wrap arguments
into a single props object.
"""

cl {
    def:pub ConditionalGreeting(cond: bool, title: str) -> JsxElement {
        if cond {
            return <div>{title}</div>;
        } else {
            return <span>{title}</span>;
        }
    }

    def:pub MatchGreeting(kind: str, title: str) -> JsxElement {
        match kind {
            case "div": return <div>{title}</div>;
            case _: return <span>{title}</span>;
        }
    }

    def:pub direct_call_conditional -> any {
        return ConditionalGreeting(true, "Hello");
    }
}
