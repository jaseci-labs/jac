"""Fixture: `auto()`, the enum member value no fold used to reach.

`Cat` is `types.jac`'s `ParameterCategory` shape exactly -- a
`class X(IntEnum)` whose every member is `auto()`. Reading one off the class
is what `get_type_of_ability` does, and it is the read that stranded a fifth
of the evaluator.

`Mixed` pins the rule that generates the values rather than just their being
generated. CPython counts from the largest value already assigned, not the
last one written, so a member declared after `10` and then `3` is `11` and
not `4`. `Step` asks the same question in the declared-enum spelling, where
an explicit value follows the generated ones.
"""

import from enum { IntEnum, auto }


class Cat(IntEnum) {
    with entry {
        Positional = auto();
        ArgsList = auto();
        KwargsDict = auto();
    }
}


class Mixed(IntEnum) {
    with entry {
        High = 10;
        Low = 3;
        Next = auto();
        After = auto();
    }
}


enum Step { First = auto(), Second = auto(), Third = 9 }


def category(n: int) -> int {
    if n == 0 {
        return int(Cat.Positional);
    }
    if n == 1 {
        return int(Cat.ArgsList);
    }
    return int(Cat.KwargsDict);
}


def counted -> int {
    return (int(Mixed.Next) * 100) + int(Mixed.After);
}


def stepped -> int {
    return (int(Step.First) * 100) + (int(Step.Second) * 10) + int(Step.Third);
}


def run -> int {
    print(category(0));
    print(category(1));
    print(category(2));
    print(int(Mixed.High));
    print(int(Mixed.Low));
    print(counted());
    print(stepped());
    return 0;
}


with entry {
    run();
}
