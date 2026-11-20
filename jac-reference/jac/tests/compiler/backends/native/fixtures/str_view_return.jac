"""A string view returned through a union, optional or `any` result is a
string of its own: the caller's value outlives the callee's frame."""

def as_union(spelling: str) -> (str | list[int] | None) {
    if len(spelling) == 0 {
        return None;
    }
    body = spelling[2:len(spelling) - 1];
    if spelling[0] == "b" {
        return list(body.encode("utf-8"));
    }
    return body;
}

def as_optional(spelling: str) -> (str | None) {
    if len(spelling) < 3 {
        return None;
    }
    body = spelling[2:len(spelling) - 1];
    return body;
}

def as_any(spelling: str) -> any {
    body = spelling[2:len(spelling) - 1];
    return body;
}

def churn -> int {
    junk = [str(i) * 4 for i in range(200)];
    return len(junk);
}

def run {
    got = as_union('r"abc"');
    print(got);
    values: list[str] = [];
    if isinstance(got, str) {
        values.append(got);
    }
    print(values);
    opt = as_optional('r"defg"');
    boxed = as_any('r"hijkl"');
    print(churn());
    if opt is not None {
        values.append(opt);
    }
    print(values, boxed);
}

with entry {
    run();
}
