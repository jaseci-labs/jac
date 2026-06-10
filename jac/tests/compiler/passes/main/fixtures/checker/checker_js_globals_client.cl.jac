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

# Mirrors the this_is_jac frontend.cl.jac:61 failure: `document`'s
# always-present root elements (documentElement/body/head) must carry the
# real HTMLElement type so `.classList` (and other element members) resolve
# instead of erroring E1030 off the bare `object` placeholder.
def toggle_dark(dark: bool) -> bool {
    if dark {
        document.documentElement.classList.add("dark");
    } else {
        document.documentElement.classList.remove("dark");
    }
    document.body.classList.toggle("ready");
    return document.head.classList.contains("loaded");
}
