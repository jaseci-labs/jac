def _parse_line(line: str) -> list[str] {
    fields: list[str] = [];
    n: int = len(line);
    if n == 0 {
        return fields;
    }
    cur: str = "";
    i: int = 0;
    quoted: bool = False;
    while i < n {
        c: int = ord(line[i]);
        # NUL passes through as an ordinary character: CPython >= 3.14
        # dropped the csv.Error("line contains NUL") check, and the bundled
        # sv runtime is 3.14 (see na_stdlib/README.md).
        if not quoted {
            if c == 34 and cur == "" {
                quoted = True;
            } elif c == 44 {
                fields.append(cur);
                cur = "";
            } else {
                cur += line[i];
            }
        } elif c == 34 {
            if i + 1 < n and ord(line[i + 1]) == 34 {
                cur += "\"";
                i += 1;
            } else {
                quoted = False;
            }
        } else {
            cur += line[i];
        }
        i += 1;
    }
    fields.append(cur);
    return fields;
}


def:pub reader(lines: list[str]) -> list[list[str]] {
    rows: list[list[str]] = [];
    i: int = 0;
    n: int = len(lines);
    while i < n {
        rows.append(_parse_line(lines[i]));
        i += 1;
    }
    return rows;
}
