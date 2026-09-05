"""A generic over a borrowed list returning a borrow of an element (#8984 A5):
the element layout is decided by the element type, so the generic body and the
caller agree on it."""

obj Box { has v: int = 0; }

def first[T](xs: &list[T]) -> &T { return &xs[0]; }

def run -> int {
    xs: list[own Box] = [];
    xs.append(Box(v=7));
    xs.append(Box(v=8));
    return first(&xs).v * 10 + first(&xs).v;
}

with entry { print(run()); }
