# 🔄 Loops in JAC-Client (Onelang)

Learn how to use loops in JAC-Client with interactive examples for beginners.

## ⚠️ Important Note

**`range()` does NOT work in JAC-Client/Onelang!**

Use counter-based loops instead.

## 🔑 Key Syntax Comparison

| Language       | Syntax                      |
| -------------- | --------------------------- |
| **JavaScript** | `for(let i=0; i<5; i++) {}` |
| **Python**     | `for i in range(5):`        |
| **JAC-Client**   | `for i=0 to i<5 by i+=1 {}` |

## 📋 Loop Syntax Breakdown

```
for i=0 to i<5 by i+=1 {
    // loop body
}
```

- `i=0` → **Start value** (initialization)
- `i<5` → **Condition** (loop continues while true)
- `i+=1` → **Increment** (executed after each iteration)

## 📚 Examples Covered

### 1. Basic Counter Loop

```jac
# Count from 0 to 4
for i=0 to i<5 by i+=1 {
    console.log(i);
}
```

### 2. Different Start Values

```jac
# Loop from 1 to 5 (inclusive)
for i=1 to i<=5 by i+=1 {
    console.log(i);  # Prints: 1, 2, 3, 4, 5
}

# Loop from 10 to 15
for i=10 to i<=15 by i+=1 {
    console.log(i);
}
```

### 3. Custom Step/Increment

```jac
# Even numbers (step by 2)
for i=0 to i<=10 by i+=2 {
    console.log(i);  # Prints: 0, 2, 4, 6, 8, 10
}

# Step by 5
for i=0 to i<=20 by i+=5 {
    console.log(i);  # Prints: 0, 5, 10, 15, 20
}
```

### 4. Countdown (Decrement)

```jac
# Countdown from 5 to 0
for i=5 to i>=0 by i-=1 {
    console.log(i);  # Prints: 5, 4, 3, 2, 1, 0
}

# Countdown by 2
for i=10 to i>=0 by i-=2 {
    console.log(i);  # Prints: 10, 8, 6, 4, 2, 0
}
```

### 5. For-In Loop (Arrays)

```jac
# Iterate array elements
let fruits = ["Apple", "Banana", "Cherry"];

for fruit in fruits {
    console.log(fruit);
}
# Prints: Apple, Banana, Cherry

# Sum numbers
let total = 0;
for num in [10, 20, 30] {
    total = total + num;
}
```

### 6. Nested Loops

```jac
# Multiplication table
for i=1 to i<=5 by i+=1 {
    for j=1 to j<=5 by j+=1 {
        let product = i * j;
        console.log(i.toString() + " x " + j.toString() + " = " + product.toString());
    }
}

# Grid coordinates
for row=0 to row<3 by row+=1 {
    for col=0 to col<3 by col+=1 {
        console.log("[" + row.toString() + "," + col.toString() + "]");
    }
}
```

### 7. While Loop

```jac
# Basic while loop
let count = 0;
while count < 5 {
    console.log("Count:", count);
    count = count + 1;
}

# Double until condition
let value = 1;
while value < 100 {
    console.log(value);
    value = value * 2;
}
```

### 8. Building Arrays with Loops

```jac
# Build array of squares
let squares = [];
for i=1 to i<=10 by i+=1 {
    let square = i * i;
    squares = squares.concat([square]);
}
# Result: [1, 4, 9, 16, 25, 36, 49, 64, 81, 100]

# Build even numbers
let evens = [];
for i=2 to i<=20 by i+=2 {
    evens = evens.concat([i]);
}
# Result: [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
```

### 9. Loop with Index + Array Access

```jac
let colors = ["Red", "Green", "Blue", "Yellow", "Purple"];

# Forward iteration with index
for i=0 to i<colors.length by i+=1 {
    console.log("Index " + i.toString() + ": " + colors[i]);
}

# Reverse iteration
for i=colors.length-1 to i>=0 by i-=1 {
    console.log(colors[i]);
}

# Every other element
for i=0 to i<colors.length by i+=2 {
    console.log(colors[i]);  # Prints: Red, Blue, Purple
}
```

### 10. Practical Examples

```jac
# Sum 1 to 100
let sum = 0;
for i=1 to i<=100 by i+=1 {
    sum = sum + i;
}
# Result: 5050

# Factorial calculation
let factorial = 1;
for i=1 to i<=5 by i+=1 {
    factorial = factorial * i;
}
# Result: 120 (5!)

# Generate star pattern
for i=1 to i<=5 by i+=1 {
    let stars = "";
    for j=0 to j<i by j+=1 {
        stars = stars + "⭐";
    }
    console.log(stars);
}
# Output:
# ⭐
# ⭐⭐
# ⭐⭐⭐
# ⭐⭐⭐⭐
# ⭐⭐⭐⭐⭐
```

## 🚀 Quick Reference Table

| Loop Type      | JAC-Client Syntax                  |
| -------------- | -------------------------------- |
| Basic Counter  | `for i=0 to i<5 by i+=1 {...}`   |
| Inclusive End  | `for i=1 to i<=10 by i+=1 {...}` |
| Custom Step    | `for i=0 to i<10 by i+=2 {...}`  |
| Countdown      | `for i=10 to i>=0 by i-=1 {...}` |
| For-In (Array) | `for item in array {...}`        |
| While          | `while condition {...}`          |

## 🏃 Running the Example

```bash
cd loop-utils
npm install
jac serve app.jac
```

Then open your browser to view the interactive examples!

## ❌ What NOT to Use

```jac
# ❌ WRONG - range() doesn't work in Onelang!
for i in range(5) {
    console.log(i);
}

# ✅ CORRECT - Use counter-based loop
for i=0 to i<5 by i+=1 {
    console.log(i);
}
```

## 💡 Tips for Beginners

1. **Always use `i+=1`** for incrementing, not `i++`
2. **Use `i<=n`** for inclusive end (includes n)
3. **Use `i<n`** for exclusive end (stops before n)
4. **Use `i-=1`** for countdown loops
5. **For arrays**, use `for item in array` when you don't need the index
6. **Use counter loop** when you need the index: `for i=0 to i<arr.length by i+=1`
