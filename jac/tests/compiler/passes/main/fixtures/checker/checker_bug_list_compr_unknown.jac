"""Bug #24: List comprehensions return UnknownType.

_get_type_of_expression_core has no case for ListCompr, so list
comprehensions fall through to UnknownType. This means type errors
involving comprehension results go undetected.

Expected: `[x * 2 for x in [1,2,3]]` should infer as list[int].
"""

with entry {
    nums: list[int] = [1, 2, 3];
    doubled = [x * 2 for x in nums];

    # Should infer as list[int], so assigning to str should error
    bad: str = doubled;  # <-- Should be Error (list[int] not assignable to str)

    strs = [str(x) for x in nums];
    bad2: int = strs;  # <-- Should be Error (list[str] not assignable to int)
}
