"""Lists of enum members, owned and lent.

A list records its element kind in a header word: a small kind, or the
descriptor of an enum. A list of borrows (`list[&T]`) is lent as well: it
holds no reference of its own. Both lists below are read through `any` and
through list operations, so every reader of that word sees the enum and the
lent mark at once.
"""
enum Color { RED = 1, BLUE = 2, GREEN = 3 }

def walk(value: &any) -> str {
    parts: list[str] = [];
    for item in value {
        parts.append(repr(item));
    }
    return ",".join(parts);
}

def show(label: &str, xs: &list[Color]) {
    held: &any = xs;
    print(label, walk(held), str(held));
    print(label, Color.BLUE in held, 2 in held, Color.GREEN in held);
    print(label, held == [Color.RED, Color.BLUE], xs == [Color.RED, Color.BLUE]);
    joined = xs + xs;
    rest = xs[1:];
    twice = xs * 2;
    print(label, len(joined), walk(&joined), walk(&rest));
    print(label, walk(&twice), xs.index(Color.BLUE), Color.RED in xs);
}

def owned_list {
    xs: list[Color] = [Color.RED, Color.BLUE];
    show("owned", &xs);
    xs.append(Color.GREEN);
    last = xs.pop();
    print("owned", last, len(xs), walk(&xs));
}

def lent_list {
    xs: list[&Color] = [Color.RED, Color.BLUE];
    show("lent", &xs);
    xs.append(Color.GREEN);
    last = xs.pop();
    print("lent", last, len(xs), walk(&xs));
}

with entry {
    owned_list();
    lent_list();
    print("done");
}
