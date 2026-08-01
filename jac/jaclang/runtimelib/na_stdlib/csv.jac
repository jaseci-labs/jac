def _parse_line(line: str) -> list[str] {
    fields: list[str] = [];
    n: int = len(line);
    if n == 0 {
        return fields;
    }
    cur: str = "";
    i: int = 0;
    quoted: bool = False;
    started: bool = False;
    while i < n {
        c: int = ord(line[i]);

        if not quoted {
            if c == 10 or c == 13 {
                break;
            }
            started = True;
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
    if not started {
        return fields;
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
