"""P-02: Retain / release throughput (rapid reassignment).

Reassigns a struct pointer 1 000 000 times.  Once retain-on-store and
scope-cleanup are wired (RC-2 / RC-3) every iteration triggers one retain
and one release.  Measures the overhead of those two RC operations.
Timing and RSS are measured externally by run_perf.sh via /usr/bin/time.
"""

obj Token {
    has id: int = 0;
}

with entry {
    tok: Token = Token(id=0);
    i: int = 0;
    while i < 1000000 {
        tok = Token(id=i);
        i = i + 1;
    }
    print("OK retain_release last_id =", tok.id);
}
