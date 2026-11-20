"""Tuple-unpack ownership test (issue #7320 Cluster 1, items 1a/1b/1c).

`for (k, v) in list_of_tuples` binds the unpacked elements into named
locals. Those locals are released at scope exit (and on early return), so
the binding must retain the borrowed tuple fields; before the fix the last
iteration's strings (and, on early return, the current iteration's) were
freed while the list still held them, corrupting the list for later reads.

Heap strings are built with str(i) concats so the refcounts are real (the
bug is invisible on static literals, whose release is a no-op).
"""

def make_pairs -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    for i in range(3) {
        out.append(("key" + str(i), "val" + str(i)));
    }
    return out;
}

def join_pairs(pairs: list[tuple[str, str]]) -> str {
    acc = "";
    for (k, v) in pairs {
        acc = acc + k + "=" + v + ";";
    }
    return acc;
}

def churn -> int {
    # Reallocate over any freed strings so use-after-free reads garbage
    # instead of stale-but-intact bytes.
    junk: list[str] = [];
    for i in range(40) {
        junk.append("clobber-" + str(i) + "-XXXXXXXX");
    }
    return len(junk);
}

def:pub join_twice -> int {
    # Two joins of the same list must agree with the expected text;
    # encode (first ok)*10 + (second ok); expect 11.
    pairs = make_pairs();
    expected = "key0=val0;key1=val1;key2=val2;";
    first = join_pairs(pairs);
    churn();
    second = join_pairs(pairs);
    a = 1 if first == expected else 0;
    b = 1 if second == expected else 0;
    return a * 10 + b;
}

def find_val(pairs: list[tuple[str, str]], want: str) -> str {
    for (k, v) in pairs {
        if k == want {
            return v;
        }
    }
    return "?";
}

def:pub early_return_keeps_list -> int {
    # Returning an unpack-bound local mid-loop must not free the tuple
    # fields still owned by the list; encode (got ok)*10 + (rejoin ok);
    # expect 11.
    pairs = make_pairs();
    got = find_val(pairs, "key1");
    churn();
    rejoined = join_pairs(pairs);
    a = 1 if got == "val1" else 0;
    b = 1 if rejoined == "key0=val0;key1=val1;key2=val2;" else 0;
    return a * 10 + b;
}

with entry {
    churn();
}
