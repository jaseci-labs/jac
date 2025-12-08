"""This is a helper file."""


def add1() -> int:
    return 1 + 1


def sub1() -> int:
    return 1 - 1


# classes
class Orange1:
    def __init__(self) -> None:
        self.orange = 1

    def get_orange(self) -> int:
        return self.orange

    def set_orange(self, orange: int) -> None:
        self.orange = orange


# variables
orange2 = 1
apple = 1
