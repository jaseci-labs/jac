"""Server module for the E1042 sv-import regression (issue #6236).

`def:pub` functions imported into a client `.cl.jac` via `sv import` compile
to async RPC stubs, so on the client they return coroutines and must be
awaited — even though they are declared synchronous here on the server.
"""

node Task {
    has id: str,
        title: str,
        done: bool = False;
}

def:pub get_tasks -> list[Task] {
    return [root-->][?:Task];
}
