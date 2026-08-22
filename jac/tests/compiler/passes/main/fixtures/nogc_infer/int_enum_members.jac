enum Kind: int { END = 0, FILE = 1 }

def pick(flag: bool) -> int {
    if flag {
        return Kind.FILE;
    }
    return Kind.END;
}

with entry {
    print(pick(True));
}
