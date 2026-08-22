from typing import Any


class Meta(type):
    def __new__(mcs, name: str, bases: tuple, ns: dict[str, Any]) -> "Meta":
        ns["made"] = "by-meta"
        return super().__new__(mcs, name, bases, ns)


class Foo(metaclass=Meta):
    x = 1


print(Foo.made)
print(Foo.x)
