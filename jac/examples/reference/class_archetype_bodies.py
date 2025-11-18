"""Archetype bodies: Member statements (has, static, methods, nested types)."""

from __future__ import annotations
from jaclang.lib import Obj, field
from typing import ClassVar


class Vehicle(Obj):
    """This is a module-level docstring"""

    "Member docstring"
    name: str
    year: int
    count: ClassVar[int] = 0
    public_id: str = "V123"
    private_data: int = 0
    config: dict = field(init=False)

    def __post_init__(self) -> None:
        self.config = {"active": True}
        Vehicle.count += 1

    def display(self) -> str:
        return f"{self.year} {self.name}"

    @staticmethod
    def get_count() -> int:
        return Vehicle.count

    class Part:
        part_name: str

    def py_method(self):
        return "Python code"


v1 = Vehicle(name="Car", year=2020)
v2 = Vehicle(name="Truck", year=2021)
print(v1.display(), v2.display(), Vehicle.get_count())
