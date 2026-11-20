"""Test @= (matrix multiply assign) operator parsing."""

with entry {
    a = [[1, 2], [3, 4]];
    b = [[5, 6], [7, 8]];
    a @= b;
    print(a);
}
