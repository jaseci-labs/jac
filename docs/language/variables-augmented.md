---
description: Augmented assignment (x += e and the other op= forms) - the result's type, what changes in place on a list, a tuple, an object and an item, and the order its target is evaluated in.
keywords: augmented assignment, +=, -=, *=, /=, //=, %=, **=, @=, &=, |=, ^=, <<=, >>=
---
# Augmented assignment

```ebnf
assignment ::= (":" ownership_prefix pipe)? ("=" value_or_yield ("=" value_or_yield)* | ("+=" | "-=" | "*=" | "/=" | "//=" | "%=" | "**=" | "@=" | "&=" | "|=" | "^=" | "<<=" | ">>=" | "+%=" | "-%=" | "*%=" | "+|=" | "-|=" | "*|=") value_or_yield)? ";"?
```

`x op= e` computes `x op e` and assigns the result to `x`. The target is a name, a field or an
item. The operators are those of the assignment statement above (see [Variables](variables.md));
the wrapping and saturating forms (`+%=`, `+|=`, ...) are in [Numbers](numbers.md).

- The result must have the target's type. `n /= 2` on an `int` is E1001, because `/` gives a
  `float`; use `//=`.
- On a list, `+=` extends the list in place, so every name bound to it sees the change. On a
  tuple or a str it makes a new value: `key += ("b", "c")` leaves other names bound to the old
  tuple as they were.
- On an object, `x op= y` calls the class's `__iop__` (`__iadd__`, ...) when it has one, and keeps
  what it returns; otherwise it is `x = x op y`, a new object. When the left operand's type has no
  method for the right one, the right one's reflected method (`__radd__`, ...) is used, and its
  result is converted to the target's type: `t += Turn(deg=45)` on an `int` `t` leaves an `int`.
- The target is evaluated once, left to right: the object, then the attribute or container, then
  the index or the slice bounds, and then the right side. In `box().items[i()] += f()`, `box()`
  and `i()` are each called once, before `f()`.
- An item of an object is read with its `__getitem__` and stored with its `__setitem__`, given the
  index as written (`s[-1] *= 3` passes `-1`). A slice target, on a list or an object, reads the
  slice, computes, and stores the result back into the slice: `xs[2:] += [0]` appends to `xs`.
- Through an `any`, an augmented assignment changes in place exactly what Python changes in
  place; see [The `any` type](types-any.md).
- An augmented assignment takes no annotation (E0141).

```jac
with entry {
    n = 7;
    n += 1;
    n //= 3;
    n **= 3;
    n <<= 2;
    n |= 1;
    print(n);

    s = "ab";
    s += "c";
    s *= 2;
    print(s);

    xs = [1];
    alias = xs;
    xs += [2];
    xs[1:] += [3];
    print(alias);

    key: tuple[str, ...] = ("a",);
    old = key;
    key += ("b", "c");
    print(key, old);
}
```

```output
33
abcabc
[1, 2, 3]
('a', 'b', 'c') ('a',)
```

```jac
obj Vec {
    has x: int = 0;

    def __add__(o: Vec) -> Vec {
        return Vec(x=self.x + o.x);
    }
}

obj Acc {
    has x: int = 0;

    def __iadd__(o: int) -> Acc {
        self.x += o;
        return self;
    }
}

with entry {
    v = Vec(x=1);
    w = v;
    v += Vec(x=2);
    print(v.x, w.x, v is w);

    a = Acc();
    b = a;
    a += 5;
    print(a.x, a is b);
}
```

```output
3 1 False
5 True
```

An object's item, read and stored through its own methods:

```jac
obj Shelf {
    has xs: list[int] = [];

    def __getitem__(k: any) -> any {
        print("get", k);
        if isinstance(k, slice) {
            sl: slice = k;
            (a, z, st) = sl.indices(len(self.xs));
            return [self.xs[i] for i in range(a, z, st)];
        }
        i: int = k;
        return self.xs[i];
    }

    def __setitem__(k: any, v: any) {
        print("set", k, v);
        if not isinstance(k, slice) {
            i: int = k;
            x: int = v;
            self.xs[i] = x;
        }
    }
}

with entry {
    s = Shelf(xs=[1, 2, 3]);
    s[-1] *= 3;
    s[0:2] += [0];
    print(s.xs);
}
```

```output
get -1
set -1 9
get slice(0, 2, None)
set slice(0, 2, None) [1, 2, 0]
[1, 2, 9]
```

What is rejected:

```jac
# expect: E1001, E1110
with entry {
    n = 7;
    n /= 2;
    n += "x";
}
```


## Differences from Python

- The target keeps its type: `n /= 2` on an `int` is an error, not a float.
- Python's rules for what changes in place hold, through an `any` too.
