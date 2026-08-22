"""An `any`-annotated glob is an ordinary global, not a declaration to skip.

Nothing here needs `typing` at run time: `any` is a builtin keyword and
appears only where a type is written, so the pre-scan has no import to
refuse and the module infers native on its own.

The glob is here on purpose. A `TypeAlias`-annotated glob is a declaration
the backend must skip; an `any`-annotated one is an ordinary global whose
value has to reach the binary. Classifying the second as the first would drop
it silently -- the trap `ClassVar` was lifted out of in #8278.
"""

glob TAGGED: any = 7;


obj Holder {
    has payload: any = 0,
        count: int = 0;
}


def stash(h: Holder, v: any) -> int {
    h.payload = v;
    h.count += 1;
    return h.count;
}


def total(h: Holder) -> int {
    return h.count + TAGGED;
}
