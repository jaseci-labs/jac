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

def local_helper_two(n: int) -> str {
    return "row " + str(n);
}
