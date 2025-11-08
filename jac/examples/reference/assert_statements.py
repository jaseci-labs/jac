from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

def foo(value: int) -> None:
    assert value > 0, 'Value must be positive'
try:
    foo(-5)
except AssertionError as e:
    print('Asserted:', e)
    
a = 5
b = 2

@_jl.jac_test
def test_test1(_check) -> None:
    _check.assertAlmostEqual(a, 6)

@_jl.jac_test
def test_test2(_check) -> None:
    _check.assertNotEqual(a, b)

@_jl.jac_test
def test_test3(_check) -> None:
    _check.assertIn('d', 'abc')

@_jl.jac_test
def test_test4(_check) -> None:
    _check.assertEqual(a - b, 3)
