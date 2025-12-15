# flake8: noqa

"""Python to Jac convertion test."""

from dataclasses import dataclass


@dataclass
class Inner:
    x: int
    y: int


@dataclass
class Container:
    inner: Inner


a = 1
b = 2

match Container(inner=Inner(x=a, y=b)):
    case Container(inner=Inner(x=a, y=0)):
        print(f"1.Inner.x={a}, Inner.y=0")
    case Container(inner=Inner(x=0, y=b)):
        print(f"2.Inner.x=0, Inner.y={b}")
    case Container(inner=Inner(x=a, y=b)):
        print(f"4.Inner.x={a}, Inner.y={b}")
    case _:
        print("5.No match")
