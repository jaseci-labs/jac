"""Escape-scan coverage for the remaining frame kinds.

A capturing closure that escapes from an event-method frame, a
no-signature method frame, the module entry frame, or a global
initializer promotes its captures to RC heap cells exactly as in plain
ability frames; the frames differ only in who owns the scan call.
"""

node Thing {
    has val: int;
}

walker Scaler {
    has result: int = 0;

    can measure with Thing entry {
        k = here.val;
        fns: list[Callable[[int], int]] = [lambda (x: int) -> int { x * k; }];
        f = fns[0];
        self.result = f(10);
    }
}

def event_frame_escape(v: int) -> int {
    return (Scaler() spawn Thing(val=v)).result;
}

obj Box {
    has base: int = 4,
        result: int = 0;

    def bump {
        k = self.base;
        fns: list[Callable[[int], int]] = [lambda (x: int) -> int { x + k; }];
        f = fns[0];
        self.result = f(100);
    }
}

def nosig_frame_escape(b: int) -> int {
    bx = Box(base=b);
    bx.bump();
    return bx.result;
}

glob futs: list[Callable[[int], int]] = [lambda (x: int) -> int { x * 3; }];

def globinit_lambda(v: int) -> int {
    g = futs[0];
    return g(v);
}

glob entry_acc: list[int] = [];

with entry {
    if len(entry_acc) == 0 {
        fns: list[Callable[[int], int]] = [lambda (x: int) -> int { x + 7; }];
        f = fns[0];
        entry_acc.append(f(1));
    }
}

def entry_frame_escape -> int {
    if len(entry_acc) > 0 {
        return entry_acc[0];
    }
    return -1;
}
