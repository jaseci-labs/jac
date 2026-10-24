impl _load_runs(data: str, starts: list[int], values: list[int]) -> None {
    i = 0;
    n = len(data);
    while i + 8 <= n {
        starts.append(int(data[i:i + 6], 16));
        values.append(int(data[i + 6:i + 8], 16));
        i += 8;
    }
}

impl _lookup(cp: int, starts: list[int], values: list[int]) -> int {
    lo = 0;
    hi = len(starts) - 1;
    while lo < hi {
        mid = (lo + hi + 1) // 2;
        if starts[mid] <= cp {
            lo = mid;
        } else {
            hi = mid - 1;
        }
    }
    return values[lo];
}

impl category(ch: str) -> str {
    if not _cat_starts {
        _load_runs(CATEGORY_RUNS, _cat_starts, _cat_values);
    }
    return CATEGORY_NAMES[_lookup(ord(ch), _cat_starts, _cat_values)];
}

impl east_asian_width(ch: str) -> str {
    if not _width_starts {
        _load_runs(WIDTH_RUNS, _width_starts, _width_values);
    }
    return WIDTH_NAMES[_lookup(ord(ch), _width_starts, _width_values)];
}
