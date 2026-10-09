def _random_span(span: int) -> int {
    if span <= 0 {
        return 0;
    }
    crypto = globalThis.crypto;
    if crypto and crypto.getRandomValues {
        buf = new(Uint8Array, 4);
        crypto.getRandomValues(buf);
        n: int = 0;
        for i in range(4) {
            n = n * 256 + int(buf[i]);
        }
        if n < 0 {
            n = -n;
        }
        return n % span;
    }
    return int(Math.floor(Math.random() * span));
}


def:pub randint(a: int, b: int) -> int {
    if a >= b {
        return a;
    }
    span: int = b - a + 1;
    return a + _random_span(span);
}
