"""The numeric invariance guard must not reject idiomatic covariant uses.

Non-numeric element types keep plain covariance, generic inference is
untouched (TypeVar arguments are skipped), and literal elements still
widen to the container's declared numeric element type. Declared
variance still wins: a covariant type parameter, and the immutable and
read-only containers that declare one (tuple, Sequence, frozenset), keep
covariance for numeric elements too, and a union destination only holds
the numeric members it can store back.
"""

def take_anything(xs: list[object]) -> object {
    return xs[0];
}

def take_floats(xs: list[float]) -> float {
    return xs[0];
}

def take_maybe_floats(xs: list[float | None]) -> float | None {
    return xs[0];
}

def first[T](xs: list[T]) -> T {
    return xs[0];
}

def take_objects(xs: list[object | None]) -> object | None {
    return xs[0];
}

def take_seq_floats(xs: Sequence[float]) -> float {
    return xs[0];
}

def take_pair(xs: tuple[float, float]) -> float {
    return xs[0];
}

def take_mixed(xs: list[int | object]) -> object {
    return xs[0];
}

glob C = TypeVar('C', contravariant=True);

obj Consumer(Generic[C]) {
    def consume(item: C) -> None {
        ;
    }
}

obj ObjConsumer(Consumer[object]) {}

def feed_strs(c: Consumer[str]) -> None {
    c.consume("x");
}

glob BT = TypeVar('BT');

obj Box(Generic[BT]) {
    has v: BT;
}

obj NumBox(Box[int | float]) {}

def take_num_box(b: Box[int | float]) -> int | float {
    return b.v;
}

glob CV = TypeVar('CV', covariant=True);

obj Source(Generic[CV]) {
    def read -> CV {
        return self.v;
    }

    has v: CV;
}

obj IntSource(Source[int]) {}

def take_float_source(s: Source[float]) -> float {
    return s.read();
}

with entry {
    ints: list[int] = [1, 2, 3];
    words: list[str] = ["a"];
    o1: object = take_anything(ints);
    o2: object = take_anything(words);
    i1: int = first(ints);
    f1: float = take_floats([1, 2]);
    fs: list[float] = [1.0];
    f2: float | None = take_maybe_floats(fs);
    oc: ObjConsumer = ObjConsumer();
    feed_strs(oc);
    nb: NumBox = NumBox(v=1);
    n: int | float = take_num_box(nb);
    nums: list[int | float] = [1, 2.5];
    same_nums: list[int | float] = nums;
    strs: list[str | None] = ["a", None];
    o3: object | None = take_objects(strs);
    f3: float = take_seq_floats(ints);
    f4: float = take_pair((1, 2));
    mixed: list[int | str] = [1, "a"];
    o4: object = take_mixed(mixed);
    isrc: IntSource = IntSource(v=1);
    f5: float = take_float_source(isrc);
}
