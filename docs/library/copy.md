---
description: The copy module, copy.copy and copy.deepcopy, as CPython's, on lists, dicts, sets, objects, nodes and edges, and the __copy__ and __deepcopy__ hooks.
keywords: copy, copy.copy, copy.deepcopy, copy.Error, shallow copy, deep copy
---
# copy

`copy.copy(x)` makes a shallow copy of a value: a new container, or a new object, holding the
same items or field values. `copy.deepcopy(x)` copies the mutable parts all the way down. Both
are jac's own runtime module, with the meaning of CPython's (see [The library](index.md),
`jac docs library`).

```jac
import copy;

obj Shelf {
    has items: list[int] = [],
        raw: bytearray = bytearray();
}

obj Stack {
    has items: list[int] = [];

    def __copy__ -> Stack {
        return Stack(items=list(self.items));
    }
}

obj Doc {
    has text: str = "",
        tags: list[str] = [];

    def __deepcopy__(memo: dict[int, any]) -> Doc {
        return Doc(text=self.text + " (copied)", tags=copy.deepcopy(self.tags, memo));
    }
}

node Place {
    has name: str = "";
}

with entry {
    a = [[1, 2], [3]];
    shallow = copy.copy(a);
    deep = copy.deepcopy(a);
    a[0].append(9);
    print(shallow, deep);
    box = Shelf(items=[1], raw=bytearray(b"x"));
    twin: Shelf = copy.copy(box);
    clone = copy.deepcopy(box);
    print(twin.items is box.items, clone.items is box.items, clone.raw is box.raw);
    s = Stack(items=[1]);
    print(copy.copy(s).items is s.items);
    inner = [1];
    pair = copy.deepcopy([inner, inner]);
    print(pair[0] is pair[1], pair[0] is inner);
    p = Place(name="dock");
    q = copy.copy(p);
    print(q.name, jid(q) == jid(p));
    d = Doc(text="a", tags=["t"]);
    docs = copy.deepcopy([d, d]);
    print(docs[0].text, docs[0] is docs[1], docs[0].tags is d.tags);
}
```

```output
[[1, 2, 9], [3]] [[1, 2], [3]]
True False False
False
True False
dock False
a (copied) True False
```

## What it copies

| Value | `copy.copy` | `copy.deepcopy` |
|---|---|---|
| A list, dict, set or bytearray | A new container with the same items | A new container with each item deep-copied (a dict's values; its keys are immutable) |
| A tuple | The tuple itself | A new tuple when an item had to be copied |
| An `obj`, `node` or `edge` | A new object whose fields hold the original's values | A new object with each field deep-copied |
| A str, bytes, number, `None` | The value itself | The value itself |

- **The result has the argument's type**: `twin: Shelf = copy.copy(box);` needs no cast.
- **A class may make its own shallow copy** by defining `__copy__`, which takes no arguments and
  returns an object (E1200 otherwise). `copy.copy` calls it, also for a value held as an `any`.
- **A class may make its own deep copy** by defining `__deepcopy__(memo)`, which returns an object
  (E1200 otherwise). `copy.deepcopy` calls it wherever it reaches an object of the class, once for
  each: what it returns is that object's copy from then on. `memo` is the copies made so far, a
  `dict[int, any]` from the `id` of each value copied to its copy (it may be typed `any`); the
  method passes it on, `copy.deepcopy(self.tags, memo)`, so that what it copies is shared with
  the rest of the copy.
- **`copy.deepcopy(x, memo)`** copies `x` among the copies `memo` has, and adds those it makes.
- **A value that occurs twice in what `deepcopy` copies occurs twice in the copy**, as one new
  value, and a container that holds itself is copied into one that holds itself.
- **A copied node or edge is a new one**, with a `jid` of its own, and is connected to nothing.

`copy.Error` is the exception class of CPython's module. `copy.replace` (Python 3.13) is not
there yet (E1145).

## Differences from CPython

`copy.copy` and `copy.deepcopy` are compiled for the type they are called with, so they are not
values: `f = copy.deepcopy;` is refused (E5090). Call them, or wrap the call in a lambda.

```jac
# expect: E5090
import copy;

with entry {
    f = copy.deepcopy;
}
```

## Where to go next

- `list.copy`, `dict.copy` and `set.copy` make shallow copies too: [list](list-methods.md),
  [dict](dict-methods.md), [set](set-methods.md).
- The special methods a class may define, `__copy__` among them: `jac docs __copy__`.
