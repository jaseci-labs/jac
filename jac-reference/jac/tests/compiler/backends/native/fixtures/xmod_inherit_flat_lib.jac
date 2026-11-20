"""A flat archetype whose own module gives it no vtable slot.

Nothing here subclasses `Anchor` and nothing names it in an `isinstance`, so
`LayoutPass` lays it out with `depth` at slot 0. A consumer subclass used to
claim that same slot for a vtable, which it got merely for having a base;
where nothing is dispatched through the subclass, that header is dropped and
both units read `depth` at slot 0.
"""

obj Anchor {
    has depth: int = 0;
}

def make_anchor(d: int) -> Anchor {
    return Anchor(depth=d);
}
