# For-In Loops

Learn how to iterate over arrays in Jac.

---

## Syntax

### JavaScript

```javascript
for (const item of items) {
  console.log(item);
}
```

### Jac

```jac
for item in items {
    console.log(item);
}
```

---

## Basic Examples

### Iterate Strings

```jac
fruits = ["apple", "banana", "cherry"];

for fruit in fruits {
    console.log(fruit);
}
# Output: apple, banana, cherry
```

### Iterate Numbers

```jac
numbers = [1, 2, 3, 4, 5];

total = 0;
for num in numbers {
    total = total + num;
}
# total = 15
```

---

## Iterate Objects

```jac
users = [
    { "name": "Alice", "age": 25 },
    { "name": "Bob", "age": 30 },
    { "name": "Charlie", "age": 35 }
];

for user in users {
    console.log(user["name"] + " is " + user["age"].toString());
}
```

---

## Building New Arrays

### Filter Pattern

```jac
numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
evens = [];

for num in numbers {
    if num % 2 == 0 {
        evens.push(num);
    }
}
# evens = [2, 4, 6, 8, 10]
```

### Transform Pattern

```jac
numbers = [1, 2, 3, 4, 5];
doubled = [];

for num in numbers {
    doubled.push(num * 2);
}
# doubled = [2, 4, 6, 8, 10]
```

---

## With Index

To get index, use counter-based loop or track manually:

### Manual Counter

```jac
items = ["a", "b", "c"];
index = 0;

for item in items {
    console.log(index.toString() + ": " + item);
    index = index + 1;
}
```

### Counter-Based Alternative

```jac
items = ["a", "b", "c"];

for i=0 to i<items.length by i+=1 {
    console.log(i.toString() + ": " + items[i]);
}
```

---

## Nested For-In

```jac
matrix = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
];

for row in matrix {
    for cell in row {
        console.log(cell);
    }
}
```

---

## Break and Continue

### Break

```jac
numbers = [1, 2, 3, 4, 5];

for num in numbers {
    if num == 3 {
        break;  # Stop at 3
    }
    console.log(num);  # 1, 2
}
```

### Continue

```jac
numbers = [1, 2, 3, 4, 5];

for num in numbers {
    if num == 3 {
        continue;  # Skip 3
    }
    console.log(num);  # 1, 2, 4, 5
}
```

---

## Practical Examples

### Find Item

```jac
users = [
    { "id": 1, "name": "Alice" },
    { "id": 2, "name": "Bob" },
    { "id": 3, "name": "Charlie" }
];

targetId = 2;
found = None;

for user in users {
    if user["id"] == targetId {
        found = user;
        break;
    }
}

if found != None {
    console.log("Found: " + found["name"]);
}
```

### Check All Match

```jac
numbers = [2, 4, 6, 8, 10];
allEven = True;

for num in numbers {
    if num % 2 != 0 {
        allEven = False;
        break;
    }
}
```

### Check Any Match

```jac
numbers = [1, 3, 5, 6, 7];
hasEven = False;

for num in numbers {
    if num % 2 == 0 {
        hasEven = True;
        break;
    }
}
```

---

## In Components

```jac
def UserList() -> any {
    users = [
        { "id": 1, "name": "Alice" },
        { "id": 2, "name": "Bob" },
        { "id": 3, "name": "Charlie" }
    ];

    items = [];
    for user in users {
        items.push(
            <li key={user["id"]}>{user["name"]}</li>
        );
    }

    return <ul>{items}</ul>;
}
```

**Note:** For JSX rendering, `.map()` is often cleaner:

```jac
def UserList() -> any {
    users = [/* ... */];

    def renderUser(user: dict, index: int) -> any {
        return <li key={user["id"]}>{user["name"]}</li>;
    }

    return <ul>{users.map(renderUser)}</ul>;
}
```

---

## Summary

| Pattern           | Syntax                               |
| ----------------- | ------------------------------------ |
| Basic             | `for item in items { }`              |
| Access properties | `for user in users { user["name"] }` |
| Break             | `break`                              |
| Continue          | `continue`                           |
| With index        | Use counter-based loop               |

---

## Next

- [While Loops](./03-while-loops.md)
