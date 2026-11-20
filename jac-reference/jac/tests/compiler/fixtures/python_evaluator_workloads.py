"""Python execution workloads shared by evaluator correctness and timing checks.

The benchmark compiles this file once with the pinned reference interpreter
and sends the same marshalled code to both runtimes. Keep Python source here:
these are tests of Python bytecode execution, not Jac's source compiler.
"""

from collections.abc import Callable, Generator


def arithmetic() -> int:
    value = 0
    for i in range(256):
        value = ((value + i) * 3) & 65535
    return value


def calls() -> int:
    def add(a: int, b: int = 2, *, scale: int = 3) -> int:
        return (a + b) * scale

    value = 0
    for i in range(64):
        value += add(i) + add(i, scale=4) + add(*(i, 3), **{"scale": 2})
    return value


class Counter:
    __slots__ = ("value",)

    def __init__(self, value: int) -> None:
        self.value = value

    def increment(self) -> int:
        self.value += 1
        return self.value


def attributes() -> int:
    counter = Counter(0)
    total = 0
    for _ in range(128):
        total += counter.increment() + counter.value
    return total


def containers() -> int:
    values = {i: i * 2 for i in range(64)}
    items = [values[i] for i in range(64) if i % 2 == 0]
    total = 0
    for i, item in enumerate(items):
        values[i] = item + 1
        total += values[i]
    return total + len({*items})


def closures() -> int:
    value = 0

    def increment(step: int) -> int:
        nonlocal value
        value += step
        return value

    total = 0
    for i in range(128):
        total += increment(i)
    return total


def generators() -> int:
    def child() -> Generator[int, int | None, int]:
        total = 0
        for i in range(32):
            sent = yield i
            total += sent if sent is not None else 0
        return total

    def parent() -> Generator[int, int | None, None]:
        result = yield from child()
        yield result

    stream = parent()
    result = next(stream)
    for i in range(32):
        result += stream.send(i)
    try:
        next(stream)
    except StopIteration:
        return result
    raise AssertionError("generator did not terminate")


def exceptions() -> int:
    total = 0
    for i in range(64):
        try:
            try:
                if i % 2:
                    raise ValueError(i)
                total += i
            except ValueError as error:
                raise RuntimeError(i) from error
        except RuntimeError as error:
            assert isinstance(error.__cause__, ValueError)
            total -= error.args[0]
        finally:
            total += 1
    return total


def exception_groups() -> int:
    total = 0
    try:
        raise ExceptionGroup("group", [ValueError(2), TypeError(3)])
    except* ValueError as group:
        total += group.exceptions[0].args[0]
    except* TypeError as group:
        total += group.exceptions[0].args[0]
    return total


def context_managers() -> int:
    events: list[int] = []

    class Scope:
        def __enter__(self) -> int:
            events.append(1)
            return 2

        def __exit__(self, kind: object, value: object, traceback: object) -> bool:
            events.append(3)
            return kind is ValueError

    for _ in range(16):
        with Scope() as value:
            events.append(value)
            raise ValueError("suppressed")
    return sum(events)


def patterns() -> int:
    total = 0
    for i in range(32):
        match {"value": (i, i + 1), "other": 2}:
            case {"value": (a, b), **rest} if a < b:
                total += a + b + rest["other"]
            case _:
                raise AssertionError("mapping pattern failed")
        match Counter(i):
            case Counter(value=value):
                total += value
    return total


def reentrant_cleanup() -> int:
    events: list[int] = []
    values: list[object] = []

    class Value:
        def __init__(self, value: int) -> None:
            self.value = value

        def __del__(self) -> None:
            # Finalization calls back into Python and mutates the container
            # whose replacement is releasing this reference.
            values.append(self.value)
            events.append(self.value)

    for i in range(32):
        values.append(Value(i))
        values[-1] = None
        assert values[-1] == i
        values.clear()
    return sum(events)


def coroutines() -> int:
    class Once:
        def __await__(self) -> Generator[int, int, int]:
            received = yield 3
            return received + 1

    async def child() -> int:
        return await Once()

    async def parent() -> int:
        return (await child()) * 2

    coroutine = parent()
    assert coroutine.send(None) == 3
    try:
        coroutine.send(7)
    except StopIteration as result:
        return result.value
    finally:
        coroutine.close()
    raise AssertionError("coroutine did not terminate")


WORKLOADS: dict[str, tuple[Callable[[], int], int]] = {
    "arithmetic": (arithmetic, 46464),
    "calls": (calls, 19424),
    "attributes": (attributes, 16512),
    "containers": (containers, 2048),
    "closures": (closures, 349504),
    "generators": (generators, 992),
    "exceptions": (exceptions, 32),
    "exception_groups": (exception_groups, 5),
    "context_managers": (context_managers, 96),
    "patterns": (patterns, 1584),
    "reentrant_cleanup": (reentrant_cleanup, 496),
    "coroutines": (coroutines, 16),
}


def python_contract_record() -> type:
    """A Python-owned record for the Jac contract adapter's compatibility test."""
    from dataclasses import field, make_dataclass

    return make_dataclass(
        "PythonContractRecord",
        [("name", str), ("items", list[int], field(default_factory=list))],
    )
