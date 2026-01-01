# Operators

Learn how operators work in JAC-Client, including the key differences from JavaScript.

---

## Logical Operators

### AND, OR, NOT

| JavaScript | JAC-Client |
|-----------|------------|
| `&&` | `and` |
| `\|\|` | `or` |
| `!` | `not` |

**JavaScript:**

```javascript
if (a && b) { }
if (a || b) { }
if (!a) { }
```

**JAC-Client:**

```jac
if a and b { }
if a or b { }
if not a { }
```

### In Conditionals

```jac
# AND - both must be true
if isLoggedIn and hasPermission {
    showDashboard();
}

# OR - either can be true
if isAdmin or isModerator {
    showControls();
}

# NOT - negate condition
if not isLoading {
    showContent();
}

# Combined
if (isLoggedIn and hasPermission) or isAdmin {
    allowAccess();
}
```

### In JSX

```jac
# AND for conditional rendering
{isLoggedIn and <Dashboard />}
{count > 0 and <p>Count: {count}</p>}
{items.length > 0 and <ItemList items={items} />}

# OR for default values
{username or "Guest"}
{data or "No data available"}

# NOT
{not isLoading and <Content />}
{not error and <SuccessMessage />}
```

---

## Comparison Operators

### Equality

| JavaScript | JAC-Client | Notes |
|-----------|------------|-------|
| `===` | `==` | Equality check |
| `!==` | `!=` | Inequality check |
| `==` | `==` | Same as `===` in JAC |

**JavaScript:**

```javascript
if (a === b) { }
if (a !== b) { }
```

**JAC-Client:**

```jac
if a == b { }
if a != b { }
```

### Comparison

| Operator | Meaning |
|----------|---------|
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

```jac
if age >= 18 {
    console.log("Adult");
}

if count < 0 {
    console.log("Negative");
}

if price <= maxPrice {
    console.log("Affordable");
}
```

---

## Arithmetic Operators

Same as JavaScript:

| Operator | Meaning |
|----------|---------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |
| `%` | Modulo (remainder) |

```jac
sum = a + b
difference = a - b
product = a * b
quotient = a / b
remainder = a % b

# Increment (no ++ operator)
count = count + 1

# Decrement
count = count - 1
```

### No `++` or `--` Operators

**JavaScript:**

```javascript
count++;
count--;
```

**JAC-Client:**

```jac
count = count + 1
count = count - 1

# Or in for loops
for i=0 to i<10 by i+=1 { }
```

---

## Assignment Operators

| Operator | Meaning |
|----------|---------|
| `=` | Assign |
| `+=` | Add and assign |
| `-=` | Subtract and assign |
| `*=` | Multiply and assign |
| `/=` | Divide and assign |

```jac
count = 0
count += 1   # count = count + 1
count -= 1   # count = count - 1
count *= 2   # count = count * 2
count /= 2   # count = count / 2
```

---

## String Operators

### Concatenation

```jac
# Use + for string concatenation
greeting = "Hello, " + name + "!"

# Multiple concatenation
fullName = firstName + " " + lastName

# With numbers (convert to string)
message = "Count: " + count.toString()
```

### No Template Literals

**JavaScript:**

```javascript
const message = `Hello, ${name}!`;
```

**JAC-Client:**

```jac
message = "Hello, " + name + "!"
```

---

## Ternary Operator (Python Style!)

This is one of the **biggest differences** from JavaScript.

**JavaScript:**

```javascript
result = condition ? valueIfTrue : valueIfFalse;
```

**JAC-Client:**

```jac
result = (valueIfTrue) if condition else (valueIfFalse)
```

### Examples

```jac
# Simple
status = ("Active") if isActive else ("Inactive")

# In JSX - WRAP IN PARENTHESES!
{(<LoggedIn />) if isLoggedIn else (<LoggedOut />)}

# Nested
grade = ("A") if score >= 90 else (("B") if score >= 80 else ("C"))

# With expressions
price = (originalPrice * 0.9) if hasDiscount else (originalPrice)
```

---

## Nullish Coalescing

**JavaScript:**

```javascript
const value = data ?? "default";
```

**JAC-Client:**

```jac
# Use explicit None check
value = data if data != None else "default"

# Or use 'or' for falsy values
value = data or "default"
```

**Note:** `or` treats empty string, 0, and False as falsy. Use explicit None check when needed.

---

## Optional Chaining Alternative

**JavaScript:**

```javascript
const city = user?.address?.city;
```

**JAC-Client:**

```jac
# Manual checking
if user != None and user["address"] != None {
    city = user["address"]["city"];
} else {
    city = None;
}

# Or with try/except
try {
    city = user["address"]["city"];
} except {
    city = None;
}
```

---

## Type Checking

```jac
# Check type with typeof (JavaScript interop)
if typeof(value) == "string" {
    console.log("It's a string");
}

# Check for None
if value == None {
    console.log("Value is None");
}

# Check for boolean
if value == True or value == False {
    console.log("It's a boolean");
}
```

---

## Operator Precedence

From highest to lowest:

1. `()` - Parentheses
2. `not` - Logical NOT
3. `*`, `/`, `%` - Multiplication, division, modulo
4. `+`, `-` - Addition, subtraction
5. `<`, `>`, `<=`, `>=` - Comparison
6. `==`, `!=` - Equality
7. `and` - Logical AND
8. `or` - Logical OR

```jac
# Example
result = a + b * c          # b * c first, then + a
result = (a + b) * c        # a + b first, then * c
result = a and b or c       # a and b first, then or c
result = a or b and c       # b and c first, then or a
```

---

## Summary

| Category | JavaScript | JAC-Client |
|----------|-----------|------------|
| AND | `&&` | `and` |
| OR | `\|\|` | `or` |
| NOT | `!` | `not` |
| Equality | `===` | `==` |
| Inequality | `!==` | `!=` |
| Ternary | `a ? b : c` | `(b) if a else (c)` |
| Increment | `++` | `+= 1` |
| Decrement | `--` | `-= 1` |
| Template | `` `${x}` `` | `"" + x` |
| Nullish | `??` | `if x != None else` |

---

## Next

- [Control Flow](05-control-flow.md) - if/elif/else and loops
