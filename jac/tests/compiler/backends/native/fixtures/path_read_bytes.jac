import from pathlib { Path }

def read_pattern(path: str, size: int) -> bool {
    data = Path(path).read_bytes();
    if len(data) != size {
        return False;
    }
    for i in range(size) {
        if data[i] != i % 256 {
            return False;
        }
    }
    return True;
}

def read_error(path: str) -> int {
    try {
        Path(path).read_bytes();
    } except FileNotFoundError {
        return 1;
    } except NotADirectoryError {
        return 2;
    } except IsADirectoryError {
        return 3;
    } except ValueError {
        return 4;
    } except PermissionError {
        return 5;
    }
    return 0;
}
