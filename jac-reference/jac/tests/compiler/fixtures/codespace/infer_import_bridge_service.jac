"""Server-anchored provider consumed via a plain import from client code.

The datetime import anchors the module server-side, so `fetch_msg` is a
`def:pub` endpoint and a client consumer reaches it over auto-RPC.
"""
import datetime;

def:pub fetch_msg(who: str) -> str {
    return "hello " + who + " @" + str(datetime.datetime.now().year);
}

def local_helper(n: int) -> str {
    return "item " + str(n);
}

def local_helper_two(n: int) -> str {
    return "row " + str(n);
}
