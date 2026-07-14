"""Regression fixture: boxing a local container into `any` must retain it.

The na backend releases a local at its last syntactic use. `pa: any =
payload` aliases the dict into a JacVal box; without a retain at the
boxing assignment, that release freed the cell while the box still
pointed at it, and the enclosing return-dict literal reused the freed
cell -- `len` through the alias then reported the RESULT dict's length
(and richer probes segfaulted). ES/JS opts out.
"""

def alias_retain_py -> dict {
    payload = {"n": 42};
    pa = payload;
    return {"a": 1, "b": 2, "c": 3, "d": 4, "e": 5, "len_thru_alias": len(pa)};
}


cl def alias_retain_cl -> dict {
    return {};
}


na {
    def len_probe_na(val: any) -> int {
        d: dict[str, any] = val;
        return len(d);
    }

    def alias_retain_na -> dict[str, any] {
        payload: dict[str, any] = {};
        payload["n"] = 42;
        pa: any = payload;
        return {
            "a": 1,
            "b": 2,
            "c": 3,
            "d": 4,
            "e": 5,
            "len_thru_alias": len_probe_na(pa)
        };
    }
}
