"""Tuple-valued dictionary reads retain their semantic element layout."""
glob OPERATORS: dict[str, tuple[str, str]] = {"+": ("add", "radd")};

def global_tuple -> int {
    (left, right) = OPERATORS["+"];
    return len(left) * 10 + len(right);
}

def local_tuple -> int {
    entries: dict[int, tuple[int, str]] = {1: (7, "seven")};
    (amount, label) = entries[1];
    return amount + len(label);
}

def returned_dictionary -> dict[str, tuple[int, int]] {
    return {"pair": (4, 9)};
}

def temporary_tuple -> int {
    (first, second) = returned_dictionary()["pair"];
    return first * 10 + second;
}

with entry {
    print(global_tuple());
    print(local_tuple());
    print(temporary_tuple());
}
