"""Phase 2: dynamic tags.

`<@expr />` chooses its tag at runtime — the expression resolves to a host
tag string, a view/component reference, or a `str | type` value. The tag
expression may be an identifier (`<@as_>`), a dotted access, or a
brace-wrapped expression (`<@{expr}>`).
"""

"""A box whose host element is chosen by the caller."""
defview Box(as_: str, children: any = None) {
    <@as_ class="box">{children}</@as_>
}

defview Icon(glyph: type) {
    <@{glyph} class="icon" />
}

defview Panel(tag: str) {
    <div class="panel">
        <h2>Panel</h2>
        <@tag class="panel-body">content</@tag>
    </div>
}

defview Demo() {
    <Box as_="article">Inside an article element</Box>
    <Icon glyph={Box} />
}
