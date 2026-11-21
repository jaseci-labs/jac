---
description: Enums, their members' names and values, int-typed and str-typed enums, looking a member up by value or name, iterating an enum, and methods written in an enum's body.
keywords: enum, enums, enum member, enumeration, typed enum, int enum, str enum, auto value
grammar: enum_decl, enum_member
---
# Enums

An `enum` is a type with a fixed set of named members. Each member has a
`name` and a `value`, is a single object for the whole program, and is
compared by identity.

## Syntax

```ebnf
enum_decl ::= decorators "enum" access_tag NAME (":" atomic_chain | "(" atomic_chain ("," atomic_chain)* ")")? ("{" (enum_member "," | module_code)* "}" | ";")

enum_member ::= NAME ("=" expression)?
```

- Every member is followed by a comma, the last one too. A member without
  one is E0002.
- A member's value is an int literal (a negative one too) or a str literal.
- `enum Status: int {` declares an int-typed enum and `enum Severity: str {`
  a str-typed one, each described below.
- An enum takes an [access tag](access.md) (`enum:pub Level {`) and
  [decorators](decorators.md).
- An enum is declared at module level.

## Members, names and values

```jac
enum Color {
    RED = 1,
    GREEN = 2,
    BLUE = 3,
}

enum Suit {
    HEARTS = "h",
    SPADES = "s",
}

enum Level {
    LOW = 5,
    MID,
    HIGH,
}

enum Step {
    FIRST,
    SECOND,
}

with entry {
    c = Color.GREEN;
    print(c, repr(c), c.name, c.value, f"{c}");
    print(Suit.HEARTS.value, Level.MID.value, Level.HIGH.value, Step.FIRST.value);
    print(c == Color.GREEN, c is Color.GREEN, c != Color.RED, type(c).__name__);
    paint = {Color.RED: "stop", Color.GREEN: "go"};
    print(paint[c], Color.BLUE in paint);
}
```

```output
Color.GREEN <Color.GREEN: 2> GREEN 2 Color.GREEN
h 6 7 1
True True True Color
go False
```

- **`E.NAME`** is the member. `m.name` is its name as a `str`, and `m.value`
  the value it was declared with.
- **A member with no value gets one more than the last int value before
  it**, and 1 when there is none: `FIRST` is 1, and `MID` after `LOW = 5`
  is 6.
- **`str(m)`, `print(m)` and `f"{m}"` give `Color.GREEN`**, and `repr(m)`
  gives `<Color.GREEN: 2>`.
- **Members are equal only to themselves.** `==` and `is` agree. A member
  is hashable, so it is a dict key or a set member.
- **The enum is a type**: `c: Color`, `def paint(c: Color) -> str`,
  `Color | None`. A value of another type is not a `Color` (E1001), and a
  member is not its value: `Color.RED == 1` and `Color.RED + 1` are errors
  (E1110). Read `.value` for the value.
- **Members cannot be assigned or added** when the program runs.

## Looking a member up, and iterating

```jac
enum Color {
    RED = 1,
    GREEN = 2,
    BLUE = 3,
}

def paint(c: Color) -> str {
    match c {
        case Color.RED:
            return "stop";
        case Color.GREEN:
            return "go";
        case _:
            return "calm";
    }
}

with entry {
    print(Color(2), Color["BLUE"], Color(3) is Color.BLUE);
    try {
        Color(9);
    } except ValueError as e {
        print("ValueError:", e);
    }
    try {
        Color["PINK"];
    } except KeyError as e {
        print("KeyError:", e);
    }
    print([c.name for c in Color], len(Color), Color.RED in Color);
    print(list(Color));
    print([paint(c) for c in Color]);
}
```

```output
Color.GREEN Color.BLUE True
ValueError: 9 is not a valid Color
KeyError: 'PINK'
['RED', 'GREEN', 'BLUE'] 3 True
[<Color.RED: 1>, <Color.GREEN: 2>, <Color.BLUE: 3>]
['stop', 'go', 'calm']
```

| Expression | Gives |
|---|---|
| `Color(v)` | The member whose value is `v`; `ValueError` when there is none |
| `Color["NAME"]` | The member named `NAME`; `KeyError` when there is none |
| `for c in Color`, `list(Color)` | The members, in declaration order |
| `len(Color)` | How many members |
| `m in Color` | Whether `m` is a member |
| `case Color.RED:` in `match` | Matches that member |

The members of an enum are also available at compile time, as
`members(Color)` from `jaclang.comptime`; see [Reflection](reflection.md).

## Int-typed enums

`enum Name: int` declares an enum whose members are ints as well as
members. A member is used where an `int` is: in arithmetic, and in
comparisons with ints and with each other.

```jac
enum Status: int {
    OK = 200,
    NOT_FOUND = 404,
}

def is_error(s: Status) -> bool {
    return s >= 400;
}

with entry {
    s = Status.NOT_FOUND;
    print(s.name, s.value, s == 404, s + 1, int(s), is_error(s));
    print(Status.OK < Status.NOT_FOUND, Status(200).name);
    print(s, f"{s}", repr(s));
}
```

```output
NOT_FOUND 404 True 405 404 True
True OK
404 404 <Status.NOT_FOUND: 404>
```

