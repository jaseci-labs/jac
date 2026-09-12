"""Typed compiler failures; Python exception objects belong to the API boundary."""
obj syntax_failure(Exception) {
    has msg: str,
        filename: str = "<unknown>",
        lineno: int = 0,
        offset: int = -1,
        text: str | None = None,
        end_lineno: int = 0,
        end_offset: int = -1,
        kind: str = "SyntaxError";
}

def split_source_lines(source: str) -> list[str] {
    data = source.encode("utf-8", "surrogatepass");
    lines: list[str] = [];
    start = 0;
    index = 0;
    while index < len(data) {
        byte = data[index];
        index += 1;
        if byte == 13 {
            if index < len(data) and data[index] == 10 {
                index += 1;
            }
        } elif byte != 10 {
            continue;
        }
        lines.append(data[start:index].decode("utf-8", "surrogatepass"));
        start = index;
    }
    if start < len(data) {
        lines.append(data[start:].decode("utf-8", "surrogatepass"));
    }
    return lines;
}

def source_character_column(source: str, byte_column: int) -> int {
    data = source.encode("utf-8", "surrogatepass");
    limit = min(max(byte_column, 0), len(data));
    index = 0;
    count = 0;
    while index < limit {
        lead = data[index];
        width = 1 if lead < 128 else 2 if lead < 224 else 3 if lead < 240 else 4;
        if index + width > limit {
            break;
        }
        index += width;
        count += 1;
    }
    return count;
}
