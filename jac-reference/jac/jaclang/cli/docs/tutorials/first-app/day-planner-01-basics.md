# Day Planner 1: Your First Lines of Jac

**Outcome:** Your First Lines of Jac. **Prerequisite:** [installation](../../quick-guide/install.md).

Work through the examples in order. Partial snippets extend the current file; blocks labeled complete contain the replacement file for that stage.

## Part 1: Your First Lines of Jac

Jac is a programming language whose compiler can generate Python bytecode, ES JavaScript, and native binaries. Its design is rooted in Python, so if you have Python experience much of Jac will feel familiar, with deliberate differences: curly braces replace indentation for block scoping, semicolons terminate statements, and the language has built-in support for graphs, AI, and full-stack web development. This part covers the syntax this project needs; depth lives in [Jac Fundamentals](../language/basics.md).

**Hello, World**

Create a file called `hello.jac`:

```jac
with entry {
    print("Hello, World!");
}
```

Run it:

```bash
jac hello.jac
```

In Jac, any free-floating code in a module must live inside a `with entry { }` block. These blocks execute when you run a `.jac` file as a script, and also at the point it's imported, like top-level code in Python. Jac makes module-level code an explicit, visible choice so side effects on import are always intentional.

**Variables and Types**

Jac has four basic scalar types: `str`, `int`, `float`, and `bool`. You can optionally annotate a variable's type, or let Jac infer it from the assigned value:

```jac
with entry {
    name: str = "My Day Planner";
    version: int = 1;
    rating: float = 4.5;
    ready: bool = True;

    # Type can be inferred from the value
    greeting = f"Welcome to {name} v{version}!";
    print(greeting);
}
```

Jac supports **f-strings** for string interpolation (just like Python), **comments** with `#`, and introduces **block comments** with `#* ... *#`:

```jac
# This is a line comment

#* This is a
   block comment *#
```

**Functions**

Functions use the familiar `def` keyword. Unlike Python, both parameters and return values require type annotations. This strictness pays off in Part 5, where type signatures become the specification that guides the AI's output:

```jac
def greet(name: str) -> str {
    return f"Good morning, {name}! Let's plan your day.";
}

def add(a: int, b: int) -> int {
    return a + b;
}

with entry {
    print(greet("Alice"));
    print(add(2, 3));  # 5
}
```

Functions without a return statement implicitly return `None`; the `-> None` annotation is optional.

**Control Flow**

Jac uses curly braces `{}` for all blocks, so indentation is purely cosmetic:

```jac
def check_time(hour: int) -> str {
    if hour < 12 {
        return "Good morning!";
    } elif hour < 17 {
        return "Good afternoon!";
    } else {
        return "Good evening!";
    }
}

with entry {
    # For loop over a list
    tasks = ["Buy groceries", "Team standup", "Go running"];
    for task in tasks {
        print(f"- {task}");
    }

    # Range-based loop
    for i in range(5) {
        print(i);  # 0, 1, 2, 3, 4
    }

    # While loop
    count = 3;
    while count > 0 {
        print(f"Countdown: {count}");
        count -= 1;
    }

    # Ternary expression
    hour = 10;
    mood = "energized" if hour < 12 else "tired";
    print(mood);
}
```

Jac also provides `switch`/`case` for value branching and Python-style `match`/`case` for structural pattern matching. This project doesn't need either; [Jac Fundamentals](../language/basics.md) covers both.

**Classes and Objects**

Jac supports Python-style classes with the `class` keyword (explicit `self` in every method signature, a manual `init` that assigns each parameter). This tutorial uses Jac's **`obj`** instead: fields declared with `has` are automatically initialized (like a dataclass), and `self` is implicitly available in methods without being listed in parameters.

!!! note "Why `obj`?"
    Python's `dataclass` decorator was an admission that traditional classes have too much boilerplate for simple data types. Jac's `obj` builds this idea into the language itself. For a deeper dive, see [Dataclasses: Python's Admission That Classes Are Broken](https://www.mars.ninja/blog/2025/10/25/dataclasses-and-jac-objects/).

```jac
obj Animal {
    has name: str,
        sound: str;

    def speak -> str {
        return f"{self.name} says {self.sound}!";
    }
}

with entry {
    dog = Animal(name="Rex", sound="Woof");
    print(dog.speak());  # Rex says Woof!
}
```

Fields listed in `has` become constructor parameters automatically, so there's no `init` method to write for simple cases. Throughout this tutorial, we'll use `obj` for plain data types and `node` (introduced in Part 2) for data that lives in the graph.

**What You Learned**

- **`with entry { }`** -- program entry point
- **Types**: `str`, `int`, `float`, `bool`
- **`def`** -- function declaration with typed parameters and return types
- **Control flow**: `if` / `elif` / `else`, `for`, `while` -- all with braces
- **`obj`** -- Jac data types with `has` fields and implicit `self`
- **`#`** -- line comments (`#* block comments *#`)
- **f-strings** -- string interpolation with `f"...{expr}..."`
- **Ternary** -- `value if condition else other`

For a quick reference of all Jac syntax, see the [Syntax Cheatsheet](../../reference/language/syntax-cheatsheet.md).

!!! example "Try It Yourself"
    Write a `plan_day` function that takes a list of task names and an `hour: int`, and returns a formatted string like `"Good morning! Today's tasks: Buy groceries, Go running"`. Use `check_time` for the greeting and a `for` loop to build the task list.

---

## Checkpoint

Run `jac run hello.jac` and confirm it prints `Hello, World!`. Change the greeting, run it again, and check that the output changes. The complete starting file appears under **Hello, World**.

[Lesson overview](build-ai-day-planner.md) · [Next lesson](day-planner-02-nodes.md)
