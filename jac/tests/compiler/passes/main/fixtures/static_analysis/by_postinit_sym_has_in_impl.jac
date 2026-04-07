obj Greeter {
    def postinit;
}

impl Greeter {
    has msg: str by postinit;
}
