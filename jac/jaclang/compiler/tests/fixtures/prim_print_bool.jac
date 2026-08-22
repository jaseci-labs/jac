"""print(bool) renders True/False on every backend (#7922)."""

def pbool_py -> dict {
    flag: bool = True;
    print(flag, False);
    return {"ok": 1};
}

def pbool_cl -> dict {
    # No print here: the ES harness parses this function's stdout as JSON,
    # so console output would corrupt the comparison channel. The bool
    # rendering under test is the native path.
    flag: bool = True;
    ok: int = 1 if flag else 0;
    return {"ok": ok};
}

def pbool_na -> dict[str, any] {
    flag: bool = True;
    print(flag, False);
    return {"ok": 1};
}
