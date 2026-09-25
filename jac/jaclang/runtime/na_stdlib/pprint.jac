import from _repr { repr_str, sorted_str_keys }


def _format(value: any) -> str {
    if isinstance(value, bool) {
        flag: bool = value;
        if flag {
            return "True";
        }
        return "False";
    }
    if isinstance(value, int) {
        i_val: int = value;
        return str(i_val);
    }
    if isinstance(value, float) {
        f_val: float = value;
        return str(f_val);
    }
    if isinstance(value, str) {
        s_val: str = value;
        return repr_str(s_val);
    }
    if isinstance(value, list) {
        arr: list[any] = value;
        out: str = "[";
        n: int = len(arr);
        i: int = 0;
        while i < n {
            if i > 0 {
                out += ", ";
            }
            out += _format(arr[i]);
            i += 1;
        }
        out += "]";
        return out;
    }
    if isinstance(value, dict) {
        d: dict[str, any] = value;
        keys: list[str] = [];
        for k in d {
            keys.append(k);
        }
        keys = sorted_str_keys(keys);
        out2: str = "{";
        m: int = len(keys);
        j: int = 0;
        while j < m {
            if j > 0 {
                out2 += ", ";
            }
            kk: str = keys[j];
            out2 += repr_str(kk) + ": " + _format(d[kk]);
            j += 1;
        }
        out2 += "}";
        return out2;
    }
    if isinstance(value, set) {
        raise ValueError("pprint: unsupported value type on native");
    }
    return "None";
}


def:pub pformat(value: any) -> str {
    return _format(value);
}
