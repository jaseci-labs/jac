"""JIT-callable probe: build A<->B cycles, force a trial-deletion sweep, and
return a sentinel. Executed in-process via MCJIT (test_native_gen_pass harness)
so a broken collect-white free path (double-free / invalid free) aborts here.

Two cycle shapes are exercised:
  - make_cycle: a plain struct A<->B cycle (struct dtor reclaim).
  - make_container_cycle: a cycle routed through a list field, so the container
    backing array must also be reclaimed by collect_white (not just the struct
    header). A leak-only regression here would not abort, but ASan/valgrind and
    the RSS assertions in the harness catch the retained backing arrays.
"""

obj Node {
    has next: Node | None = None;
    has kids: list[Node] = [];
}

def make_cycle {
    a: Node = Node();
    b: Node = Node();
    a.next = b;
    b.next = a;
}

def make_container_cycle {
    p: Node = Node();
    c: Node = Node();
    p.kids.append(c);
    c.next = p;
}

def drive_cycles(n: int) -> int {
    i: int = 0;
    while i < n {
        make_cycle();
        make_container_cycle();
        i = i + 1;
    }
    __rc_collect_cycles();
    return n;
}
