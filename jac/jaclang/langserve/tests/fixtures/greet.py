class GreetMessage:

    def pass_message(self, msg: str) -> str:
        return f"Hello, {msg}!"


class Greet:

    def try_to_greet(self) -> GreetMessage:
        return GreetMessage()

    def say_hello(self) -> str:
        return self.try_to_greet().pass_message("World")
