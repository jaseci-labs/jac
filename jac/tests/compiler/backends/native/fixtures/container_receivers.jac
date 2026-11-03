"""Containers reached through a field, an element or a narrowed optional.

`meta.path_fields |= fields` updates the field's set in place, as does
`groups[0] |= extra`. A module-level `dict | None` that an `if ... is None`
filled in answers `.get` with the default for a missing key.
"""
glob _table: dict[str, str] | None = None,
     _DEFAULT: str = "none";

obj Meta {
    has managed: bool = False,
        path_fields: set[str] = set();
}

def merge(meta: Meta, other: Meta | None) -> int {
    fields: set[str] = set();
    if other is not None and other.managed {
        fields |= other.path_fields;
    }
    if not fields.issubset(meta.path_fields) {
        meta.path_fields |= fields;
    }
    return len(meta.path_fields);
}

def grow_element -> int {
    groups: list[set[int]] = [{1}, {2}];
    shared = groups[0];
    groups[0] |= {3, 4};
    return len(shared) * 10 + len(groups[1]);
}

def build -> dict[str, str] {
    return {"a": "alpha"};
}

def lookup(tag: str) -> str {
    if _table is None {
        _table = build();
    }
    return _table.get(tag, _DEFAULT);
}

def chk_field_union -> int {
    a = Meta(path_fields={"x"});
    b = Meta(managed=True, path_fields={"y", "z"});
    return merge(a, b) * 10 + merge(a, None);
}

def chk_narrowed_get -> int {
    return len(lookup("a")) * 10 + len(lookup("b"));
}

with entry {
    print(chk_field_union(), grow_element(), chk_narrowed_get());
}
