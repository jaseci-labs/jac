# Chapter 2: Environment Setup and First Program

Getting started with Jac is straightforward - you'll have your development environment ready and your first program running in just a few minutes. This chapter covers installation, IDE setup, and writing your first Jac programs.

!!! topic "Development Environment"
    Jac builds on Python's ecosystem while adding powerful new features. You'll need Python 3.12+ and can use any text editor, though VS Code provides the best experience with syntax highlighting and debugging tools.

## Installation and IDE Setup

### Installing Jac

!!! topic "System Requirements"
    - Python 3.12 or higher
    - pip package manager
    - 4GB RAM minimum (8GB recommended)
    - 500MB storage for Jac and dependencies

Installing Jac is as simple as installing any Python package:

```bash
# Install Jac from PyPI
pip install jaclang

# Verify installation
jac --version
```

For project isolation, consider using a virtual environment:

```bash
# Create virtual environment
python -m venv jac-env

# Activate it (Linux/Mac)
source jac-env/bin/activate

# Activate it (Windows)
jac-env\Scripts\activate

# Install Jac
pip install jaclang
```

### VS Code Extension

For the best development experience, install the Jac VS Code extension:

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "Jac"
4. Install the official Jac extension

Alternatively, visit the [VS Code marketplace](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension) directly.

The extension provides:

- Syntax highlighting for Jac-specific constructs
- Error detection and type checking
- Code formatting and snippets
- Graph visualization for nodes and edges

### Basic CLI Commands

```bash
# Run a Jac file
jac run filename.jac

# Get help
jac --help

# Serve as web application (advanced)
jac serve filename.jac
```

##### Jac REPL

Note: Currently, the Jac REPL feature is not available. Please use standard Jac script execution for testing and running your code.

## Project Structure Conventions

!!! topic "Clean Organization"
    Jac encourages separating interface declarations from implementations, making code more maintainable as projects grow.

As your projects grow, following these conventions will help:

```
my_project/
├── main.jac              # Main program
├── models/
│   ├── user.jac          # User interface
│   ├── user.impl.jac     # User implementation
│   └── user.test.jac     # User tests
└── utils/
    ├── helpers.jac       # Helper functions
    └── constants.jac     # Application constants
```

### Interface and Implementation Separation

!!! example "Separation Pattern"
    === "Jac"
        <!-- <div class="code-block"> -->
        ```jac
        # user.jac - Interface declaration
        obj User {
            has name: str;
            has email: str;

            def validate() -> bool;
            def get_display_name() -> str;
        }

        # user.impl.jac - Implementation
        impl User.validate {
            return "@" in self.email and len(self.name) > 0;
        }

        impl User.get_display_name {
            return f"{self.name} <{self.email}>";
        }
        ```
        <!-- </div> -->
    === "Python"
        ```python
        # Python equivalent - everything in one file
        class User:
            def __init__(self, name: str, email: str):
                self.name = name
                self.email = email

            def validate(self) -> bool:
                return "@" in self.email and len(self.name) > 0

            def get_display_name(self) -> str:
                return f"{self.name} <{self.email}>"
        ```

## Entry Blocks and Basic Execution

!!! topic "Entry Points"
    The `with entry` block is Jac's equivalent to Python's `if __name__ == "__main__":` - it defines where program execution begins.

### Understanding Entry Blocks

!!! example "Entry Block Usage"
    === "Jac"
        <div class="code-block">
        ```jac
        # Variables and functions can be defined outside entry
        glob app_name: str = "My Jac App";
        glob version: str = "1.0.0";

        def greet(name: str) -> str {
            return f"Hello, {name}!";
        }

        # Entry block - program starts here
        with entry {
            print(f"Starting {app_name} v{version}");

            user_name: str = "Alice";
            greeting: str = greet(user_name);
            print(greeting);

            print("Program finished!");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python equivalent
        app_name = "My Python App"
        version = "1.0.0"

        def greet(name: str) -> str:
            return f"Hello, {name}!"

        if __name__ == "__main__":
            print(f"Starting {app_name} v{version}")

            user_name = "Alice"
            greeting = greet(user_name)
            print(greeting)

            print("Program finished!")
        ```

