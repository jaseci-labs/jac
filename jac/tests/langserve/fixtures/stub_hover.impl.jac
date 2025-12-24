"""Implementation file for stub_hover.jac."""

impl MyServer.init(self: MyServer, name: str) -> None {
    self.name = name;
    self.request_id = MyServer._counter;
    MyServer._counter += 1;
}

impl MyServer.process(self: MyServer, data: str) -> str {
    return self.name + ": " + data;
}

impl MyServer.handle(self: MyServer, request: int) -> None {
    print(f"Handling request {request}");
}
