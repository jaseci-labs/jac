Jac supports a comprehensive set of arithmetic operations that follow the standard mathematical precedence rules. The arithmetic expression system in Jac is designed to be intuitive and consistent with mathematical conventions while maintaining compatibility with Python's arithmetic operations.

**Basic Arithmetic Operators**

The fundamental arithmetic operators available in Jac are:

- **Addition (`+`)**: Adds two operands
- **Subtraction (`-`)**: Subtracts the right operand from the left operand  
- **Multiplication (`*`)**: Multiplies two operands
- **Division (`/`)**: Performs floating-point division
- **Floor Division (`//`)**: Performs division and returns the floor of the result
- **Modulo (`%`)**: Returns the remainder of division
- **Exponentiation (`**`)**: Raises the left operand to the power of the right operand

**Operator Precedence**

Jac follows the standard mathematical order of operations (PEMDAS/BODMAS):

1. Parentheses `()` - highest precedence
2. Exponentiation `**` 
3. Unary plus/minus `+x`, `-x`
4. Multiplication `*`, Division `/`, Floor Division `//`, Modulo `%`
5. Addition `+`, Subtraction `-` - lowest precedence

**Expression Combinations**

Complex arithmetic expressions can be constructed by combining multiple operators and operands. Parentheses can be used to override the default precedence and create more complex calculations.

The provided code example demonstrates all basic arithmetic operations including multiplication (`7 * 2`), division (`15 / 3`), floor division (`15 // 3`), modulo (`17 % 5`), exponentiation (`2 ** 3`), and a combination expression with parentheses to control evaluation order (`(9 + 2) * 9 - 2`).

These arithmetic expressions form the foundation for mathematical computations in Jac programs and can be used in variable assignments, function arguments, and conditional statements.
