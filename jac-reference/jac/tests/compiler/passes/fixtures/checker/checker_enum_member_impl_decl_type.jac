"""Fixture for enum member declarations in impl-based enums.

Members declared inside an `impl` block for an enum should resolve to
EnumMemberType just like inline declarations. DeclImplMatchPass connects
the ImplDef back to its Enum declaration via decl_link, so the type
evaluator can find the owning enum from an impl-based declaration site.
"""

enum Color;

impl Color {
    RED = 1,
    GREEN = 2,
    BLUE = 3
}
