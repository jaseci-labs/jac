"""
Defines `JUnionType`, which represents a union of multiple possible types
in the Jac type system (e.g., `int | str | None`).

This is useful for modeling nullable values, overloads, structural flexibility,
and situations where values may conform to one of several types.
"""

from typing import Iterable

from jaclang.compiler.jtyping.types.jclassmember import JClassMember
from jaclang.compiler.jtyping.types.jtype import JType


class JUnionType(JType):
    """
    Represents a union of multiple possible types in the Jac type system.

    A value of this type may be one of several constituent types.
    Unions are automatically flattened and deduplicated upon creation.

    Attributes:
        options (list[JType]): The list of possible types (flattened and unique).

    Behavior:
        - Nested unions are flattened automatically.
        - Redundant types are eliminated (by object identity).
        - Assignability allows for any direction between a union and its members.
        - Member access is limited to common members across all union branches.
    """

    def __init__(self, types: Iterable[JType]) -> None:
        """
        Initialize a JUnionType by flattening and deduplicating input types.

        Args:
            types (Iterable[JType]): The types to include in the union.
        """
        flattened: set[JType] = set()
        for t in types:
            if isinstance(t, JUnionType):
                flattened.update(t.options)
            else:
                flattened.add(t)
        self.options: list[JType] = list(flattened)

        super().__init__(
            name=" | ".join(sorted(t.name for t in self.options)), module=None
        )

    def is_instantiable(self) -> bool:
        """
        Check if all types in the union are instantiable.

        Returns:
            bool: True only if every constituent type is instantiable.
        """
        return all(t.is_instantiable() for t in self.options)

    def can_assign_from(self, other: JType) -> bool:
        """
        Check if this union type can accept a value of the given type.

        A value of type `other` is assignable to the union if any constituent
        type can accept it.

        Args:
            other (JType): The type of the value being assigned.

        Returns:
            bool: True if any union member can accept `other`.
        """
        if isinstance(other, JUnionType):
            return all(
                any(t.can_assign_from(o) for t in self.options) for o in other.options
            )
        return any(t.can_assign_from(other) for t in self.options)

    def get_members(self) -> dict[str, JClassMember]:
        """
        Return only the members that are common to all union options.

        Used for safe dot-access (`obj.foo`) when type is a union.

        Returns:
            dict[str, JClassMember]: Members common across all union branches.
        """
        if not self.options:
            return {}
        common_keys = set(self.options[0].get_members().keys())
        for t in self.options[1:]:
            common_keys.intersection_update(t.get_members().keys())

        return {k: self.options[0].get_members()[k] for k in common_keys}

    def supports_binary_op(self, op: str) -> bool:
        return super().supports_binary_op(op)
