"""Client-placed module tested from an annex; `len` needs client lowering."""

def label(items: list[int]) -> str {
    return f"{len(items)} items";
}
