"""Module with a class to be re-exported."""


class MyClass:
    def __init__(self, value: int) -> None:
        self.value = value

    def greet(self) -> str:
        return f"Hello {self.value}"
