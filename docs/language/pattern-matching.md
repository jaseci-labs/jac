---
description: The match statement and every kind of pattern: literals, captures and _, dotted values, or-patterns and as, sequence, mapping and class patterns, and guards.
keywords: match, case, pattern, pattern matching, wildcard, capture pattern, class pattern, sequence pattern, mapping pattern, or-pattern, guard
grammar: match_stmt, match_case, pattern, or_pattern, single_pattern, list_pattern, tuple_pattern, mapping_pattern, literal_pattern, name_pattern, seq_item, mapping_entry, mapping_key, class_pattern, class_pattern_arg
---
# Pattern matching

`match` compares a value, the subject, with a list of patterns, and runs the statements of the
first case whose pattern fits. A pattern can test the value's type, shape and contents and bind
parts of it to names in one step.

## Syntax

```ebnf
match_stmt ::= "match" expression "{" match_case* "}"

match_case ::= "case" pattern ("if" expression)? ":" stmt*

pattern ::= or_pattern ("as" NAME)?

or_pattern ::= single_pattern ("|" single_pattern)*

single_pattern ::=
    list_pattern
    | tuple_pattern
    | mapping_pattern
    | atom
    | literal_pattern
    | name_pattern
    | expression

list_pattern ::= "[" (seq_item ("," seq_item)* ","?)? "]"

tuple_pattern ::= "(" seq_item ")"

seq_item ::= "*" NAME | pattern

mapping_pattern ::= "{" (mapping_entry ("," mapping_entry)* ","?)? "}"

mapping_entry ::= "**" NAME | mapping_key ":" pattern

mapping_key ::= signed_number | multistring

literal_pattern ::= signed_number | multistring | expression

name_pattern ::= (NAME ("." any_word)* | KEYWORD) class_pattern?

class_pattern ::= "(" (class_pattern_arg ("," class_pattern_arg)* ","?)? ")"

class_pattern_arg ::= pattern | (NAME | KEYWORD) "=" pattern
```

## What `match` does

1. The subject is evaluated once.
2. The cases are tried in order. A case matches when its pattern fits the subject and its guard,
   if it has one, is true. The guard is evaluated after the pattern has bound its names, so it can
   use them.
3. The statements of the first matching case run, and the `match` is done: there is no
   fallthrough. When no case matches, nothing runs and no error is raised.

A case's statements follow its `:` up to the next `case` or the closing brace; they are not a
block. The names a pattern binds are locals of the enclosing function and stay bound after the
`match`. Like every local, a name has one type: capturing `v` as a `bytes` in one case and as a
`bool` in another is an error (E1452), so give the two captures different names.

```jac
with entry {
    for n in [1, 15, 150] {
        match n {
            case 1:
                print("one");
            case x if x < 100:
                label = "medium";
                print(label, x);
            case _:
                print("large");
        }
    }
}
```

```output
one
medium 15
large
```

## The patterns

| Pattern | Example | Matches |
|---|---|---|
| Literal | `0`, `-1`, `2.5`, `"hi"` | A value equal (`==`) to it |
| Singleton | `None`, `True`, `False` | That very value (`is`) |
| Capture | `n` | Anything, and binds it to `n` |
| Wildcard | `_` | Anything, and binds nothing |
| Value | `Color.RED`, `math.pi` | A value equal to the one the dotted name holds |
| Or | `1 \| 2 \| 3`, `[a] \| [a, 0]` | A value one of the alternatives matches, tried left to right; the names the one that matched captures are bound |
| As | `[_, _] as pair` | What the pattern before `as` matches, binding the whole value to `pair` |
| Sequence | `[]`, `[a, b]`, `[first, *rest]` | A list or tuple of that length, item by item |
| Mapping | `{"k": v, **rest}` | A dict that has those keys, each value matching |
| Class | `Point(x=0, y=y)`, `int(n)` | An instance of the class whose fields match |

Patterns nest: `[Pt(x=0) as p, *_]` matches a list whose first item is a point on the y axis, and
binds that point to `p`.

