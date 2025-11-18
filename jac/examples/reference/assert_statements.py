from __future__ import annotations

assert True
print("assertion passed")
x = 10
assert x > 5
print("x > 5")
assert x < 100, "x must be less than 100"
print("x < 100")
try:
    assert False
except AssertionError:
    print("assertion failed")
try:
    assert 1 > 2, "1 is not greater than 2"
except AssertionError as e:
    print(f"assertion failed: {e}")
assert len([1, 2, 3]) == 3
print("list length is 3")
assert "hello" != "world"
print("strings are different")
assert 5 in [1, 2, 3, 4, 5]
print("5 in list")
assert None is None
print("None is None")
