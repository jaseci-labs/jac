import from pathlib { Path }

obj Holder {
    has path: Path = Path("a/b.txt");
}

def suffix(value: Path) -> str {
    return value.suffix;
}

def identity(value: Path) -> Path {
    return value;
}

def check_values -> bool {
    holder = Holder();
    first = holder.path;
    holder.path = Path("next.md");
    return suffix(first) == ".txt"
        and suffix(holder.path) == ".md"
        and identity(first) is first;
}
