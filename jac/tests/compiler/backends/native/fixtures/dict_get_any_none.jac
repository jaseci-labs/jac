def describe(fields: dict[str, any], key: str) -> str {
    value = fields.get(key);
    if value is not None {
        return f"{key}=set:{value}";
    }
    return f"{key}=none";
}

def describe_default(fields: dict[str, any], key: str) -> str {
    value = fields.get(key, None);
    return f"{key}=none" if value is None else f"{key}=set:{value}";
}

def truthy(fields: dict[str, any], key: str) -> str {
    value = fields.get(key);
    return f"{key}=truthy" if value else f"{key}=falsy";
}

with entry {
    fields: dict[str, any] = {"source": None, "path": "p", "count": 0};
    for key in ["source", "path", "count", "missing"] {
        print(describe(fields, key));
        print(describe_default(fields, key));
        print(truthy(fields, key));
    }
}
