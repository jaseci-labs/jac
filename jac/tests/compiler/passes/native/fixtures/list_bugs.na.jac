# Test fixture for list bug reproductions

# Bug 1: list.pop() on locals — works
def pop_and_len() -> int {
    items: list[int] = [10, 20, 30];
    items.pop();
    return len(items);
}

def pop_value() -> int {
    items: list[int] = [10, 20, 30];
    v: int = items.pop();
    return v;
}

def pop_loop() -> int {
    items: list[int] = [1, 2, 3];
    count: int = 0;
    while len(items) > 0 {
        items.pop();
        count = count + 1;
    }
    return count;
}

# Bug 1b: list.pop() on globals via global keyword
glob g_items: list[int] = [10, 20, 30];

def pop_global_len() -> int {
    global g_items;
    g_items.pop();
    return len(g_items);
}

# Bug 2: list[Object] field access
obj Item {
    has x: int = 0,
        y: int = 0;
}

def obj_list_field() -> int {
    it: Item = Item(x=42, y=10);
    items: list[Item] = [it];
    first: Item = items[0];
    return first.x;
}

def obj_list_two_items() -> int {
    a: Item = Item(x=10, y=20);
    b: Item = Item(x=30, y=40);
    items: list[Item] = [a, b];
    second: Item = items[1];
    return second.y;
}

# Bug 2b: list[Object] stored globally
glob g_obj_items: list[Item] = [];

def obj_global_list() -> int {
    global g_obj_items;
    g_obj_items.append(Item(x=100, y=200));
    first: Item = g_obj_items[0];
    return first.x;
}

# Bug 3: [] literal in global reassignment
glob g_ints: list[int] = [1, 2, 3];

def reassign_int_list() -> int {
    global g_ints;
    g_ints = [];
    g_ints.append(99);
    return g_ints[0];
}

glob g_strs: list[str] = ["hello"];

def reassign_str_list() -> int {
    global g_strs;
    g_strs = [];
    g_strs.append("world");
    return len(g_strs);
}

with entry {
    _x: int = 1;
}
