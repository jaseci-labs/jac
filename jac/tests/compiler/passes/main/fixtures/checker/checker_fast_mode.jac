"""Fixture for --fast flag contract tests.

This file has a type error (int assigned to str) but no syntax errors and no
undefined symbols.  The contract being tested:
  - --fast (symtab_ir_only=True, type_check=False): 0 errors reported
  - full check (type_check=True):                   >= 1 error reported
"""

glob x: str = 42;   # type error: int not assignable to str
