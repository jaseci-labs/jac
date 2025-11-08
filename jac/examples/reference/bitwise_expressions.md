Bitwise expressions in Jac provide low-level bit manipulation operations that work directly on the binary representation of integer values. These operations are essential for systems programming, data encoding, optimization algorithms, and working with binary data formats.

**Bitwise Operators**

Jac supports all standard bitwise operators:

- **AND (`&`)**: Performs bitwise AND operation between two operands
- **OR (`|`)**: Performs bitwise OR operation between two operands  
- **XOR (`^`)**: Performs bitwise exclusive OR operation between two operands
- **NOT (`~`)**: Performs bitwise complement (NOT) operation on a single operand
- **Left Shift (`<<`)**: Shifts bits to the left by specified positions
- **Right Shift (`>>`)**: Shifts bits to the right by specified positions

**Operator Semantics**

**Bitwise AND (`&`)**
- Returns 1 for each bit position where both operands have 1
- Example: `5 & 3` → `101 & 011` = `001` = 1

**Bitwise OR (`|`)**  
- Returns 1 for each bit position where at least one operand has 1
- Example: `5 | 3` → `101 | 011` = `111` = 7

**Bitwise XOR (`^`)**
- Returns 1 for each bit position where operands differ
- Example: `5 ^ 3` → `101 ^ 011` = `110` = 6

**Bitwise NOT (`~`)**
- Inverts all bits (1 becomes 0, 0 becomes 1)
- Example: `~5` → `~101` = `...11111010` (two's complement representation)

**Left Shift (`<<`)**
- Shifts bits left, filling with zeros from the right
- Example: `5 << 1` → `101 << 1` = `1010` = 10

**Right Shift (`>>`)**
- Shifts bits right, behavior depends on sign (arithmetic shift)
- Example: `5 >> 1` → `101 >> 1` = `10` = 2

**Operator Precedence**

Bitwise operators follow this precedence order (highest to lowest):
1. Bitwise NOT (`~`)
2. Shift operators (`<<`, `>>`)
3. Bitwise AND (`&`)
4. Bitwise XOR (`^`)
5. Bitwise OR (`|`)

**Common Use Cases**

Bitwise operations are commonly used for:

- **Flags and masks**: Setting, clearing, and checking individual bits
- **Performance optimization**: Fast multiplication/division by powers of 2 using shifts
- **Data compression**: Bit packing and unpacking
- **Cryptography**: XOR operations for encryption algorithms
- **Hardware interfacing**: Direct bit manipulation for embedded systems

The provided code example demonstrates all bitwise operators with operands 5 and 3, showing practical usage of each operation and their results.

Understanding bitwise expressions is crucial for low-level programming tasks and optimizations in Jac applications.
