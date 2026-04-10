"""Fixture: hover on an LHS assignment target shows the post-write
effective type, matching pyright/pylance."""

def flat_narrow(x: int | None) -> int {
    x = 90;
    return x;
}


def flat_to_none(x: int | None) -> int | None {
    x = None;
    return x;
}


def flat_to_union(x: int | None, y: int | None) -> int | None {
    x = y;
    return x;
}


def destructure_narrow(x: int | None) -> int {
    (x, _) = (5, "ok");
    return x;
}


def destructure_nested(b: int | None) -> int {
    ((_, b), _) = ((1, 2), 3);
    return b;
}


def aug_op(x: int | None) -> int | None {
    if x is not None {
        x += 1;
    }
    return x;
}
