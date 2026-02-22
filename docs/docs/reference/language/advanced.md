# Comprehensions & Filters

**In this part:**

- [Standard Comprehensions](#standard-comprehensions) - List, dict, set, generator
- [Filter Comprehensions](#filter-comprehensions) - The `?` operator on collections
- [Typed Filter Comprehensions](#typed-filter-comprehensions) - Filter by type with `?:Type`
- [Assign Comprehensions](#assign-comprehensions) - Bulk update with `=`

---

Jac extends Python's comprehension syntax with **filter** (`?`) and **assign** (`=`) operators that work on collections of nodes or objects. These provide concise ways to query and modify groups of items.

> **Related:**
>
> - [Error Handling](foundation.md#8-exception-handling) - Try/except/finally, raising exceptions
> - [Pipe Operators](foundation.md#8-pipe-operators) - Forward/backward pipes
> - [Testing](../testing.md) - Test blocks, assertions, CLI commands

## Standard Comprehensions

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

Filter collections with `?condition`:

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
    adults = people(?age >= 18);

    # Multiple conditions
    qualified = employees(?salary > 50000, experience >= 5);

    # On graph traversal results
    friends = [-->](?status == "active");
}
```

## Typed Filter Comprehensions

Filter by type with filter syntax:

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
    dogs = animals(?:Dog);                    # By type only
    indoor_cats = animals(?:Cat, indoor==True); # Type with condition
    people = [-->](?:Person);                 # On graph traversal
    adults = [-->](?:Person, age > 21);        # Traversal with condition
}
```

## Assign Comprehensions

Modify all items with `=attr=value`:

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
    people(?age >= 18)(=can_vote=True);

    # Multiple assignments
    items(=status="processed", processed_at=now());
}
```
