"""Hash-table dict under headerless --memory nogc.

The scope-exit drop of `d` is the regression target: live entries sit at
sparse ctrl-occupied slots, so a dense keys[0..len) drop frees garbage from
uninitialized slots (heap corruption) and leaks the real keys. popitem checks
the key copy survives the pop freeing the dict's stored key.
"""

def run_ops {
    d: dict[str, str] = {};
    d[f"k{0}"] = f"v{0}";
    d[f"k{1}"] = f"v{1}";
    d[f"k{2}"] = f"v{2}";
    del d[f"k{1}"];
    print(len(d));
    d[f"k{1}"] = "w";
    print(d["k1"]);
    d.clear();
    print(len(d));
    d["x"] = "y";
    print(d["x"]);
    i = 0;
    while i < 20 {
        d[f"g{i}"] = f"h{i}";
        i += 1;
    }
    print(len(d));
}

def run_popitem {
    d2: dict[str, str] = {};
    d2[f"p{1}"] = f"q{1}";
    d2[f"p{2}"] = f"q{2}";
    item = d2.popitem();
    print(item[0]);
    print(item[1]);
    print(len(d2));
}

with entry {
    run_ops();
    run_popitem();
    print("done");
}
