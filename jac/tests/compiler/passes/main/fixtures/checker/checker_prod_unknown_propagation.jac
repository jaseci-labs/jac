"""Production test: UnknownType must not propagate silently through expressions.

When Unknown enters an expression, the result should NOT silently become
Unknown and suppress all downstream type checking. Each step of the
expression chain should either resolve to a known type or report that
type information was lost.

Unknown source: bare generic list.pop() returns Unknown.

Expected errors: 5
  1. bad1: str = result1          — arithmetic on Unknown -> should error
  2. bad2: int = result2          — str concat on Unknown -> should error
  3. bad3: str = chained          — chained Unknown ops -> should error
  4. bad4: int = compared         — comparison with Unknown -> should error
  5. bad5: float = negated        — negation of Unknown -> should error
"""

with entry {
    # Bare generic list — .pop() returns Unknown
    items: list = [1, 2, 3];
    u = items.pop();

    # Arithmetic with Unknown should not silently produce Unknown
    result1 = u + 1;
    bad1: str = result1;           # Error: should not silently accept

    # String concat with Unknown
    result2 = u + "hello";
    bad2: int = result2;           # Error: should not silently accept

    # Chained operations
    chained = u + 1 + 2 + 3;
    bad3: str = chained;           # Error: should not silently accept

    # Comparison with Unknown
    compared = u > 5;
    bad4: int = compared;          # Error: bool not assignable to int (if resolved)

    # Unary on Unknown
    negated = -u;
    bad5: float = negated;         # Error: should not silently accept
}
