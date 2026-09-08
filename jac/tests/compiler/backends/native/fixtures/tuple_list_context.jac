"""Tuple conversion uses the declared list element layout, including empty input."""
def empty_lists -> int {
    integers: list[int] = list(());
    words: list[str] = list(());
    values: list[any] = list(());
    for i in range(20) {
        integers.append(i);
        words.append("abc");
        values.append(i);
    }
    values.append("done");
    return integers[19] + len(words[19]) + len(values);
}

def widened_elements -> int {
    values: list[any] = list((1, 2));
    values.append("abc");
    total = 0;
    for value in values {
        if isinstance(value, int) {
            total += value;
        } elif isinstance(value, str) {
            total += len(value);
        }
    }
    return total;
}

with entry {
    print(empty_lists());
    print(widened_elements());
}
