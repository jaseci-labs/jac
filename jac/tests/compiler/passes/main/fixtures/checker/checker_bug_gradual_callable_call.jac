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
