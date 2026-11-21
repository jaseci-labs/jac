"""Fixture: a dict keyed by `type`, the shape of `UniNode.__sub_node_tab`.

The table is an identity map over a closed set of classes: it is built from
`type(x)` on a receiver whose static type is a base class, probed with class
literals, merged key-by-key out of another table's `.items()`, and carried as
an object field. Every one of those needs the same notion of class identity,
and it has to be the *runtime* class -- a `Node`-typed slot holding an `Alpha`
must key the `Alpha` bucket, and `AlphaLeaf` must not fall into `Alpha`'s.

`type_keyed_dict_lib` mints class references in a second module, so the
identity is checked across a module boundary too: a key produced by
`ext_class` has to match the literal `Ext` / `ExtSub` written here.

Every function returns an int so the native result can be compared against
the sv/bytecode result of the same source.
"""

import from type_keyed_dict_lib { Ext, ExtSub, ext_class }

obj Node {
    has n: int = 0;
}

obj Alpha(Node) {
    has a: int = 1;
}

obj Beta(Node) {
    has b: int = 2;
}

obj AlphaLeaf(Alpha) {
    has c: int = 3;
}

# `Registry.tab` is the layout-compatibility case: the table as an object
# field, which is where #8068 first bites (`UniNode.__sub_node_tab`).
obj Registry {
    has tab: dict[type, list[Node]] = {};

    def add(it: Node) {
        if `type(it) in self.tab {
            self.tab[`type(it)].append(it);
        } else {
            self.tab[`type(it)] = [it];
        }
    }

    def count(k: type) -> int {
        if k in self.tab {
            return len(self.tab[k]);
        }
        return 0;
    }
}

"""Six nodes over four classes, each carrying a distinct `n`."""
def sample -> list[Node] {
    out: list[Node] = [];
    out.append(Node(n=1));
    out.append(Alpha(n=2));
    out.append(Beta(n=3));
    out.append(Alpha(n=4));
    out.append(AlphaLeaf(n=5));
    out.append(Node(n=7));
    return out;
}

"""`_construct_sub_node_tab`'s shape: bucket by the runtime class of each kid."""
def index_by_type(items: list[Node]) -> dict[type, list[Node]] {
    tab: dict[type, list[Node]] = {};
    for it in items {
        if `type(it) in tab {
            tab[`type(it)].append(it);
        } else {
            tab[`type(it)] = [it];
        }
    }
    return tab;
}

"""A `type` crossing a call boundary as a parameter."""
def bucket_sum(tab: dict[type, list[Node]], k: type) -> int {
    if k not in tab {
        return 0;
    }
    total = 0;
    for it in tab[k] {
        total += it.n;
    }
    return total;
}

def key_count -> int {
    return len(index_by_type(sample()));
}

# Node 1+7, Alpha 2+4, Beta 3, AlphaLeaf 5 -- one digit each.
def literal_key_sums -> int {
    tab = index_by_type(sample());
    return (
        bucket_sum(tab, Node) * 1000
        + bucket_sum(tab, Alpha) * 100
        + bucket_sum(tab, Beta) * 10
        + bucket_sum(tab, AlphaLeaf)
    );
}

