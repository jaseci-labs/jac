"""jac run must compile .py entries without inheriting future flags (#10524).

Jac-compiled frames carry CO_FUTURE_ANNOTATIONS, and a compile() that
inherits caller flags picks that bit up, giving the file PEP 563
string-annotation semantics instead of 3.14's deferred __annotate__ /
__classdict__ machinery. This fixture is run via `jac run`; the test
asserts its markers survive to stdout.
"""

import __future__
import dis

BIT = __future__.annotations.compiler_flag

inner = compile("x = 1", "<t>", "exec")
assert not inner.co_flags & BIT, f"nested compile inherited flags {inner.co_flags:#x}"


def annotated(a: int) -> int:
    return a


assert annotated.__annotations__ == {"a": int, "return": int}, annotated.__annotations__


class Body:
    x: int = 1


assert callable(Body.__annotate__), "__annotate__ missing on class body"
assert Body.__annotate__(1) == {"x": int}, Body.__annotate__(1)

print("py entry future flags clean")
