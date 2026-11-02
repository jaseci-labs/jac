"""Arithmetic with a tagged numeric operand lowers natively.

A value typed `int | float`, or an `any` narrowed by `isinstance(v, (int,
float))`, is a tagged value at run time. Binary `+ - * / // %` and unary
`-`/`+` on one used to refuse to lower, demoting the whole function (the
compiler's own constant folder among them). They now follow Python's numeric
tower: ints and bools compute as int, anything with a float, and true
division, compute as float. The nogc profile refuses `any`-typed values, so the
program runs under the counted and managed profiles.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "tagged numeric arithmetic matches CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "tagged_arith.jac"), profiles=["rc", "managed"]
    );
}
