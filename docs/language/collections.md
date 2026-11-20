---
description: Lists, tuples, dicts and sets: their literals (displays), indexing and slices, comprehensions and generator expressions, and unpacking with * and **.
keywords: list, tuple, dict, set, frozenset, collection, display, comprehension, list comprehension, dict comprehension, generator expression, slice, slicing, index, indexing, subscript, unpacking, star
grammar: paren_expr, bracket_expr, brace_expr, list_or_compr, dict_entry, tuple_item, index_slice, slice_from, compr_clauses, compr_clause, unpack
---
# Collections

The four builtin collections are `list`, `tuple`, `dict` and `set`. Each has a literal form, called
a display, and a comprehension form that builds one from a loop.

| Type | Display | Empty | Changeable | Items |
|---|---|---|---|---|
| `list[T]` | `[1, 2, 3]` | `[]` | Yes | Ordered, by position |
| `tuple[A, B]` | `(1, "a")`, `(1,)` | `()` | No | Ordered, fixed shape |
| `dict[K, V]` | `{"a": 1}` | `{}` | Yes | Key to value, in insertion order |
| `set[T]` | `{1, 2}` | `set()` | Yes | Unique, hashable |

A collection has one element type (or, for a tuple, one type per position), known at compile time.
A display whose items have different types has elements of type `any`. An empty `{}` has no
element types of its own and takes them from an annotation: `d: dict[str, int] = {};` (W1051
without one). See [Types](types.md).

## Lists

```ebnf
bracket_expr ::= "[" (filter_body | edge_ref_chain | list_or_compr)

list_or_compr ::=
    "]"
    | expression (compr_clauses "]" | edge_chain_tail | ("," expression)* ","? "]")
```

A list display evaluates its items left to right and makes a new list, each time it is evaluated:
a function returning `[1, 2, 3]` gives a fresh list at every call, whatever a caller did to the
last one. A global list (`glob table: list[int] = [5, 6, 7];`) is one list, changed in place by
every function that changes it. A trailing comma is allowed. A display of mixed items keeps each
item's own value: `[1.5, -2.0, True]` holds the bool `True`, not `1.0`.

- Storing past the end raises `IndexError: list assignment index out of range`; `append` grows a
  list.
- Lists and tuples compare item by item: the first pair of items that are neither the same object
  nor equal decides the order, and when one runs out first it is the smaller. Two items that are
  neither equal nor ordered (two objects of a class whose `__eq__` is identity, of one height)
  make `(a, 1) < (b, 2)` `False`, while `(a, 1) < (a, 2)` is `True`. A number is not an object,
  and a NaN equals nothing, itself included: two lists of a NaN are neither equal nor ordered.
(The other bracket forms, filters and edge references, belong to the object-spatial part of the
language: `jac docs object-spatial`.)

```jac
with entry {
    xs = [3, 1, 2];
    xs.append(4);
    xs.insert(0, 9);
    xs.extend([5, 6]);
    print(xs, len(xs), xs[0], xs[-1], 3 in xs, xs.index(1));
    print(xs.pop(), xs.pop(0), xs);
    xs.sort();
    xs.reverse();
    xs.remove(1);
    xs[0] = 100;
    print(xs, xs + [0], [0] * 3, sorted(xs), sum(xs), min(xs), max(xs));

    alias = xs;
    copy = xs.copy();
    xs.clear();
    print(alias, copy, [1, 2] == [1, 2], [1, 2] < [1, 3]);
    nan = float("nan");
    print([nan] == [nan], [nan] <= [nan], [nan] >= [nan], [1.0, nan] < [2.0, nan]);
}
```

```output
[9, 3, 1, 2, 4, 5, 6] 7 9 6 True 2
6 9 [3, 1, 2, 4, 5]
[100, 4, 3, 2] [100, 4, 3, 2, 0] [0, 0, 0] [2, 3, 4, 100] 109 2 100
[] [100, 4, 3, 2] True True
False False False True
```

## Tuples

```ebnf
paren_expr ::= "(" (")" | yield_expr ")" | ability ")" | tuple_item (compr_clauses ")" | ("," tuple_item)* ","? ")" | ")"))

tuple_item ::= "**" expression | expression
```

