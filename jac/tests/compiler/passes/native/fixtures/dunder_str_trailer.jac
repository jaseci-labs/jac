"""`__str__` dunders whose body is an attribute / index chain (roadmap N8b).

Three shapes: a Python-class-form enum (`class K(StrEnum)`) whose `__str__`
returns `self.value`, which is the shape `Constants.__str__` takes in the
compiler's own source; an object dunder reading through a nested field; and an
object dunder reading through a field-then-index chain. All three must lower
natively, and the enum members must keep their sv value semantics (a StrEnum
member IS its string).
"""

import from enum { StrEnum }

class Kind(StrEnum) {
    with entry {
        ALPHA = 'alpha';
        BETA = 'beta';
    }

    def __str__(self: Kind) -> str;
}

impl Kind.__str__(self: Kind) -> str {
    return self.value;
}

obj Inner {
    has label: str,
        tags: list[str];
}

obj Outer {
    has inner: Inner;

    def __str__ -> str {
        return self.inner.label;
    }
}

obj Indexed {
    has inner: Inner;

    def __str__ -> str {
        return self.inner.tags[1];
    }
}

def alpha_value -> str {
    return Kind.ALPHA.value;
}

def alpha_str -> str {
    return str(Kind.ALPHA);
}

def beta_render -> str {
    return f"{Kind.BETA}";
}

def alpha_is_text -> int {
    return 1 if Kind.ALPHA == "alpha" else 0;
}

def outer_str -> str {
    return str(Outer(inner=Inner(label="deep", tags=["t0", "t1"])));
}

def indexed_str -> str {
    return str(Indexed(inner=Inner(label="deep", tags=["t0", "t1"])));
}
