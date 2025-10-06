from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

@_jl.jac_test
def test_test1(_check) -> None:
    _check.assertAlmostEqual(4.99999, 4.99999)

@_jl.jac_test
def test_test2(_check) -> None:
    _check.assertEqual(5, 5)

@_jl.jac_test
def test_test3(_check) -> None:
    _check.assertIn('e', 'qwerty')
if __name__ == '__main__':
    import subprocess
    result = subprocess.run(['jac', 'test', f'{__file__}'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    print(result.stderr)
