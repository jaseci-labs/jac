"""Server provider consumed via a plain (unmarked) import from client code.

`fetch_msg` is a `def:pub` endpoint, so a client consumer reaches it over
auto-RPC; `local_helper` has no client-side presence at all.
"""

def:pub fetch_msg(who: str) -> str {
    return "hello " + who;
}

def local_helper(n: int) -> str {
    return "item " + str(n);
}
