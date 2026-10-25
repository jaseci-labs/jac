def keep_odd(rows: list[list[int]]) -> int {
    kept = 0;
    for row in rows {
        for x in row {
            if x % 2 == 0 {
                break;
            }
        } else {
            continue;
        }
        kept += 1;
    }
    return kept;
}

def stop_at_odd(rows: list[list[int]]) -> int {
    seen = 0;
    for row in rows {
        for x in row {
            if x % 2 == 0 {
                break;
            }
        } else {
            break;
        }
        seen += 1;
    }
    return seen;
}
