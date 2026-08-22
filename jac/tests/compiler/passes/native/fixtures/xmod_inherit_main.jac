"""Inherited field access through a consumer subclass of an imported base.

Every line printed here is an offset the consumer had to take from the
defining module: an inherited read, an inherited write, a declared field that
must sit *after* the inherited ones, a constructor keyword naming an
inherited field, and an imported method reading the same object through the
base's own offsets. The library's instances go through the same reads, so a
layout that only satisfies the subclass would be caught too.

`Deep` is the two-link case: `Mid`'s layout is itself already flattened over
`Base`, so adopting it adopts the whole chain, and `d.bump` reaches a method
declared two links up through the wrapper `Mid` carries.
"""

import from xmod_inherit_lib { Base, Mid, make_base, read_tag }

obj Kid(Base) {
    has mine: int = 0;
}

obj Deep(Mid) {
    has extra: int = 0;
}

def run_probe {
    k = Kid(tag="kid", depth=3, mine=7);
    print(k.tag);
    print(k.depth);
    print(k.mine);
    k.depth = 11;
    k.tag = "rekid";
    print(k.tag);
    print(k.depth);
    print(k.mine);
    print(k.describe());
    print(k.bump(4));
    print(read_tag(k));
    b = make_base("lib", 2);
    print(b.tag);
    print(b.depth);
    print(b.describe());
    d = Deep(tag="deep", depth=1, mid=5, extra=9);
    print(d.tag);
    print(d.depth);
    print(d.mid);
    print(d.extra);
    print(d.describe());
    print(d.bump(2));
    print(d.depth);
}

with entry {
    run_probe();
}
