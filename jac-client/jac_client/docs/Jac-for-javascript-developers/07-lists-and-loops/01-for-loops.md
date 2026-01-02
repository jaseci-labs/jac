# For Loops

Learn counter-based for loops in Jac.

---

## Syntax

### JavaScript

```javascript
for (let i = 0; i < 5; i++) {
  console.log(i);
}
```

### Jac

```jac
for i=0 to i<5 by i+=1 {
    console.log(i);
}
```

**Format:** `for init to condition by increment { }`

---

## Basic Examples

### Count 0 to 4

```jac
for i=0 to i<5 by i+=1 {
    console.log(i);  # 0, 1, 2, 3, 4
}
```

### Count 1 to 5

```jac
for i=1 to i<=5 by i+=1 {
    console.log(i);  # 1, 2, 3, 4, 5
}
```

### Custom Start

```jac
for i=10 to i<20 by i+=1 {
    console.log(i);  # 10, 11, ..., 19
}
```

---

## Custom Step

### Skip by 2

```jac
for i=0 to i<10 by i+=2 {
    console.log(i);  # 0, 2, 4, 6, 8
}
```

### Skip by 5

```jac
for i=0 to i<100 by i+=5 {
    console.log(i);  # 0, 5, 10, ..., 95
}
```

### Skip by 10

```jac
for i=0 to i<=100 by i+=10 {
    console.log(i);  # 0, 10, 20, ..., 100
}
```

---

## Countdown (Decrement)

```jac
for i=5 to i>=0 by i-=1 {
    console.log(i);  # 5, 4, 3, 2, 1, 0
}

for i=10 to i>0 by i-=1 {
    console.log(i);  # 10, 9, 8, ..., 1
}

# Countdown by 2
for i=10 to i>=0 by i-=2 {
    console.log(i);  # 10, 8, 6, 4, 2, 0
}
```

---

## Building Arrays

```jac
def BuildArray() -> any {
    items = [];

    for i=0 to i<5 by i+=1 {
        items.push("Item " + i.toString());
    }

    # items = ["Item 0", "Item 1", "Item 2", "Item 3", "Item 4"]
    return <ul>{items.map(lambda x: str, idx: int -> any {
        return <li key={idx}>{x}</li>;
    })}</ul>;
}
```

---

## Nested Loops

```jac
def MultiplicationTable() -> any {
    rows = [];

    for i=1 to i<=5 by i+=1 {
        cols = [];
        for j=1 to j<=5 by j+=1 {
            cols.push(
                <td key={j}>{i * j}</td>
            );
        }
        rows.push(<tr key={i}>{cols}</tr>);
    }

    return (
        <table>
            <tbody>{rows}</tbody>
        </table>
    );
}
```

---

## Practical Examples

### Sum Numbers

```jac
total = 0;
for i=1 to i<=100 by i+=1 {
    total = total + i;
}
# total = 5050
```

### Factorial

```jac
def factorial(n: int) -> int {
    result = 1;
    for i=1 to i<=n by i+=1 {
        result = result * i;
    }
    return result;
}
```

### Prime Check

```jac
def isPrime(n: int) -> bool {
    if n < 2 {
        return False;
    }
    for i=2 to i<n by i+=1 {
        if n % i == 0 {
            return False;
        }
    }
    return True;
}
```

---

## No `range()` Function!

=== "Python"

    ```python
    for i in range(5):
        print(i)
    ```

=== "Jac"

    ```jac
    # range() does NOT work!
    # Use for loop instead:
    for i=0 to i<5 by i+=1 {
        console.log(i);
    }
    ```

---

## Using Loops in Components

```jac
def NumberList() -> any {
    numbers = [];

    for i=1 to i<=10 by i+=1 {
        numbers.push(i);
    }

    def renderNumber(num: int, index: int) -> any {
        return <li key={index}>{num}</li>;
    }

    return <ul>{numbers.map(renderNumber)}</ul>;
}
```

---

## Summary

| Pattern      | Syntax                     |
| ------------ | -------------------------- |
| Basic        | `for i=0 to i<5 by i+=1`   |
| Custom start | `for i=10 to i<20 by i+=1` |
| Custom step  | `for i=0 to i<10 by i+=2`  |
| Countdown    | `for i=5 to i>=0 by i-=1`  |
| Inclusive    | `for i=1 to i<=5 by i+=1`  |

---

## Next

- [For-In Loops](./02-for-in-loops.md) - Array iteration