```jac
obj Pt {
    has x: int,
        y: int;
}

def classify(v: any) -> str {
    match v {
        case None:
            return "none";
        case True:
            return "true";
        case 0:
            return "zero";
        case -1:
            return "minus one";
        case 1 | 2 | 3:
            return "small";
        case int(n) if n < 0:
            return f"negative {n}";
        case "hi" as h:
            return f"greeting {h}";
        case str(s):
            return f"text {s}";
        case []:
            return "empty list";
        case [a] | [a, 0]:
            return f"one {a}";
        case [a, b, *rest]:
            return f"head {a} {b} rest {rest}";
        case {"k": k, **others}:
            return f"map k={k} others={others}";
        case Pt(x=0, y=y):
            return f"on the y axis at {y}";
        case Pt(x=x, y=y) if x == y:
            return f"diagonal {x}";
        case Pt():
            return "point";
        case _:
            return "other";
    }
}

with entry {
    vals: list[any] = [
        None,
        True,
        0,
        -1,
        2,
        -5,
        "hi",
        "yo",
        [],
        [9],
        [9, 0],
        [1, 2, 3, 4],
        {"k": 1, "j": 2},
        Pt(x=0, y=4),
        Pt(x=3, y=3),
        Pt(x=1, y=2),
        99,
    ];
    for v in vals {
        print(repr(v), "->", classify(v));
    }
}
```

```output
None -> none
True -> true
0 -> zero
-1 -> minus one
2 -> small
-5 -> negative -5
'hi' -> greeting hi
'yo' -> text yo
[] -> empty list
[9] -> one 9
[9, 0] -> one 9
[1, 2, 3, 4] -> head 1 2 rest [3, 4]
{'k': 1, 'j': 2} -> map k=1 others={'j': 2}
Pt(x=0, y=4) -> on the y axis at 4
Pt(x=3, y=3) -> diagonal 3
Pt(x=1, y=2) -> point
99 -> other
```

### Literal and value patterns

A number (with an optional `-`) or a string matches a value equal to it, as `==` decides: `case 1`
matches `1`, `1.0` and `True`. `None`, `True` and `False` match only themselves: `case True` does
not match `1`. Adjacent string literals form one string, as anywhere.

A dotted name, such as an enum member or a module's constant, is a value pattern: it compares the
subject with the value the name holds. A bare name is never a value pattern; it is a capture. To
compare with a local, use a guard: `case x if x == limit`.

Against a typed subject, a literal must be comparable with it: `case "a"` on an `int` subject is an
error (E1110).

```jac
import math;

enum Color {
    RED,
    GREEN,
}

def name(c: Color) -> str {
    match c {
        case Color.RED:
            return "red";
        case Color.GREEN:
            return "green";
    }
    return "?";
}

def which(x: float) -> str {
    match x {
        case math.pi:
            return "pi";
        case _:
            return "not pi";
    }
}

with entry {
    print(name(Color.GREEN), which(3.141592653589793), which(1.0));
}
```

```output
green pi not pi
```

### Sequence patterns

`[p1, p2, ...]` matches a list or a tuple with exactly that many items, each matching its pattern.
One item may be `*name`, which takes the items the others leave, as a list, so the sequence may be
longer: `[first, *middle, last]`. `*_` takes them without binding. A string is not a sequence for a
pattern.

A sequence pattern is written in brackets; `case (a, b):` is an error (E0155), and so are `case ():`
and `case (*a):`. A pattern has at most one starred name (E0154).

Parentheses around one pattern only group it, as in Python and as they group an expression:
`case (a):` matches what `case a:` matches and is no sequence of one item, `case (1 | 2):` is
`case 1 | 2:`, and `[(1 | 2), x]` is a sequence whose first item is 1 or 2. They are needed where
an `as` is one alternative of an `|`: `case (3 as n) | 4:`.

```jac
def shape(v: any) -> str {
    match v {
        case [(0 | 1), b]:
            return f"bit then {b}";
        case [a, b]:
            return f"pair {a} {b}";
        case [first, *middle, last]:
            return f"{first} {middle} {last}";
        case (7 | 8):
            return "seven or eight";
        case _:
            return "not a sequence of two or more";
    }
}

with entry {
    print(shape((1, 2)), shape([1, 2, 3, 4]), shape("ab"), shape([1]));
    print(shape([2, 3]), shape(7), shape([7]));
}
```

