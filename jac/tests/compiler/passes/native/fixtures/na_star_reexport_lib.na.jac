"""Native library whose public names are re-exported through an include chain."""

obj StarPoint {
    has x: int;
    has y: int;
}

def:pub star_helper(x: int) -> int {
    return x * 2 + 1;
}

def:pub star_make(x: int, y: int) -> StarPoint {
    return StarPoint(x=x, y=y);
}
