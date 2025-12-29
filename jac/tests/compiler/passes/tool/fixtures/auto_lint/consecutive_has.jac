"""Test combining consecutive has statements.

Consecutive has statements with the same modifiers (static, access, frozen)
should be combined into a single has statement with comma-separated vars.
"""

obj Person {
    """A person with multiple attributes."""
    has name: str;

    has age: int;
    has email: str;
    has : pub address: str;
    has : pub phone: str;
    has city: str = "Unknown";

    def greet()  -> str {
        return "Hello, " + self.name;
    }
}

obj Config {
    """Config with static has statements."""
    static has DEBUG: bool = False;

    static has VERSION: str = "1.0";
    static has MAX_RETRIES: int = 3;
}
