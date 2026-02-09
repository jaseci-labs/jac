"""Test yield expression inside parentheses."""

def gen(items: list) -> int {
    for item in items {
        (yield item);
    }
}

with entry {
    for v in gen([1, 2, 3]) {
        print(v);
    }
}
