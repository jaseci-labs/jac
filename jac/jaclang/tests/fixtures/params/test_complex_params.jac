# Test complex parameter combinations
def ultimate_signature(
    pos_only: int,
    pos_def: str = "def",
    /,
    reg_def: bool = True,
    *args: int,
    kw_req: str,
    kw_opt: int = 100,
    **kwargs: any
) -> str {
    return f"{pos_only}|{pos_def}|{reg_def}|{len(args)}|{kw_req}|{kw_opt}|{len(kwargs)}";
}

def separators_only( / , * , x: int)  -> int {
    return x;
}

def edge_case_mix(a: int, /, b: str, *args: float, c: bool, **kwargs: str) -> str {
    return f"{a}-{b}-{len(args)}-{c}-{len(kwargs)}";
}

def recursive_test(data: int, /, depth: int = 0, *, max_depth: int = 2) -> int {
    if depth >= max_depth {
        return data;
    }
    return recursive_test(data + 1, depth + 1, max_depth=max_depth);
}

def validation_test(
    x: int, y: str = "test", /, z: float, *args: int, w: bool, **kwargs: str
) -> str {
    return f"x:{x},y:{y},z:{z},args:{len(args)},w:{w},kwargs:{len(kwargs)}";
}

with entry {
    print("ULTIMATE_MIN:", ultimate_signature(1, reg_def=2.5, kw_req="test"));
    print(
        "ULTIMATE_FULL:",
        ultimate_signature(
            1, "custom", 3.14, False, 10, 20, kw_req="req", kw_opt=200, extra="data"
        )
    );
    print("SEPARATORS:", separators_only(x=42));
    print("EDGE_MIX:", edge_case_mix(1, "test", 1.1, 2.2, c=True, name="edge"));
    print("RECURSIVE:", recursive_test(5), recursive_test(10, max_depth=1));
    print("VALIDATION:", validation_test(1, 2.5, 10, 20, w=True, debug="on"));
}
