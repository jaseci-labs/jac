"""An open-receiver `__class__.__name__` that only the rc header can answer.

`Box[T].held` is type-erased, so the receiver is an opaque object pointer with
no struct behind it and no vtable to walk. Every gc mode that gives an
allocation a header answers this off the header's class-name stamp. Headerless
`--memory nogc` gives it none, so there is nothing to read and the
read has to be **refused** -- reading anyway would probe memory in front of a
bare `malloc`, which either faults or, worse, passes the sentinel/magic check
on whatever bytes happen to be there and returns garbage as a class name.

The ownership annotations are here so that a refusal observed under headerless
mode is the class-name refusal and not an unrelated `--memory nogc`
diagnostic. Compiled under an ordinary gc mode this same file lowers and
answers, which is what makes the refusal mode-specific rather than a defect.
"""

obj Marked {
    has m: int = 1;
}

obj Box[T] {
    has held: T;
}


def erased_rank(pick: int) -> int {
    b: own Box = Box(held=Marked());
    if type(b.held).__name__ == "Marked" {
        return 1;
    }
    return 0;
}
