# Loops in JAC-Client (Onelang)

This guide covers loop syntax in JAC-Client for developers familiar with JavaScript.

> **Full Examples**: See the complete working examples at [jac-client-examples/loops](https://github.com/jaseci-labs/jac-client-examples/tree/main/loops)

---

## Important Note

!!! warning "range() does NOT work"
    The `range()` function does NOT work in JAC-Client/Onelang. Use counter-based loops instead.

---

## Key Syntax Comparison

| Language       | Syntax                      |
| -------------- | --------------------------- |
| **JavaScript** | `for(i=0; i<5; i++) {}` |
| **Python**     | `for i in range(5):`        |
| **JAC-Client** | `for i=0 to i<5 by i+=1 {}` |

---

## Basic Counter Loop

=== "JavaScript"

    ```javascript
    // Count from 0 to 4
    for (i = 0; i < 5; i++) {
      console.log(i);
    }
    ```

=== "JAC-Client"

    ```jac
    # Count from 0 to 4
    for i=0 to i<5 by i+=1 {
        print(i);
    }
    ```

**Syntax breakdown:**

- `i=0` → Start value (initialization)
- `i<5` → Condition (loop continues while true)
- `i+=1` → Increment (after each iteration)

---

## Custom Step/Increment

=== "JavaScript"

    ```javascript
    // Even numbers (step by 2)
    for (i = 0; i <= 10; i += 2) {
      console.log(i);  // 0, 2, 4, 6, 8, 10
    }
    ```

=== "JAC-Client"

    ```jac
    # Even numbers (step by 2)
    for i=0 to i<=10 by i+=2 {
        print(i);  # 0, 2, 4, 6, 8, 10
    }
    ```

---

## Countdown (Decrement)

=== "JavaScript"

    ```javascript
    // Countdown from 5 to 0
    for (i = 5; i >= 0; i--) {
      console.log(i);  // 5, 4, 3, 2, 1, 0
    }
    ```

=== "JAC-Client"

    ```jac
    # Countdown from 5 to 0
    for i=5 to i>=0 by i-=1 {
        print(i);  # 5, 4, 3, 2, 1, 0
    }
    ```

---

## For-In Loop (Arrays)

=== "JavaScript"

    ```javascript
    const fruits = ["Apple", "Banana", "Cherry"];

    for (const fruit of fruits) {
      console.log(fruit);
    }
    // or
    fruits.forEach(fruit => console.log(fruit));
    ```

=== "JAC-Client"

    ```jac
    fruits = ["Apple", "Banana", "Cherry"];

    for fruit in fruits {
        print(fruit);
    }
    ```

---

## While Loop

=== "JavaScript"

    ```javascript
    count = 0;
    while (count < 5) {
      console.log("Count:", count);
      count++;
    }
    ```

=== "JAC-Client"

    ```jac
    count = 0;
    while count < 5 {
        print("Count:", count);
        count = count + 1;
    }
    ```

---

## Nested Loops

=== "JavaScript"

    ```javascript
    // Multiplication table
    for (i = 1; i <= 3; i++) {
      for (j = 1; j <= 3; j++) {
        console.log(`${i} x ${j} = ${i * j}`);
      }
    }
    ```

=== "JAC-Client"

    ```jac
    # Multiplication table
    for i=1 to i<=3 by i+=1 {
        for j=1 to j<=3 by j+=1 {
            product = i * j;
            print(str(i) + " x " + str(j) + " = " + str(product));
        }
    }
    ```

---

## Loop with Array Index

=== "JavaScript"

    ```javascript
    const colors = ["Red", "Green", "Blue"];

    for (i = 0; i < colors.length; i++) {
      console.log(`Index ${i}: ${colors[i]}`);
    }
    ```

=== "JAC-Client"

    ```jac
    colors = ["Red", "Green", "Blue"];

    for i=0 to i<colors.length by i+=1 {
        print("Index " + str(i) + ": " + colors[i]);
    }
    ```

---

## Building Arrays with Loops

=== "JavaScript"

    ```javascript
    // Build array of squares
    squares = [];
    for (i = 1; i <= 5; i++) {
      squares.push(i * i);
    }
    // Result: [1, 4, 9, 16, 25]
    ```

=== "JAC-Client"

    ```jac
    # Build array of squares
    squares = [];
    for i=1 to i<=5 by i+=1 {
        square = i * i;
        squares = squares + [square];
    }
    # Result: [1, 4, 9, 16, 25]
    ```

---

## Quick Reference Table

| Loop Type      | JavaScript                    | JAC-Client                       |
| -------------- | ----------------------------- | -------------------------------- |
| Basic Counter  | `for(i=0; i<5; i++)`      | `for i=0 to i<5 by i+=1`         |
| Inclusive End  | `for(i=1; i<=10; i++)`    | `for i=1 to i<=10 by i+=1`       |
| Custom Step    | `for(i=0; i<10; i+=2)`    | `for i=0 to i<10 by i+=2`        |
| Countdown      | `for(i=10; i>=0; i--)`    | `for i=10 to i>=0 by i-=1`       |
| For-In (Array) | `for(const x of arr)`         | `for x in arr`                   |
| While          | `while(condition) {}`         | `while condition {}`             |

---

## Common Mistakes

```jac
#  WRONG - range() does not work
for i in range(5) {
    print(i);
}

#  CORRECT - Use counter-based loop
for i=0 to i<5 by i+=1 {
    print(i);
}

#  WRONG - i++ does not work
for i=0 to i<5 by i++ {
    print(i);
}

#  CORRECT - Use i+=1
for i=0 to i<5 by i+=1 {
    print(i);
}
```

---

## Tips

1. **Always use `i+=1`** for incrementing, not `i++`
2. **Use `i<=n`** for inclusive end (includes n)
3. **Use `i<n`** for exclusive end (stops before n)
4. **Use `i-=1`** for countdown loops
5. **For arrays**, use `for item in array` when you don't need the index