| Written | Is |
|---|---|
| `()` | The empty tuple |
| `(e)` | The expression `e`, grouped. Not a tuple. |
| `(e,)` | A tuple of one item |
| `(a, b)` | A tuple of two items |
| `(e for x in xs)` | A generator expression (below) |
| `(yield e)` | A `yield` used as a value; see [Generators](generators.md) |

**A tuple is always written with its parentheses.** `a, b` without them is not a tuple: `x = 1, 2;`
and `return a, b;` are syntax errors. Write `x = (1, 2);` and `return (a, b);`.

A tuple cannot be changed (E1191 for an item assignment, E1030 for `append`). Its type lists the
type of each position, `tuple[int, str]`, or one type for any length, `tuple[int, ...]`. An index
that is a constant is checked against the shape at compile time (E1174).

```jac
with entry {
    t = (1, "a", 2.5);
    one = (1,);
    grouped = (5);
    print(t, t[0], t[-1], t[1:], len(t), one, grouped + 1);
    print(t + (4,), (1, 2) * 2, (1, 2) < (1, 3), "a" in t);
    (a, b, c) = t;
    print(a, b, c, tuple([1, 2]));
    for (x, y) in ((1, 2), (3, 4)) {
        print(x + y);
    }
}
```

```output
(1, 'a', 2.5) 1 2.5 ('a', 2.5) 3 (1,) 6
(1, 'a', 2.5, 4) (1, 2, 1, 2) True True
1 a 2.5 (1, 2)
3
7
```

```jac
# expect: E1191, E1030, E1174
with entry {
    t = (1, 2);
    t[0] = 3;
    t.append(4);
    print(t[2]);
}
```

## Dicts and sets

```ebnf
brace_expr ::= "{" ("}" | dict_entry ("," dict_entry)* ","? "}" | expression (":" expression (compr_clauses | ("," dict_entry)* ","?) | compr_clauses | ("," expression)* ","?) "}")

dict_entry ::= ("**" | expression ":") expression
```

Braces with `key: value` entries make a dict; braces with plain items make a set. `{}` is the empty
dict; the empty set is `set()`.

- A dict keeps its entries in the order their keys were first inserted. Assigning an existing key
  replaces its value in place; a key deleted and inserted again goes to the end. `popitem()` takes
  the last entry.
- A dict changed while a `for` loop (or an iterator from `iter(d)`) walks it, or walks its
  `keys()`, `values()` or `items()`: a change of size
  raises `RuntimeError: dictionary changed size during iteration` at the next step. Deleting one
  key and adding another in the same step raises `RuntimeError: dictionary keys changed during
  iteration`, unless the deleted key was the dict's last, when the loop walks on and reaches the
  new key (`{1: 1, 2: 2, 3: 3}`, deleting `3` and adding `9` at `1`, visits 1, 2, 9). A change
  followed by `break` raises nothing. (CPython and a JavaScript host walk on in every same-size
  case.) A set that changes size under a loop over it raises `RuntimeError: Set changed size during
  iteration`.
- Keys and set items must be hashable: numbers, strings, bytes, tuples of hashable values,
  enum members, and objects whose class defines `__hash__`. A list is not (a `TypeError` when the
  display runs); an `obj` without `__hash__` is refused at compile time (E1180).
- `d[k]` raises `KeyError` when `k` is absent; `d.get(k)` gives `None`, and `d.get(k, default)` the
  default.
- A set display drops duplicates. Do not rely on the order in which a set's items are iterated.
- `frozenset` is a set that cannot be changed. It is not a `set`: `isinstance(fs, set)` is
  `False`.
- `s.pop()` of an empty set raises `KeyError: 'pop from an empty set'`.

```jac
with entry {
    d = {"a": 1, "b": 2};
    d["c"] = 3;
    d["a"] += 10;
    print(d, len(d), d["a"], d.get("z"), d.get("z", 0), "a" in d);
    print(list(d), list(d.values()), list(d.items()));
    for (k, v) in d.items() {
        print(k, v, end="; ");
    }
    print();
    print(d.pop("a"), d.pop("zz", -1), d.setdefault("q", 7), d);
    d.update({"b": 20});
    del d["q"];
    print(d, d == {"c": 3, "b": 20});
    try {
        print(d["nope"]);
    } except KeyError as e {
        print("KeyError:", e);
    }
}
```

