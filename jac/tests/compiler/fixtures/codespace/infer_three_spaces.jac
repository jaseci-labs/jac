"""One markerless-client module spanning all three codespaces.

Server side is the default (imports, archetypes, `def:pub` endpoints stay
put - client references reach them via auto-RPC, not relocation); the client
side is inferred from JSX; the pure helper stays server unless native
inference or a [placement.pins] entry moves it.
"""

import os;

node Item {
    has label: str;
}

walker list_items {
    can go with Root entry {
        report [-->];
    }
}

def:pub server_stats -> dict {
    return {"cwd": os.getcwd()};
}

def:pub app -> JsxElement {
    stats = await server_stats();
    todos = root spawn list_items();
    return <div>{stats}</div>;
}


def fast_add(a: i64, b: i64) -> i64 {
    return a + b;
}
