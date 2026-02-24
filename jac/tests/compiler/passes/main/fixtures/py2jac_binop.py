"""Test py2jac BinOp conversion: operator precedence and chain flattening."""

# Same-operator chain: should flatten to (a + b + c), NOT ((a + b) + c)
a = 1
b = 2
c = 3
add_chain = a + b + c
sub_chain = a - b - c

# Mixed-precedence: floor-div must apply to the whole subtraction group.
# (a - b - c) // 2  should NOT become  a - b - c // 2
w = 80
title_len = 5
left_pad = (w - title_len - 2) // 2
right_pad = (w - title_len - 1) // 2

# Multiplication over addition: (a + b) * c
mul_over_add = (a + b) * c

# Nested mixed: ((a + b) * c) - d
d = 4
nested = ((a + b) * c) - d
