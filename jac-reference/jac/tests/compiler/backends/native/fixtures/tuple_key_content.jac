def paren_fresh -> int {
    seen: set[tuple[(str, str)]] = set();
    seen.add(("val", "setter"));
    k = ("va" + "l", "set" + "ter");
    hits = 0;
    if k in seen {
        hits += 1;
    }
    seen.add(k);
    return hits * 100 + len(seen);
}

def plain_fresh -> int {
    seen: set[tuple[str, str]] = set();
    seen.add(("val", "setter"));
    k = ("va" + "l", "set" + "ter");
    hits = 0;
    if k in seen {
        hits += 1;
    }
    seen.add(k);
    return hits * 100 + len(seen);
}

def mixed_fresh -> int {
    seen: set[tuple[str, int]] = set();
    seen.add(("val", 3));
    hits = 0;
    if ("va" + "l", 3) in seen {
        hits += 1;
    }
    if ("va" + "l", 4) in seen {
        hits += 10;
    }
    seen.add(("va" + "l", 3));
    return hits * 100 + len(seen);
}

def dedup_fresh -> int {
    props: set[str] = set();
    props.add("val");
    seen_accessors: set[tuple[(str, str)]] = set();
    dups = 0;
    i = 0;
    while i < 3 {
        kind: (str | None) = None;
        if i > 0 {
            kind = "set" + "ter";
        } else {
            kind = "get" + "ter";
        }
        mname = "va" + "l";
        if kind is not None and mname in props {
            key = (mname, kind);
            if key in seen_accessors {
                dups += 1;
            }
            seen_accessors.add(key);
        }
        i += 1;
    }
    return dups * 100 + len(seen_accessors);
}
