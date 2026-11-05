"""Stores into a typed container reached through an `any` view."""
obj Cell {
    has cls: str,
        keys: list[str] = [],
        vals: list[any] = [];

    def get(key: str) -> any {
        i = 0;
        while i < len(self.keys) {
            if self.keys[i] == key {
                return self.vals[i];
            }
            i += 1;
        }
        raise KeyError(key);
    }

    def setf(key: str, value: any) -> None {
        i = 0;
        while i < len(self.keys) {
            if self.keys[i] == key {
                self.vals[i] = value;
                return;
            }
            i += 1;
        }
        self.keys.append(key);
        self.vals.append(value);
    }

    def items(key: str) -> list[any] {
        value: list[any] = self.get(key);
        return value;
    }

    def push(key: str, item: any) {
        value = self.items(key);
        value.append(item);
        self.setf(key, value);
    }
}

def leaf(name: str) -> Cell {
    return Cell(cls=name, keys=["value"], vals=[name]);
}

def walk(v: object) -> int {
    if v is None {
        return 1;
    } elif isinstance(v, Cell) {
        total = 0;
        for item in v.vals {
            got = walk(item);
            if got < 0 {
                return got;
            }
            total += got;
        }
        return total + 100;
    } elif isinstance(v, str) {
        return 1;
    } elif isinstance(v, list) {
        total = 0;
        for item in v {
            got = walk(item);
            if got < 0 {
                return got;
            }
            total += got;
        }
        return total + 10;
    }
    return -1;
}

def leaves(names: list[str]) -> list[Cell] {
    return [leaf(n) for n in names];
}

def as_any(value: any) -> any {
    return value;
}

"""The shape of CgNode.push on a test block's decorator_list."""
def chk_push_into_typed_slot -> int {
    names: list[str] = [];
    func = Cell(
        cls="FunctionDef",
        keys=["name", "decorator_list"],
        vals=["t", [leaf(n) for n in names] if names else leaves(["a"])]
    );
    func.push("decorator_list", leaf("jac_test"));
    func.push("decorator_list", leaf("patch"));
    return walk(func);
}

def chk_set_insert_extend -> int {
    held: list[any] = as_any(leaves(["a", "b"]));
    held[0] = leaf("c");
    held.insert(1, leaf("d"));
    held.extend([leaf("e")]);
    return len(held) * 1000 + walk(held);
}

def chk_ints_through_any -> int {
    nums: list[any] = as_any([1, 2]);
    nums.append(3);
    nums[0] = True;
    total = 0;
    for n in nums {
        total += n;
    }
    return total;
}

def chk_dict_through_any -> int {
    table: dict[str, any] = as_any({"a": leaf("a")});
    table["b"] = leaf("b");
    return len(table) * 1000 + walk(table["a"]) + walk(table["b"]);
}

with entry {
    print(chk_push_into_typed_slot());
    print(chk_set_insert_extend());
    print(chk_ints_through_any());
    print(chk_dict_through_any());
}
