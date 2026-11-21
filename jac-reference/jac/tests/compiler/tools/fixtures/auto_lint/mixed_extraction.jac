"""Test partial extraction when some statements can be extracted and others cannot.

The extractable assignments (x, y) become globs, but the non-extractable
statement (print) stays in the with entry block.
"""

with entry {
    x = 5;
    print("hello");
    y = 10;
}
