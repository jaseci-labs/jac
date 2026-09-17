def identity(cls: type) -> type {
    return cls;
}

def test_local_object {
    @identity
    obj MyResult {
        has is_match: bool = False,
            value: (str | None) = None;
    }

    result = MyResult();
    x: bool = result.is_match;
    y: (str | None) = result.value;
}
