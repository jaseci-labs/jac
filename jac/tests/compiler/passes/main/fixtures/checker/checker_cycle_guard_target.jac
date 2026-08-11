"""Bug #CYCLE-IMPORT-1 fixture: target for the re-entrant import-guard test.

Never imported organically; the test asks the evaluator for this path while
simulating that its compile is already on the stack, and the guard must
answer with a stub instead of re-entering the compiler.
"""

glob GUARD_TARGET_MARKER: int = 42;
