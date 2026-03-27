"""Fixture: obj with 'by postinit' field for symbol resolution tests."""
obj Greeter {
    has msg: str by postinit;

    def postinit -> None;
}
