"""Predicates."""

from collections.abc import Iterable
from enum import StrEnum
from typing import Any


class PredicateType(StrEnum):
    """Predicate Type Enum."""

    AND = "AND"
    OR = "OR"
    NOR = "NOR"
    NOT = "NOT"
    EQUAL = "EQUAL"
    NOT_EQUAL = "NOT_EQUAL"
    GREATER_THAN = "GREATER_THAN"
    LESS_THAN = "LESS_THAN"
    GREATER_THAN_OR_EQUAL = "GREATER_THAN_OR_EQUAL"
    LESS_THAN_OR_EQUAL = "LESS_THAN_OR_EQUAL"
    IN = "IN"
    NOT_IN = "NOT_IN"
    LIKE = "LIKE"
    ILIKE = "ILIKE"
    EXISTS = "EXISTS"
    CONTAINS = "CONTAINS"
    ANY = "ANY"
    ALL = "ALL"
    TYPE = "TYPE"
    REGEX = "REGEX"


class Predicate:
    """Base Predicate."""

    type: PredicateType
    predicates: Iterable["Predicate"]
    field: str | None
    value: Any

    def __init__(
        self,
        type: PredicateType,
        *predicates: "Predicate",
        field: str | None = None,
        value: Any = None,  # noqa: ANN401
    ) -> None:
        """Initialize Init."""
        self.type = type
        self.predicates = predicates
        self.field = field
        self.value = value

    @classmethod
    def _and(cls, *predicates: "Predicate") -> "Predicate":
        """And Operator."""
        return Predicate(PredicateType.AND, *predicates)

    @classmethod
    def _or(cls, *predicates: "Predicate") -> "Predicate":
        """Or Operator."""
        return Predicate(PredicateType.OR, *predicates)

    @classmethod
    def _nor(cls, *predicates: "Predicate") -> "Predicate":
        """Nor Operator."""
        return cls._not(Predicate(PredicateType.OR, *predicates))

    @classmethod
    def _not(cls, predicate: "Predicate") -> "Predicate":
        """Not Operator."""
        return Predicate(PredicateType.NOT, predicate)

    @classmethod
    def _eq(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Equal Operator."""
        return Predicate(PredicateType.EQUAL, field=field, value=value)

    @classmethod
    def _ne(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Not Equal Operator."""
        return Predicate(PredicateType.NOT_EQUAL, field=field, value=value)

    @classmethod
    def _gt(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Greater Than Operator."""
        return Predicate(PredicateType.GREATER_THAN, field=field, value=value)

    @classmethod
    def _lt(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Less Than Operator."""
        return Predicate(PredicateType.LESS_THAN, field=field, value=value)

    @classmethod
    def _gte(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Greater Than or Equal Operator."""
        return Predicate(PredicateType.GREATER_THAN_OR_EQUAL, field=field, value=value)

    @classmethod
    def _lte(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Less Than or Equal Operator."""
        return Predicate(PredicateType.LESS_THAN_OR_EQUAL, field=field, value=value)

    @classmethod
    def _in(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """In Operator."""
        return Predicate(PredicateType.IN, field=field, value=value)

    @classmethod
    def _nin(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Not In Operator."""
        return Predicate(PredicateType.NOT_IN, field=field, value=value)

    @classmethod
    def _lk(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Like Operator."""
        return Predicate(PredicateType.IN, field=field, value=value)

    @classmethod
    def _ilk(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Case insensitive Like Operator."""
        return Predicate(PredicateType.NOT_IN, field=field, value=value)

    @classmethod
    def _exists(cls, field: str) -> "Predicate":
        """Exists Operator."""
        return Predicate(PredicateType.EXISTS, field=field)

    @classmethod
    def _contains(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Contains Operator."""
        return Predicate(PredicateType.CONTAINS, field=field, value=value)

    @classmethod
    def _any(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """Any Operator."""
        return Predicate(PredicateType.ANY, field=field, value=value)

    @classmethod
    def _all(cls, field: str, value: Any) -> "Predicate":  # noqa: ANN401
        """All Operator."""
        return Predicate(PredicateType.ALL, field=field, value=value)

    @classmethod
    def _type(cls, field: str, value: str) -> "Predicate":
        """Type Operator."""
        return Predicate(PredicateType.TYPE, field=field, value=value)

    @classmethod
    def _regex(cls, field: str, value: str) -> "Predicate":
        """Regex Operator."""
        return Predicate(PredicateType.REGEX, field=field, value=value)
