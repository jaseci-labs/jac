"""Bare JS host constructor calls in client code (issue #7651).

As a `.jac` the whole module is client codespace, so bare `def:pub` runs
client-side (no `cl { }` wrapper needed).
"""
def:pub IndexPage -> any {
    enc = TextEncoder();
    url = URL("https://example.com");
    ws = WebSocket("ws://example.com");
    promise = Promise(
        lambda (resolve: any, reject: any) { resolve.call(None, "done"); }
    );
    return "hi";
}
