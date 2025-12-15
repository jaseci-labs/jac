obj SomeObj {
    def foo(param1: str, param2: int) -> str;
    def bar(param1: str, param2: int) -> str;
}

# Miss match parameter count.
impl SomeObj.foo(param1: str) -> str {
    return "foo";
}

# Mis matching parameter name.
impl SomeObj.bar(param1: str, praam2: int) -> str {
    return "bar";
}
