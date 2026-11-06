"""A chunk of `xs.chunks(n)` is a view into its parent: element writes land
in the parent, and nothing may grow, shrink or reorder it. Every such
operation raises what the Python backend's `JacListView` raises, natively
under every memory profile and from a parallel `flow for` worker, and the
parent is left exactly as it was. The checker already refuses these calls on
the loop variable itself (E1313), so the fixture reaches them through a
function the chunk is passed to."""

def apply(c: &mut list[int], op: &str) {
    if op == "append" {
        c.append(99);
    } elif op == "extend" {
        c.extend([7, 8]);
    } elif op == "insert" {
        c.insert(0, 5);
    } elif op == "pop" {
        c.pop();
    } elif op == "pop0" {
        c.pop(0);
    } elif op == "remove" {
        c.remove(c[0]);
    } elif op == "clear" {
        c.clear();
    } elif op == "sort" {
        c.sort();
    } elif op == "reverse" {
        c.reverse();
    } elif op == "iadd" {
        c += [4];
    } elif op == "del" {
        del c[0];
    } elif op == "delslice" {
        del c[0:2];
    } elif op == "getslice" {
        print(len(c[0:2]));
    }
}

def mutate(xs: &mut list[int], op: &str) -> str {
    for c in &mut xs.chunks(3) {
        try {
            apply(&mut c, op);
        } except AttributeError as e {
            return f"{op}: AttributeError: {e}";
        } except TypeError as e {
            return f"{op}: TypeError: {e}";
        }
        return f"{op}: allowed";
    }
    return f"{op}: no chunk";
}

def drop_last(c: &mut list[str]) {
    c.pop();
}

def mutate_text(names: &mut list[str]) -> str {
    for c in &mut names.chunks(2) {
        try {
            drop_last(&mut c);
        } except AttributeError as e {
            return f"text pop: {e}";
        }
    }
    return "text pop: allowed";
}

def grow(c: &mut list[int]) {
    c.append(1);
}

def flow_append(xs: &mut list[int]) -> str {
    try {
        flow for c in &mut xs.chunks(4) {
            grow(&mut c);
        }
    } except AttributeError as e {
        return f"flow append: {e}";
    }
    return "flow append: allowed";
}

def flow_write(xs: &mut list[int]) {
    flow for c in &mut xs.chunks(4) {
        for j in range(len(c)) {
            c[j] = c[j] + 100;
        }
    }
}

def run {
    xs: list[int] = [];
    for i in range(10) {
        xs.append(i);
    }
    ops = [
        "append",
        "extend",
        "insert",
        "pop",
        "pop0",
        "remove",
        "clear",
        "sort",
        "reverse",
        "iadd",
        "del",
        "delslice",
        "getslice"
    ];
    for op in &ops {
        print(mutate(&mut xs, op));
    }
    print(xs);
    names = ["a", "b", "c"];
    print(mutate_text(&mut names));
    print(names);
    print(flow_append(&mut xs));
    flow_write(&mut xs);
    print(xs);
}

with entry {
    run();
}
