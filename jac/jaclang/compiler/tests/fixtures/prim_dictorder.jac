"""dict insertion-order cross-backend lock (issue #6404, congruence decision
#3). CPython dicts preserve insertion order; json/collections/iteration parity
depend on native matching that. Keys are inserted in a non-sorted order; a
position-weighted sum of the values captures the iteration order without
boxing strings into the result (int-only, so it isolates ordering).
"""

def dictorder_py() -> dict {
    d: dict = {};
    d["zebra"] = 10;
    d["apple"] = 20;
    d["mango"] = 30;
    d["cherry"] = 40;
    weighted: int = 0;
    place: int = 1;
    first_val: int = 0;
    last_val: int = 0;
    for k in d {
        v: int = d[k];
        if place == 1 {
            first_val = v;
        }
        last_val = v;
        weighted += v * place;
        place += 1;
    }
    return {"weighted": weighted, "first_val": first_val, "last_val": last_val, "n": place - 1};
}

cl def dictorder_cl() -> dict {
    return {};
}

na {
    def dictorder_na() -> dict[str, any] {
        d: dict = {};
        d["zebra"] = 10;
        d["apple"] = 20;
        d["mango"] = 30;
        d["cherry"] = 40;
        weighted: int = 0;
        place: int = 1;
        first_val: int = 0;
        last_val: int = 0;
        for k in d {
            v: int = d[k];
            if place == 1 {
                first_val = v;
            }
            last_val = v;
            weighted += v * place;
            place += 1;
        }
        return {
            "weighted": weighted, "first_val": first_val,
            "last_val": last_val, "n": place - 1,
        };
    }
}
