"""Implementation with TypeVar in impl block."""

impl Basics.assign_all(
    target: list[T], attr_val: tuple[tuple[str], tuple[Any]]
) -> list[T] {
    for `obj in target {
        (attrs, values) = attr_val;
        for (attr, value) in zip(attrs, values, strict=False) {
            setattr(`obj, attr, value);
        }
    }
    return target;
}
