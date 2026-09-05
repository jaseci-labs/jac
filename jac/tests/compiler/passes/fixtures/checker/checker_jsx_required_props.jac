"""Prop checking does not depend on the call site passing an attribute -- E1101, E1102.

`_validate_jsx_props` used to return early on a call site with no attributes, and
`_validate_component_jsx_props` on a component with no parameters, so `<Plain/>`
against `def Plain(title: str)` checked clean. Nested children now count as the
`children` prop, so a `children` parameter without a default is satisfied by the
content it exists to receive."""

def Plain(title: str) -> JsxElement {
    return <div>{title}</div>;
}

def Card(title: str, children: any) -> JsxElement {
    return <div>{title}{children}</div>;
}

def AllOptional(title: str = "T") -> JsxElement {
    return <div>{title}</div>;
}

def Zero -> JsxElement {
    return <div>zero</div>;
}

glob
     # E1102 'title': a call site that passes nothing is still a call site.
     a = <Plain/>,
     # OK: the one required prop is passed.
     b = <Plain title="ok"/>,
     # E1102 'title': children are not an attribute and do not stand in for one.
     c = <Card>body</Card>,
     # OK: nested content satisfies `children`, which carries no default.
     d = <Card title="ok">body</Card>,
     # E1102 'children': nothing nested, and no default to fall back on.
     e = <Card title="ok"/>,
     # OK: every parameter is optional.
     f = <AllOptional/>,
     # E1101 'bogus': a zero-parameter component is not exempt from prop checks.
     g = <Zero bogus="x"/>,
     # OK: nothing passed, nothing to check.
     h = <Zero/>;