"""Probe with `type(x)` off a base-typed slot rather than a class literal."""
def runtime_key_sums -> int {
    items = sample();
    tab = index_by_type(items);
    total = 0;
    for it in items {
        total = total * 10 + bucket_sum(tab, `type(it));
    }
    return total;
}

"""A subclass key must not collapse into its parent's bucket."""
def subclass_keys_distinct -> int {
    tab = index_by_type(sample());
    return (
        bucket_sum(tab, Alpha) * 100
        + bucket_sum(tab, AlphaLeaf) * 10
        + bucket_sum(tab, Node)
    );
}

"""Keys minted in `type_keyed_dict_lib`, read with literals written here."""
def cross_module_key -> int {
    tab: dict[type, int] = {};
    tab[ext_class(ExtSub(w=1))] = 7;
    tab[ext_class(Ext(v=2))] = 9;
    sub = tab[ExtSub] if ExtSub in tab else -1;
    base = tab[Ext] if Ext in tab else -1;
    return sub * 10 + base;
}

"""The same crossing in the other direction: literals in, minted keys out."""
def cross_module_key_reverse -> int {
    tab: dict[type, int] = {};
    tab[ExtSub] = 4;
    tab[Ext] = 5;
    return (
        tab[ext_class(ExtSub(w=1))] * 10 + tab[ext_class(Ext(v=2))] + len(tab) * 100
    );
}

"""A `type` held in a local before it is used as a key."""
def key_in_local -> int {
    tab = index_by_type(sample());
    k = Beta;
    other = AlphaLeaf;
    return bucket_sum(tab, k) * 10 + bucket_sum(tab, other);
}

"""Class literals as keys of a dict literal."""
def dict_literal_keys -> int {
    tab: dict[type, list[Node]] = {Alpha: [Node(n=1)], Beta: [Node(n=2), Node(n=3)]};
    return len(tab) * 100 + bucket_sum(tab, Beta) * 10 + bucket_sum(tab, Alpha);
}

"""`_construct_sub_node_tab`'s merge: keys read out of one table into another."""
def merge_tables -> int {
    dst: dict[type, list[Node]] = {};
    i = 0;
    while i < 2 {
        src = index_by_type(sample());
        for (k, v) in src.items() {
            if k in dst {
                dst[k].extend(v);
            } else {
                dst[k] = `list(v);
            }
        }
        i += 1;
    }
    total = 0;
    for k in dst {
        total += len(dst[k]);
    }
    return len(dst) * 1000 + total;
}

"""A key recovered by iterating one table still indexes an independent one."""
def key_roundtrip -> int {
    a = index_by_type(sample());
    b = index_by_type(sample());
    hits = 0;
    for k in a {
        if k in b {
            hits += len(b[k]);
        }
    }
    return hits;
}

"""The table as an object field -- the layout-compatibility case."""
def registry_field -> int {
    r = Registry();
    for it in sample() {
        r.add(it);
    }
    return (
        len(r.tab) * 1000
        + r.count(Alpha) * 100
        + r.count(AlphaLeaf) * 10
        + r.count(Beta)
    );
}

"""`UniPass.get_all_sub_nodes`' shape: a `type[T]` probe plus a runtime filter."""
def collect[T](tab: dict[type, list[Node]], typ: type[T]) -> list[T] {
    out: list[T] = [];
    if typ in tab {
        for it in tab[typ] {
            if isinstance(it, typ) {
                out.append(it);
            }
        }
    }
    return out;
}

def generic_collect -> int {
    tab = index_by_type(sample());
    return (
        len(collect(tab, Node)) * 1000
        + len(collect(tab, Alpha)) * 100
        + len(collect(tab, AlphaLeaf)) * 10
        + len(collect(tab, Beta))
    );
}

"""`isinstance` against a class value carried in a variable, not a literal."""
def isa_runtime[T](it: Node, typ: type[T]) -> int {
    return 1 if isinstance(it, typ) else 0;
}

# A runtime class value has to answer with subclass semantics, not identity:
# an AlphaLeaf is an Alpha and a Node, a Node is neither an Alpha nor a Beta.
def runtime_isinstance -> int {
    leaf = AlphaLeaf(n=5);
    base = Node(n=1);
    beta = Beta(n=3);
    return (
        isa_runtime(leaf, Alpha) * 100000
        + isa_runtime(leaf, Node) * 10000
        + isa_runtime(leaf, AlphaLeaf) * 1000
        + isa_runtime(base, Alpha) * 100
        + isa_runtime(beta, Alpha) * 10
        + isa_runtime(beta, Node)
    );
}

"""A class never inserted must miss, and must not alias a class that was."""
def absent_key -> int {
    tab: dict[type, list[Node]] = {};
    tab[Alpha] = [Node(n=1), Node(n=2)];
    hit = 1 if Alpha in tab else 0;
    miss = 1 if AlphaLeaf in tab else 0;
    return hit * 100 + miss * 10 + bucket_sum(tab, Beta);
}

with entry {
    _ready: int = key_count();
}
