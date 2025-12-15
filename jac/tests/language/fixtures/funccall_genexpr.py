from collections.abc import Iterable


def total(values: Iterable[int]) -> int:
    return sum(values)


result = total((x * x) for x in range(5))
print(result)
