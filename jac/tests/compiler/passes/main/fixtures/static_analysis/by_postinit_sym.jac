obj Greeter {
    has msg: str by postinit;
    def postinit {
        self.msg = "hello";
    }
}