### Multiple Entry Blocks

Jac allows multiple entry blocks that execute in order:

!!! example "Multiple Entries"
    === "Jac"
        <div class="code-block">
        ```jac
        # setup.jac - Multiple entry blocks execute in sequence
        glob counter: int = 0;

        # First entry block
        with entry {
            print("Initialization phase");
            counter = 1;
        }

        # Second entry block
        with entry {
            print("Processing phase");
            counter += 1;
            print(f"Counter is now: {counter}");
        }

        # Third entry block
        with entry {
            print("Cleanup phase");
            print(f"Final counter value: {counter}");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python - need to structure manually
        counter = 0

        def initialization():
            global counter
            print("Initialization phase")
            counter = 1

        def processing():
            global counter
            print("Processing phase")
            counter += 1
            print(f"Counter is now: {counter}")

        def cleanup():
            print("Cleanup phase")
            print(f"Final counter value: {counter}")

        if __name__ == "__main__":
            initialization()
            processing()
            cleanup()
        ```

## Basic Calculator Program

Let's build a simple calculator to demonstrate Jac's syntax:

!!! example "Simple Calculator"
    === "Jac"
        <div class="code-block">
        ```jac
        # calculator.jac
        def add(a: float, b: float) -> float {
            return a + b;
        }

        def subtract(a: float, b: float) -> float {
            return a - b;
        }

        def multiply(a: float, b: float) -> float {
            return a * b;
        }

        def divide(a: float, b: float) -> float | str {
            if b == 0.0 {
                return "Error: Cannot divide by zero!";
            }
            return a / b;
        }

        def calculate(operation: str, x: float, y: float) -> float | str {
            match operation {
                case "add": return add(x, y);
                case "sub": return subtract(x, y);
                case "mul": return multiply(x, y);
                case "div": return divide(x, y);
                case _:
                    return f"Unknown operation: {operation}";
            }
        }

        with entry {
            print("=== Simple Calculator ===");

            # Test calculations
            num1: float = 10.0;
            num2: float = 3.0;

            print(f"{num1} + {num2} = {calculate('add', num1, num2)}");
            print(f"{num1} - {num2} = {calculate('sub', num1, num2)}");
            print(f"{num1} * {num2} = {calculate('mul', num1, num2)}");
            print(f"{num1} / {num2} = {calculate('div', num1, num2)}");

            # Test division by zero
            print(f"{num1} / 0 = {calculate('div', num1, 0.0)}");
        }
        ```
        </div>
    === "Python"
        ```python
        # calculator.py
        def add(a: float, b: float) -> float:
            return a + b

        def subtract(a: float, b: float) -> float:
            return a - b

        def multiply(a: float, b: float) -> float:
            return a * b

        def divide(a: float, b: float) -> float:
            if b == 0.0:
                print("Error: Cannot divide by zero!")
                return 0.0
            return a / b

        def calculate(operation: str, x: float, y: float) -> float:
            match operation:
                case "add": return add(x, y)
                case "sub": return subtract(x, y)
                case "mul": return multiply(x, y)
                case "div": return divide(x, y)
                case _:
                    print(f"Unknown operation: {operation}")
                    return 0.0

        if __name__ == "__main__":
            print("=== Simple Calculator ===")

            # Test calculations
            num1 = 10.0
            num2 = 3.0

            print(f"{num1} + {num2} = {calculate('add', num1, num2)}")
            print(f"{num1} - {num2} = {calculate('sub', num1, num2)}")
            print(f"{num1} * {num2} = {calculate('mul', num1, num2)}")
            print(f"{num1} / {num2} = {calculate('div', num1, num2)}")

            # Test division by zero
            print(f"{num1} / 0 = {calculate('div', num1, 0.0)}")
        ```

**Output:**
```
=== Simple Calculator ===
10.0 + 3.0 = 13.0
10.0 - 3.0 = 7.0
10.0 * 3.0 = 30.0
10.0 / 3.0 = 3.3333333333333335
Error: Cannot divide by zero!
10.0 / 0 = 0.0
```

