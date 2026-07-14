import from typing { Callable }

with entry {
    nums: list[int] = [3, 1, 2];

    # OK: seeded from context / annotated / no params.
    ok_callback = sorted(nums, key=lambda (x) { -x; });
    ok_callable: Callable[[int], int] = lambda (x) { x + 1; };
    ok_annot = (lambda (x: int) { x / 2; })(10);
    ok_noargs = lambda { 567; };

    # E1119: no annotation, no context to seed the param(s).
    bad_bare = lambda (y) { -y; };
    bad_two = lambda (a, b) { a + b; };

    _ = (ok_callback, ok_callable, ok_annot, ok_noargs, bad_bare, bad_two);
}
