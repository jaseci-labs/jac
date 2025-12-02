**By as an Operator**

The `by` operator in Jac is a syntactic construct for expression composition. It allows chaining expressions together in a declarative manner.

> **Note:** The exact execution behavior and semantics of the `by` operator are not yet fully defined. The current implementation focuses on the syntactic structure, and the runtime behavior may evolve in future versions of Jac.

**Basic Syntax**

The `by` expression follows the pattern: `expression by expression`. The operator is right-associative, meaning `a by b by c` is parsed as `a by (b by c)`.

**Simple By Expression**

Line 11 demonstrates the basic usage: `result = "hello" by "world"`. This composes the string "hello" with "world" using the `by` operator.

**Chained By Expressions**

Line 15 shows chained `by` operators: `result2 = "a" by "b" by "c"`. Due to right-associativity:
1. First, `"b" by "c"` is evaluated
2. Then, `"a" by (result of step 1)` is evaluated

**By with Arithmetic**

Line 19 demonstrates `by` with arithmetic expressions: `result3 = (1 + 2) by (3 * 4)`. The parentheses ensure the arithmetic operations are evaluated before the `by` composition.

**Common Use Cases**

The `by` operator is commonly used with:
- LLM function calls: `def process(input: str) -> str by llm()`
- Function composition patterns
- Data transformation pipelines
