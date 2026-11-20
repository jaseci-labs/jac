"""Test fixture for symbol resolution in impl bodies."""

obj Counter {
    has count: int = 0,
        name: str = "default";

    def increment -> int;
    def get_info -> str;
}
