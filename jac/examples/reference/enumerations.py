from enum import Enum, auto, unique


@unique
class Color(Enum):
    RED = 1
    pencil = auto()


class Role(Enum):
    ADMIN = ("admin",)
    USER = "user"

    print("Initializing role system..")

    def foo():
        return "Accessing privileged Data"


print(Color.RED.value, Role.foo())
