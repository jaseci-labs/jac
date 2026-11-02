import lazy_ret_lib;

def items -> list[int] {
    return [1, 2, 3];
}

def imported_count -> int {
    return len(lazy_ret_lib.items());
}

def local_total -> int {
    return sum(items());
}
