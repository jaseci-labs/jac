"""Implementation file for stub_hover.jac."""

import from threading { Thread }

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

impl MyServer.start_worker(self: MyServer) -> None {
    # This tests that Python type methods (Thread.start) are properly resolved
    # in impl bodies.
    self.worker = Thread(target=self.process);
    self.worker.start();
}
