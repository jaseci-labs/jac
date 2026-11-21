"""Which objects the cycle collector buffers as candidate roots, and how long
it waits before the next collection. Driven through ctypes by
test_native_cycle_collect_pacing.jac: each function is one step.

`Leaf` and `list[int]` have nothing to trace, so they can never be on a cycle
the collector reclaims. `Hub` holds a live cyclic graph (each `Node` points
back at it) that a collection has to trace in full. `Box` pairs are cyclic
garbage that only the collector reclaims."""

glob leaves_dropped: int = 0,
     boxes_dropped: int = 0;

obj Leaf {
    has x: float = 0.0,
        y: float = 0.0;

    def drop {
        leaves_dropped += 1;
    }
}

obj Box {
    has other: Box | None = None,
        leaf: Leaf | None = None;

    def drop {
        boxes_dropped += 1;
    }
}

obj Hub {
    has nodes: list[Node] = [];
}

obj Node {
    has home: Hub | None = None,
        weight: float = 0.0;
}

"""Untraced values reached through fields: a list of ints, a leaf, an
optional leaf and a list of leaves."""
obj Holder {
    has numbers: list[int] = [],
        leaf: Leaf = Leaf(),
        maybe: Leaf | None = None,
        leaves: list[Leaf] = [];
}

glob holder: Holder = Holder(
         numbers=[1, 2, 3], maybe=Leaf(), leaves=[Leaf(), Leaf()]
     ),
     hub: Hub = Hub(),
     first: Box | None = None,
     second: Box | None = None;

"""Share `n` leaves and `n` lists of ints for a moment, then drop them: each
is released to a nonzero count (the moment its sharer lets go) and then
freed."""
def share_untraced(n: int) {
    for i in range(n) {
        leaf = Leaf(x=float(i));
        numbers = [i, i + 1];
        leaves: list[Leaf] = [leaf];
        lists: list[list[int]] = [numbers];
        leaves = [];
        lists = [];
    }
}

"""Read the holder's untraced fields `n` times: each local releases its value
to a nonzero count."""
def read_untraced(n: int) {
    for i in range(n) {
        numbers = holder.numbers;
        leaf = holder.leaf;
        maybe = holder.maybe;
        for each in holder.leaves {
            x = each.x;
        }
    }
}

"""Give the hub `n` nodes pointing back at it."""
def grow_hub(n: int) {
    for i in range(n) {
        hub.nodes.append(Node(home=hub, weight=float(i)));
    }
}

"""Release the hub to a nonzero count, making it a candidate root."""
def touch_hub {
    holder: list[Hub] = [hub];
    holder = [];
}

"""Make `n` garbage pairs of boxes, each holding a leaf."""
def make_pairs(n: int) {
    for i in range(n) {
        a = Box(leaf=Leaf());
        b = Box(other=a);
        a.other = b;
    }
}

"""Buffer two boxes the globals keep alive."""
def buffer_two {
    a = Box();
    b = Box();
    first = a;
    second = b;
    holder: list[Box] = [a, b];
    holder = [];
}

"""Free the first buffered box while it is still buffered."""
def drop_first {
    first = None;
}

def dropped_boxes -> int {
    return boxes_dropped;
}

def dropped_leaves -> int {
    return leaves_dropped;
}

def collect {
    __rc_collect_cycles();
}
