"""A constructor whose argument raises inside a region open.

The object is allocated and its drop logged before the arguments run, so a
raising argument leaves a half-built object in the region's dtor log. Each
round first fills a region with integer payloads, so the next region's recycled
chunk holds stale words exactly where the half-built object's fields sit; the
close must drop it without releasing them.
"""

obj Mod {
    has body: list[str],
        other: list[str];
}

def make_list(n: int) -> list[str] {
    result: list[str] = [];
    for i in range(3) {
        if n == 1 and i == 1 {
            raise ValueError("boom");
        }
        result.append(str(i));
    }
    return result;
}

obj Junk {
    has a: int,
        b: int;
}

def fill(n: int) -> int {
    total = 0;
    for i in range(n) {
        j = Junk(a=8, b=8);
        total += j.a - j.b + 6;
    }
    return total;
}

def fail_once -> int {
    try {
        m = Mod(body=make_list(0), other=make_list(1));
        return len(m.body);
    } except ValueError {
        return 1;
    }
}

def probe -> i64 {
    score = 0;
    for round in range(20) {
        in Region() {
            score += fill(50);
        }
        in Region() {
            score += fail_once();
        }
    }
    return score;
}
