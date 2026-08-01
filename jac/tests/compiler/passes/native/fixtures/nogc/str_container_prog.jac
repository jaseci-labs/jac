"""Owned str containers under --gc none: moves, copies, and element drops."""

def run_lists {
    xs: list[str] = [];
    i = 0;
    while i < 3 {
        xs.append(f"x{i}");
        i += 1;
    }
    xs.append("lit");
    print(len(xs));
    print(xs[0]);
    print(xs[3]);
    s = f"keep{7}";
    xs.append(s);
    print(s);
}

def run_dicts {
    d = {"a": f"v{1}"};
    d[f"k{2}"] = "w";
    print(d["a"]);
    print(d["k2"]);
}

def run_sets {
    st: set[str] = set();
    j = 0;
    while j < 2 {
        st.add(f"m{1}");
        j += 1;
    }
    print(len(st));
}

with entry {
    run_lists();
    run_dicts();
    run_sets();
}