```output
bit then 2 1 [2, 3] 4 not a sequence of two or more not a sequence of two or more
pair 2 3 seven or eight not a sequence of two or more
```

### Mapping patterns

`{key: pattern, ...}` matches a dict that has every key listed, each value matching its pattern.
Other keys are allowed. `**rest` binds a dict of the keys not listed. A key is a number or a string
literal (E0045).

```jac
def describe(event: dict[str, any]) -> str {
    match event {
        case {"type": "click", "pos": [x, y]}:
            return f"click at {x},{y}";
        case {"type": "key", "key": str(k), **more}:
            return f"key {k}, {len(more)} more";
        case _:
            return "unknown";
    }
}

with entry {
    print(describe({"type": "click", "pos": [3, 4]}));
    print(describe({"type": "key", "key": "q", "shift": True}));
    print(describe({"type": "scroll"}));
}
```

```output
click at 3,4
key q, 1 more
unknown
```

### Class patterns

`Cls(...)` matches an instance of `Cls` or of a subclass of it.

- `Cls()` tests the class alone.
- `Cls(field=pattern)` also matches the field's value against the pattern. Any word names the field,
  reserved or not: `case Record(type="x")`.
- `Cls(p1, p2)` matches the fields by position, in the order the class declares them. More
  positional patterns than fields is an error (E1204).
- For `int`, `float`, `str`, `bool` and `bytes`, one positional pattern matches the value itself:
  `case int(n)` binds an `int` subject to `n`.
- A container type has no class pattern (`case list(xs)` is E1036): match its shape with a sequence
  or mapping pattern.

**A class pattern narrows the subject.** In the case's guard and statements, the subject has the
matched class's type, so the subclass's fields can be read through it. `as` binds the narrowed
value under a name of its own.

```jac
obj Animal {
    has name: str;
}

obj Dog(Animal) {
    has tricks: int = 0;
}

obj Cat(Animal) {
    has lives: int = 9;
}

def about(a: Animal) -> str {
    match a {
        case Dog() if a.tricks > 0:
            return f"{a.name} knows {a.tricks}";
        case Cat() as c:
            return f"{c.name} has {c.lives}";
        case Dog(name, 0):
            return f"{name} knows nothing";
    }
    return a.name;
}

with entry {
    print(about(Dog(name="rex", tricks=3)), about(Cat(name="tom")), about(Dog(name="pup")));
}
```

```output
rex knows 3 tom has 9 pup knows nothing
```

## What is rejected

| Code | Condition |
|---|---|
| E0155 | A sequence pattern in parentheses: `case (a, b):`, `case ():`, `case (*a):` |
| E0154 | Two starred names in one sequence pattern |
| E0045 | A mapping pattern key that is not a number or a string |
| E1204 | More positional patterns than the class has fields |
| E1205 | A class pattern whose name is not a class: a function, a variable, an enum |
| E1036 | A class pattern of a container type: `case list(xs)` |
| E1110 | A literal that cannot equal a value of the subject's type |
| E1452 | One name captured as two different types in different cases |
| E0001 | An expression that is not a pattern, such as `case 1 + 1:` |

```jac
# expect: E0155 x2, E0154, E0045
with entry {
    match [1, 2] {
        case (a, b):
            print(a);
        case (*rest):
            print(rest);
        case [*a, *b]:
            print(a);
        case {k: 1}:
            print(k);
    }
}
```

```jac
# expect: E1204, E1110, E1205
obj Pt {
    has x: int,
        y: int;
}

def origin -> Pt {
    return Pt(x=0, y=0);
}

def test_point(p: Pt, n: int) {
    match p {
        case Pt(1, 2, 3):
            print("three");
        case origin():
            print("origin");
    }
    match n {
        case "a":
            print("a");
    }
}
```

## Differences from Python

- A sequence pattern is written in brackets only.
- A class pattern's positional arguments follow the class's field order; there is no
  `__match_args__`.
- `case list(xs)` and the other container class patterns are not available.
- A literal that can never equal the subject is a compile error.
- `switch` is the form with C's fallthrough; see [Control flow](control-flow.md#switch).
