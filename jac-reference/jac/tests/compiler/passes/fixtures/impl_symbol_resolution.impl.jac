"""Implementation file for Counter - tests symbol resolution of self and members."""

impl Counter.increment -> int {
    self.count += 1;
    return self.count;
}

impl Counter.get_info -> str {
    return f"{self.name}: {self.count}";
}
