"""Pure markerless module whose only defs are variadic.

Under the native default codespace this must classify AND lower natively:
variadic parameters are within the native capability set, so no #7587
demotion back to server.
"""

def pack_sum(*nums: int) -> int {
    acc = 0;
    for n in nums {
        acc += n;
    }
    return acc;
}

def opt_pick(**opts: int) -> int {
    return opts["v"] if "v" in opts else 0;
}

def use_packs -> int {
    return pack_sum(1, 2, 3) + opt_pick(v=10);
}
