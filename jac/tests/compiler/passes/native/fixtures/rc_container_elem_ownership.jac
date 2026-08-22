"""Ownership accounting for comprehension elements (issue #8088).

A container must hold a reference of its own to every element it stores:
+1 per element, given back when the container itself dies. The way to get
this wrong is for the element expression to hand the container a borrow the
emitter believes is a fresh reference, so the retain the container takes is
undone by the release of the "temporary": the pair nets zero and the element
lives only as long as whatever else happens to hold it.

`Node.self_ref` is the shape that provokes it -- a method whose body is
`return self` gives back the receiver, which the caller lent it. The
comprehension's other axes sit next to it, because getting one element
expression right and leaving the others is the failure mode:

  - a call that makes a fresh object (`fresh_*`), where the container must
    *not* end up with a second reference;
  - a bare loop variable (`alias_*`), a borrow of the source container;
  - a source the frame owns (a local) versus one it only borrows (a param),
    since the walk releases the collection only in the first case;
  - list, dict, set and nested-list containers;
  - a heap string element, whose slot is a descriptor rather than a pointer.

Every builder returns its container and lets the source list and the other
locals die at its scope exit, so on the way back the only thing keeping the
elements alive is the container's own reference. `def drop` bumps a module
glob, so the tests count destructions exactly instead of reading whatever
freed memory happens to contain.
"""

glob dropped = 0;

obj Node {
    has tag: int = 0,
        label: str = "",
        kids: list[Node] = [],
        parent: (Node | None) = None;

    def drop {
        dropped += 1;
    }

    """Bind a parent and give back the receiver -- a borrow, not a new ref."""
    def self_ref(p: Node) -> Node {
        self.parent = p;
        return self;
    }

    """Hand back a field -- also a borrow, and a string descriptor slot."""
    def get_label -> str {
        return self.label;
    }

    """An element indexed out of a field: borrowed through the receiver."""
    def first_kid -> Node {
        return self.kids[0];
    }

    """The same shape where the element slot is a string descriptor."""
    def first_kid_label -> str {
        return self.kids[0].label;
    }
}

def drop_count -> int {
    return dropped;
}

def make_src(n: int) -> list[Node] {
    out: list[Node] = [];
    for i in range(n) {
        out.append(Node(tag=i + 1, label=f"n{i + 1}"));
    }
    return out;
}

# --- builders: each drops its source and locals before returning ----------

"""[x.self_ref(owner) for x in src]: the element expression returns a borrow."""
def borrow_elems(n: int) -> list[Node] {
    owner = Node(tag=100);
    src = make_src(n);
    return [x.self_ref(owner) for x in src];
}

"""[Node(...) for x in src]: the element expression returns a fresh object."""
def fresh_elems(n: int) -> list[Node] {
    src = make_src(n);
    return [Node(tag=x.tag + 10) for x in src];
}

"""[x for x in src]: the element expression is a bare borrow of the source."""
def alias_elems(n: int) -> list[Node] {
    src = make_src(n);
    return [x for x in src];
}

"""[x.get_label() for x in src]: heap string elements, borrowed from a field."""
def label_elems(n: int) -> list[str] {
    src = make_src(n);
    return [x.get_label() for x in src];
}

"""The borrow-returning element expression over a collection we only borrow."""
def borrow_elems_from_param(src: list[Node], owner: Node) -> list[Node] {
    return [x.self_ref(owner) for x in src];
}

"""Nested list comprehension: every inner list owns what it stores too."""
def nested_elems(n: int) -> list[list[Node]] {
    owner = Node(tag=100);
    src = make_src(n);
    return [[y.self_ref(owner) for y in src] for x in src];
}

"""{x.tag: x.self_ref(owner) ...}: dict values from a borrow-returning call."""
def dict_elems(n: int) -> dict[int, Node] {
    owner = Node(tag=100);
    src = make_src(n);
    return {x.tag: x.self_ref(owner) for x in src};
}

"""{x.self_ref(owner) ...}: set elements from a borrow-returning call."""
def set_elems(n: int) -> set[Node] {
    owner = Node(tag=100);
    src = make_src(n);
    return {x.self_ref(owner) for x in src};
}

# --- readers -------------------------------------------------------------

