# While Loops

Learn while loop syntax in Jac.

---

## Syntax

### JavaScript

```javascript
while (condition) {
  // code
}
```

### Jac

```jac
while condition {
    # code
}
```

**Note:** No parentheses around condition.

---

## Basic Examples

### Simple Counter

```jac
count = 0;
while count < 5 {
    console.log(count);
    count = count + 1;
}
# Output: 0, 1, 2, 3, 4
```

### Countdown

```jac
count = 5;
while count > 0 {
    console.log(count);
    count = count - 1;
}
# Output: 5, 4, 3, 2, 1
```

---

## With Boolean Condition

```jac
isRunning = True;
attempts = 0;

while isRunning {
    attempts = attempts + 1;
    console.log("Attempt " + attempts.toString());

    if attempts >= 3 {
        isRunning = False;
    }
}
```

---

## Break and Continue

### Break

```jac
count = 0;
while True {
    count = count + 1;
    console.log(count);

    if count >= 5 {
        break;  # Exit loop
    }
}
```

### Continue

```jac
count = 0;
while count < 10 {
    count = count + 1;

    if count % 2 == 0 {
        continue;  # Skip even numbers
    }

    console.log(count);  # 1, 3, 5, 7, 9
}
```

---

## Practical Examples

### Wait for Condition

```jac
def waitForReady() -> None {
    attempts = 0;
    maxAttempts = 5;
    ready = False;

    while not ready and attempts < maxAttempts {
        attempts = attempts + 1;
        ready = checkIfReady();

        if not ready {
            console.log("Not ready, attempt " + attempts.toString());
        }
    }

    if ready {
        console.log("Ready!");
    } else {
        console.log("Gave up after " + maxAttempts.toString() + " attempts");
    }
}
```

### Process Queue

```jac
queue = [1, 2, 3, 4, 5];

while queue.length > 0 {
    item = queue.shift();  # Remove first item
    console.log("Processing: " + item.toString());
}
```

### Find Value

```jac
numbers = [3, 7, 2, 9, 1, 5];
target = 9;
index = 0;
found = False;

while index < numbers.length and not found {
    if numbers[index] == target {
        found = True;
        console.log("Found at index " + index.toString());
    }
    index = index + 1;
}

if not found {
    console.log("Not found");
}
```

---

## Infinite Loop (Intentional)

```jac
# Game loop pattern
while True {
    handleInput();
    updateGame();
    render();

    if shouldExit {
        break;
    }
}
```

---

## Avoid Infinite Loops

Always ensure the condition will eventually be false:

```jac
# BAD - Infinite loop!
count = 0;
while count < 5 {
    console.log(count);
    # Forgot to increment count!
}

# GOOD
count = 0;
while count < 5 {
    console.log(count);
    count = count + 1;  # This ensures loop ends
}
```

---

## While vs For

### Use While When

- Unknown number of iterations
- Complex stop condition
- Processing until done

### Use For When

- Known number of iterations
- Iterating over arrays
- Counter-based loops

```jac
# While: unknown iterations
while not isComplete {
    processNext();
}

# For: known iterations
for i=0 to i<10 by i+=1 {
    processItem(i);
}
```

---

## Summary

| Pattern             | Syntax                |
| ------------------- | --------------------- |
| Basic               | `while condition { }` |
| Infinite            | `while True { }`      |
| Break               | `break`               |
| Continue            | `continue`            |
| Multiple conditions | `while a and b { }`   |

---

## Next

- [Array Methods](./04-array-methods.md) - map, filter, find, reduce
