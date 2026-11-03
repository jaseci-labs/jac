impl _is_atomic(x: any) -> bool {
    return x is None
        or isinstance(x, bool)
        or isinstance(x, int)
        or isinstance(x, float)
        or isinstance(x, str)
        or isinstance(x, bytes)
        or isinstance(x, complex)
        or isinstance(x, date)
        or isinstance(x, time)
        or isinstance(x, timedelta)
        or isinstance(x, tzinfo);
}

impl copy(x: any) -> any {
    if _is_atomic(x) or isinstance(x, tuple) {
        return x;
    }
    if isinstance(x, dict) {
        return dict(x);
    }
    if isinstance(x, list) {
        return list(x);
    }
    if isinstance(x, set) {
        return set(x);
    }
    raise Error("copy: no native copy for " + typename(x));
}

impl deepcopy(x: any) -> any {
    if _is_atomic(x) {
        return x;
    }
    if isinstance(x, dict) {
        out: dict[any, any] = {};
        for (key, value) in x.items() {
            out[key] = deepcopy(value);
        }
        return out;
    }
    if isinstance(x, list) {
        items: list[any] = [];
        for value in x {
            items.append(deepcopy(value));
        }
        return items;
    }
    if isinstance(x, tuple) {
        members: list[any] = [];
        for value in x {
            members.append(deepcopy(value));
        }
        return tuple(members);
    }
    if isinstance(x, set) {
        return set(x);
    }
    raise Error("deepcopy: no native deep copy for " + typename(x));
}
