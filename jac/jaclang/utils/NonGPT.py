# flake8: noqa
from __future__ import annotations
import inspect
import random
import string
import sys
import types
from collections import deque
from dataclasses import is_dataclass, fields as dc_fields, MISSING
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from functools import wraps
from typing import (
    Any,
    Annotated,
    Literal,
    Union,
    get_args,
    get_origin,
    get_type_hints,
    TypeVar,
    NewType,
)
from collections.abc import Callable
from uuid import UUID, uuid4

# -------------------------------
# Core: random value generator
# -------------------------------

_RAND_STR_ALPH = string.ascii_letters + string.digits


def _rand_str(n: int = 12) -> str:
    return "".join(random.choice(_RAND_STR_ALPH) for _ in range(n))


def _is_typed_dict(tp: Any) -> bool:
    # TypedDict subclasses have these markers in CPython
    return (
        isinstance(tp, type)
        and hasattr(tp, "__annotations__")
        and hasattr(tp, "__required_keys__")
    )


def _is_namedtuple(tp: Any) -> bool:
    return (
        isinstance(tp, type)
        and issubclass(tp, tuple)
        and hasattr(tp, "_fields")
        and hasattr(tp, "__annotations__")
    )


def _is_enum(tp: Any) -> bool:
    try:
        import enum

        return isinstance(tp, type) and issubclass(tp, enum.Enum)
    except Exception:
        return False


def _safe_subclasses(tp: Any) -> list[type]:
    try:
        return list(tp.__subclasses__())  # pragma: no cover
    except Exception:
        return []


def _unwrap_annotated(tp: Any) -> Any:
    if get_origin(tp) is Annotated:
        return get_args(tp)[0]
    return tp


def _unwrap_newtype(tp: Any) -> Any:
    # NewType returns a function that has __supertype__ attr
    if hasattr(tp, "__supertype__"):
        return tp.__supertype__
    return tp


def _choose_from(seq):
    return random.choice(list(seq))


def _random_primitive(tp):
    if tp is int:
        return random.randint(-(10**6), 10**6)
    if tp is float:
        # Avoid NaN/inf to keep it JSON-safe & well-behaved
        return random.uniform(-(10**6), 10**6)
    if tp is bool:
        return bool(random.getrandbits(1))
    if tp is str:
        return _rand_str()
    if tp is bytes:
        return _rand_str().encode()
    if tp is complex:
        return complex(random.uniform(-100, 100), random.uniform(-100, 100))
    if tp is Decimal:
        return Decimal(str(random.uniform(-1000, 1000)))
    if tp is UUID:
        return uuid4()
    if tp is datetime:
        return datetime.fromtimestamp(random.randint(0, 2_000_000_000))
    if tp is date:
        return date.fromordinal(random.randint(700_000, 800_000))
    if tp is time:
        return (
            datetime.min + timedelta(seconds=random.randint(0, 24 * 3600 - 1))
        ).time()
    if tp is type(None):
        return None
    return None  # sentinel


