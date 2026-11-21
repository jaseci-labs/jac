"""Test fixture for hover on type annotations in method stubs with impl files."""

import from threading { Thread }

class MyServer {
    has name: str = "server",
        request_id: int = 0,
        worker: Thread;

    static has _counter: int = 0;

    def init(self: MyServer, name: str) -> None;
    def process(self: MyServer, data: str) -> str;
    def handle(self: MyServer, request: int) -> None;
    def start_worker(self: MyServer) -> None;
}
