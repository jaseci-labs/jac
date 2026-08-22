"""Fixture: a plain-function keyword argument keeps its parameter slot.

`theme` is a client `has` field, so the VALUE read lowers to the state cell
`__jacS_theme.val`. The KEY names a parameter of `label`, so the emitted call
must place the state read in `label`'s first slot. Rewriting the key made the
key unrecognizable to the argument resolver, which silently demoted the pair to
a trailing `...spread` and left the slot as `undefined` -- valid JavaScript that
passed `theme` as `undefined` at runtime.
"""

def:pub label(theme: str, size: int) -> str {
    return theme + str(size);
}

def:pub use_thing -> str {
    has theme: str = "dark";
    return label(theme=theme, size=2);
}

def:pub app -> JsxElement {
    return <div>{use_thing()}</div>;
}
