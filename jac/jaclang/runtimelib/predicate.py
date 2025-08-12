"""Predicates."""

from enum import StrEnum
from itertools import islice
from re import compile, match
from typing import Any, Callable, Generic, TypeVar, cast


T = TypeVar("T")
GROUP = compile(r'([^\.\[\]\"]+)|\["([^"]+)"\]|\[(\d+)\]')


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
    predicates: tuple["Predicate", ...]
    field: str
    value: Any

    def __init__(
        self,
        type: PredicateType,
        *predicates: "Predicate",
        field: str = "",
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


class PredicateTranslator(Generic[T]):
    """Predicate Translator handler."""

    def __init__(self, predicate: Predicate) -> None:
        """Build translator."""
        self.predicate = predicate

    @property
    def query(self) -> T:
        """Translate predicate to query."""
        query = traversal_parsing(self.predicate)
        return cast(T, query)


def get_attr(source: Any, field: str) -> Any:  # noqa: ANN401
    """Get attribute."""
    for mat in GROUP.finditer(field):
        f = mat.group()
        if f.isdigit():
            if source and (_f := int(f)) < len(source):
                source = source[_f]
            else:
                source = None
        else:
            source = getattr(source, f, None)
    return source


def has_attr(source: Any, field: str) -> Any:  # noqa: ANN401
    """Has attribute."""
    attrs = GROUP.findall(field)
    for f, _, _ in islice(attrs, 0, len(attrs) - 1):
        if f.isdigit():
            if source and (f := int(f)) < len(source):
                source = source[f]
            else:
                source = None
        else:
            source = getattr(source, f, None)

    f = attrs[-1]
    if f.isdigit():
        return source and int(f) < len(source)
    else:
        return has_attr(source, f)


def traversal_parsing(predicate: Predicate) -> Callable[[object], bool]:
    """Parse while traversing."""
    match predicate.type:
        case PredicateType.AND | PredicateType.ALL:
            preds = [traversal_parsing(pred) for pred in predicate.predicates]
            return lambda x: all(pred(x) for pred in preds)
        case PredicateType.OR | PredicateType.ANY:
            preds = [traversal_parsing(pred) for pred in predicate.predicates]
            return lambda x: any(pred(x) for pred in preds)
        case PredicateType.NOR:
            preds = [traversal_parsing(pred) for pred in predicate.predicates]
            return lambda x: not all(pred(x) for pred in preds)
        case PredicateType.NOT:
            pred = traversal_parsing(predicate.predicates[0])
            return lambda x: not pred(x)
        case PredicateType.EQUAL:
            return lambda x: get_attr(x, predicate.field) == predicate.value
        case PredicateType.NOT_EQUAL:
            return lambda x: get_attr(x, predicate.field) != predicate.value
        case PredicateType.GREATER_THAN:
            return lambda x: get_attr(x, predicate.field) > predicate.value
        case PredicateType.LESS_THAN:
            return lambda x: get_attr(x, predicate.field) < predicate.value
        case PredicateType.GREATER_THAN_OR_EQUAL:
            return lambda x: get_attr(x, predicate.field) >= predicate.value
        case PredicateType.LESS_THAN_OR_EQUAL:
            return lambda x: get_attr(x, predicate.field) <= predicate.value
        case PredicateType.IN:
            return lambda x: get_attr(x, predicate.field) in predicate.value
        case PredicateType.NOT_IN:
            return lambda x: get_attr(x, predicate.field) not in predicate.value
        case PredicateType.LIKE:
            if predicate.value.startswith("%"):
                if predicate.value.endsswith("%"):
                    return (
                        lambda x: (field := get_attr(x, predicate.field)) is not None
                        and predicate.value in field
                    )
                else:
                    return lambda x: (
                        field := get_attr(x, predicate.field)
                    ) is not None and field.endswith(predicate.value)
            elif predicate.value.endsswith("%"):
                return lambda x: (
                    field := get_attr(x, predicate.field)
                ) is not None and field.startswith(predicate.value)
            return (
                lambda x: (field := get_attr(x, predicate.field)) is not None
                and field == predicate.value
            )
        case PredicateType.ILIKE:
            if predicate.value.startswith("%"):
                if predicate.value.endsswith("%"):
                    return (
                        lambda x: (field := get_attr(x, predicate.field)) is not None
                        and predicate.value.lower() in field.lower()
                    )
                else:
                    return lambda x: (
                        field := get_attr(x, predicate.field)
                    ) is not None and field.lower().endswith(predicate.value.lower())
            elif predicate.value.endsswith("%"):
                return lambda x: (
                    field := get_attr(x, predicate.field)
                ) is not None and field.lower().startswith(predicate.value.lower())
            return (
                lambda x: (field := get_attr(x, predicate.field)) is not None
                and field.lower() == predicate.value.lower()
            )
        case PredicateType.EXISTS:
            return lambda x: has_attr(x, predicate.field)
        case PredicateType.CONTAINS:
            return lambda x: predicate.value in get_attr(x, predicate.field)
        case PredicateType.TYPE:
            return lambda x: get_attr(x, predicate.field).__class__ == predicate.value
        case PredicateType.REGEX:
            return (
                lambda x: match(predicate.value, get_attr(x, predicate.field))
                is not None
            )
        case _:
            raise TypeError("Not a valid predicate type!")


JacPredicateTranslator = PredicateTranslator[Callable[..., bool]]
