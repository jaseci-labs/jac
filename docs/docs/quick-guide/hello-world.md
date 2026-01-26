# Hello World

Write and run your first Jac program in 2 minutes.

---

## Your First Program

Create a file named `hello.jac`:

```jac
with entry {
    print("Hello, World!");
}
```

Run it:

```bash
jac hello.jac
```

Output:

```
Hello, World!
```

**Congratulations!** You just wrote your first Jac program.

---

## Understanding the Code

```jac
with entry {
    print("Hello, World!");
}
```

| Part | Meaning |
|------|---------|
| `with entry` | The program's starting point (like `main()` in other languages) |
| `{ }` | Code block (Jac uses braces, not indentation) |
| `print()` | Built-in function to output text |
| `;` | Statement terminator (required in Jac) |

---

## A Bit More

### Variables and Functions

```jac
def greet(name: str) -> str {
    return f"Hello, {name}!";
}

with entry {
    message = greet("Jac");
    print(message);
}
```

Output: `Hello, Jac!`

### Using Python Libraries

Jac is a Python superset - use any Python library directly:

```jac
import math;

with entry {
    result = math.sqrt(16);
    print(f"Square root of 16 is {result}");
}
```

Output: `Square root of 16 is 4.0`

### Control Flow

```jac
with entry {
    numbers = [1, 2, 3, 4, 5];

    for n in numbers {
        if n % 2 == 0 {
            print(f"{n} is even");
        } else {
            print(f"{n} is odd");
        }
    }
}
```

---

## Key Syntax Differences from Python

| Python | Jac |
|--------|-----|
| Indentation-based blocks | `{ }` braces |
| No semicolons | `;` required |
| `def func():` | `def func() { }` |
| `if x:` | `if x { }` |
| `elif` | `elif` (same) |
| `for x in y:` | `for x in y { }` |

---

## Quick AI Example

If you have `byllm` installed, try this:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

"""Translate the given text to French."""
def translate(text: str) -> str by llm();

with entry {
    result = translate("Hello, World!");
    print(result);
}
```

Output: `Bonjour, le monde!`

(Requires `OPENAI_API_KEY` environment variable)

---

## Next Steps

Ready for something more substantial?

- [Your First Graph](first-graph.md) - Learn nodes, edges, and walkers (5 min)
- [Your First App](first-app.md) - Build a complete todo application (10 min)
- [Next Steps](next-steps.md) - Choose a learning path based on your goals
