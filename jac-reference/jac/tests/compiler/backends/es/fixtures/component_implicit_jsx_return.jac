"""Implicit-return JSX components: a tail JSX element without ';' is the
component's return value and must lower exactly like an explicit `return`,
including props-destructure classification and call-site ABI.
"""

def:pub ImplicitBadge(label: str) -> JsxElement {
    <span className="badge">{label}</span>
}

def:pub ImplicitAfterStmts(title: str) -> JsxElement {
    upper = title.upper();
    <div>{upper}</div>
}

def:pub GuardedImplicit(cond: bool, title: str) -> JsxElement {
    if cond {
        return <div>{title}</div>;
    }
    <span>{title}</span>
}

def:pub direct_call_implicit -> any {
    return ImplicitBadge("Hello");
}
