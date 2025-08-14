"""Predicates."""

from collections.abc import Iterable
from enum import StrEnum
from itertools import islice
from re import compile, match
from typing import Any, Callable, Generic, TYPE_CHECKING, TypeVar, cast

if TYPE_CHECKING:
    from jaclang.runtimelib.archetype import Anchor


T = TypeVar("T")
GROUP = compile(r"([^\.\[\]\"]+)|\[([^\]]+)\]")


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


class PredicateQuery(Generic[T]):
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
        f: str = next((m for m in mat.groups() if m is not None))
        if f.isdigit():
            if source and (_f := int(f)) < len(source):
                source = source[_f]
            else:
                source = None
        else:
            match source:
                case dict():
                    source = source.get(f)
                case Iterable():
                    if source:
                        src = next(iter(source))
                        if isinstance(src, Iterable):
                            source = [
                                (
                                    s.get(f)
                                    if isinstance(s, dict)
                                    else getattr(s, f, None)
                                )
                                for src in source
                                for s in src
                            ]
                        else:
                            source = [
                                (
                                    src.get(f)
                                    if isinstance(src, dict)
                                    else getattr(src, f, None)
                                )
                                for src in source
                            ]
                    else:
                        source = []
                case _:
                    source = getattr(source, f, None)
    return source


def has_attr(source: Any, field: str) -> Any:  # noqa: ANN401
    """Has attribute."""
    attrs = GROUP.findall(field)
    for mat in islice(attrs, 0, len(attrs) - 1):
        f: str = next((m for m in mat if m is not None))
        if f.isdigit():
            if source and (_f := int(f)) < len(source):
                source = source[_f]
            else:
                source = None
        else:
            match source:
                case dict():
                    source = source.get(f)
                case Iterable():
                    if source:
                        src = next(iter(source))
                        if isinstance(src, Iterable):
                            source = [
                                (
                                    s.get(f)
                                    if isinstance(s, dict)
                                    else getattr(s, f, None)
                                )
                                for src in source
                                for s in src
                            ]
                        else:
                            source = [
                                (
                                    src.get(f)
                                    if isinstance(src, dict)
                                    else getattr(src, f, None)
                                )
                                for src in source
                            ]
                    else:
                        source = []
                case _:
                    source = getattr(source, f, None)

    f = attrs[-1]
    if f.isdigit():
        return source and int(f) < len(source)
    else:
        match source:
            case dict():
                return f in source
            case Iterable():
                if source:
                    src = next(iter(source))
                    if isinstance(src, Iterable):
                        return any(
                            (f in s if isinstance(s, dict) else hasattr(s, f))
                            for src in source
                            for s in src
                        )
                    else:
                        return any(
                            (f in src if isinstance(src, dict) else hasattr(src, f))
                            for src in source
                        )
                else:
                    return False
            case _:
                return hasattr(source, f)


def traversal_parsing(predicate: Predicate) -> Callable[["Anchor"], bool]:
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
            return lambda x: (
                any(val == predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value == predicate.value
            )
        case PredicateType.NOT_EQUAL:
            return lambda x: (
                any(val != predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value != predicate.value
            )
        case PredicateType.GREATER_THAN:
            return lambda x: (
                any(val > predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value > predicate.value
            )
        case PredicateType.LESS_THAN:
            return lambda x: (
                any(val < predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value < predicate.value
            )
        case PredicateType.GREATER_THAN_OR_EQUAL:
            return lambda x: (
                any(val >= predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value >= predicate.value
            )
        case PredicateType.LESS_THAN_OR_EQUAL:
            return lambda x: (
                any(val <= predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value <= predicate.value
            )
        case PredicateType.IN:
            return lambda x: (
                any(val in predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value in predicate.value
            )
        case PredicateType.NOT_IN:
            return lambda x: (
                any(val not in predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value not in predicate.value
            )
        case PredicateType.LIKE:
            if predicate.value.startswith("%"):
                if predicate.value.endsswith("%"):
                    return lambda x: (
                        any(
                            predicate.value in val
                            for val in value
                            if isinstance(val, str)
                        )
                        if isinstance(value := get_attr(x, predicate.field), Iterable)
                        and not isinstance(value, str)
                        else (isinstance(value, str) and predicate.value in value)
                    )
                else:
                    return lambda x: (
                        any(
                            val.endswith(predicate.value)
                            for val in value
                            if isinstance(val, str)
                        )
                        if isinstance(value := get_attr(x, predicate.field), Iterable)
                        and not isinstance(value, str)
                        else (
                            isinstance(value, str) and value.endswith(predicate.value)
                        )
                    )
            elif predicate.value.endsswith("%"):
                return lambda x: (
                    any(
                        val.startswith(predicate.value)
                        for val in value
                        if isinstance(val, str)
                    )
                    if isinstance(value := get_attr(x, predicate.field), Iterable)
                    and not isinstance(value, str)
                    else (isinstance(value, str) and value.startswith(predicate.value))
                )
            return lambda x: (
                any(val == predicate.value for val in value if isinstance(val, str))
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else (isinstance(value, str) and value == predicate.value)
            )
        case PredicateType.ILIKE:
            pvalue = predicate.value.lower()
            if pvalue.startswith("%"):
                if pvalue.endsswith("%"):
                    return lambda x: (
                        any(
                            pvalue in val.lower()
                            for val in value
                            if isinstance(val, str)
                        )
                        if isinstance(value := get_attr(x, predicate.field), Iterable)
                        and not isinstance(value, str)
                        else (isinstance(value, str) and pvalue in value.lower())
                    )
                else:
                    return lambda x: (
                        any(
                            val.lower().endswith(pvalue)
                            for val in value
                            if isinstance(val, str)
                        )
                        if isinstance(value := get_attr(x, predicate.field), Iterable)
                        and not isinstance(value, str)
                        else (isinstance(value, str) and value.lower().endswith(pvalue))
                    )
            elif pvalue.endsswith("%"):
                return lambda x: (
                    any(
                        val.lower().startswith(pvalue)
                        for val in value
                        if isinstance(val, str)
                    )
                    if isinstance(value := get_attr(x, predicate.field), Iterable)
                    and not isinstance(value, str)
                    else (isinstance(value, str) and value.lower().startswith(pvalue))
                )
            return lambda x: (
                any(val.lower() == pvalue for val in value if isinstance(val, str))
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else (isinstance(value, str) and value.lower() == pvalue)
            )
        case PredicateType.EXISTS:
            return lambda x: has_attr(x, predicate.field)
        case PredicateType.CONTAINS:
            return lambda x: (
                any(predicate.value in val for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else predicate.value in value
            )
        case PredicateType.TYPE:
            return lambda x: (
                any(val.__class__.__name__ == predicate.value for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else value.__class__.__name__ == predicate.value
            )
        case PredicateType.REGEX:
            return lambda x: (
                any(match(predicate.value, val) is not None for val in value)
                if isinstance(value := get_attr(x, predicate.field), Iterable)
                and not isinstance(value, str)
                else match(predicate.value, value) is not None
            )
        case _:
            raise TypeError("Not a valid predicate type!")


JacPredicateQuery = PredicateQuery[Callable[["Anchor"], bool]]