```output
{'a': 11, 'b': 2, 'c': 3} 3 11 None 0 True
['a', 'b', 'c'] [11, 2, 3] [('a', 11), ('b', 2), ('c', 3)]
a 11; b 2; c 3; 
11 -1 7 {'b': 2, 'c': 3, 'q': 7}
{'b': 20, 'c': 3} True
KeyError: 'nope'
```

```jac
with entry {
    s = {3, 1, 2, 3};
    s.add(4);
    s.discard(1);
    print(sorted(s), len(s), 2 in s);
    print(sorted(s | {9}), sorted(s & {2, 3}), sorted(s - {2}), sorted(s ^ {2, 5}));
    print({1, 2} <= {1, 2, 3}, {1} == {1}, set("aab") == {"a", "b"});
    empty: set[int] = set();
    frozen = frozenset([1, 2]);
    print(len(empty), 1 in frozen, sorted(frozen | {3}));
}
```

```output
[2, 3, 4] 3 True
[2, 3, 4, 9] [2, 3] [3, 4] [3, 4, 5]
True True True
0 True [1, 2, 3]
```

## Indexing and slices

```ebnf
index_slice ::= "[" ((slice_from | expression slice_from?) ("," (slice_from | expression slice_from?))* ","?)? "]"

slice_from ::= ":" expression? (":" expression?)?
```

`x[i]` reads one item; `x[a:b]` and `x[a:b:step]` read a slice. They apply to `list`, `tuple`,
`str`, `bytes` and `bytearray`; `d[k]` reads a dict by key.

- **Indexes start at 0.** A negative index counts from the end: `x[-1]` is the last item.
- **An index out of range raises `IndexError`.** The index's type is checked at compile time: a
  list takes an `int`, a dict its key type (E1001).
- **A slice `a:b:step`** takes the items from index `a` up to, not including, `b`, every `step`.
  Each part may be left out: `a` defaults to the start, `b` to the end, `step` to 1. A negative
  step runs backward. Bounds past the ends are clipped, so a slice never raises for its bounds.
  A step of zero raises `ValueError`.
- **A tuple's slice is taken at compile time**, since each item has its own type: its bounds and
  step are constants (E0033), and a step of zero is an error there (E1201).
- **A slice is a new collection** of the same type as the one sliced.
- **A slice of a list may be assigned** (`xs[1:3] = [9]` replaces those items, changing the length)
  and deleted (`del xs[::2]`).

```jac
with entry {
    l = [0, 1, 2, 3, 4, 5, 6];
    print(l[2:5], l[:3], l[4:], l[-3:], l[:-2]);
    print(l[1:6:2], l[::-1], l[5:1:-2], l[10:], l[3:1]);
    print("abcdef"[1:4], (1, 2, 3)[:2], b"abc"[1:]);
    l[1:3] = [9];
    print(l);
    grid = [[1, 2], [3, 4]];
    print(grid[1][0], grid[-1][-1]);
    try {
        print(l[99]);
    } except IndexError as e {
        print("IndexError:", e);
    }
}
```

```output
[2, 3, 4] [0, 1, 2] [4, 5, 6] [4, 5, 6] [0, 1, 2, 3, 4]
[1, 3, 5] [6, 5, 4, 3, 2, 1, 0] [5, 3] [] []
bcd (1, 2) b'bc'
[0, 9, 3, 4, 5, 6]
3 4
IndexError: list index out of range
```

```jac
# expect: E1001 x2, E1201, E0033
with entry {
    l = [1, 2];
    d = {"a": 1};
    print(l["a"], d[1]);
    t = (1, "a", 2.5);
    k = len(l);
    print(t[::0], t[:k]);
}
```

## Comprehensions

```ebnf
compr_clauses ::= compr_clause+

compr_clause ::= "async"? "for" atomic_chain "in" pipe ("if" walrus)*
```

A comprehension builds a collection from one or more `for` clauses, each with optional `if`
filters.

