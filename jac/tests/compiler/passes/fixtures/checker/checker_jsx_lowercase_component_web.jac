"""Fixture: in a web project, a lowercase in-scope component must not emit
W1050 (Unknown intrinsic JSX element), while a genuinely unknown lowercase
host tag must still be flagged. Classification is by scope resolution, not by
the first letter's case."""

def myWidget(label: str) -> JsxElement {
    return <div>{label}</div>;
}

def App -> JsxElement {
    return <myWidget label="hi"/>;
}

def Unknown -> JsxElement {
    return <blepblorp/>;
}
