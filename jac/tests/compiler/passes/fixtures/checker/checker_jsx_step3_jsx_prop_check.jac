"""Step 3: JSX call sites are checked against component parameters.

Attribute types (E1100), unknown props (E1101) and missing required props
(E1102) are checked at every call site, including one that passes no attribute
and a component that declares no parameter. Nested content counts as the
`children` prop; a component that declares no `children` drops it (W1053)."""

def Button(
    label: str, onClick: Callable[[MouseEvent], None],
    variant: str = "primary", disabled: bool = False
) -> JsxElement {
    return <button>{label}</button>;
}

def Plain(title: str) -> JsxElement {
    return <div>{title}</div>;
}

def Zero -> JsxElement {
    return <div>zero</div>;
}

def Card(title: str, children: any) -> JsxElement {
    return <div>{title}{children}</div>;
}

def handle_click(e: MouseEvent) -> None {}

with entry {
    # OK: correct props via JSX
    x = <Button label="OK" onClick={handle_click}/>;

    # Error: int is not Callable[[MouseEvent], None] via JSX prop
    y = <Button label="Bad" onClick={42}/>;

    # E1102 'title': a call site that passes nothing is still a call site.
    a = <Plain/>;

    # E1101 'bogus': a zero-parameter component is not exempt from prop checks.
    b = <Zero bogus="x"/>;

    # W1053: neither `Plain` nor `Zero` declares `children`, so they are dropped.
    c = <Plain title="ok">kids</Plain>;
    d = <Zero><Plain title="ok"/></Zero>;

    # OK: nested content satisfies `children`, which carries no default.
    e = <Card title="ok">kids</Card>;

    # E1102 'children': nothing nested, and a comment is not a child.
    f = <Card title="ok"/>;
    g = <Card title="ok">{#* note *#}</Card>;
}
