impl Box.doubled -> int {
    return cast(int, self.n) * 2;
}

impl run -> int {
    return cast(int, Box(n=6).doubled());
}
