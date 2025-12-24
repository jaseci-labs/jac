"""Test fixture for hover on type annotations in method stubs with impl files."""

class MyServer {
    has name: str = "server",
        request_id: int = 0;

    static has _counter: int = 0;

    def init(self: MyServer, name: str) -> None;
    def process(self: MyServer, data: str) -> str;
    def handle(self: MyServer, request: int) -> None;
}
