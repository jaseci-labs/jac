"""Field access through a secondary base owned by another module (issue #8163).

Same shape as `secondary_base_field.jac`, but the whole hierarchy lives in
`secondary_base_xmod_lib`. The slot for `flagged` still has to come from the
runtime class, which means the layout lookup has to reach the *defining*
module's registry rather than the one being compiled.
"""

import from secondary_base_xmod_lib { Root, Tagged, Flagged, Item, make }

def read_narrowed(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) and it.flagged {
        return 1;
    }
    return 0;
}

def read_direct(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) {
        return 1 if it.flagged else 0;
    }
    return 0;
}

def write_narrowed(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) {
        it.flagged = True;
    }
    if isinstance(it, Item) {
        return 1 if it.flagged else 0;
    }
    if isinstance(it, Flagged) {
        return 1 if it.flagged else 0;
    }
    return 0;
}

def call_narrowed(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) {
        return it.flag_kind();
    }
    return 0;
}

def tag_intact(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) {
        it.flagged = True;
    }
    if isinstance(it, Tagged) and it.tag is not None {
        return 1;
    }
    return 0;
}