An int-typed member prints as its number (`str`, `print` and f-strings),
and `repr` still names it. Held as an `any` it is an `int` to `isinstance`,
and `json.dumps` writes it as its number.

## Str-typed enums

`enum Name: str` declares an enum whose members are strs as well as
members. A member is used where a `str` is: given to a `str` parameter or
variable, joined, compared and ordered with strs and with each other,
measured, indexed, sliced and iterated, and asked for a str's methods.
Every member is given a str literal for its value (E1001 otherwise).

```jac
enum Severity: str {
    LOW = "low",
    HIGH = "high",
}

def shouted(s: str) -> str {
    return s.upper();
}

with entry {
    s = Severity.HIGH;
    print(s, f"{s}!", repr(s), s.name, s.value);
    print(s == "high", s + "er", shouted(s), s.title(), len(s), s[0], "ig" in s);
    print(s is Severity("high"), Severity["LOW"] < s, max(Severity.LOW, s));
    held: any = s;
    print(held == "high", isinstance(held, str), repr(held));
}
```

```output
high high! <Severity.HIGH: 'high'> HIGH high
True higher HIGH High 4 h True
True False low
True True <Severity.HIGH: 'high'>
```

A str-typed member prints as its value (`str`, `print` and f-strings), and
`repr` still names it. It stays its enum's member wherever its type says so,
or an `any` or a union holds it: there `repr` names it, `is` tells it from another
member, and `json.dumps` writes it as its value. Where a `str` is declared
(`words: list[str] = [s]`) what is held is the str.

Members of two str-typed enums with one value are equal, as the strs they
are, and are never the same member.

`int` and `str` are the value types. A base list (`enum B(IntEnum)`) is
refused (E5090), so there are no flag enums.

## Methods

A function for an enum's members is written inside the enum, in a `with
entry` block after the members. It takes the member as an explicit first
parameter, `self`, typed as the enum, and is called on a member.

```jac
enum Level {
    LOW = 1,
    HIGH = 2,

    with entry {
        def weight(self: Level) -> int {
            return self.value * 10;
        }

        def next(self: Level) -> Level {
            return Level.HIGH if self == Level.LOW else Level.LOW;
        }

        def label(self: Level, prefix: str = "level") -> str {
            return f"{prefix} {self.name.lower()}";
        }
    }
}

with entry {
    l = Level.LOW;
    print(l.weight(), l.next(), l.next().next(), l.label(), Level.HIGH.label(prefix="is"));
}
```

```output
10 Level.HIGH Level.LOW level low is high
```

The block holds `def`s only. Any other statement in an enum's body is
refused (E5090).

## What is rejected

| Code | When |
|---|---|
| E0002 | A member without its comma |
| W3005 | Empty parentheses: `enum Color() {` |
| E0077 | Two members with one name |
| E1030 | `Color.PINK`, a member the enum does not have; assigning a member or its `value` |
| E1001 | A value that is not a member where the enum is wanted: `c: Color = 1`, and `s: Severity = "low"` for a str-typed one; a member of a str-typed enum whose value is not a str literal, or that has none |
| E1110 | A member of a plain enum compared or computed with an int, or ordered with `<` |
| E5090 | A value that is not an int or str literal (`X = 1 + 1`, `X = 1.5`); two members with the same value; a value type other than `int` and `str`; a base list; a statement other than a `def` in the body |

```jac
# expect: E0002
enum Color { RED, GREEN }
```

```jac
# expect: E5090 x4, E0077
enum Size {
    SMALL = 1 + 1,
    HALF = 0.5,
    LARGE = 4,
    HUGE = 4,
    LARGE = 5,
}

enum Name: float {
    A = 1,
}
```

```jac
# expect: E1001 x2
enum Mood: str {
    GLAD,
    SAD = 2,
}
```

```jac
# expect: E1030, E1001, E1110 x2
enum Color {
    RED,
    GREEN,
}

with entry {
    print(Color.PINK);
    c: Color = 1;
    print(Color.RED + 1, Color.RED < Color.GREEN);
}
```

## Differences from Python and from the reference design

- **In Python an enum is a class deriving from `Enum`, `IntEnum`, `StrEnum`
  or `Flag`; here it is the `enum` declaration**, `: int` is what `IntEnum`
  is and `: str` what `StrEnum` is. There are no flags.
- **In Python a `StrEnum` member needs no value (`auto()` gives its name in
  lower case); here every member of a str-typed enum is given its str.**
- **In Python a `StrEnum` member held in a `list[str]` is still the member;
  here a `str` slot holds the str it is**, as an `int` slot holds an
  int-typed member's int.
- **In Python two members with one value are aliases; here that is
  refused** (E5090).
- **In Python a member's value is any expression; here it is an int or str
  literal.**
- **In Python `Color.RED == 1` is `False`; here it is a compile-time
  error** for a plain enum, and `True` only for an int-typed one.
- **Auto values start at 1**, as Python's `auto()` does.
- **In the reference design the last member needs no comma; here every member has one.**
- **Methods live in a `with entry` block and write `self` out**, unlike an
  archetype's methods.

## See also

- [Archetypes](archetypes.md): types with fields.
- [Pattern matching](pattern-matching.md): `match` on members.
- [Reflection](reflection.md): `members(E)` and `kind(E)` at compile time.
