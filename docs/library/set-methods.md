---
description: The methods and operators of set and frozenset, with their signatures and where they differ from Python's.
keywords: set methods, frozenset methods, set.add, set.remove, set.discard, set.pop, set.clear, set.copy, set.update, set.union, set.intersection, set.difference, set.symmetric_difference, set.intersection_update, set.difference_update, set.symmetric_difference_update, set.isdisjoint, set.issubset, set.issuperset
---
# set and frozenset methods

A `set[T]` is a mutable collection of distinct hashable items of type `T`; a `frozenset[T]` is
an immutable one. Both have every method of Python's, with Python's results.

## Operators

| Expression | Result |
|---|---|
| `s \| t`, `s & t`, `s - t`, `s ^ t` | Union, intersection, difference, symmetric difference, as a new set |
| `s \|= t`, `s &= t`, `s -= t`, `s ^= t` | The same in place (set only) |
| `x in s` | Whether `s` has an item equal to `x` |
| `s == t` | The same items |
| `s <= t`, `s < t`, `s >= t`, `s > t` | Subset, proper subset, superset, proper superset |
| `len(s)`, `for x in s` | The number of items; the items |
| `{f(x) for x in it}` | A set comprehension |

An operator between a set and a frozenset gives the type of its left operand.

## Methods

| Method | Result |
|---|---|
| `s.add(x)` | Adds `x` |
| `s.remove(x)` | Removes `x`; `KeyError` when absent |
| `s.discard(x)` | Removes `x` if present |
| `s.pop()` | Removes and returns an item; `KeyError` when empty |
| `s.clear()` | Removes every item |
| `s.copy()` | A new set with the same items |
| `s.update(other)` | Adds the items of a set or another iterable |
| `s.union(other)`, `s.intersection(other)`, `s.difference(other)`, `s.symmetric_difference(other)` | A new set, as the operators give; `other` may be any iterable |
| `s.intersection_update(other)`, `s.difference_update(other)`, `s.symmetric_difference_update(other)` | The same in place |
| `s.isdisjoint(other)`, `s.issubset(other)`, `s.issuperset(other)` | Whether the two share no item; whether one contains the other |

A frozenset has the methods that change nothing: `copy`, `union`, `intersection`,
`difference`, `symmetric_difference`, `isdisjoint`, `issubset`, `issuperset`. Calling `add` or
another changing method on one is a compile error (E1030). A frozenset can be a dict key or an
item of a set.

```jac
with entry {
    s = {3, 1, 2};
    s.add(5);
    s.discard(9);
    s.update([7, 1]);
    print(s, len(s), 2 in s, sorted(s), s == {1, 2, 3, 5, 7});
    print(s | {8}, s & {1, 2, 9}, s - {1, 2}, {1, 2} ^ {2, 3}, {1} < s, s >= {7});
    print(s.union([9]), s.intersection([3, 4]), s.issubset(range(10)), s.isdisjoint([100]));
    s.intersection_update([1, 2, 3, 4]);
    s.symmetric_difference_update([3, 6]);
    print(s, {c.upper() for c in "abca"} == {"A", "B", "C"});
    try {
        s.remove(99);
    } except KeyError as e {
        print("KeyError:", e);
    }
    f = frozenset([1, 2]);
    seen = {f: "pair"};
    print(f | {3}, f & {2}, 1 in f, seen[frozenset([2, 1])], f == {1, 2});
}
```

```output
{3, 1, 2, 5, 7} 5 True [1, 2, 3, 5, 7] True
{3, 1, 2, 5, 7, 8} {1, 2} {3, 5, 7} {1, 3} True True
{3, 1, 2, 5, 7, 9} {3} True True
{1, 2, 6} True
KeyError: 99
frozenset({1, 2, 3}) frozenset({2}) True pair True
```

## Where it differs from Python

- **A set iterates and prints in the order its items were added.** CPython's order depends on
  the items' hashes. A program must not depend on either order: sort the items when the order
  matters.
- **`{}` is an empty dict**, as in Python, and `set()` needs its item type:
  `seen: set[str] = set();`.
- **On a typed set, `union`, `update` and the other methods take one argument.**
  `s.union(a, b)` is refused (E1051): write `s.union(a).union(b)` or `s | a | b`. A set held
  in an `any` takes several, as in Python: `held.union(a, b)`.
- **A set that changes size while it is iterated always raises `RuntimeError`**
  (`Set changed size during iteration`).
- **An item must be hashable.** `{[1]}` raises `TypeError: unhashable type: 'list'` as the
  program runs, as in Python.

## Where to go next

- `set`, `frozenset`, `len`, `sorted`: [Builtin functions](builtins.md).
- [dict methods](dict-methods.md), [list methods](list-methods.md).
