"""`def drop` must fire when a managed (rc/cycles) release destroys the
object, not only under enforced headerless `--gc none` (issue #7466 bug 4).
The hook mutates module globals so the JIT tests can observe firing count
and order without capturing stdout."""

glob dropped = 0,
     last_tag = 0;

obj Res {
    has tag: int = 0;

    def drop {
        global dropped;
        global last_tag;
        dropped += 1;
        last_tag = self.tag;
    }
}

def spin(tag: int) -> int {
    r = Res(tag=tag);
    return r.tag;
}

def run_drops -> int {
    total = 0;
    for i in range(3) {
        total += spin(i + 5);
    }
    return total;
}

def drop_count -> int {
    return dropped;
}

def last_dropped -> int {
    return last_tag;
}
