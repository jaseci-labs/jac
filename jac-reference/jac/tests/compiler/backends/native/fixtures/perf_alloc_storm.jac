"""P-01: Allocation storm.

Allocates 100 000 plain structs in a tight loop, letting each go out of scope
immediately.  Measures raw __rc_alloc throughput.
Timing and RSS are measured externally by run_perf.sh via /usr/bin/time.
"""

obj Node {
    has val: int = 0;
}

with entry {
    i: int = 0;
    while i < 100000 {
        n: Node = Node(val=i);
        i = i + 1;
    }
    print("OK alloc_storm");
}
