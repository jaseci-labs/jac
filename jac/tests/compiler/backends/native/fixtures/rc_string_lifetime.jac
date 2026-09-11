"""A caller-owned string must outlive borrows without accumulating references."""

obj Text {
    has value: str;
}

def local(value: str) -> int {
    copy = value;
    return len(copy);
}

def field(value: str) -> int {
    text = Text(value=value);
    return len(text.value);
}

def loop(value: str) -> int {
    count = 0;
    for i in range(3) {
        copy = value;
        count += len(copy);
    }
    return count;
}

def identity(value: str) -> str {
    return value;
}

def call(value: str) -> int {
    return len(identity(value));
}
