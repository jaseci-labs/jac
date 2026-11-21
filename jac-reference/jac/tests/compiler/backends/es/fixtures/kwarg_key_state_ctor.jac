"""Fixture: a constructor keyword-argument key survives client state lowering.

`theme` is a client `has` field, so reads of it lower to the state cell
`__jacS_theme.val`. The KEY of `theme=theme` names a field of `Box`; it is not
a reference to anything in this scope, so it must stay the identifier `theme`.
Rewriting it produced `new Box({__jacS_theme.val: ...})`, which is not
parseable JavaScript and failed the bundle.
"""

obj:pub Box {
    has theme: str = "";
}

def:pub use_thing -> Box {
    has theme: str = "dark";
    return Box(theme=theme);
}

def:pub app -> JsxElement {
    return <div>{use_thing().theme}</div>;
}
