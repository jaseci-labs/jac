"""Slice assignment into a chunk view raises what the Python backend's
`JacListView.__setitem__` raises for a slice key, and leaves the parent
untouched. (The nogc profile refuses list slice assignment outright, so this
case is diffed under rc and managed.)"""

def splice(c: list[int]) {
    c[0:1] = [6, 6];
}

def run {
    xs: list[int] = [0, 1, 2, 3, 4];
    for c in &mut xs.chunks(2) {
        try {
            splice(c);
        } except TypeError as e {
            print(f"setslice: TypeError: {e}");
        }
    }
    print(xs);
}

with entry {
    run();
}