| Form | Builds |
|---|---|
| `[e for x in xs]` | A list |
| `{k: v for x in xs}` | A dict |
| `{e for x in xs}` | A set |
| `(e for x in xs)` | A generator |

- Clauses nest left to right: `[e for x in xs for y in ys]` runs the `y` loop inside the `x` loop.
- Each `if` filters the clause before it; several `if`s on one clause must all hold.
- The loop target may unpack: `for (k, v) in pairs`.
- **The loop variables belong to the comprehension.** They do not exist after it, and a variable of
  the enclosing function with the same name is untouched.

```jac
with entry {
    xs = [1, 2, 3, 4];
    print([x * x for x in xs], [x for x in xs if x % 2 == 0]);
    print([x for x in xs if x > 1 if x < 4], [(x, y) for x in [1, 2] for y in "ab"]);
    print({x: x * x for x in xs if x < 3}, sorted({x % 2 for x in xs}));
    print([a + b for (a, b) in zip([1, 2], [10, 20])]);
    x = 99;
    ys = [x for x in range(2)];
    print(x, ys);
}
```

```output
[1, 4, 9, 16] [2, 4]
[2, 3] [(1, 'a'), (1, 'b'), (2, 'a'), (2, 'b')]
{1: 1, 2: 4} [0, 1]
[11, 22]
99 [0, 1]
```

### Generator expressions

`(e for x in xs)` makes a generator: nothing is computed until something iterates it, each item is
computed as it is asked for, and it can be iterated once. As the only argument of a call, it needs
no parentheses of its own: `sum(x * x for x in xs)`.

```jac
with entry {
    xs = [1, 2, 3];
    g = (x * 2 for x in xs);
    xs.append(4);
    print(list(g), list(g));
    print(sum(x * x for x in xs if x > 1), ",".join(str(x) for x in xs));
    print(any(x > 3 for x in xs), max(x for x in xs), tuple(x for x in xs));
}
```

```output
[2, 4, 6, 8] []
29 1,2,3,4
True 4 (1, 2, 3, 4)
```

An `async for` clause is allowed inside an `async` function; see [Async](async.md).

## Unpacking with `*` and `**`

```ebnf
unpack ::= "*" ref | ref
```

- **`*xs` in a list, tuple or set display** inserts the items of `xs`, which may be any iterable.
- **`**d` in a dict display** inserts the entries of the dict `d`. A later entry with the same key
  replaces an earlier one.
- **`*xs` and `**d` in a call** pass the items as positional arguments and the entries as keyword
  arguments; see [Functions](functions.md).
- A starred expression anywhere else is not a value (E0130).

```jac
def add(a: int, b: int, c: int = 0) -> int {
    return a + b + c;
}

with entry {
    xs = [1, 2];
    t = (3, 4);
    d = {"a": 1};
    print([0, *xs, *t], (*xs, 9), [*"ab"], [*range(2)]);
    print({**d, "b": 2}, {**d, "a": 100});
    print(add(*xs), add(*xs, 5), add(**{"a": 1, "b": 2}), add(*t, c=1));
}
```

```output
[0, 1, 2, 3, 4] (1, 2, 9) ['a', 'b'] [0, 1]
{'a': 1, 'b': 2} {'a': 100}
3 8 3 8
```

```jac
# expect: E0130
with entry {
    xs = [1, 2];
    ys = *xs;
}
```

## Differences from Python

- **A tuple needs its parentheses.** `x = 1, 2`, `return a, b` and `for k, v in items` are written
  `x = (1, 2);`, `return (a, b);` and `for (k, v) in items`.
- **Elements are typed.** A list display of mixed types is a `list[any]`, a dict's keys are of one
  type, and an empty `{}` needs an annotation.
- A set of unhashable `obj` values is a compile error, not a run-time one.
- A starred target in an assignment (`(first, *rest) = xs`) is not accepted.
- A list or tuple holding a NaN is not ordered as equal to itself: `[nan] <= [nan]` is `False`,
  as `[nan] == [nan]` is. Python takes the one float object as equal to itself there.

The methods of each type follow Python's. For the complete list of builtins and methods, see the
library reference: `jac docs builtins`.
