def arm(name: str) -> (dict[str, any] | None) {
    return {"code": "str"} if name == "str" else None;
}

def direct(name: str) -> (dict[str, any] | None) {
    if name == "str" {
        return {"code": "str"};
    }
    return None;
}

with entry {
    found = direct("str");
    print(len(found) if found is not None else 0, direct("int") is None);
    other = arm("str");
    print(len(other) if other is not None else 0);
}
