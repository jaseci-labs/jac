"""Plain .jac dep with a typed glob, consumed via from-import."""

glob G: int = 5;

def getg() -> int {
    return G;
}
