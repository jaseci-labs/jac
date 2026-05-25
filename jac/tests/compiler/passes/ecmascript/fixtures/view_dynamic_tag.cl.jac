"""Dynamic JSX tags.

`<@expr />` chooses its tag at runtime -- the expression resolves to a host
tag string, a component reference, or a `str | type` value. The tag
expression may be an identifier (`<@as_>`), a dotted access, or a
brace-wrapped expression (`<@{expr}>`).
"""

"""A box whose host element is chosen by the caller."""
def:pub Box(as_: str, children: any = None) -> JsxElement {
    return
        <@as_ class="box">{children}</@as_>;
}

def:pub Icon(glyph: type) -> JsxElement {
    return
        <@{glyph} class="icon"/>;
}

def:pub Panel(tag: str) -> JsxElement {
    return
        <div class="panel">
            <h2>Panel</h2>
            <@tag class="panel-body">content</@tag>
        </div>;
}

def:pub Demo -> JsxElement {
    return
        <>
            <Box as_="article">Inside an article element</Box>
            <Icon glyph={Box}/>
        </>;
}
