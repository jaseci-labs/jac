"""Runtime behavior of the `expr as Type` cast — it is type-erased.

At runtime the cast does nothing: it evaluates to the operand unchanged.
"""

obj Box {
    has v: int;
}

with entry {
    x: any = 42;
    y = x as int;
    print(y);

    b: any = Box(v=7);
    bb = b as Box;
    print(bb.v);

    nums: any = [1, 2, 3];
    total = sum(nums as list[int]);
    print(total);

    # Cast inside a larger expression.
    print((x as int) + 1);
}
