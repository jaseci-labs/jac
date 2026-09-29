"""A distinct brand used as a value needs a binding in the client output.

`type Brand := int;` is an erased brand over a primitive: `Brand(x)` is a
zero-cost cast, and the Python lane binds the primitive the checker resolved
the base to. The ES lane emitted nothing for either alias kind, so a brand was
a free identifier in the emitted module -- client codegen refused it outright
("Client codegen emitted 'Brand', which the module never binds"), and no
client code could brand a value.

Both the call form and the value form are covered: a brand is callable
wherever the primitive it erases to is.
"""

type Brand := int;

type Tag := str;


def brand_all(parts: list[any]) -> list[any] {
    return list(map(Brand, parts));
}


def:pub Badge(n: int, text: str) -> JsxElement {
    count = Brand(n);
    label = Tag(text);
    <div>{label}{count}{brand_all([1, 2])}</div>
}
