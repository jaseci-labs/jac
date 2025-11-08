Inline Python in Jac provides a powerful mechanism to seamlessly integrate native Python code within Jac programs. This feature enables developers to leverage the vast Python ecosystem and existing Python libraries directly within their Jac applications.

**Inline Python Syntax**

Python code can be embedded in Jac using the `::py::` directive:

```jac
::py::
# Python code goes here
def python_function():
    return "Hello from Python!"
::py::
```

The `::py::` markers act as delimiters that tell the Jac compiler to treat the enclosed content as native Python code rather than Jac syntax.

**Integration with Jac Code**

Inline Python code can coexist with Jac code in the same module. Variables, functions, and classes defined in Python blocks are accessible to subsequent Jac code, and vice versa, creating a seamless integration between the two languages.

**Use Cases**

Inline Python is particularly useful for:

- **Library Integration**: Using existing Python libraries that don't have Jac equivalents
- **Performance Critical Code**: Writing performance-sensitive algorithms in Python
- **Legacy Code Reuse**: Incorporating existing Python code into new Jac projects
- **Gradual Migration**: Transitioning from Python to Jac incrementally
- **Specialized Operations**: Accessing Python-specific features or libraries

**Execution Context**

The Python code executes in the same runtime environment as the Jac code, sharing the same namespace and variable scope. This allows for natural interaction between Jac and Python components.

**Example Usage**

The provided code example demonstrates a simple integration where:

1. Jac code prints "hello " using the standard Jac print function
2. An inline Python block defines a function `foo()` that prints "world"
3. The Python function is called immediately within the same Python block

This creates a seamless output of "hello world" by combining Jac and Python execution.

**Best Practices**

When using inline Python:

- Keep Python blocks focused and cohesive
- Document the purpose of Python integration
- Consider whether the functionality could be achieved in pure Jac
- Be mindful of the mixing of language paradigms for code maintainability

Inline Python support makes Jac highly interoperable with the Python ecosystem while maintaining the benefits of Jac's unique language features.
