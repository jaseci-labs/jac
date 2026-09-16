"""`ObjectField` descriptors supply internal has-field initialization metadata.

`ObjectField(default_factory=...)` says "construct an empty one of the declared
type" and `ObjectField(default=...)` says "this literal". Both are answered at the
declaration site, so the call never has to exist at run time.
"""

import from jaclang.runtime.object_model { ObjectField }


obj Bag {
    has names: list[str] = ObjectField(default_factory=`list),
        counts: dict[str, int] = ObjectField(default_factory=`dict),
        seen: set[int] = ObjectField(default_factory=`set),
        label: str = ObjectField(`default='bag'),
        size: int = ObjectField(`default=7);
}


def run -> int {
    b = Bag();
    b.names.append('a');
    b.counts['a'] = 2;
    b.seen.add(9);
    return len(b.names) + len(b.counts) + len(b.seen) + len(b.label) + b.size;
}
