"""The bottom of the diamond: one class and one helper every other unit sees."""

obj Point {
    has x: int = 0,
        y: int = 0;

    def sum -> int {
        return self.x + self.y;
    }
}

def scale(v: int, k: int) -> int {
    return v * k;
}

def:pub diamond_abi_version -> int {
    return 1;
}
