"""Bare JS host constructor calls in client code (issue #7651)."""

cl {
    def:pub IndexPage() -> any {
        enc = TextEncoder();
        url = URL("https://example.com");
        ws = WebSocket("ws://example.com");
        promise = Promise(lambda (resolve: any, reject: any) {
            resolve.call(None, "done");
        });
        return "hi";
    }
}
