"""Fixture: @classmethod on node should warn with 'node' in message."""

node Bar {
    @classmethod
    def baz(cls: type) -> str {
        return "hello";
    }
}
