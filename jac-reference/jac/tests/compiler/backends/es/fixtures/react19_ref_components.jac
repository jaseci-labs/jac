"""Ref-target fixtures for the React 19 ref-as-prop suite.

`Button` is the shadcn shape the site actually ships: one `props` bundle, a
rest copy that drops only the keys the component consumes itself, and a spread
onto the host element. Under React 19 an incoming `ref` is an ordinary prop, so
it rides that spread onto the DOM node with no `forwardRef` in sight -- which is
what makes a radix `asChild` composition able to anchor on it.

`Badge` is the other half: a named-param component that opts into the explicit
`forwardRef` lowering with a trailing `ref: Ref[...]` param. It must keep
working, since React 19 still honours `forwardRef`.
"""

def:pub Button(props: any) -> JsxElement {
    restProps = {};
    for key in Object.keys(props) {
        if key != "children" {
            restProps[key] = props[key];
        }
    }
    return <button data-slot="button" {**restProps}>{props["children"]}</button>;
}


def:pub Badge(label: str, ref: Ref[HTMLElement]) -> JsxElement {
    return <span data-slot="badge" data-testid="badge" ref={ref}>{label}</span>;
}
