---
description: The methods and operators of tuple, range and slice objects.
keywords: tuple methods, range methods, tuple.count, tuple.index, range.count, range.index, range.start, range.stop, range.step, slice.indices, slice.start, slice.stop, slice.step
---
# tuple, range and slice

Three immutable builtin types: a `tuple` holds a fixed number of items, each with its own type;
a `range` is a sequence of ints computed on demand; a `slice` is what `a[start:stop:step]`
passes to `__getitem__`.

## tuple

A tuple's type lists its items' types: `(1, "a", 2.5)` is a `tuple[int, str, float]`.

| Expression | Result |
|---|---|
| `t[i]`, `t[a:b]` | An item, a tuple of part of it |
| `t + u`, `t * n` | A new tuple |
| `x in t`, `len(t)`, `for x in t` | Membership, length, iteration |
| `t == u`, `t < u` | Comparison item by item |
| `(a, b) = t` | Unpacking into as many targets as it has items |
| `hash(t)` | Its hash, when every item is hashable: a tuple can be a dict key |
| `t.count(v)` | How many items equal `v` |
| `t.index(v)` | The position of the first item equal to `v`; `ValueError` when there is none |

```jac
with entry {
    t = (3, "a", 2.5);
    (n, name, ratio) = t;
    print(t[0], t[-1], t[0:2], len(t), n, name, ratio, "a" in t);
    pairs = [(2, "b"), (1, "z"), (1, "a")];
    print(sorted(pairs), max(pairs), (1, 2) < (1, 3), (1, 2) + (3,), (0,) * 3);
    print((1, 2, 1).count(1), (1, 2, 1).index(2), tuple("ab"), {(0, 0): "origin"}[(0, 0)]);
    (a, b) = (1, 2);
    (a, b) = (b, a);
    print(a, b);
}
```

```output
3 2.5 (3, 'a') 3 3 a 2.5 True
[(1, 'a'), (1, 'z'), (2, 'b')] (2, 'b') True (1, 2, 3) (0, 0, 0)
2 1 ('a', 'b') origin
2 1
```

Comparison, as Python's for tuples and lists: items that are the same object or equal are
skipped, and the first pair that is neither decides. When that pair has no order (two NaNs, or
two objects whose `__lt__` says neither is less), `<` and `>` are both `False`. A tuple
repeated by a count of 0 or less is `()`.

Where it differs from Python:

- **An index that is out of range is a compile error** when it is a literal (E1174), since the
  tuple's length is part of its type. Assigning to an item is E1191.
- **Unpacking must match the length** (E1020), and a starred target (`(a, *rest) = t`) is not
  supported (E0130).
- **`tuple()` with no argument is refused**: write `()`.

## range

`range(stop)` and `range(start, stop, step=1)` make a range. It holds no list: its items are
computed from its three ints.

| Expression | Result |
|---|---|
| `r.start`, `r.stop`, `r.step` | The three ints it was made with |
| `len(r)`, `r[i]`, `x in r`, `for x in r` | Length, the item at `i` (`IndexError` out of range), membership, iteration |
| `r[a:b:c]` | A range of part of it |
| `r == s` | Whether both produce the same ints |
| `r.count(v)` | `1` when `v` is in the range, else `0` |
| `r.index(v)` | The position of `v`; `ValueError` when it is not in the range |

`range(a, b, 0)` raises `ValueError`. The arguments are ints.

```jac
with entry {
    r = range(0, 10, 3);
    print(r, list(r), len(r), r[1], r[-1], 9 in r, r.start, r.stop, r.step);
    print(r[1:], list(reversed(r)), r.index(6), r.count(4), range(3) == range(0, 3), sum(r));
    try {
        r.index(5);
    } except ValueError as e {
        print(e);
    }
}
```

```output
range(0, 10, 3) [0, 3, 6, 9] 4 3 9 True 0 10 3
range(3, 12, 3) [9, 6, 3, 0] 2 0 True 18
5 is not in range
```

## slice

`slice(stop)` or `slice(start, stop, step=None)` makes the object a subscript `a[start:stop:step]`
makes. A class that defines `__getitem__` receives one for a slice subscript, and a list, a str or
bytes indexed by one gives that slice, held in an `any` too.

| Member | Result |
|---|---|
| `s.start`, `s.stop`, `s.step` | Its bounds: each an int or `None` |
| `s.indices(length)` | The `(start, stop, step)` it selects from a sequence of `length` items |

```jac
obj Evens {
    def __getitem__(k: any) -> any {
        if isinstance(k, slice) {
            (start, stop, step) = k.indices(10);
            return [2 * i for i in range(start, stop, step)];
        }
        return 2 * k;
    }
}

with entry {
    s = slice(1, 5, 2);
    print(s, s.start, s.stop, s.step, s.indices(4), "abcdef"[s], [0, 1, 2, 3][slice(2)]);
    e = Evens();
    print(e[3], e[1:4], e[::5]);
    held: any = [0, 1, 2, 3];
    print(held[s], held[slice(None, None, -1)]);
}
```

```output
slice(1, 5, 2) 1 5 2 (1, 4, 2) bd [0, 1]
6 [2, 4, 6] [0, 10]
[1, 3] [3, 2, 1, 0]
```

## Where to go next

- `tuple`, `range`, `slice`, `len`, `sorted`: [Builtin functions](builtins.md).
- [list methods](list-methods.md) for the mutable sequence.
