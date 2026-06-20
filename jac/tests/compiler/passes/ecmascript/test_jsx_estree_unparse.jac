"""Round-trip spec for the ESTree-JSX node types + `es_unparse` JSX emission
(View IR plan / solid-dom-expressions-plan Branch 2).

These assertions **pin the exact JSX dialect** the unparser emits — the target
string `SolidBackend.lower_view` will build in Branch 3 and hand to
`vite-plugin-solid` (`babel-plugin-jsx-dom-expressions`). The nodes are built by
hand here (no backend produces them yet); Branch 2 is inert infrastructure, so
this is the only consumer of the JSX nodes until Branch 3 flips Solid onto them.

The dialect (per the plan's Phase 0): real JSX *syntax* — `{expr}` containers,
`{...obj}` native spreads, value-less boolean attrs, self-closing `<tag />`,
fragments `<>…</>`, dotted component names. Attribute name-mapping
(`className`→`class`, events, refs) is the backend's job in Branch 3, not the
unparser's — these tests emit names verbatim.
"""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }

"""`<div className="box">Hello</div>` — host tag, static string attr, text."""
test "jsx host element with static attribute and text child" {
    jsx = es.JsxElement(
        openingElement=es.JsxOpeningElement(
            name=es.JsxIdentifier(name="div"),
            attributes=[
                es.JsxAttribute(
                    name=es.JsxIdentifier(name="className"),
                    value=es.Literal(value="box")
                )
            ]
        ),
        children=[es.JsxText(value="Hello")],
        closingElement=es.JsxClosingElement(name=es.JsxIdentifier(name="div"))
    );
    assert es_to_js(jsx) == '<div className="box">Hello</div>';
}

"""`<input value={count()} onInput={handler} />` — self-closing, dynamic attr
(expression container) + event handler, both emitted as `{expr}`."""
test "jsx self-closing element with dynamic and event attributes" {
    jsx = es.JsxElement(
        openingElement=es.JsxOpeningElement(
            name=es.JsxIdentifier(name="input"),
            attributes=[
                es.JsxAttribute(
                    name=es.JsxIdentifier(name="value"),
                    value=es.JsxExpressionContainer(
                        expression=es.CallExpression(
                            callee=es.Identifier(name="count"), arguments=[]
                        )
                    )
                ),
                es.JsxAttribute(
                    name=es.JsxIdentifier(name="onInput"),
                    value=es.JsxExpressionContainer(
                        expression=es.Identifier(name="handler")
                    )
                )
            ],
            selfClosing=True
        )
    );
    assert es_to_js(jsx) == "<input value={count()} onInput={handler} />";
}

"""`<button {...props} disabled>Go</button>` — native spread + boolean attr."""
test "jsx spread attribute and value-less boolean attribute" {
    jsx = es.JsxElement(
        openingElement=es.JsxOpeningElement(
            name=es.JsxIdentifier(name="button"),
            attributes=[
                es.JsxSpreadAttribute(argument=es.Identifier(name="props")),
                es.JsxAttribute(name=es.JsxIdentifier(name="disabled"))
            ]
        ),
        children=[es.JsxText(value="Go")],
        closingElement=es.JsxClosingElement(name=es.JsxIdentifier(name="button"))
    );
    assert es_to_js(jsx) == "<button {...props} disabled>Go</button>";
}

"""`<Foo.Bar><span>{x}</span></Foo.Bar>` — dotted component tag + nested
element child with a dynamic child."""
test "jsx member-expression tag with nested element child" {
    inner = es.JsxElement(
        openingElement=es.JsxOpeningElement(name=es.JsxIdentifier(name="span")),
        children=[es.JsxExpressionContainer(expression=es.Identifier(name="x"))],
        closingElement=es.JsxClosingElement(name=es.JsxIdentifier(name="span"))
    );
    member = es.JsxMemberExpression(
        object=es.JsxIdentifier(name="Foo"), property=es.JsxIdentifier(name="Bar")
    );
    jsx = es.JsxElement(
        openingElement=es.JsxOpeningElement(name=member),
        children=[inner],
        closingElement=es.JsxClosingElement(name=member)
    );
    assert es_to_js(jsx) == "<Foo.Bar><span>{x}</span></Foo.Bar>";
}

"""Nested member chain `a.b.c` lowers left-associatively."""
test "jsx nested member-expression chain" {
    chain = es.JsxMemberExpression(
        object=es.JsxMemberExpression(
            object=es.JsxIdentifier(name="a"), property=es.JsxIdentifier(name="b")
        ),
        property=es.JsxIdentifier(name="c")
    );
    assert es_to_js(chain) == "a.b.c";
}

"""`<><span>a</span>{b}</>` — fragment with mixed element + dynamic children."""
test "jsx fragment with mixed children" {
    span = es.JsxElement(
        openingElement=es.JsxOpeningElement(name=es.JsxIdentifier(name="span")),
        children=[es.JsxText(value="a")],
        closingElement=es.JsxClosingElement(name=es.JsxIdentifier(name="span"))
    );
    jsx = es.JsxFragment(
        children=[span, es.JsxExpressionContainer(expression=es.Identifier(name="b"))]
    );
    assert es_to_js(jsx) == "<><span>a</span>{b}</>";
}

"""An empty expression container (`{}`) emits empty braces."""
test "jsx empty expression container" {
    jsx = es.JsxExpressionContainer(expression=es.JsxEmptyExpression());
    assert es_to_js(jsx) == "{}";
}

"""A `JsxText` with an explicit `raw` emits `raw` verbatim (raw wins)."""
test "jsx text prefers raw over value" {
    jsx = es.JsxText(value="decoded", raw="&amp;");
    assert es_to_js(jsx) == "&amp;";
}
