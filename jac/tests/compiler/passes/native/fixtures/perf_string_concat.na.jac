"""P-06: String concatenation churn.

Concatenates a 10-character string 5 000 times.  Each iteration allocates a
new string via __rc_alloc + memcpy.  Measures string allocation and RC
bookkeeping throughput.
Timing and RSS are measured externally by run_perf.sh via /usr/bin/time.
"""

with entry {
    s: str = "";
    chunk: str = "0123456789";   # 10 chars
    i: int = 0;
    while i < 5000 {
        s = s + chunk;
        i = i + 1;
    }

    final_len: int = len(s);
    print("OK string_concat len =", final_len);
}
