Free code in Jac refers to executable statements that exist at the module level but are not part of a function, class, or other structural element. Unlike many programming languages that allow loose statements to float freely in a module, Jac requires such code to be explicitly wrapped in `with entry` blocks for better code organization and clarity.

**Entry Blocks**

The `with entry` construct serves as a container for free-floating code that should execute when the module is run. This design choice promotes:

- **Code cleanliness**: Makes module structure more explicit and organized
- **Readability**: Clearly identifies executable code vs. definitions
- **Maintainability**: Reduces ambiguity about what runs when

**Basic Syntax**

```jac
with entry {
    # executable statements here
}
```

**Named Entry Points**

Entry blocks can optionally be given names for specific execution contexts:

```jac
with entry:name {
    # named entry point code
}
```

This type of block can be used to define the program's initialization and execution starting point, similar to Python's `if __name__ == "__main__"`: idiom. This design decision creates a clear separation between declarations and executable code at the module level, leading to more maintainable and better-organized programs. Note that declaring multiple instances of ```with entry``` in one script is supported and, they will be executed one after the other, top to bottom.

Here's a with example usage of a named block:

```jac linenums="1"
"""Calculates the area of a circle"""
can calculate_area(radius: float) -> float{
    return math.pi * radius * radius;
}

# Main entry point for the program
with entry:__main__{
    # Define constants
    RADIUS = 5.0;

    # Program execution
    print(f"Area of the circle: {calculate_area(RADIUS)}");
}
```
**Module Organization**

A typical Jac module structure includes:

1. **Import statements**: Bringing in external dependencies
2. **Type definitions**: Classes, objects, and other archetype definitions  
3. **Function definitions**: Standalone functions and abilities
4. **Entry blocks**: Executable code that runs when the module is executed

**Use Cases**

Entry blocks are commonly used for:

- **Main program logic**: The primary execution flow of a script
- **Initialization code**: Setting up module state or configuration
- **Testing and examples**: Demonstrating how defined functions and classes work
- **Script execution**: Code that should run when the module is executed directly

**Interaction with Definitions**

Code within entry blocks can access and use any functions, classes, and variables defined elsewhere in the module. The provided example demonstrates this by:

- Defining a `circle` object with `init` and `area` methods
- Defining a standalone `foo` function
- Using both within the entry block to perform calculations and print results

The entry block executes the main program logic: printing "Hello World!", calling the `foo` function with argument 7, and creating a circle instance to calculate and display its area.

This approach ensures that Jac modules maintain a clear separation between definitions and executable code, leading to more maintainable and understandable programs.
