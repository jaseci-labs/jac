"""Regression fixture for #6564: flat JoinedStr codegen for f-strings."""

obj PluginError {
    has code: str;
    has message: str;
    def init(code: str, message: str) {
        self.code = code;
        self.message = message;
    }
}

def repro(
    command: str,
    platform: str,
    escaped_title: str,
    escaped_body: str,
    x: str
) -> None {
    # Single-quoted literals around interpolation (original bug report)
    msg = f"Plugin 'jac.dialog' has no command '{command}'";

    # Mixed outer-quote style
    script = f'POSIX path of (choose file with prompt "{escaped_title}")';
    raise PluginError("UNSUPPORTED", f"Platform '{platform}' not supported");

    # Adjacent f-string concatenation
    concat = f"hello" f" {command}";

    # Mixed plain + f-string + plain
    mixed = "pre" f"mid {x}" "post";

    # Nested braces in format spec
    nested = f"value={x!r}";

    print(msg);
    print(script);
    print(concat);
    print(mixed);
    print(nested);
}