def random_value_for_type(tp: Any, *, _depth: int = 0, _max_depth: int = 10) -> Any:
    """Generate a random value that (best-effort) conforms to the type 'tp'."""
    random.seed(42)  # for reproducibility in tests
    if _depth > _max_depth:
        # Depth cap to avoid infinite recursion on self-referential types
        origin = get_origin(tp)
        if origin in (list, set, frozenset, tuple, dict, deque):
            return origin() if origin is not tuple else tuple()
        prim = _random_primitive(_unwrap_newtype(_unwrap_annotated(tp)))
        if prim is not None:
            return prim
        return None

    tp = _unwrap_newtype(_unwrap_annotated(tp))

    # Any / object => pick a simple JSON-friendly value
    if tp in (Any, object):
        return random.choice(
            [_rand_str(), random.randint(0, 9999), True, None, random.uniform(0, 1)]
        )

    # Primitives and common stdlib scalars
    prim = _random_primitive(tp)
    if prim is not None:
        return prim

    # Literal
    if get_origin(tp) is Literal:
        choices = get_args(tp)
        return _choose_from(choices)

    # Union / Optional
    if get_origin(tp) is Union:
        options = list(get_args(tp))
        # Bias slightly away from None, if present
        if type(None) in options and len(options) > 1 and random.random() < 0.3:
            return None
        chosen = (
            _choose_from([t for t in options if t is not type(None)])
            if options
            else None
        )
        return random_value_for_type(chosen, _depth=_depth + 1, _max_depth=_max_depth)

    # Tuple (fixed-length or variadic)
    if get_origin(tp) is tuple:
        args = get_args(tp)
        if len(args) == 2 and args[1] is Ellipsis:
            # Tuple[T, ...]
            n = random.randint(0, 5)
            return tuple(
                random_value_for_type(args[0], _depth=_depth + 1, _max_depth=_max_depth)
                for _ in range(n)
            )
        else:
            return tuple(
                random_value_for_type(a, _depth=_depth + 1, _max_depth=_max_depth)
                for a in args
            )

    # List / Set / FrozenSet / Deque / Dict
    origin = get_origin(tp)
    if origin in (list, set, frozenset, deque):
        (elem_type,) = get_args(tp) or (Any,)
        size = random.randint(0, 5)
        elems = [
            random_value_for_type(elem_type, _depth=_depth + 1, _max_depth=_max_depth)
            for _ in range(size)
        ]
        if origin is list:
            return elems
        if origin is set:
            # Attempt to hash; fallback to str
            try:
                return set(elems)
            except TypeError:
                return {str(e) for e in elems}
        if origin is frozenset:
            try:
                return frozenset(elems)
            except TypeError:
                return frozenset(str(e) for e in elems)
        if origin is deque:
            return deque(elems)

    if origin is dict:
        key_t, val_t = (get_args(tp) + (Any, Any))[:2]

        # Try to keep keys hashable and simple
        def mk_key():
            k = random_value_for_type(key_t, _depth=_depth + 1, _max_depth=_max_depth)
            try:
                hash(k)
                return k
            except TypeError:
                return str(k)

        size = random.randint(0, 5)
        return {
            mk_key(): random_value_for_type(
                val_t, _depth=_depth + 1, _max_depth=_max_depth
            )
            for _ in range(size)
        }

    # TypedDict
    if _is_typed_dict(tp):
        # Required and optional keys are tracked by __required_keys__/__optional_keys__
        req: set[str] = getattr(tp, "__required_keys__", set())
        opt: set[str] = getattr(tp, "__optional_keys__", set())
        anns = tp.__annotations__
        out = {}
        # required
        for k in req:
            out[k] = random_value_for_type(
                anns[k], _depth=_depth + 1, _max_depth=_max_depth
            )
        # some optional
        for k in opt:
            if random.random() < 0.6:
                out[k] = random_value_for_type(
                    anns[k], _depth=_depth + 1, _max_depth=_max_depth
                )
        return out

    # NamedTuple
    if _is_namedtuple(tp):
        anns = get_type_hints(tp, include_extras=True)
        values = [
            random_value_for_type(anns[name], _depth=_depth + 1, _max_depth=_max_depth)
            for name in tp._fields
        ]
        return tp(*values)

    # Enum
    if _is_enum(tp):
        return _choose_from(list(tp))

    # Dataclass
    if is_dataclass(tp):
        # Resolve string annotations to actual types
        try:
            type_hints = get_type_hints(tp, include_extras=True)
        except Exception:
            type_hints = {}

        kwargs = {}
        for f in dc_fields(tp):
            if f.init:
                if f.default is not MISSING or f.default_factory is not MISSING:
                    # let default/default_factory handle it sometimes
                    if random.random() < 0.35:
                        continue
                # Use resolved type hints if available, otherwise use the field type
                field_type = type_hints.get(f.name, f.type)
                kwargs[f.name] = random_value_for_type(
                    field_type, _depth=_depth + 1, _max_depth=_max_depth
                )
        try:
            assert isinstance(tp, type)  # tp is a dataclass type, not instance
            return tp(**kwargs)
        except TypeError:
            # Fall back to constructing with defaults only
            assert isinstance(tp, type)
            return tp(**{k: v for k, v in kwargs.items() if v is not MISSING})

    # Annotated already unwrapped; NewType already unwrapped

    # TypeVar: use bound or one of constraints, else Any
    if isinstance(tp, TypeVar):
        if tp.__constraints__:
            chosen = _choose_from(tp.__constraints__)
            return random_value_for_type(
                chosen, _depth=_depth + 1, _max_depth=_max_depth
            )
        if tp.__bound__:
            return random_value_for_type(
                tp.__bound__, _depth=_depth + 1, _max_depth=_max_depth
            )
        return random_value_for_type(Any, _depth=_depth + 1, _max_depth=_max_depth)

    # Callable[...] -> synthesize a dummy callable with compatible signature if possible
    if get_origin(tp) is Callable:
        # Return a lambda that returns a random value for the annotated return type (or Any)
        args = get_args(tp)
        ret_t = Any
        if args:
            # args is (arg_types, ret_type)
            if len(args) == 2:
                ret_t = args[1]

        def _fn_stub(*_a, **_k):
            return random_value_for_type(
                ret_t, _depth=_depth + 1, _max_depth=_max_depth
            )

        return _fn_stub

    # Plain classes:
    # 1) If it’s a built-in container alias (like typing.List without params), treat as Any
    if tp in (list, set, frozenset, tuple, dict, deque):
        return random_value_for_type(Any, _depth=_depth + 1, _max_depth=_max_depth)

    # 2) Try to instantiate using __init__ annotations.
    if isinstance(tp, type):
        try:
            sig = inspect.signature(tp)
            kwargs = {}
            for name, param in sig.parameters.items():
                if name == "self":
                    continue
                ann = (
                    param.annotation if param.annotation is not inspect._empty else Any
                )
                if param.default is not inspect._empty and random.random() < 0.4:
                    # sometimes rely on defaults
                    continue
                # if VAR_POSITIONAL/VAR_KEYWORD, skip
                if param.kind in (param.VAR_POSITIONAL, param.VAR_KEYWORD):
                    continue
                kwargs[name] = random_value_for_type(
                    ann, _depth=_depth + 1, _max_depth=_max_depth
                )
            return tp(**kwargs)
        except Exception:
            try:
                return tp()
            except Exception:
                # Last resort: create a simple object with random attrs
                obj = types.SimpleNamespace()
                return obj

    # Fallback
    return None


# -------------------------------
# Decorator
# -------------------------------


def returns_fake(func: Any):
    """Decorator that returns a random instance of the function's return type."""
    # Resolve forward refs and Annotated, NewType, etc.
    try:
        type_hints = get_type_hints(
            func, globalns=func.__globals__, localns=None, include_extras=True
        )
    except Exception:
        type_hints = getattr(func, "__annotations__", {})
    ret_t = type_hints.get("return", Any)

    @wraps(func)
    def wrapper(*args, **kwargs):
        return random_value_for_type(ret_t)

    return wrapper
