"""Test: Mix of clean and JS-idiomatic code."""

def mostly_clean() -> None {
    items: list[any] = [1, 2, 3];
    items.append(4);
    print(len(items));
    # But then one JS slip:
    console.log("debug");
}

def mostly_js() -> None {
    arr: list[any] = [1, 2, 3];
    arr.push(4);
    arr.forEach(print);
    n = arr.length;
}
