"""FIXED: Self type is now resolved in method return types.

The `Self` type (from typing_extensions) indicates that a method returns
the same type as the class it belongs to. This is commonly used in:
- __iter__ methods that return Self (the iterator itself)
- Builder pattern methods
- copy() methods

Fix: _get_special_form_type() uses hardcoded name matching (like Pyright's
handleTypingStubTypeAnnotation) to recognize "Self" as a special form,
returning TypeVarType("Self") which is then substituted to the actual
class type by _apply_type_map().
"""

# Note: This test uses Python builtins that return Self

with entry {
    items: list[int] = [1, 2, 3];

    # enumerate.__iter__() returns Self
    # Self should be resolved to enumerate[int]
    e = enumerate(items);
    it = e.__iter__();
    # When fixed, this should error (it is enumerate, not int)
    wrong_it: int = it;  # <-- Should Error: Cannot assign enumerate to int

    # Similarly, list.copy() returns Self in typeshed
    copied = items.copy();
    # When fixed, this should error (copied is list[int], not int)
    wrong_copied: int = copied;  # <-- Should Error: Cannot assign list[int] to int

    # dict.copy() returns Self
    d: dict[str, int] = {"a": 1};
    d_copy = d.copy();
    # When fixed, this should error (d_copy is dict[str, int], not str)
    wrong_d: str = d_copy;  # <-- Should Error: Cannot assign dict[str, int] to str
}
