"""Reference counting correctness tests.

Tests allocation, lifecycle, reassignment, container growth,
and ownership transfer to verify the RC memory management.
"""

# Test 1: Basic allocation and scope exit
def test_alloc_basic() -> int {
    x: int = 42;
    return x;
}

# Test 2: Object lifecycle
obj Box {
    has val: int = 0;

    def get_val() -> int {
        return self.val;
    }
}

def test_object_lifecycle() -> int {
    b: Box = Box(val=10);
    result: int = b.get_val();
    return result;
}

# Test 3: Reassignment (old value should be released)
def test_reassign() -> int {
    b1: Box = Box(val=1);
    b2: Box = Box(val=2);
    b1 = b2;
    return b1.get_val();
}

# Test 4: List that grows beyond initial capacity
def test_list_growth() -> int {
    items: list[int] = [];
    i: int = 0;
    while i < 20 {
        items.append(i);
        i = i + 1;
    }
    return len(items);
}

# Test 5: List of objects (ptr elements)
def test_list_of_objects() -> int {
    items: list[Box] = [];
    items.append(Box(val=10));
    items.append(Box(val=20));
    items.append(Box(val=30));
    return len(items);
}

# Test 6: Object with list field
obj Container {
    has items: list[int],
        name: str = "default";
}

def test_nested_structure() -> int {
    c: Container = Container(items=[1, 2, 3], name="test");
    return len(c.items);
}

# Test 7: String operations that allocate
def test_string_alloc() -> int {
    s: str = "hello";
    u: str = s + " world";
    return len(u);
}

# Test 8: Function return ownership transfer
def make_box(v: int) -> Box {
    return Box(val=v);
}

def test_return_transfer() -> int {
    b: Box = make_box(42);
    return b.get_val();
}

# Test 9: Dict growth
def test_dict_growth() -> int {
    d: dict[int, int] = {};
    i: int = 0;
    while i < 20 {
        d[i] = i * 10;
        i = i + 1;
    }
    return len(d);
}

# Test 10: Multiple reassignments in a loop
def test_loop_reassign() -> int {
    total: int = 0;
    i: int = 0;
    while i < 5 {
        b: Box = Box(val=i);
        total = total + b.get_val();
        i = i + 1;
    }
    return total;
}

# Test 11: Set operations
def test_set_operations() -> int {
    s: set[int] = {1, 2, 3, 4, 5};
    return len(s);
}

# Test 12: String reassignment
def test_string_reassign() -> int {
    s: str = "hello";
    s = "world";
    return len(s);
}
