"""A Final annotation yields the type it wraps, subscripted or not.

`X: Final = value` takes its type from the value, which already worked. But
`X: Final[T]` kept the Final wrapper itself, so the symbol behaved like a
Final instance rather than a T -- it read fine, and then failed the moment
anything was asked of it.

typeshed writes constants both ways in the same module: string.digits is a
bare Final and string.ascii_letters is Final[LiteralString], so
`ascii_letters + digits` reported no matching overload for __add__ while
each half looked healthy on its own.
"""

import from tests.support { kernel_check_source }

def check_src(src: str) -> list[str] {
    return [
        f"{diag.code}: {diag.message}"
        for diag in kernel_check_source(src, "finals.jac").errors
    ];
}

test "a subscripted Final is usable as the type it wraps" {
    src = "import string;\n"
        + "def probe -> str {\n"
        + "    return string.ascii_letters + string.digits;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"Final[T] not unwrapped: {errs}";
}

test "a bare Final still takes its type from its value" {
    src = "import logging;\n"
        + "def probe -> int {\n"
        + "    level: int = logging.INFO;\n"
        + "    return level;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"bare Final regressed: {errs}";
}
