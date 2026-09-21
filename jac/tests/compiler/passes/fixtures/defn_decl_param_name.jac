obj Greeter {
    def greet(name: str, times: int) -> str;
}

impl Greeter.greet(who: str, times: int) -> str {
    return who * times;
}
