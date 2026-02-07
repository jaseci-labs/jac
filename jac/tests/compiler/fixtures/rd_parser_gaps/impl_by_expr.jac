"""Test impl with by expression parsing."""

def greet_impl -> str {
    return "Hello";
}

obj Greeter {
    def greet -> str;
}

impl Greeter.greet by greet_impl;
