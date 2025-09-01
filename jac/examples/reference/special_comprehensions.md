#### Filter comprehension

Special comprehensions provide concise, chainable operations on collections. Two common forms are filtering and bulk-setting fields across all elements.

- **Filter comprehension**: Selects elements that satisfy all predicates.
  - Syntax: `collection(?predicate1, predicate2, ...)`
  - Predicates are boolean expressions evaluated against each element (you can reference fields directly, e.g., `x`, or with `?x`).
  - Returns a new collection containing only matching elements, preserving order.

Example:

```jac
import random;

obj TestObj {
    has x: int = random.randint(0, 15),
        y: int = random.randint(0, 15),
        z: int = random.randint(0, 15);
}

with entry {
    random.seed(42);
    apple = [];
    for i=0 to i<100 by i+=1  {
        apple.append(TestObj());
    }

    # check if all apple's x are random between 0 and 15
    print(apple(?x >= 0, x <= 15) == apple);
}
```

Output:

```text
True
```

#### Assign (bulk-assign) comprehension

Setter comprehension applies field assignments to each element and returns the (same) collection reference. This is useful for bulk updates.

- **Setter comprehension**: Mutates all elements in-place.
  - Syntax: `collection(=field1=value1, field2=value2, ...)`
  - Each assignment is applied to every element in the collection.

Example:

```jac
obj MyObj {
    has apple: int = 0,
        banana: int = 0;
}

with entry {
    x = MyObj();
    y = MyObj();
    mvar = [x, y](=apple=5, banana=7);
    print(mvar);
}
```

Output:

```text
[MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]
```

Notes:
- **Multiple predicates** in filters are combined with logical AND.
- **Setter comprehension** returns the collection after mutation, enabling chaining with subsequent operations if desired.

