"""`dataclasses.field` is a declaration a has-field default reads, not a value.

`field(default_factory=...)` says "construct an empty one of the declared
type" and `field(default=...)` says "this literal". Both are answered at the
declaration site, so the call never has to exist at run time.
"""

import from dataclasses { field }


obj Bag {
    has names: list[str] = field(default_factory=`list),
        counts: dict[str, int] = field(default_factory=`dict),
        seen: set[int] = field(default_factory=`set),
        label: str = field(`default='bag'),
        size: int = field(`default=7);
}


def run -> int {
    b = Bag();
    b.names.append('a');
    b.counts['a'] = 2;
    b.seen.add(9);
    return len(b.names) + len(b.counts) + len(b.seen) + len(b.label) + b.size;
}
