---
description: The native collections module, as CPython's collections, its container classes and how they differ from Python's dict subclasses.
keywords: collections, collections.deque, deque, collections.defaultdict, defaultdict, collections.OrderedDict, OrderedDict, collections.Counter, Counter, collections.ChainMap, ChainMap, collections.UserDict, UserDict, collections.UserList, UserList, collections.UserString, UserString, namedtuple, collections.namedtuple, collections.abc
---
# collections

`collections` has the container classes of CPython's `collections`: `deque`, `defaultdict`,
`OrderedDict`, `Counter`, `ChainMap`, `UserDict`, `UserList` and `UserString`, with CPython's
methods, operators, `repr`, exceptions and messages. It is native (see
[The library](index.md), `jac docs library`). `namedtuple` is left out on purpose.

```jac
import from collections { deque, defaultdict, OrderedDict, Counter, ChainMap }

with entry {
    q = deque([1, 2, 3], maxlen=3);
    q.append(4);
    q.appendleft(0);
    print(q, q[0], len(q));
    groups = defaultdict(list[str]);
    for w in ["apple", "avocado", "banana"] {
        groups[w[0]].append(w);
    }
    print(groups["a"], "z" in groups, len(groups));
    print(dict(groups), dict(Counter("aab").items()));
    c = Counter("mississippi");
    print(c.most_common(2), c["s"], c["z"]);
    od = OrderedDict();
    od["b"] = 1;
    od["a"] = 2;
    od.move_to_end("b");
    print(list(od.keys()), od.popitem(last=False));
    cm = ChainMap({"color": "red"}, {"color": "blue", "size": 3});
    print(cm["color"], cm["size"], len(cm));
}
```

```output
deque([0, 2, 3], maxlen=3) 0 3
['apple', 'avocado'] False 2
{'a': ['apple', 'avocado'], 'b': ['banana']} {'a': 2, 'b': 1}
[('i', 4), ('s', 4)] 4 0
['a', 'b'] ('a', 2)
red 3 2
```

## What is there

| Class | What it is |
|---|---|
| `deque(iterable=(), maxlen=None)` | A double-ended queue: `append`, `appendleft`, `pop`, `popleft`, `extend`, `extendleft`, `rotate`, `insert`, `remove`, `index`, `count`, `reverse`, `clear`, `copy`, indexing, `maxlen` |
| `defaultdict(default_factory)` | A mapping that calls `default_factory` for a missing key read with `d[key]` |
| `OrderedDict` | A mapping with `move_to_end` and `popitem(last=)`; equality with another OrderedDict depends on order |
| `Counter(iterable)` | Counts: `most_common`, `elements`, `update`, `subtract`, `total`, and `+ - & |` |
| `ChainMap(*maps)` | Several mappings read as one; writes go to the first |
| `UserDict`, `UserList`, `UserString` | Wrappers to inherit from, holding a dict, list or str in `data` |

Behavior, as CPython's:

- A bounded `deque` drops from the other end when full; `insert` into a full one raises
  `IndexError: deque already at its maximum size`. Changing a deque while iterating it raises
  `RuntimeError: deque mutated during iteration`. `deque(maxlen=-1)` raises
  `ValueError: maxlen must be non-negative`, and `hash(q)` raises
  `TypeError: unhashable type: 'collections.deque'`. A deque that holds itself prints as
  `deque([1, [...]])`.
- `defaultdict`'s factory may be a type (`int`), a generic type (`list[str]`, `dict[str, int]`),
  a function, or `None` (a missing key then raises `KeyError`). Only `d[key]` calls it; `get`
  and `in` do not. Another factory raises `TypeError: first argument must be callable or
  None`. The `repr` names the factory's class: `defaultdict(<class 'list'>, {})` for
  `defaultdict(list[str])`.
- `Counter` reads a missing key as 0 without adding it. `-`, `&`, `|` and unary `+`/`-` drop
  counts that are not positive; `subtract` keeps them. `most_common()` orders by count, and
  equal counts by first appearance. `Counter.fromkeys` raises `NotImplementedError`
  (`Counter.fromkeys() is undefined.  Use Counter(iterable) instead.`), as in CPython.
- An `OrderedDict` equals a plain dict with the same entries in any order, and another
  `OrderedDict` only in the same order. `popitem()` of an empty one raises
  `KeyError: 'dictionary is empty'`, and changing one while iterating it raises
  `RuntimeError: OrderedDict mutated during iteration`.
- `ChainMap` deletes and pops only in its first mapping:
  `KeyError: "Key not found in the first mapping: 'color'"`.

## Inheriting from a collection

A program's `obj` may inherit `UserDict`, `UserList`, `UserString`, `OrderedDict` or `Counter`
and override their methods with `override def`; the inherited methods then go through the
overrides (`__setitem__`, `__getitem__`, `__contains__`, a `Counter`'s `__missing__`, ...), and
methods that return a new object return the subclass:

```jac
import from collections { UserDict }

obj Folded(UserDict) {
    override def __setitem__(key: any, value: any) -> None {
        super.__setitem__(str(key).lower(), value);
    }

    override def __getitem__(key: any) -> any {
        return super.__getitem__(str(key).lower());
    }
}

with entry {
    d = Folded();
    d["Name"] = "Ada";
    d.update({"LANG": "jac"});
    print(d["NAME"], d["lang"], sorted(d.keys()));
}
```

```output
Ada jac ['lang', 'name']
```

## Differences from CPython

- **`defaultdict`, `Counter` and `OrderedDict` are objects, not dicts.** `isinstance(c, dict)` is
  `False`, and one cannot be passed where a `dict[K, V]` is declared (E1053). Declare the
  parameter with the class (`d: defaultdict`), or `any`. `dict(d)` makes a dict of one's
  entries, as of any mapping's, and `dict(d.items())` of its pairs.

```jac
# expect: E1053
import from collections { defaultdict }

def total(d: dict[str, int]) -> int {
    return sum(d.values());
}

with entry {
    print(total(defaultdict(int)));
}
```

- **Items are `any`.** A class's type parameters are erased, so what a `deque` or `Counter` holds
  is typed `any`; assign it to an annotated name to give it a type (`n: int = q.pop();`).
- **`UserString.format`** is not written yet (E1030).

## What is not there

`namedtuple` makes a class as the program runs, and a Jac class is declared in the program, so it
is left out on purpose (E5142). Declare an `obj` with the fields, or use a tuple:

```jac
# expect: E5142
import from collections { namedtuple }

with entry {
    print(namedtuple);
}
```

`collections.abc` has no native module: `import collections.abc` is E5143. Jac's own
`Iterable[T]`, `Iterator[T]` and `Callable` types stand in for its abstract classes. Both are
reachable from CPython explicitly with `importlib.import_module("collections")`, as Python
objects (see [The library](index.md)).
