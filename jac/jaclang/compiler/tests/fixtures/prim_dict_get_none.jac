"""dict.get miss None-identity: cross-backend equivalence fixture (#7884).

A 1-arg .get() miss must be a real None on every backend: `is None`
true, `is not None` false, truthiness false. Values are returned as
ints so the comparison is representation-agnostic.
"""

def dgn_py -> dict {
    d: dict[str, int] = {"value": 1};
    miss_is_none: int = 1 if (d.get("error") is None) else 0;
    miss_is_not_none: int = 1 if (d.get("error") is not None) else 0;
    hit_is_none: int = 1 if (d.get("value") is None) else 0;
    miss_truthy: int = 1 if d.get("error") else 0;
    miss_default: int = d.get("missing", 7);
    hit_default: int = d.get("value", 99);
    return {
        "miss_is_none": miss_is_none,
        "miss_is_not_none": miss_is_not_none,
        "hit_is_none": hit_is_none,
        "miss_truthy": miss_truthy,
        "miss_default": miss_default,
        "hit_default": hit_default
    };
}

def dgn_cl -> dict {
    d: dict[str, int] = {"value": 1};
    miss_is_none: int = 1 if (d.get("error") is None) else 0;
    miss_is_not_none: int = 1 if (d.get("error") is not None) else 0;
    hit_is_none: int = 1 if (d.get("value") is None) else 0;
    miss_truthy: int = 1 if d.get("error") else 0;
    miss_default: int = d.get("missing", 7);
    hit_default: int = d.get("value", 99);
    return {
        "miss_is_none": miss_is_none,
        "miss_is_not_none": miss_is_not_none,
        "hit_is_none": hit_is_none,
        "miss_truthy": miss_truthy,
        "miss_default": miss_default,
        "hit_default": hit_default
    };
}

def dgn_na -> dict[str, any] {
    d: dict[str, int] = {"value": 1};
    miss_is_none: int = 1 if (d.get("error") is None) else 0;
    miss_is_not_none: int = 1 if (d.get("error") is not None) else 0;
    hit_is_none: int = 1 if (d.get("value") is None) else 0;
    miss_truthy: int = 1 if d.get("error") else 0;
    miss_default: int = d.get("missing", 7);
    hit_default: int = d.get("value", 99);
    return {
        "miss_is_none": miss_is_none,
        "miss_is_not_none": miss_is_not_none,
        "hit_is_none": hit_is_none,
        "miss_truthy": miss_truthy,
        "miss_default": miss_default,
        "hit_default": hit_default
    };
}
