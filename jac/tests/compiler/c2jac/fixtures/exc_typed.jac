"""Typed user-exception payloads for the jac2c backend.

`raise AppError(...)` throws a constructed, RC-owned exception object; the
`except AppError as e` handler binds it as a typed struct pointer and reads its
fields, then releases it on every exit path (return and fallthrough) so the
live-object count stays balanced -- including when the raise crosses a call
boundary into an outer handler.
"""

obj AppError(Exception) {
    has code: int,
        detail: int;

    def init(c: int, d: int) {
        self.code = c;
        self.detail = d;
    }
}

def run_read_field -> int {
    try {
        raise AppError(7, 5);
    } except AppError as e {
        return e.code + e.detail;
    }
    return 0;
}

def _may_raise(n: int) -> int {
    if n > 0 {
        raise AppError(n, 9);
    }
    return -1;
}

def run_field_across_call -> int {
    acc = 0;
    try {
        acc = _may_raise(3);
    } except AppError as e {
        acc = e.code * 10 + e.detail;
    }
    return acc;
}

def run_nothrow -> int {
    try {
        return 42;
    } except AppError as e {
        return e.code;
    }
}
