"""Indexed scope lookup preserves definition identity and local-slot order."""
import from builtins { compile as pycompile, exec as pyexec }

# Exercise the shipped Python compiler boundary, as do the local-slot tests.
def check_scope_source(source: str, expected: any) {
    actual: dict[str, any] = {};
    pyexec(pycompile(source, "scope_indices.py", "exec", dont_inherit=True), actual);
    assert actual["result"] == expected , str(actual["result"]);
}

test "scope indices distinguish names locations annotations and generic scopes" {
    check_scope_source(
        """
def same(value):
    return value + 1
first = same
def same(value: int) -> str:
    return str(value + 2)
class Same:
    def identity(self):
        return __class__.tag
    tag = 7
First = Same
class Same:
    tag = 11
    def identity(self):
        return __class__.tag
left, right = (lambda: 17), (lambda: 19)
def generic[T: int = int](value: T) -> T:
    return value
T = generic.__type_params__[0]
result = (first(3), same(3), same.__annotations__, First().identity(),
          Same().identity(), left(), right(), generic(23), T.__name__,
          T.__bound__.__name__, T.__default__.__name__,
          generic.__annotations__['value'] is T,
          generic.__annotations__['return'] is T)
""",
        (
            4,
            "5",
            {"value": int, "return": str},
            7,
            11,
            17,
            19,
            23,
            "T",
            "int",
            "int",
            True,
            True
        )
    );
}

test "inlined comprehension storage preserves captures and shadowed locals" {
    check_scope_source(
        """
def factory(argument):
    x = 100
    callbacks = [lambda: x for x in range(3)]
    nested = [[(x, y) for y in range(x)] for x in range(4)]
    generators = [(x + y for y in range(2)) for x in range(3)]
    mappings = {x: x + argument for x in range(3)}
    values = {x + argument for x in range(3)}
    return x, [f() for f in callbacks], nested, [list(g) for g in generators], mappings, sorted(values)
result = factory(7)
""",
        (
            100,
            [2, 2, 2],
            [[], [(1, 0)], [(2, 0), (2, 1)], [(3, 0), (3, 1), (3, 2)]],
            [[2, 3], [2, 3], [2, 3]],
            {0: 7, 1: 8, 2: 9},
            [7, 8, 9]
        )
    );
}

test "many locals retain parameter and closure ordering" {
    lines = ["def factory(second, first, *args, keyword=3, **kwargs):"];
    for index in range(500) {
        lines.append(f"    local_{index} = first + second + {index}");
    }
    lines.extend(
        [
            "    return lambda: (first, second, local_499, local_0, args, keyword, kwargs)",
            "result = factory(2, 1, 4, keyword=5, extra=6)()"
        ]
    );
    check_scope_source("\n".join(lines) + "\n", (1, 2, 502, 3, (4, ), 5, {"extra": 6}));
}
