"""Fixture dependency: an attribute assigned from a `with ... as` alias."""

obj Blob {
    has data: bytes = b"";

    def init(path: str) {
        with open(path, "rb") as stream {
            self.data = stream.read();
        }
    }
}
