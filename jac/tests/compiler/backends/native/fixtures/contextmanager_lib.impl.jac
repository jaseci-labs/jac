@contextmanager
impl Tracker.track(label: str) -> Iterator[int] {
    self.depth += 1;
    self.log.append(f"enter {label}");
    try {
        yield self.depth;
    } finally {
        self.log.append(f"exit {label}");
        self.depth -= 1;
    }
}
