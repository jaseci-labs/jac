"""A unit whose handlers arm, raise and index long strings across a call."""

def:pub tls_sjlj_probe(n: int) -> int {
    text = "é" * (n + 40);
    total = 0;
    try {
        if n > 3 {
            raise ValueError("too big");
        }
        total = len(text[n:]);
    } except ValueError {
        total = -1;
    }
    return total;
}
