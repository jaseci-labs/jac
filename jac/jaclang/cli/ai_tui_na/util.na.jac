def parse_int_or(s: str, fallback: int) -> int {
    try {
        return int(s);
    } except Exception {
        return fallback;
    }
}

def split_kv(line: str, sep: str) -> tuple[str, str] {
    parts = line.partition(sep);
    return (parts[0], parts[2]);
}
