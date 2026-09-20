"""A brand must behave at run time like the primitive it erases to.

The compile-time half of this contract (a brand binds `_jac.types.<primitive>`)
says nothing about what that binding does when it is called. These functions
are executed in Node so the brand is held to the same behavior the primitive
itself already has in value position: a call coerces, and a brand handed to
`map` keeps Python's one-argument call contract -- JS `.map` passes
(value, index, array), so a leaked index would land in `int`'s `base`
parameter and turn ["1", "2", "3"] into [1, NaN, NaN].
"""

type Brand := int;

type Tag := str;


def brand_call(x: any) -> any {
    return Brand(x);
}


def tag_call(x: any) -> any {
    return Tag(x);
}


def brand_all(parts: list[any]) -> list[any] {
    return list(map(Brand, parts));
}


def brands_from_list(x: any) -> list[any] {
    coercions = [Brand, Tag];
    return [
        c(x)
        for c in coercions
    ];
}
