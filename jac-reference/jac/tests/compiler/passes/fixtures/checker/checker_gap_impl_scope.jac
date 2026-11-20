"""Gap #46: Impl files checked standalone don't resolve parent module scope.

When an impl file is given directly to the type checker (e.g., via
`jac check some.impl.jac`), the checker should use discover_base_file()
to find the parent module and check the impl in its full scope context.
All impls should only be checked in the context of the full module.

Currently, standalone compilation of an impl file leaves all parent-scope
types (including `self`, parameter types, imports) as Unknown, causing
cascading false positives that mask real type errors.

Expected errors (when properly resolved through parent):
  1. return 42 in bad_return -> str          (int not assignable to str)
  2. self.value + "oops" in bad_op -> int    (int + str has no __add__ overload)
"""

obj Calculator {
    has value: int;

    def add(amount: int) -> int;
    def multiply(factor: int) -> int;
    def bad_return -> str;
    def bad_op -> int;
}
