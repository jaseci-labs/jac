"""A `pages/` directory that declares no route, so routing stays manual."""

def:pub AppShell -> JsxElement {
    return <div>shell</div>;
}

def:pub app -> JsxElement {
    return <AppShell/>;
}