### Enhanced Calculator with Object-Oriented Design

!!! example "OOP Calculator"
    === "Jac"
        <div class="code-block">
        ```jac
        # oop_calculator.jac
        obj Calculator {
            has history: list[str] = [];

            def add(a: float, b: float) -> float {
                result: float = a + b;
                self.history.append(f"{a} + {b} = {result}");
                return result;
            }

            def subtract(a: float, b: float) -> float {
                result: float = a - b;
                self.history.append(f"{a} - {b} = {result}");
                return result;
            }

            def get_history() -> list[str] {
                return self.history;
            }

            def clear_history() {
                self.history = [];
            }
        }

        with entry {
            calc = Calculator();

            # Perform calculations
            result1: float = calc.add(5.0, 3.0);
            result2: float = calc.subtract(10.0, 4.0);

            print(f"Results: {result1}, {result2}");

            # Show history
            print("Calculation History:");
            for entry in calc.get_history() {
                print(f"  {entry}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        # oop_calculator.py
        class Calculator:
            def __init__(self):
                self.history = []

            def add(self, a: float, b: float) -> float:
                result = a + b
                self.history.append(f"{a} + {b} = {result}")
                return result

            def subtract(self, a: float, b: float) -> float:
                result = a - b
                self.history.append(f"{a} - {b} = {result}")
                return result

            def get_history(self):
                return self.history

            def clear_history(self):
                self.history = []

        if __name__ == "__main__":
            calc = Calculator()

            # Perform calculations
            result1 = calc.add(5.0, 3.0)
            result2 = calc.subtract(10.0, 4.0)

            print(f"Results: {result1}, {result2}")

            # Show history
            print("Calculation History:")
            for entry in calc.get_history():
                print(f"  {entry}")
        ```

## Interactive Mode (REPL)

For quick experimentation, you can use Jac interactively:

```bash
# Start interactive mode
jac

# Try some basic operations
> x: int = 42;
> print(x * 2);
84
> greeting: str = "Hello from REPL!";
> print(greeting);
Hello from REPL!
```

## Common Beginner Mistakes and Solutions

!!! topic "Troubleshooting"
    Most beginner issues stem from Jac's stricter type requirements compared to Python. Here are the most common mistakes and their solutions.

| **Issue** | **Solution** |
|-----------|--------------|
| Missing semicolons | Add `;` at the end of statements |
| Missing type annotations | Add types to all variables: `x: int = 5;` |
| No entry block | Add `with entry { ... }` for executable scripts |
| Python-style indentation | Use `{ }` braces instead of indentation |

### Example of Common Fixes

!!! example "Common Fixes"
    === "Jac (Incorrect)"
        <div class="code-block">
        ```jac
        # This won't work - missing types and semicolons
        def greet(name) {
            return f"Hello, {name}"
        }

        # Missing entry block
        print(greet("World"))
        ```
        </div>
    === "Jac (Correct)"
        <div class="code-block">
        ```jac
        # This works - proper types and syntax
        def greet(name: str) -> str {
            return f"Hello, {name}";
        }

        with entry {
            print(greet("World"));
        }
        ```
        </div>

## Key Differences from Python

!!! topic "Syntax Comparison"
    While Jac is inspired by Python, it introduces stricter typing and slightly different syntax conventions for better safety and clarity.

| **Feature** | **Python** | **Jac** |
|-------------|------------|---------|
| Entry point | `if __name__ == "__main__":` | `with entry { }` |
| Code blocks | Indentation | Curly braces `{ }` |
| Type hints | Optional | Required |
| Statement termination | Newlines | Semicolons `;` |
| Global variables | `global` keyword | `glob` declaration |

## What's Next?

You now have:

- Jac installed and working
- VS Code extension set up
- Your first programs running
- Understanding of entry blocks and basic syntax

In the next chapter, we'll explore Jac's core language features, including variables, types, control flow, and how they differ from Python while remaining familiar.

!!! topic "Coming Up"
    Next, we'll dive into Jac's enhanced syntax features, including mandatory type annotations, improved control flow, and collection operations that make your code both safer and more expressive.

