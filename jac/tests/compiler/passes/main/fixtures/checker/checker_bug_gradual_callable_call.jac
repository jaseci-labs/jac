"""Bug #GRADUAL-CALL fixture.

Calling a value typed as a bare `Callable` (or `Callable[..., T]`) must accept
any argument list. The real-world trigger is the language-server decorator
pattern `server.feature(method)(handler)`, where `feature` is annotated
`-> Callable`.
"""

obj Server {
    def feature(method: str) -> Callable;
}

def handler(a: int, b: str) -> None;

with entry {
    server = Server();
    server.feature("did_open")(handler);  # prev false E1051 -> ok

    g: Callable = handler;
    g();                # always ok (zero args never errored)
    g(1, 2, 3, 4, 5);   # prev false E1051 -> ok
    g(x=1, y=2);        # prev false E1052 -> ok

    e: Callable[..., int] = handler;
    total: int = e("anything", 5, 6);  # prev false E1051 -> ok
}
