obj Counter {
    has start: int = 0;
    has doubled: int { getter; }
}

impl Counter.doubled.getter -> int {
    return self.start * 2;
}
