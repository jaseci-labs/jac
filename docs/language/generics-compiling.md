---
description: How generic functions and classes are checked and compiled - one shared function or a copy for each type - and a body that reflects on its type parameter, using it as a value.
keywords: specialization, monomorphization
---
# How generic code is compiled

A [generic](generics.md) function or class means the same whatever the
compiler makes of it. This page says what it makes, which decides what a
body may do with its type parameter as a value and when a body is checked
for one type. Type parameters themselves are on [Generics](generics.md)
(`jac docs type parameter`).

## One function, or a copy for each type

How a generic declaration compiles is the compiler's choice:

- **One compiled function serves every type** where the body does with `T`
  only what every type, or the bounding class, does, each value held as a
  64-bit word. Such a body is checked once, where it is declared.
- **A copy is compiled for each type a call gives** where the body needs
  one: a parameter bounded by an interface (its abilities, and builtin
  numbers' operators, are then called directly), by several bounds, by
  `Iterable[E]` or by a type its argument fits; a body that calls another
  function copied so; a body that reflects on `T` (below); and a body with
  [value parameters](comptime-parameters.md). A copied function may call
  itself.
- **A type parameter may stand for a [struct](structs.md) whatever its
  bound**, or another value type, and a shared function is copied for each
  struct type a call gives it.
- **A body that reflects on a type parameter, or has value parameters, is
  also checked in each copy**, as only the copy knows what its `comptime if`
  and its reflection pick. A body bounded by interfaces is still checked
  where it is declared first, so a use its bounds do not provide is E1284
  there, not an error in one copy.

A method that is copied for each call neither overrides nor is overridden
(E5090); see [Generic methods](generics.md).
[Generic classes](generics-classes.md) are compiled the same way: one class
for every type argument that is not a value type, an instance of its own
for each value type, and a copy for each type where a parameter is bounded
by an interface.

## Reflecting on a type parameter

A body may use a type parameter as a value: `T(x)` makes a `T`, `T.BYTES`
reads a [compile-time member](interfaces.md), `fields(T)` takes it apart
(see [Reflection](reflection.md)), `T is None` tests it, and `f[T](...)`
passes it on. For an [array or a vector](../accel/vectors.md) type, `T(x)`
puts `x` in every element. Such a body is copied for each type, and checked
in each copy.

```jac
def conv[T: Number](x: float) -> T {
    return T(x);
}

def filled[T](x: f32) -> T {
    return T(x);
}

def least_by[T, K: Callable[[T], any]](items: list[T], key: K = None) -> T {
    best = items[0];
    comptime if K is None {
        for x in items {
            if x < best {
                best = x;
            }
        }
    } else {
        for x in items {
            if key(x) < key(best) {
                best = x;
            }
        }
    }
    return best;
}

def depth[T](x: T, n: int) -> int {
    if n == 0 {
        return 0;
    }
    return 1 + depth(x, n - 1);
}

with entry {
    words = ["pear", "fig", "banana"];
    print(conv[int](3.7), conv[f32](0.1), least_by(words), least_by(words, key=len));
    print(filled[simd[f32, 4]](f32(1.5)), filled[array[f32, 2]](f32(2.0)));
    print(depth("x", 3));
}
```

```output
3 0.1 banana fig
[1.5, 1.5, 1.5, 1.5] [2.0, 2.0]
3
```

`K` is the type of what is passed for `key`, `None`'s when nothing is, which
`comptime if` tells apart, so `least_by(words)` compares the words
themselves and `least_by(words, key=len)` their lengths.

## See also

- [Generics](generics.md): type parameters, bounds and inference.
- [Generic classes](generics-classes.md): `obj Box[T]`.
- [Reflection](reflection.md): `fields`, `kind` and `type_args` of a type.
- [Compile-time evaluation](compile-time.md): `comptime if` and
  `comptime for`.
