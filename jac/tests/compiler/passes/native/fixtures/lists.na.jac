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
