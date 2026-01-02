xxaa# Control Flow

Learn if/elif/else statements and loop syntax in Jac.

---

## If/Elif/Else Statements

### Basic Syntax

=== "JavaScript"

    ```javascript
    if (condition) {
      // code
    } else if (other) {
      // code
    } else {
      // code
    }
    ```

=== "Jac"

    ```jac
    if condition {
        # code
    } elif other {
        # code
    } else {
        # code
    }
    ```

### Key Differences

1. No parentheses around condition
2. Use `elif` instead of `else if`
3. Use `#` for comments

### Examples

```jac
# Simple if
if isLoggedIn {
    showDashboard();
}

# If-else
if count > 0 {
    console.log("Positive");
} else {
    console.log("Zero or negative");
}

# If-elif-else
if score >= 90 {
    grade = "A";
} elif score >= 80 {
    grade = "B";
} elif score >= 70 {
    grade = "C";
} else {
    grade = "F";
}
```

### With Logical Operators

```jac
if isLoggedIn and hasPermission {
    showAdmin();
}

if isError or isLoading {
    showSpinner();
}

if not isValid {
    showError();
}

if (age >= 18 and hasLicense) or isExempt {
    allowDriving();
}
```

---

## For Loops

### Counter-Based For Loop

=== "JavaScript"

    ```javascript
    for (let i = 0; i < 5; i++) {
      console.log(i);
    }
    ```

=== "Jac"

    ```jac
    for i=0 to i<5 by i+=1 {
        console.log(i);
    }
    ```

### Syntax: `for init to condition by increment`

```jac
# Basic (0 to 4)
for i=0 to i<5 by i+=1 {
    console.log(i);  # 0, 1, 2, 3, 4
}

# Start from different value
for i=10 to i<20 by i+=1 {
    console.log(i);  # 10, 11, ..., 19
}

# Custom step
for i=0 to i<10 by i+=2 {
    console.log(i);  # 0, 2, 4, 6, 8
}

# Countdown
for i=5 to i>=0 by i-=1 {
    console.log(i);  # 5, 4, 3, 2, 1, 0
}

# Larger steps
for i=0 to i<100 by i+=10 {
    console.log(i);  # 0, 10, 20, ..., 90
}
```

### Building Arrays with For Loops

```jac
items = [];
for i=0 to i<5 by i+=1 {
    items.push("Item " + i.toString());
}
# items = ["Item 0", "Item 1", "Item 2", "Item 3", "Item 4"]
```

---

## For-In Loops (Iterate Arrays)

=== "JavaScript"

    ```javascript
    for (const item of items) {
      console.log(item);
    }
    ```

=== "Jac"

    ```jac
    for item in items {
        console.log(item);
    }
    ```

### Examples

```jac
# Iterate array
fruits = ["apple", "banana", "cherry"];
for fruit in fruits {
    console.log(fruit);
}

# Sum numbers
numbers = [1, 2, 3, 4, 5];
total = 0;
for num in numbers {
    total = total + num;
}

# Process objects
users = [
    { "name": "Alice", "age": 25 },
    { "name": "Bob", "age": 30 }
];
for user in users {
    console.log(user["name"]);
}
```

### With Index

To get the index, use a counter:

```jac
items = ["a", "b", "c"];
index = 0;
for item in items {
    console.log(index.toString() + ": " + item);
    index = index + 1;
}
```

Or use a counter-based loop:

```jac
items = ["a", "b", "c"];
for i=0 to i<items.length by i+=1 {
    console.log(i.toString() + ": " + items[i]);
}
```

---

## While Loops

=== "JavaScript"

    ```javascript
    while (condition) {
      // code
    }
    ```

=== "Jac"

    ```jac
    while condition {
        # code
    }
    ```

### Examples

```jac
# Basic while
count = 0;
while count < 5 {
    console.log(count);
    count = count + 1;
}

# With condition
attempts = 0;
success = False;
while not success and attempts < 3 {
    success = tryOperation();
    attempts = attempts + 1;
}

# Infinite loop with break
while True {
    input = getInput();
    if input == "quit" {
        break;
    }
    processInput(input);
}
```

---

## Break and Continue

### Break - Exit Loop

```jac
for i=0 to i<10 by i+=1 {
    if i == 5 {
        break;  # Exit loop when i is 5
    }
    console.log(i);  # 0, 1, 2, 3, 4
}
```

### Continue - Skip Iteration

```jac
for i=0 to i<10 by i+=1 {
    if i % 2 == 0 {
        continue;  # Skip even numbers
    }
    console.log(i);  # 1, 3, 5, 7, 9
}
```

---

## Nested Loops

```jac
# Multiplication table
for i=1 to i<=3 by i+=1 {
    for j=1 to j<=3 by j+=1 {
        result = i * j;
        console.log(i.toString() + " x " + j.toString() + " = " + result.toString());
    }
}

# Nested array iteration
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

## No `range()` Function

=== "Python"

    ```python
    for i in range(5):
        print(i)
    ```

=== "Jac"

    ```jac
    # range() does NOT work!
    # Use counter-based for loop instead
    for i=0 to i<5 by i+=1 {
        console.log(i);
    }
    ```

---

## Switch/Case Alternative

Jac doesn't have switch/case. Use if/elif/else or object lookup:

=== "JavaScript"

    ```javascript
    switch (action) {
      case "add":
        return handleAdd();
      case "delete":
        return handleDelete();
      default:
        return handleDefault();
    }
    ```

=== "Jac"

    ```jac
    # Option 1: If/elif/else
    if action == "add" {
        handleAdd();
    } elif action == "delete" {
        handleDelete();
    } else {
        handleDefault();
    }

    # Option 2: Object lookup
    handlers = {
        "add": handleAdd,
        "delete": handleDelete
    };

    if action in handlers {
        handlers[action]();
    } else {
        handleDefault();
    }
    ```

---

## Early Returns

```jac
def processUser(user: dict) -> any {
    # Guard clauses
    if user == None {
        return <p>No user</p>;
    }

    if not user["active"] {
        return <p>User inactive</p>;
    }

    if user["banned"] {
        return <p>User banned</p>;
    }

    # Main logic
    return <div>
        <h1>{user["name"]}</h1>
        <p>{user["email"]}</p>
    </div>;
}
```

---

## Control Flow in Components

```jac
def UserList(users: list) -> any {
    # Early return for empty
    if users.length == 0 {
        return <p>No users found</p>;
    }

    # Build list items
    items = [];
    for user in users {
        if user["active"] {
            items.push(
                <li key={user["id"]}>
                    {user["name"]}
                </li>
            );
        }
    }

    return <ul>{items}</ul>;
}
```

---

## Summary

| Pattern     | JavaScript               | Jac                      |
| ----------- | ------------------------ | ------------------------ |
| If          | `if (cond) {}`           | `if cond {}`             |
| Else if     | `else if`                | `elif`                   |
| For counter | `for(let i=0; i<5; i++)` | `for i=0 to i<5 by i+=1` |
| For-of/in   | `for(x of arr)`          | `for x in arr`           |
| While       | `while(cond) {}`         | `while cond {}`          |
| Break       | `break`                  | `break`                  |
| Continue    | `continue`               | `continue`               |
| Switch      | `switch(x) { case: }`    | Use if/elif/else         |

---

## Next Section

- [Components](../03-components/01-basic-components.md) - Learn component patterns
