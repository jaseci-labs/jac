"""B1 fix: typing.cast() special-form handling.

Before this fix, cast(T, val) matched the `object` overload in the typeshed
stub and returned Any/Unknown instead of T.
"""
import from typing { cast }

obj Foo {
    has name: str = "foo";
}

with entry {
    x: object = "hello";
    y: str = cast(str, x);
    z: Foo = cast(Foo, x);
    w: int = cast(int, x);
    print(z.name);
}
