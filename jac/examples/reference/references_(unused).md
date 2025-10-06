**Reference Operator with BW_AND (&) - Unused Feature**

This file documents the `&` (BW_AND) operator as a reference operator, which is defined in Jac's grammar but is currently unused or deprecated.

**What This Example Shows**

Line 7 demonstrates a simple variable assignment where `x` is set to 42. The example notes that while the grammar includes a reference operator syntax using `&`, this feature is not currently active in Jac. Line 13 explicitly states that the reference operator `&` is defined in the grammar but remains unused.

**Grammar Definition**

Lines 9-10 explain the grammar rule that defines this unused feature. The `ref` rule in Jac's grammar uses the pattern `BW_AND? pipe_call`, where the `?` indicates the `&` prefix is optional. This means syntax like `&x` would be recognized by the parser, but it doesn't have active runtime behavior.

**Current Status**

| Aspect | Status |
|--------|--------|
| Grammar Support | Defined (BW_AND? allows optional & prefix) |
| Parser Recognition | Yes (syntax is valid) |
| Runtime Behavior | No (feature is inactive) |
| Recommended Usage | Do not use in production code |

**Why It's Unused**

Jac follows Python's reference semantics model where:
- Variables automatically hold references to objects
- Assignment creates new references to the same object
- Explicit reference operators are unnecessary

Languages like C++ use `&` for explicit references, but Python-influenced languages like Jac make this redundant since reference semantics are built into the object model.

**Practical Implications**

For developers working with Jac:
- Avoid using the `&` operator in your code
- Use standard variable assignment instead
- The grammar may include this for parsing compatibility
- Future versions might remove it or give it new meaning

**Historical Context**

The presence of this unused operator suggests it was considered during language design. Many programming languages evolve away from explicit reference operators when adopting implicit reference semantics, similar to how Python, JavaScript, and Ruby work compared to C/C++.
