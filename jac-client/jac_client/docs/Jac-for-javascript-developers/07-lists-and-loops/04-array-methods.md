# Array Methods

Learn map, filter, find, reduce and other array methods in Jac.

---

## map

Transform each element in an array.

### JavaScript

```javascript
const doubled = numbers.map((n) => n * 2);
```

### Jac

```jac
# Use helper function (recommended)
def double(n: int, index: int) -> int {
    return n * 2;
}
doubled = numbers.map(double);

# Or inline lambda
doubled = numbers.map(lambda n: int, i: int -> int { return n * 2; });
```

**Note:** Callback receives `(item, index)`.

---

## filter

Keep only elements that match a condition.

### JavaScript

```javascript
const evens = numbers.filter((n) => n % 2 === 0);
```

### Jac

```jac
evens = numbers.filter(lambda n: int -> bool { return n % 2 == 0; });

# With helper function
def isEven(n: int) -> bool {
    return n % 2 == 0;
}
evens = numbers.filter(isEven);
```

---

## find

Find the first element that matches.

### JavaScript

```javascript
const user = users.find((u) => u.id === targetId);
```

### Jac

```jac
user = users.find(lambda u: dict -> bool { return u["id"] == targetId; });
```

---

## some

Check if any element matches.

### JavaScript

```javascript
const hasAdmin = users.some((u) => u.role === "admin");
```

### Jac

```jac
hasAdmin = users.some(lambda u: dict -> bool { return u["role"] == "admin"; });
```

---

## every

Check if all elements match.

### JavaScript

```javascript
const allActive = users.every((u) => u.active);
```

### Jac

```jac
allActive = users.every(lambda u: dict -> bool { return u["active"]; });
```

---

## reduce

Reduce array to a single value.

### JavaScript

```javascript
const sum = numbers.reduce((acc, n) => acc + n, 0);
```

### Jac

```jac
sum = numbers.reduce(
    lambda acc: int, n: int -> int { return acc + n; },
    0
);
```

---

## Practical Examples

### Transform Objects

```jac
users = [
    { "id": 1, "name": "Alice", "email": "alice@example.com" },
    { "id": 2, "name": "Bob", "email": "bob@example.com" }
];

# Extract names
def getName(user: dict, index: int) -> str {
    return user["name"];
}
names = users.map(getName);
# ["Alice", "Bob"]

# Create select options
def toOption(user: dict, index: int) -> dict {
    return { "value": user["id"], "label": user["name"] };
}
options = users.map(toOption);
```

### Filter by Multiple Conditions

```jac
products = [
    { "name": "Laptop", "price": 999, "inStock": True },
    { "name": "Phone", "price": 699, "inStock": True },
    { "name": "Tablet", "price": 499, "inStock": False },
    { "name": "Watch", "price": 299, "inStock": True }
];

# Affordable AND in stock
affordable = products.filter(lambda p: dict -> bool {
    return p["price"] < 500 and p["inStock"];
});
```

### Chain Methods

```jac
users = [
    { "name": "Alice", "age": 25, "active": True },
    { "name": "Bob", "age": 17, "active": True },
    { "name": "Charlie", "age": 30, "active": False },
    { "name": "Diana", "age": 22, "active": True }
];

# Get names of active adults
activeAdults = users
    .filter(lambda u: dict -> bool { return u["active"]; })
    .filter(lambda u: dict -> bool { return u["age"] >= 18; })
    .map(lambda u: dict, i: int -> str { return u["name"]; });
# ["Alice", "Diana"]
```

### Calculate Totals

```jac
cart = [
    { "name": "Apple", "price": 1.50, "quantity": 3 },
    { "name": "Banana", "price": 0.75, "quantity": 5 },
    { "name": "Orange", "price": 2.00, "quantity": 2 }
];

total = cart.reduce(
    lambda acc: float, item: dict -> float {
        return acc + (item["price"] * item["quantity"]);
    },
    0
);
# total = 12.25
```

### Group By

```jac
items = [
    { "type": "fruit", "name": "Apple" },
    { "type": "vegetable", "name": "Carrot" },
    { "type": "fruit", "name": "Banana" },
    { "type": "vegetable", "name": "Broccoli" }
];

grouped = items.reduce(
    lambda acc: dict, item: dict -> dict {
        itemType = item["type"];
        if acc[itemType] == None {
            acc[itemType] = [];
        }
        acc[itemType].push(item);
        return acc;
    },
    {}
);
# { "fruit": [...], "vegetable": [...] }
```

---

## Other Methods

### concat

```jac
arr1 = [1, 2, 3];
arr2 = [4, 5, 6];
combined = arr1.concat(arr2);  # [1, 2, 3, 4, 5, 6]
```

### slice

```jac
arr = [0, 1, 2, 3, 4, 5];
portion = arr.slice(1, 4);  # [1, 2, 3]
last3 = arr.slice(-3);      # [3, 4, 5]
```

### indexOf

```jac
arr = ["a", "b", "c", "d"];
index = arr.indexOf("c");  # 2
notFound = arr.indexOf("z");  # -1
```

### includes

```jac
arr = [1, 2, 3, 4, 5];
has3 = arr.includes(3);  # True
has9 = arr.includes(9);  # False
```

### join

```jac
arr = ["a", "b", "c"];
str = arr.join(", ");  # "a, b, c"
str = arr.join("-");   # "a-b-c"
```

### reverse

```jac
arr = [1, 2, 3];
reversed = arr.reverse();  # [3, 2, 1]
```

### sort

```jac
arr = [3, 1, 4, 1, 5, 9, 2, 6];
sorted = arr.sort();  # [1, 1, 2, 3, 4, 5, 6, 9]

# Custom sort
def compare(a: int, b: int) -> int {
    return b - a;  # Descending
}
sorted = arr.sort(compare);
```

---

## Summary

| Method | Purpose       | Callback                   |
| ------ | ------------- | -------------------------- |
| map    | Transform     | `(item, index) -> newItem` |
| filter | Keep matching | `(item) -> bool`           |
| find   | First match   | `(item) -> bool`           |
| some   | Any match     | `(item) -> bool`           |
| every  | All match     | `(item) -> bool`           |
| reduce | Accumulate    | `(acc, item) -> newAcc`    |

---

## Next

- [Rendering Lists](./05-rendering-lists.md) - Lists in JSX
