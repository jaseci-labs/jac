"""Iterating a call result straight from the `for` header (issue #8147).

`for part in t.mangle().split("|")` and `parts = t.mangle().split("|"); for
part in parts` are the same loop, and the native emitter used to treat them
very differently. A call result is +1 by the calling convention, so the
frame owns whatever the header produced; a named local carries that
reference in a frame slot the scope-cleanup walk can see, while an unnamed
header temporary lived only in an SSA register and was released in exactly
one place -- the loop's own exit block.

Every exit that does not pass through that block therefore leaked the whole
collection: an early `return`, an exception unwinding past the loop, and
the outer loop of a nested pair whose inner loop returns. `break` was fine,
because `break` branches to precisely the block holding the release, which
is why the shape looked healthy from the outside.

The values are the same either way -- the leak is invisible to the answer --
so `drop` bumps a module glob and every accounting function encodes
`destructions * 1000 + value` into one i64. The plain-value functions are
the parity surface: the fix must not change a single answer.

`n` is the only parameter so both codespaces can be driven through one
`(int) -> int` signature.
"""

glob dropped = 0;


obj Node {
    has tag: int = 0;

    def drop {
        dropped += 1;
    }
}


"""A container whose accessor returns a second owned list -- the `a.f().g()` shape."""
obj Bag {
    has items: list[Node] = [];

    def all -> list[Node] {
        out: list[Node] = [];
        for x in self.items {
            out.append(x);
        }
        return out;
    }
}


def drop_count -> int {
    return dropped;
}


"""n fresh Nodes, tagged 1..n. The caller owns the list it gets back."""
def mk_nodes(n: int) -> list[Node] {
    out: list[Node] = [];
    for i in range(n) {
        out.append(Node(tag=i + 1));
    }
    return out;
}


"""A call whose result is an empty container."""
def mk_empty(n: int) -> list[Node] {
    out: list[Node] = [];
    return out;
}


def mk_bag(n: int) -> Bag {
    return Bag(items=mk_nodes(n));
}


"""A call returning a heap string, iterated character by character."""
def mk_word(n: int) -> str {
    out = "";
    for i in range(n) {
        out = out + "ab";
    }
    return out;
}


# --- plain-value functions: the parity surface -----------------------------

"""The loop runs to completion; the exit block does hold the release."""
def full_header(n: int) -> int {
    acc = 0;
    for nd in mk_nodes(n) {
        acc = acc * 10 + nd.tag;
    }
    return acc;
}


"""`break` branches to the loop's own exit block."""
def break_header(n: int) -> int {
    acc = 0;
    for nd in mk_nodes(n) {
        if nd.tag == 2 {
            break;
        }
        acc = acc * 10 + nd.tag;
    }
    return acc;
}


"""`continue` goes round the back edge, so the collection must stay live."""
def continue_header(n: int) -> int {
    acc = 0;
    for nd in mk_nodes(n) {
        if nd.tag == 2 {
            continue;
        }
        acc = acc * 10 + nd.tag;
    }
    return acc;
}


"""An early `return` leaves the loop without passing through its exit block."""
def early_ret_header(n: int) -> int {
    for nd in mk_nodes(n) {
        if nd.tag == 2 {
            return nd.tag;
        }
    }
    return -1;
}


"""The identical loop with the call bound to a local first."""
def early_ret_local(n: int) -> int {
    lst = mk_nodes(n);
    for nd in lst {
        if nd.tag == 2 {
            return nd.tag;
        }
    }
    return -1;
}


"""A chained header, `a.f().g()`: two owned temporaries, neither one named."""
def chained_header(n: int) -> int {
    for nd in mk_bag(n).all() {
        if nd.tag == 2 {
            return nd.tag;
        }
    }
    return -1;
}


"""An exception unwinds past the loop; the collection is still the frame's."""
def raise_header(n: int) -> int {
    try {
        for nd in mk_nodes(n) {
            if nd.tag == 2 {
                raise ValueError("boom");
            }
        }
    } except ValueError {
        return 5;
    }
    return -1;
}


"""Two header calls nested; the inner loop's `return` leaves both loops."""
def nested_header(n: int) -> int {
    for a in mk_nodes(n) {
        for b in mk_nodes(n) {
            if a.tag == 2 and b.tag == 2 {
                return a.tag * 10 + b.tag;
            }
        }
    }
    return -1;
}


"""An adapter over a header call: the iterator protocol path, not the indexed one."""
def adapter_header(n: int) -> int {
    for (i, nd) in enumerate(mk_nodes(n)) {
        if nd.tag == 2 {
            return i * 10 + nd.tag;
        }
    }
    return -1;
}


"""A header call whose result is empty: zero iterations, still +1 to give back."""
def empty_header(n: int) -> int {
    acc = 7;
    for nd in mk_empty(n) {
        acc = acc + nd.tag;
    }
    return acc;
}


"""A header call returning a heap string, left early."""
def str_header(n: int) -> int {
    acc = 0;
    for c in mk_word(n) {
        acc += 1;
        if acc == 3 {
            return acc;
        }
    }
    return acc;
}


"""A header call returning a dict, left early."""
def dict_header(n: int) -> int {
    for k in mk_map(n) {
        if k == "k1" {
            return len(k);
        }
    }
    return -1;
}


def mk_map(n: int) -> dict[str, int] {
    out: dict[str, int] = {};
    for i in range(n) {
        out[f"k{i}"] = i;
    }
    return out;
}


# --- accounting: destructions * 1000 + value -------------------------------

def full_header_drops(n: int) -> int {
    before = drop_count();
    v = full_header(n);
    return (drop_count() - before) * 1000 + v;
}


def break_header_drops(n: int) -> int {
    before = drop_count();
    v = break_header(n);
    return (drop_count() - before) * 1000 + v;
}


def continue_header_drops(n: int) -> int {
    before = drop_count();
    v = continue_header(n);
    return (drop_count() - before) * 1000 + v;
}


def early_ret_header_drops(n: int) -> int {
    before = drop_count();
    v = early_ret_header(n);
    return (drop_count() - before) * 1000 + v;
}


def early_ret_local_drops(n: int) -> int {
    before = drop_count();
    v = early_ret_local(n);
    return (drop_count() - before) * 1000 + v;
}


def chained_header_drops(n: int) -> int {
    before = drop_count();
    v = chained_header(n);
    return (drop_count() - before) * 1000 + v;
}


def raise_header_drops(n: int) -> int {
    before = drop_count();
    v = raise_header(n);
    return (drop_count() - before) * 1000 + v;
}


def nested_header_drops(n: int) -> int {
    before = drop_count();
    v = nested_header(n);
    return (drop_count() - before) * 1000 + v;
}


def adapter_header_drops(n: int) -> int {
    before = drop_count();
    v = adapter_header(n);
    return (drop_count() - before) * 1000 + v;
}


def empty_header_drops(n: int) -> int {
    before = drop_count();
    v = empty_header(n);
    return (drop_count() - before) * 1000 + v;
}


with entry {
    assert full_header(3) == 123;
    assert early_ret_header(3) == 2;
    assert early_ret_local(3) == 2;
    print("ok");
}
