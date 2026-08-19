"""`json.dumps` over a homogeneous dict -- the reported corruption.

`dumps(value: any)` narrows to `d: dict[str, any] = value`, so a caller's
`dict[str, int]` crosses the jacval seam on the way in. Values came back
shifted by one slot: `{"k": 7, "j": 42}` rendered as `{"k": 42, "j": ""}`.
"""

import json;


"""1 when `dumps` renders the dict faithfully, 0 when the seam corrupts it."""
def dumps_int_dict_na -> int {
    d: dict[str, int] = {"k": 7, "j": 42};
    if json.dumps(d) == "{\"k\": 7, \"j\": 42}" {
        return 1;
    }
    return 0;
}
