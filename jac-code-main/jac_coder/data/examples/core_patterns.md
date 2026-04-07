# Core Jac Patterns — Complete Working Examples

## Basic Module with Entry Block

```jac
"""A simple greeting module."""

def greet(name: str) -> str {
    return f"Hello, {name}!";
}

with entry {
    message = greet("World");
    print(message);
}
```

## Object with Fields and Methods

```jac
"""Object archetype with has declarations and methods."""

obj Person {
    has name: str = "",
        age: int = 0,
        email: str = "";

    def greet() -> str {
        return f"Hi, I'm {self.name}, age {self.age}";
    }

    def is_adult() -> bool {
        return self.age >= 18;
    }
}

with entry {
    p = Person(name="Alice", age=30, email="alice@example.com");
    print(p.greet());
    print(f"Adult: {p.is_adult()}");
}
```

## Interface and Implementation Separation

Declaration (`calculator.jac`):

```jac
obj Calculator {
    has result: float = 0.0;

    def add(x: float) -> float;
    def subtract(x: float) -> float;
    def reset() -> None;
    def get_result() -> float;
}
```

Implementation (`impl/calculator.impl.jac`):

```jac
impl Calculator.add(x: float) -> float {
    self.result += x;
    return self.result;
}

impl Calculator.subtract(x: float) -> float {
    self.result -= x;
    return self.result;
}

impl Calculator.reset() -> None {
    self.result = 0.0;
}

impl Calculator.get_result() -> float {
    return self.result;
}
```

## Walker Traversal

```jac
"""Walker that traverses a city graph."""

node City {
    has name: str = "",
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

## Social Network Graph

```jac
"""Graph-based social network with typed edges."""

node User {
    has username: str = "",
        bio: str = "";
}

edge Follows {
    has since: str = "";
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

## AI-Powered Function (by llm)

```jac
"""Using by llm() for AI-powered functions."""

import from byllm.lib { Model }

glob model: Model = Model(model_name="openai/gpt-4o-mini");

def summarize(text: str) -> str by model(
    reason="Summarize the given text in 2-3 sentences"
);

enum Sentiment { POSITIVE, NEGATIVE, NEUTRAL }

def classify_sentiment(text: str) -> Sentiment by model(
    reason="Classify the sentiment of the text"
);

with entry {
    result = summarize("Long article text here...");
    print(result);
}
```

## Test Blocks

```jac
"""Tests for the calculator module."""

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
```

## Enum and Match/Case

```jac
"""Enum types and pattern matching."""

enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

def describe_value(x: object) -> str {
    match x {
        case int():
            return f"Integer: {x}";
        case str():
            return f"String: {x}";
        case list():
            return f"List with {len(x)} items";
        case _:
            return "Unknown type";
    }
}

with entry {
    print(describe_value(42));
    print(describe_value("hello"));
}
```

## Async/Await

```jac
"""Async operations in Jac."""

import asyncio;

async def fetch_data(url: str) -> str {
    await asyncio.sleep(0.1);
    return f"Data from {url}";
}

with entry {
    result = asyncio.run(fetch_data("https://example.com"));
    print(result);
}
```

## CRUD Backend with Graph

```jac
"""Complete CRUD backend using nodes and def:pub endpoints."""

import from uuid { uuid4 }

node Product {
    has id: str = "";
    has name: str = "";
    has price: float = 0.0;
    has category: str = "";
}

def:pub add_product(name: str, price: float, category: str = "") -> dict {
    product = (root() ++> Product(
        id=str(uuid4()), name=name, price=price, category=category
    ))[0];
    return {"id": product.id, "name": product.name, "price": product.price};
}

def:pub get_products(category: str = "") -> list {
    all_products = [root()-->][?:Product];
    if category {
        all_products = [p for p in all_products if p.category == category];
    }
    return [{"id": p.id, "name": p.name, "price": p.price}
            for p in all_products];
}

def:pub delete_product(product_id: str) -> dict {
    for p in [root()-->][?:Product] {
        if p.id == product_id {
            root() del--> p;
            return {"success": True};
        }
    }
    return {"success": False, "error": "Not found"};
}
```

## Multi-Node Walker Endpoint

```jac
"""Walker that traverses Order → OrderItems in one request."""

node Order {
    has id: str = "";
    has status: str = "pending";
    has total: float = 0.0;
}

node OrderItem {
    has name: str = "";
    has qty: int = 0;
    has price: float = 0.0;
}

walker :pub get_order_details {
    has order_id: str = "";

    can find_order with Root entry {
        for order in [-->][?:Order] {
            if order.id == self.order_id {
                visit order;
                return;
            }
        }
        report {"error": "Order not found"};
    }

    can collect_items with Order entry {
        items = [{"name": i.name, "qty": i.qty, "price": i.price}
                 for i in [-->][?:OrderItem]];
        report {
            "order_id": here.id,
            "status": here.status,
            "items": items,
            "total": here.total
        };
    }
}
```
