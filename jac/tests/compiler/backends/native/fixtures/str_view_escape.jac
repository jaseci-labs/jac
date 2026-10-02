"""A suffix slice (`s[k:]`) is a NUL-terminated view into the middle of its
root string. Stored into a list, set, dict or tuple it must become a string
of its own: the container retains, releases and traces its elements through
the RC header below the pointer, and the middle of another string has none.
Each check prints True when the stored element is not the view's interior
pointer; the loop at the end has the cycle collector trace thousands of
lists of views of a string literal, whose bytes are read-only."""

obj Pack {
    has names: list[str] = [],
        peer: Pack | None = None;
}

def fill(pack: Pack, kind: str) {
    pack.names.append(kind[7:]);
}

def own_string(source: str, stored: str) -> bool {
    return id(stored) != id(source) + 7;
}

def check_escapes {
    source = "weapon_" + str(123456789);
    appended: list[str] = [];
    appended.append(source[7:]);
    print("append", own_string(source, appended[0]));
    inserted: list[str] = ["?"];
    inserted.insert(0, source[7:]);
    print("insert", own_string(source, inserted[0]));
    literal = [source[7:]];
    print("list literal", own_string(source, literal[0]));
    assigned: list[str] = ["?"];
    assigned[0] = source[7:];
    print("index set", own_string(source, assigned[0]));
    view = source[7:];
    from_local: list[str] = [view, view];
    print("local view", own_string(source, from_local[1]));
    unique: set[str] = set();
    unique.add(source[7:]);
    for name in unique {
        print("set add", own_string(source, name));
    }
    table: dict[str, str] = {};
    table.setdefault("k", source[7:]);
    print("setdefault", own_string(source, table["k"]));
    pair = (source[7:], 1);
    print("tuple", own_string(source, pair[0]));
    pack = Pack();
    fill(pack, source);
    print("through a parameter", own_string(source, pack.names[0]));
    print(source[7:], appended, literal, pair[0]);
}

def collect_literal_views -> int {
    total = 0;
    for round in range(10) {
        packs: list[Pack] = [];
        for i in range(3000) {
            held = Pack();
            fill(held, "weapon_bfg");
            packs.append(held);
        }
        for held in packs {
            total += len(held.names[0]);
        }
    }
    return total;
}

with entry {
    check_escapes();
    print(collect_literal_views());
    print("end");
}
