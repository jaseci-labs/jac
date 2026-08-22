"""Multi-statement lambdas in compound-statement headers (if/while conditions).

The helper must hoist to the enclosing function-or-module scope *before* the
statement that evaluates the condition, not be drained into the statement body
where the condition reference would be unresolved.
"""

with entry {
    if (
        lambda (y: int) -> bool {
            z = y > 0;
            z
        }
    )(
        5
    ) {
        print("positive");
    }
    if (
        lambda (y: int) -> bool {
            z = y < 0;
            z
        }
    )(
        5
    ) {
        print("negative");
    }
    i = 0;
    while (
        lambda (n: int) -> bool {
            keep = n < 3;
            keep
        }
    )(
        i
    ) {
        print(i);
        i += 1;
    }
}
