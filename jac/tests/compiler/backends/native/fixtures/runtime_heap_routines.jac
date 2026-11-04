"""A program's own C malloc and free stay the C library's under a configured heap."""
import from c { def malloc(n: int) -> int;  def free(p: int) -> None;  }

def scratch(n: int) -> int {
    block = malloc(n);
    free(block);
    return n;
}

def grow(n: int) -> int {
    items: list[int] = [];
    for i in range(n) {
        items.append(i);
    }
    return len(items);
}
