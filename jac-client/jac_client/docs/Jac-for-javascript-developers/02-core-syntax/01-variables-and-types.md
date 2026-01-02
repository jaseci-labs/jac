# Variables and Types

Learn how variables and data types work in Jac.

---

## Variables - No `let` or `const`

In Jac, you don't need `let`, `const`, or `var`. Just assign directly:

=== "JavaScript"

    ```javascript
    const name = "John";
    let count = 0;
    const isActive = true;
    var legacy = "old";
    ```

=== "Jac"

    ```jac
    name = "John"
    count = 0
    isActive = True
    legacy = "old"
    ```

### State Variables

Same pattern for React state:

=== "JavaScript"

    ```javascript
    const [count, setCount] = useState(0);
    const [name, setName] = useState("");
    const [items, setItems] = useState([]);
    ```

=== "Jac"

    ```jac
    [count, setCount] = useState(0);
    [name, setName] = useState("");
    [items, setItems] = useState([]);
    ```

---

## Data Types

### Booleans - Capitalized!

=== "JavaScript"

    ```javascript
    const isActive = true;
    const isHidden = false;
    ```

=== "Jac"

    ```jac
    isActive = True
    isHidden = False
    ```

### Null - Use `None`

=== "JavaScript"

    ```javascript
    const data = null;
    const user = undefined;
    ```

=== "Jac"

    ```jac
    data = None
    user = None  # undefined is also None
    ```

### Checking for None

```jac
if data == None {
    console.log("No data");
}

# Or
if data != None {
    console.log("Has data");
}
```

---

## Type Annotations

Jac supports optional type annotations:

```jac
# Basic types
name: str = "John"
age: int = 25
price: float = 19.99
isActive: bool = True

# Complex types
items: list = [1, 2, 3]
user: dict = { "name": "John", "age": 25 }

# Any type (flexible)
data: any = someValue
```

### Common Types

| Type    | Description       | Example              |
| ------- | ----------------- | -------------------- |
| `str`   | String            | `"hello"`            |
| `int`   | Integer           | `42`                 |
| `float` | Decimal           | `3.14`               |
| `bool`  | Boolean           | `True`, `False`      |
| `list`  | Array             | `[1, 2, 3]`          |
| `dict`  | Object/Dictionary | `{ "key": "value" }` |
| `any`   | Any type          | Flexible             |
| `None`  | No type/null      | `None`               |

---

## Objects/Dictionaries

### Key Difference: Quoted Keys

In Jac, object keys **must be quoted strings**:

=== "JavaScript"

    ```javascript
    const user = { name: "John", age: 25 };
    const style = { padding: "10px", margin: "5px" };
    ```

=== "Jac"

    ```jac
    user = { "name": "John", "age": 25 }
    style = { "padding": "10px", "margin": "5px" }
    ```

### Property Access - Bracket Notation

Use bracket notation to access properties:

=== "JavaScript"

    ```javascript
    const name = user.name;
    const age = user.age;
    ```

=== "Jac"

    ```jac
    name = user["name"]
    age = user["age"]
    ```

**Note:** Dot notation (`user.name`) may work but bracket notation is recommended.

### Nested Objects

```jac
user = {
    "name": "John",
    "address": {
        "city": "New York",
        "zip": "10001"
    },
    "tags": ["developer", "designer"]
}

# Access nested properties
city = user["address"]["city"]
firstTag = user["tags"][0]
```

---

## Arrays

Arrays work similarly to JavaScript:

```jac
# Create arrays
numbers = [1, 2, 3, 4, 5]
names = ["Alice", "Bob", "Charlie"]
mixed = [1, "two", True, None]

# Access elements
first = numbers[0]
last = numbers[numbers.length - 1]

# Array methods
numbers.push(6)
removed = numbers.pop()
combined = numbers.concat([7, 8, 9])
```

### No Spread Operator for Arrays

=== "JavaScript"

    ```javascript
    const newArr = [...arr, 4, 5];
    ```

=== "Jac"

    ```jac
    newArr = arr.concat([4, 5])
    ```

### Object Spread Uses `**`

=== "JavaScript"

    ```javascript
    const newObj = { ...obj, newKey: "value" };
    ```

=== "Jac"

    ```jac
    newObj = { **obj, "newKey": "value" }
    ```

---

## String Interpolation

Jac uses string concatenation:

=== "JavaScript"

    ```javascript
    const message = `Hello, ${name}! You are ${age} years old.`;
    ```

=== "Jac"

    ```jac
    message = "Hello, " + name + "! You are " + age.toString() + " years old."
    ```

---

## Constants (Global Variables)

Use `glob` for global constants:

```jac
cl {
    glob API_URL: str = "https://api.example.com"
    glob MAX_ITEMS: int = 100
    glob DEBUG: bool = False

    def app() -> any {
        console.log(API_URL);
        return <div>App</div>;
    }
}
```

### Exporting Constants

Use `glob:pub` to export:

```jac
glob:pub API_URL: str = "https://api.example.com"
glob:pub MAX_ITEMS: int = 100
```

---

## Type Coercion

```jac
# String to number
numStr = "42"
num = parseInt(numStr)  # 42

# Number to string
age = 25
ageStr = age.toString()  # "25"

# Boolean coercion
if items.length {  # truthy if length > 0
    console.log("Has items");
}
```

---

## Summary

| Concept              | JavaScript     | Jac               |
| -------------------- | -------------- | ----------------- |
| Variable declaration | `const x = 5`  | `x = 5`           |
| Boolean true         | `true`         | `True`            |
| Boolean false        | `false`        | `False`           |
| Null                 | `null`         | `None`            |
| Object creation      | `{ key: val }` | `{ "key": val }`  |
| Property access      | `obj.key`      | `obj["key"]`      |
| Object spread        | `{...obj}`     | `{**obj}`         |
| Array spread         | `[...arr]`     | `arr.concat([])`  |
| Template string      | `` `${var}` `` | `"" + var`        |
| Type annotation      | TypeScript     | `name: str = "x"` |

---

## Next

- [Functions](02-functions.md) - Learn function syntax
