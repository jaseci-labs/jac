def list_len_test() -> int {
    items: list[int] = [10, 20, 30];
    return len(items);
}

def list_get_test() -> int {
    items: list[int] = [10, 20, 30];
    return items[1];
}

def list_append_test() -> int {
    items: list[int] = [1, 2, 3];
    items.append(4);
    return len(items);
}

def list_sum() -> int {
    items: list[int] = [10, 20, 30, 40];
    total: int = 0;
    for i in range(len(items)) {
        total = total + items[i];
    }
    return total;
}

def list_set_test() -> int {
    items: list[int] = [1, 2, 3];
    items[1] = 99;
    return items[1];
}

# ── empty-container literal in a RETURN position ──
# `return []` is lowered from the function's declared list return type.
def make_empty_list_ret() -> list[int] {
    return [];
}

def empty_list_return_len() -> int {
    x: list[int] = make_empty_list_ret();
    return len(x);
}

# ── empty-container literal in a CALL-ARGUMENT position ──
# `f([])` lowers the empty list from the callee's parameter slot type.
def take_list_len(x: list[int]) -> int {
    return len(x);
}

def empty_list_call_arg() -> int {
    return take_list_len([]);
}
