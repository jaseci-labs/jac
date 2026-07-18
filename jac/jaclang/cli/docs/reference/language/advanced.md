# Comprehensions & Filters

**In this part:**

- [Standard Comprehensions](#standard-comprehensions) - List, dict, set, generator
- [Filter Comprehensions](#filter-comprehensions) - The `[?...]` operator on collections
- [Typed Filter Comprehensions](#typed-filter-comprehensions) - Filter by type with `[?:Type]`
- [Assign Comprehensions](#assign-comprehensions) - Bulk update with `=`

---

Jac includes Python's familiar list, dict, set, and generator comprehensions -- and extends them with two powerful operators designed for working with collections of graph nodes and objects:

- **Filter comprehensions** (`[?...]`) -- query a collection by attribute conditions or type, returning only the matching elements. This replaces verbose `for`/`if` filtering with a concise inline syntax. For example, `people[?age >= 18]` returns all people whose age is 18 or above.
- **Assign comprehensions** (`=`) -- bulk-update attributes on every item in a collection. Instead of writing a loop to set a field on each element, `people(=verified=True)` sets `verified` to `True` on all items in one expression.

These operators are especially useful during graph traversal, where you often need to filter connected nodes by type or attribute and then update them. They chain naturally: `people[?age >= 18](=can_vote=True)` filters *then* assigns in a single expression.

> **Related:**
>
> - [Error Handling](foundation.md#8-exception-handling) - Try/except/finally, raising exceptions
> - [Pipe Operators](foundation.md#8-pipe-operators) - Forward/backward pipes
> - [Testing](../testing.md) - Test blocks, assertions, CLI commands

## Standard Comprehensions

Jac supports all four Python comprehension forms -- list, dict, set, and generator -- with identical semantics. If you know Python comprehensions, these work exactly as you'd expect, just wrapped in braces and terminated with semicolons.

```jac
def example() {
    # List comprehension
    squares = [x ** 2 for x in range(10)];

    # With condition
    evens = [x for x in range(20) if x % 2 == 0];

    # Dict comprehension
    squared_dict = {x: x ** 2 for x in range(5)};

    # Set comprehension
    strings = ["hello", "world", "hi"];
    unique_lengths = {len(s) for s in strings};

    # Generator expression
    gen = (x ** 2 for x in range(1000000));
}
```

## Filter Comprehensions

Filter comprehensions use the `[?...]` operator to select elements from a collection based on attribute conditions. The syntax is `collection[?attr op value]` -- the condition references attributes directly by name, without needing a lambda or loop variable. Multiple conditions are separated by commas and are ANDed together.

This is particularly powerful with graph traversals. Instead of fetching all connected nodes and then filtering in a separate loop, you can write `[-->][?status == "active"]` to get only the active connections in one expression.

```jac
node Person {
    has age: int,
        status: str;
}

node Employee {
    has salary: int,
        experience: int;
}

def example(people: list[Person], employees: list[Employee]) {
    # Filter people by age
    adults = people[?age >= 18];

    # Multiple conditions
    qualified = employees[?salary > 50000, experience >= 5];

    # On graph traversal results
    friends = [-->][?status == "active"];
}
```

## Typed Filter Comprehensions

When a graph has multiple node types connected to the same parent, typed filter comprehensions let you select by type using the `[?:Type]` syntax. This is the graph-aware equivalent of `isinstance` filtering -- `[-->][?:Person]` returns only `Person` nodes from all outgoing connections. You can combine type filters with attribute conditions: `[-->][?:Person, age > 21]` filters by both type and attribute in one expression.

```jac
node Dog {
    has name: str;
}

node Cat {
    has indoor: bool;
}

node Person {
    has age: int;
}

def example(animals: list) {
    dogs = animals[?:Dog];                    # By type only
    indoor_cats = animals[?:Cat, indoor==True]; # Type with condition
    people = [-->][?:Person];                 # On graph traversal
    adults = [-->][?:Person, age > 21];        # Traversal with condition
}
```

## Assign Comprehensions

Assign comprehensions bulk-update attributes on every item in a collection using the `=attr=value` syntax. This eliminates the need for `for` loops that exist solely to set a field on each element. The real power comes from chaining with filter comprehensions: `people[?age >= 18](=can_vote=True)` first selects adults, then sets `can_vote` on each one -- a pattern that would otherwise require a multi-line loop with a conditional.

```jac
node Person {
    has age: int,
        verified: bool = False,
        can_vote: bool = False;
}

node Item {
    has status: str,
        processed_at: str;
}

def now() -> str {
    return "2024-01-01";
}

def example(people: list[Person], items: list[Item]) {
    # Set attribute on all items
    people(=verified=True);

    # Chained: filter then assign
    people[?age >= 18](=can_vote=True);

    # Multiple assignments
    items(=status="processed", processed_at=now());
}
```
