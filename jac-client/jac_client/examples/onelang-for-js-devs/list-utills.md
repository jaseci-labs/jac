# List Handling in JAC-Client (Onelang)

This guide covers array and list methods for developers familiar with JavaScript.

> **Full Examples**: See the complete working examples at [jac-client-examples/list-utils](https://github.com/jaseci-labs/jac-client-examples/tree/main/list-utils)

---

## Quick Reference

| Method        | Purpose         | React/JS                          | JAC-Client                                        |
| ------------- | --------------- | --------------------------------- | ------------------------------------------------- |
| `.map()`      | Transform items | `arr.map(x => x * 2)`             | `arr.map(lambda x -> any { return x * 2; })`      |
| `.filter()`   | Keep matching   | `arr.filter(x => x > 0)`          | `arr.filter(lambda x -> bool { return x > 0; })`  |
| `.find()`     | First match     | `arr.find(x => x.id === 1)`       | `arr.find(lambda x -> bool { return x["id"] == 1; })` |
| `.some()`     | Any match?      | `arr.some(x => x < 0)`            | `arr.some(lambda x -> bool { return x < 0; })`    |
| `.every()`    | All match?      | `arr.every(x => x > 0)`           | `arr.every(lambda x -> bool { return x > 0; })`   |
| `.reduce()`   | Aggregate       | `arr.reduce((a,x) => a+x, 0)`     | `arr.reduce(lambda a, x -> int { return a + x; }, 0)` |
| `.sort()`     | Sort items      | `arr.sort((a,b) => a - b)`        | `arr.sort(lambda a, b -> int { return a - b; })`  |

---

## Render List with .map()

=== "React"

    ```jsx
    <ul>
      {items.map((item, i) => (
        <li key={i}>{item}</li>
      ))}
    </ul>
    ```

=== "JAC-Client"

    ```jac
    <ul>
        {items.map(lambda item: str, i: int -> any {
            return <li key={i}>{item}</li>;
        })}
    </ul>
    ```

---

## Filter Array

=== "React"

    ```jsx
    // Get even numbers
    const evens = numbers.filter(n => n % 2 === 0);

    // Filter active users
    const activeUsers = users.filter(u => u.active);
    ```

=== "JAC-Client"

    ```jac
    # Get even numbers
    let evens = numbers.filter(lambda n: int -> bool { return n % 2 == 0; });

    # Filter active users
    let activeUsers = users.filter(lambda u: dict -> bool { return u["active"]; });
    ```

---

## Find, Some, Every

=== "React"

    ```jsx
    const users = [
      { name: "Alice", age: 25 },
      { name: "Bob", age: 17 },
      { name: "Charlie", age: 30 }
    ];

    // Find first adult
    const adult = users.find(u => u.age >= 18);

    // Check if any minor exists
    const hasMinor = users.some(u => u.age < 18);  // true

    // Check if all are adults
    const allAdults = users.every(u => u.age >= 18);  // false
    ```

=== "JAC-Client"

    ```jac
    let users = [
        { "name": "Alice", "age": 25 },
        { "name": "Bob", "age": 17 },
        { "name": "Charlie", "age": 30 }
    ];

    # Find first adult
    let adult = users.find(lambda u: dict -> bool { return u["age"] >= 18; });

    # Check if any minor exists
    let hasMinor = users.some(lambda u: dict -> bool { return u["age"] < 18; });  # True

    # Check if all are adults
    let allAdults = users.every(lambda u: dict -> bool { return u["age"] >= 18; });  # False
    ```

---

## Reduce (Sum/Aggregate)

=== "React"

    ```jsx
    const prices = [29.99, 9.99, 49.99];

    const total = prices.reduce((acc, price) => acc + price, 0);
    // Result: 89.97
    ```

=== "JAC-Client"

    ```jac
    let prices = [29.99, 9.99, 49.99];

    let total = prices.reduce(lambda acc: float, price: float -> float {
        return acc + price;
    }, 0);
    # Result: 89.97
    ```

---

## Chain Filter + Map

=== "React"

    ```jsx
    const products = [
      { name: "Laptop", price: 999, inStock: true },
      { name: "Mouse", price: 29, inStock: true },
      { name: "Keyboard", price: 79, inStock: false }
    ];

    // Get names of in-stock products
    const availableNames = products
      .filter(p => p.inStock)
      .map(p => p.name);
    // Result: ["Laptop", "Mouse"]
    ```

=== "JAC-Client"

    ```jac
    let products = [
        { "name": "Laptop", "price": 999, "inStock": True },
        { "name": "Mouse", "price": 29, "inStock": True },
        { "name": "Keyboard", "price": 79, "inStock": False }
    ];

    # Get names of in-stock products
    let available = products.filter(lambda p: dict -> bool { return p["inStock"]; });
    let availableNames = available.map(lambda p: dict -> str { return p["name"]; });
    # Result: ["Laptop", "Mouse"]
    ```

---

## Add/Remove Items (Immutable)

=== "React"

    ```jsx
    const [items, setItems] = useState(["A", "B", "C"]);

    // Add item
    setItems([...items, "D"]);
    // or
    setItems(items.concat(["D"]));

    // Remove by index
    setItems(items.filter((_, i) => i !== indexToRemove));
    ```

=== "JAC-Client"

    ```jac
    let (items, setItems) = useState(["A", "B", "C"]);

    # Add item
    setItems(items.concat(["D"]));

    # Remove by index
    setItems(items.filter(lambda item: str, i: int -> bool { return i != indexToRemove; }));
    ```

---

## Sort Array

=== "React"

    ```jsx
    const numbers = [42, 8, 15, 23, 4];

    // Sort ascending (mutates original!)
    numbers.sort((a, b) => a - b);  // [4, 8, 15, 23, 42]

    // Sort descending
    numbers.sort((a, b) => b - a);  // [42, 23, 15, 8, 4]

    // Safe sort (copy first)
    const sorted = [...numbers].sort((a, b) => a - b);
    ```

=== "JAC-Client"

    ```jac
    let numbers = [42, 8, 15, 23, 4];

    # Sort ascending
    numbers.sort(lambda a: int, b: int -> int { return a - b; });  # [4, 8, 15, 23, 42]

    # Sort descending
    numbers.sort(lambda a: int, b: int -> int { return b - a; });  # [42, 23, 15, 8, 4]

    # Safe sort (copy first)
    let sorted = numbers.slice().sort(lambda a: int, b: int -> int { return a - b; });
    ```

---

## Spread & Slice

=== "React"

    ```jsx
    const original = [1, 2, 3, 4, 5];

    // Copy array
    const copy = [...original];

    // Slice (start, end)
    const first3 = original.slice(0, 3);  // [1, 2, 3]
    const last2 = original.slice(-2);     // [4, 5]

    // Merge arrays
    const merged = [...original, ...[6, 7, 8]];
    ```

=== "JAC-Client"

    ```jac
    let original = [1, 2, 3, 4, 5];

    # Copy array
    let copy = [*original];

    # Slice (start, end)
    let first3 = original.slice(0, 3);  # [1, 2, 3]
    let last2 = original.slice(-2);     # [4, 5]

    # Merge arrays
    let merged = [*original, *[6, 7, 8]];
    ```

---

## Includes & IndexOf

=== "React"

    ```jsx
    const colors = ["red", "green", "blue"];

    colors.includes("red");    // true
    colors.includes("pink");   // false

    colors.indexOf("blue");    // 2
    colors.indexOf("pink");    // -1
    ```

=== "JAC-Client"

    ```jac
    let colors = ["red", "green", "blue"];

    colors.includes("red");    # True
    colors.includes("pink");   # False

    colors.indexOf("blue");    # 2
    colors.indexOf("pink");    # -1
    ```

---

## Tips

1. **Use `.concat()`** instead of `.push()` for immutable updates in state
2. **Always provide `key`** prop when mapping in JSX
3. **Use `.slice()`** to copy arrays before sorting (sort mutates!)
4. **Chain methods**: `.filter().map().slice()`
5. **Spread syntax**: Use `[*arr]` in JAC vs `[...arr]` in JS
