"""The `main.jac` of a `pages/` project. `shell` proves the wrapper mounted, so
"routes dropped" is distinguishable from "nothing mounted"."""

def:pub app(children: any = None) -> JsxElement {
    <div data-testid="shell">{children}</div>
}
