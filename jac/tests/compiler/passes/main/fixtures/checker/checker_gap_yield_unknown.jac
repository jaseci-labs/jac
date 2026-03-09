"""Gap #37: YieldExpr type checking — yield value vs declared return type.

When a generator function declares `-> int`, each `yield expr` should
check that expr is assignable to int. Currently YieldExpr has no case
in _get_type_of_expression_core, so yield values are never type-checked.

Expected errors:
  1. yield "hello" in int generator (str -> int)
  2. yield [1,2] in int generator (list -> int)
  3. yield 3.14 in int generator (float -> int)
  4. yield "bad" in str generator that declares -> int (str -> int)
  5. yield from string_list in int generator (str elements -> int)
"""

# Generator declared to yield ints
def int_generator -> int {
    yield 1;          # Ok: int -> int
    yield 2;          # Ok: int -> int
    yield "hello";    # Error: str -> int
    yield [1, 2];     # Error: list -> int
    yield 3.14;       # Error: float -> int
}

# Generator declared to yield strs
def str_generator -> str {
    yield "alice";    # Ok: str -> str
    yield "bob";      # Ok: str -> str
    yield 42;         # Error: int -> str
}

# Generator with yield from — element types should match
def chain_generator -> int {
    yield from [1, 2, 3];         # Ok: list[int] elements -> int
    yield from ["a", "b", "c"];   # Error: list[str] elements -> int
}

with entry {
    # Using generators is fine — just calling them
    g1 = int_generator();
    g2 = str_generator();
    g3 = chain_generator();
}
