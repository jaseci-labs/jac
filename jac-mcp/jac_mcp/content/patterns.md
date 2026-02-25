# Idiomatic Jac Patterns

Complete, working code examples showing correct Jac patterns.

## 1. Basic Module with Entry Block

```jac
"""A simple greeting module."""

can greet(name: str) -> str {
    return f"Hello, {name}!";
}

with entry {
    message = greet("World");
    print(message);
}
```

## 2. Archetype (obj) with Has Declarations and Abilities

```jac
"""A basic object archetype with fields and methods."""

obj Person {
    has name: str,
        age: int,
        email: str = "";

    can greet -> str {
        return f"Hi, I'm {self.name}, age {self.age}";
    }

    can is_adult -> bool {
        return self.age >= 18;
    }
}

with entry {
    p = Person(name="Alice", age=30, email="alice@example.com");
    print(p.greet());
    print(f"Adult: {p.is_adult()}");
}
```

## 3. Interface Declaration + Matching Implementation

Declaration file (`calculator.jac`):

```jac
"""Calculator archetype with declared abilities."""

obj Calculator {
    has result: float = 0.0;

    can add(x: float) -> float;
    can subtract(x: float) -> float;
    can multiply(x: float) -> float;
    can reset -> None;
    can get_result -> float;
}
```

Implementation file (`impl/calculator.impl.jac`):

```jac
"""Calculator implementations."""

impl Calculator.add(x: float) -> float {
    self.result += x;
    return self.result;
}

impl Calculator.subtract(x: float) -> float {
    self.result -= x;
    return self.result;
}

impl Calculator.multiply(x: float) -> float {
    self.result *= x;
    return self.result;
}

impl Calculator.reset -> None {
    self.result = 0.0;
}

impl Calculator.get_result -> float {
    return self.result;
}
```

## 4. Walker Definition and Traversal

```jac
"""Walker that traverses a graph and collects data."""

node City {
    has name: str,
        population: int = 0;
}

edge Road {
    has distance: float = 0.0;
}

walker Explorer {
    has visited: list[str] = [];

    can visit_city with City entry {
        self.visited.append(here.name);
        print(f"Visiting {here.name} (pop: {here.population})");
        visit [-->];
    }
}

with entry {
    nyc = City(name="New York", population=8_300_000);
    la = City(name="Los Angeles", population=3_900_000);
    chi = City(name="Chicago", population=2_700_000);

    root ++> nyc;
    nyc +>:Road(distance=790.0):+> chi;
    chi +>:Road(distance=2015.0):+> la;

    explorer = root spawn Explorer();
}
```

## 5. Node and Edge Definitions with Graph Construction

```jac
"""Graph-based social network."""

node User {
    has username: str,
        bio: str = "";
}

edge Follows {
    has since: str = "";
}

edge Blocks {
    has reason: str = "";
}

with entry {
    alice = User(username="alice", bio="Developer");
    bob = User(username="bob", bio="Designer");
    carol = User(username="carol", bio="Manager");

    alice +>:Follows(since="2024-01"):+> bob;
    alice +>:Follows(since="2024-03"):+> carol;
    bob +>:Follows(since="2024-02"):+> carol;
}
```

## 6. By LLM Usage Pattern

```jac
"""Using by llm() for AI-powered functions."""

import from byllm.llm { Model }

glob model = Model(model_name="openai/gpt-4o-mini");

"""Summarize text using LLM."""
can summarize(text: str) -> str by model(
    reason="Summarize the given text in 2-3 sentences"
);

"""Classify sentiment of text."""
enum Sentiment {
    POSITIVE,
    NEGATIVE,
    NEUTRAL
}

can classify_sentiment(text: str) -> Sentiment by model(
    reason="Classify the sentiment of the text"
);

with entry {
    result = summarize("Long article text here...");
    print(result);
}
```

## 7. Test Block Pattern

```jac
"""Tests for a calculator module."""

import from calculator { Calculator }

test "calculator addition" {
    calc = Calculator();
    calc.add(5.0);
    assert calc.get_result() == 5.0;
    calc.add(3.0);
    assert calc.get_result() == 8.0;
}

test "calculator reset" {
    calc = Calculator();
    calc.add(10.0);
    calc.reset();
    assert calc.get_result() == 0.0;
}

test "calculator multiply" {
    calc = Calculator();
    calc.add(5.0);
    calc.multiply(3.0);
    assert calc.get_result() == 15.0;
}
```

## 8. Import Conventions

```jac
# From Jac packages
import from mypackage.module { MyClass, my_function }

# From Python standard library
import from os { path }
import from pathlib { Path }
import from typing { Any, Optional }
import from collections { defaultdict }

# Whole module import
import os;
import json;

# Relative import (within same package)
import from .submodule { Helper }
```

## 9. Enum Definition

```jac
"""Enum types in Jac."""

enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

enum Direction {
    NORTH,
    SOUTH,
    EAST,
    WEST
}

can describe_color(c: Color) -> str {
    return f"The color is {c.value}";
}

with entry {
    print(describe_color(Color.RED));
}
```

## 10. Match/Switch Statement

```jac
"""Pattern matching in Jac."""

can describe_value(x: object) -> str {
    match x {
        case int() {
            return f"Integer: {x}";
        }
        case str() {
            return f"String: {x}";
        }
        case list() {
            return f"List with {len(x)} items";
        }
        case _ {
            return "Unknown type";
        }
    }
}

with entry {
    print(describe_value(42));
    print(describe_value("hello"));
    print(describe_value([1, 2, 3]));
}
```

## 11. Plugin Hook Pattern

```jac
"""Example of a Jac plugin with hookimpl."""

import from jaclang.jac0core.runtime { hookimpl }
import from typing { Any }

class MyPlugin {
    @hookimpl
    static def my_hook(arg: str) -> Any {
        return f"Processed: {arg}";
    }
}
```

## 12. Async/Await Pattern

```jac
"""Async operations in Jac."""
import asyncio;

async can fetch_data(url: str) -> str {
    # Simulate async fetch
    await asyncio.sleep(0.1);
    return f"Data from {url}";
}

with entry {
    result = asyncio.run(fetch_data("https://example.com"));
    print(result);
}
```
