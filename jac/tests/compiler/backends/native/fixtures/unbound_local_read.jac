"""A local read on a path where it may not be bound raises UnboundLocalError."""

def maybe(flag: bool) -> int {
    if flag {
        found = 5;
    }
    try {
        return found;
    } except UnboundLocalError {
        return -1;
    }
}
