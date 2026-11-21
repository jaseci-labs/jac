"""Fixture: lowercase in-scope component in a mobUI project must not
emit W1050 (Unknown intrinsic JSX element) — the type evaluator routes it
via scope resolution, not the _JsxIntrinsicElements registry."""

def myWidget(label: str) -> JsxElement {
    return <>{label}</>;
}

def App -> JsxElement {
    return <myWidget label="hi"/>;
}
