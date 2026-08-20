"""A manual-routing project: no `pages/`, so the no-argument `app` is right."""

def:pub AppShell -> JsxElement {
    return <div>shell</div>;
}

def:pub app -> JsxElement {
    return <AppShell/>;
}
