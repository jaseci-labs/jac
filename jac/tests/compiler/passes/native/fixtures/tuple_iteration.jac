"""Fixture: iterating a tuple, in every shape a tuple reaches a loop header.

A tuple literal lowers to an unboxed LLVM literal struct -- a value with one
field per element and no runtime sequence behind it -- so nothing in the
for-loop's iterable dispatch could ever match it. The list-literal form of the
same loop lowers, which is why the idiomatic tuple form had to be rewritten as
a list at its one real call site.

The cases differ in where the tuple comes from (a literal in the header, a
local bound above the loop, a call's return value) and in what the elements
are, because the element flavor is what picks the backing store: a homogeneous
str tuple is a pointer sequence, a homogeneous int tuple a raw-integer one, a
homogeneous float tuple a double one. The empty and single-element literals are
the two degenerate shapes: the first has no element to infer a flavor from, the
second is a tuple only because of its trailing comma.

Every tuple here is homogeneous. A tuple of mixed element storage is refused
rather than iterated, and lives in `tuple_iteration_mixed.jac`.

Each `_tuple` function has a `_list` twin running the identical body over the
list form, so the two spellings can be held against each other as well as
against the sv result.
"""

"""The `unitree` shape: a homogeneous str tuple in the loop header."""
def str_tuple(seed: int) -> int {
    acc = seed;
    for name in ('__init__.jac', '__init__.py', '__init__.pyi') {
        acc = acc * 31 + len(name);
    }
    return acc;
}


"""The same loop written as a list, the form that already lowers."""
def str_list(seed: int) -> int {
    acc = seed;
    for name in ['__init__.jac', '__init__.py', '__init__.pyi'] {
        acc = acc * 31 + len(name);
    }
    return acc;
}


"""A homogeneous int tuple: a raw-integer backing store."""
def int_tuple(seed: int) -> int {
    acc = seed;
    for v in (3, 5, 7) {
        acc = acc * 10 + v;
    }
    return acc;
}


"""The list twin of the int tuple."""
def int_list(seed: int) -> int {
    acc = seed;
    for v in [3, 5, 7] {
        acc = acc * 10 + v;
    }
    return acc;
}


"""A homogeneous float tuple, the third element flavor."""
def float_tuple(seed: int) -> int {
    acc = seed;
    for v in (1.5, 2.25, 4.0) {
        acc = acc * 10 + int(v * 4.0);
    }
    return acc;
}


"""An empty tuple literal: no element to infer a flavor from, body never runs.

The body cannot read the loop variable: an empty literal carries no element
type, so `v` is `Unknown` and any use of it is a type error before codegen
ever sees the loop.
"""
def empty_tuple(seed: int) -> int {
    acc = seed;
    for v in () {
        acc = acc + 1;
    }
    return acc;
}


"""A single-element tuple, which is a tuple only by its trailing comma."""
def single_tuple(seed: int) -> int {
    acc = seed;
    for v in (9, ) {
        acc = acc * 10 + v;
    }
    return acc;
}


"""A tuple bound to a local above the loop, not written in the header."""
def local_tuple(seed: int) -> int {
    names = ('ab', 'cde', 'f');
    acc = seed;
    for s in names {
        acc = acc * 7 + len(s);
    }
    return acc;
}


"""The source of a tuple that arrives through a return."""
def make_tuple -> tuple[int, int, int] {
    return (2, 4, 6);
}


"""A tuple handed back from a call, iterated directly off the call."""
def call_tuple(seed: int) -> int {
    acc = seed;
    for v in make_tuple() {
        acc = acc * 10 + v;
    }
    return acc;
}


"""The mixed list, which lowers boxed and types its element as a union.

This is the contrast case for the refused mixed tuple: the same three values
in a list iterate as tagged `jacval` slots, and the checker widens the loop
variable to `int | str`, so the `isinstance` in the body reads the tag it was
stored with.
"""
def hetero_list(seed: int) -> int {
    acc = seed;
    for v in [1, 'ab', 3] {
        acc = acc * 5;
        if isinstance(v, str) {
            acc = acc + len(v);
        } elif isinstance(v, int) {
            acc = acc + v;
        }
    }
    return acc;
}


"""A tuple loop nested in another loop, with `break` and `continue` over it."""
def nested_tuple(seed: int) -> int {
    acc = seed;
    for i in range(3) {
        for name in ('aa', 'bbb', 'cccc') {
            if len(name) == 3 {
                continue;
            }
            acc = acc * 3 + len(name) + i;
            if len(name) == 4 {
                break;
            }
        }
    }
    return acc;
}


with entry {
    print(str_tuple(1));
    print(int_tuple(1));
    print(empty_tuple(1));
    print(single_tuple(1));
    print(local_tuple(1));
    print(call_tuple(1));
    print(hetero_list(1));
    print(nested_tuple(1));
}