def sum_list(kept: list[Node]) -> int {
    total = 0;
    for e in kept {
        total += e.tag;
    }
    return total;
}

def borrow_elem_sum(n: int) -> int {
    return sum_list(borrow_elems(n));
}

"""Each element's parent field must have kept the owner alive as well."""
def borrow_elem_parent_sum(n: int) -> int {
    kept = borrow_elems(n);
    total = 0;
    for e in kept {
        p = e.parent;
        if p is not None {
            total += p.tag;
        }
    }
    return total;
}

def fresh_elem_sum(n: int) -> int {
    return sum_list(fresh_elems(n));
}

def alias_elem_sum(n: int) -> int {
    return sum_list(alias_elems(n));
}

"""Read every string element back and compare it byte for byte."""
def label_match_count(n: int) -> int {
    kept = label_elems(n);
    hits = 0;
    i = 0;
    for s in kept {
        i += 1;
        if s == f"n{i}" {
            hits += 1;
        }
    }
    return hits;
}

def dict_elem_sum(n: int) -> int {
    d = dict_elems(n);
    total = 0;
    for i in range(n) {
        v = d[i + 1];
        total += v.tag;
    }
    return total;
}

def param_elem_sum(n: int) -> int {
    src = make_src(n);
    owner = Node(tag=100);
    kept = borrow_elems_from_param(src, owner);
    return sum_list(kept) + sum_list(src);
}

# --- destruction counters ------------------------------------------------

"""Destructions the builder caused, then those releasing its result caused."""
def borrow_elem_drops(n: int) -> int {
    before = dropped;
    kept = borrow_elems(n);
    mid = dropped - before;
    total = sum_list(kept);
    kept = [];
    after = dropped - before;
    return mid * 1000000 + after * 1000 + total;
}

def fresh_elem_drops(n: int) -> int {
    before = dropped;
    kept = fresh_elems(n);
    mid = dropped - before;
    total = sum_list(kept);
    kept = [];
    after = dropped - before;
    return mid * 1000000 + after * 1000 + total;
}

def alias_elem_drops(n: int) -> int {
    before = dropped;
    kept = alias_elems(n);
    mid = dropped - before;
    total = sum_list(kept);
    kept = [];
    after = dropped - before;
    return mid * 1000000 + after * 1000 + total;
}

def dict_elem_drops(n: int) -> int {
    before = dropped;
    d = dict_elems(n);
    mid = dropped - before;
    total = 0;
    for i in range(n) {
        v = d[i + 1];
        total += v.tag;
    }
    d = {};
    after = dropped - before;
    return mid * 1000000 + after * 1000 + total;
}

"""Sets have no native element iteration, so length is the read-back."""
def set_elem_drops(n: int) -> int {
    before = dropped;
    s = set_elems(n);
    mid = dropped - before;
    return mid * 1000 + len(s);
}

"""Nested: `after` is left out, see the suite's comment on this one."""
def nested_elem_drops(n: int) -> int {
    before = dropped;
    outer = nested_elems(n);
    mid = dropped - before;
    total = 0;
    for inner in outer {
        total += sum_list(inner);
    }
    return mid * 1000 + total;
}

"""A borrowed source keeps its elements when the built list is released."""
def param_elem_drops(n: int) -> int {
    src = make_src(n);
    owner = Node(tag=100);
    before = dropped;
    kept = borrow_elems_from_param(src, owner);
    kept = [];
    mid = dropped - before;
    return mid * 1000 + sum_list(src);
}

# --- the receiver itself, outside any container ---------------------------

"""`return self` on its own: the caller must get a reference of its own."""
def self_ref_direct(n: int) -> int {
    owner = Node(tag=100);
    src = make_src(n);
    kept = src[0].self_ref(owner);
    src = [];
    return kept.tag * 1000 + owner.tag;
}

"""`return self.kids[i]`: an element reached through the receiver."""
def kid_elem_return(n: int) -> int {
    holder = Node(tag=0, kids=make_src(n));
    k = holder.first_kid();
    holder.kids = [];
    return k.tag;
}

"""The same, where the element is a string descriptor rather than a pointer."""
def kid_label_return(n: int) -> int {
    holder = Node(tag=0, kids=make_src(n));
    s = holder.first_kid_label();
    holder.kids = [];
    return len(s);
}
