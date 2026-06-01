"""Client-context fixture: ECMAScript / browser globals must resolve.

Mirrors the real-world failure from littleX TweetCard.cl.jac line 25:
`Date.now() - new(Date, created_at).getTime()` plus a few other standard
JS globals. All of this must type-check cleanly in client context.
"""

def now_diff(created_at: str) -> int {
    diff_ms = Date.now() - new(Date, created_at).getTime();
    return int(diff_ms / 1000);
}

def math_json(seed: float) -> str {
    floored: float = Math.floor(Math.random() * 100.0);
    bounded: float = Math.max(floored, seed);
    console.log("bounded", bounded);
    return JSON.stringify({"value": bounded});
}

def parse_and_format(raw: str) -> int {
    n = parseInt(raw, 10);
    return int(n);
}
