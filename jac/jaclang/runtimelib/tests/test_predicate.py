"""Test for jaseci predicate."""

from dataclasses import dataclass
from typing import Any, cast

from jaclang.utils.test import TestCase
from jaclang.runtimelib.archetype import Anchor
from jaclang.runtimelib.predicate import Predicate as P, JacPredicateQuery as T


@dataclass
class Child:
    children: dict[str, Any]
    age: int
    name: str


@dataclass
class Parent:
    son: Child
    daughters: list[Child]
    cars: list[str]


class TestPredicate(TestCase):
    """Test jaseci predicate."""

    def test_predicate(self) -> None:
        """Test predicate."""
        parent = cast(
            Anchor,
            Parent(
                son=Child(
                    children={"field1": True, "field2": "abcdefghijklmnopqrstuvwxyz"},
                    name="boy1",
                    age=1,
                ),
                daughters=[
                    Child(
                        children={
                            "field1": True,
                            "field2": "abcdefghijklmnopqrstuvwxyz",
                        },
                        name="girl1",
                        age=2,
                    ),
                    Child(
                        children={
                            "field1": True,
                            "field2": "abcdefghijklmnopqrstuvwxyz",
                        },
                        name="girl2",
                        age=3,
                    ),
                    Child(
                        children={
                            "field1": True,
                            "field2": "abcdefghijklmnopqrstuvwxyz",
                        },
                        name="girl3",
                        age=4,
                    ),
                ],
                cars=["tesls", "toyota"],
            ),
        )

        self.assertTrue(
            T(P._eq("son.name", "boy1")).query(parent),
        )
        self.assertTrue(
            T(P._ne("son.name", "boy2")).query(parent),
        )
        self.assertTrue(
            T(P._eq("daughters.name", "girl1")).query(parent),
        )
        self.assertTrue(
            T(P._eq("daughters[2].name", "girl3")).query(parent),
        )
