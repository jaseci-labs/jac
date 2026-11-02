"""Cyclic garbage in which one object is reached through several references:
two fields of the same object, a list holding it twice, and two parents.
The collector must visit each such reference without reading an object it
has already freed. Each line printed is `name value`."""

glob freed: int = 0;

obj Box {
    has x: Box | None = None,
        y: Box | None = None,
        kids: list[Box] = [],
        tag: int = 0;

    def drop {
        freed += 1;
    }
}

def two_fields {
    a = Box(tag=1);
    b = Box(tag=2);
    a.x = b;
    a.y = b;
    b.x = a;
}

def list_twice {
    a = Box(tag=1);
    b = Box(tag=2);
    a.kids.append(b);
    a.kids.append(b);
    b.x = a;
}

def two_parents {
    a = Box(tag=1);
    b = Box(tag=2);
    c = Box(tag=3);
    a.x = b;
    a.y = c;
    b.x = c;
    c.x = a;
}

def run(which: str, n: int) -> int {
    freed = 0;
    for i in range(n) {
        if which == "two_fields" {
            two_fields();
        } elif which == "list_twice" {
            list_twice();
        } else {
            two_parents();
        }
    }
    __rc_collect_cycles();
    return freed;
}

with entry {
    print("two_fields", run("two_fields", 200));
    print("list_twice", run("list_twice", 200));
    print("two_parents", run("two_parents", 200));
}
