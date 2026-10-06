impl NativeLowering._split_type_args(s: str, sep: str = ",") -> list[str] {
    parts: list[str] = [];
    depth = 0;
    cur = "";
    for ch in s {
        if ch == "[" {
            depth += 1;
        } elif ch == "]" {
            depth -= 1;
        }
        if ch == sep and depth == 0 {
            parts.append(cur);
            cur = "";
        } else {
            cur += ch;
        }
    }
    parts.append(cur);
    return parts;
}
