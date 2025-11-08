"""Document Intermediate Representation (DocIR) classes."""

from __future__ import annotations

from typing import Optional, Union

# Define DocType for self-referential typing
DocType = Union["Doc", "Text", "Line", "Group", "Indent", "Concat", "IfBreak", "Align"]


class Doc:
    """Base class for document parts."""

    def __str__(self) -> str:
        """Return a string representation of the Doc object."""
        return self.__class__.__name__

    def __repr__(self) -> str:
        """Return a string representation of the Doc object."""
        return self.treeprint()

    def treeprint(self, level: int = 0) -> str:
        """Return an indented string representation of the Doc object."""
        indent = "  " * level
        return f"{indent}{self.__class__.__name__}"


class Text(Doc):
    """Simple text content."""

    def __init__(self, text: str) -> None:
        """Initialize a Text object."""
        self.text: str = text

    def __str__(self) -> str:
        """Return a string representation of the Text object."""
        return f'Text("{self.text}")'

    def treeprint(self, level: int = 0) -> str:
        indent = "  " * level
        return f'{indent}Text("{self.text}")'


class Line(Doc):
    """Represents a line break that can be preserved or flattened."""

    def __init__(
        self, hard: bool = False, literal: bool = False, tight: bool = False
    ) -> None:
        """Initialize a Line object."""
        self.hard: bool = hard  # If True, always break
        self.literal: bool = literal  # includes the literal newline in flattened output
        self.tight: bool = tight  # If True, no space is added

    def __str__(self) -> str:
        """Return a string representation of the Line object."""
        attrs: list[str] = []
        if self.hard:
            attrs.append("hard")
        if self.literal:
            attrs.append("literal")
        return f"Line({', '.join(attrs)})"

    def treeprint(self, level: int = 0) -> str:
        indent = "  " * level
        attrs: list[str] = []
        if self.hard:
            attrs.append("hard=True")
        if self.literal:
            attrs.append("literal=True")
        return f"{indent}Line({', '.join(attrs)})"


class Group(Doc):
    """A group that can be printed flat or broken into multiple lines."""

    def __init__(
        self,
        contents: DocType,
        break_contiguous: bool = False,
        id: Optional[str] = None,
    ) -> None:
        """Initialize a Group object."""
        self.contents: DocType = contents
        self.break_contiguous: bool = break_contiguous
        self.id: Optional[str] = id

    def __str__(self) -> str:
        """Return a string representation of the Group object."""
        return f"Group({self.contents})"

    def treeprint(self, level: int = 0) -> str:
        indent = "  " * level
        header = (
            f"{indent}Group(id={self.id}, break_contiguous={self.break_contiguous}):"
        )
        children_repr: list[str] = [self.contents.treeprint(level + 1)]
        return f"{header}\n" + "\n".join(children_repr)


class Indent(Doc):
    """Indented content."""

    def __init__(self, contents: DocType) -> None:
        """Initialize an Indent object."""
        self.contents: DocType = contents

    def __str__(self) -> str:
        """Return a string representation of the Indent object."""
        return f"Indent({self.contents})"

    def treeprint(self, level: int = 0) -> str:
        indent = "  " * level
        header = f"{indent}Indent:"
        children_repr: list[str] = [self.contents.treeprint(level + 1)]
        return f"{header}\n" + "\n".join(children_repr)


class Concat(Doc):
    """A sequence of doc parts."""

    def __init__(self, parts: list[DocType]) -> None:
        """Initialize a Concat object."""
        self.parts: list[DocType] = parts

    def __str__(self) -> str:
        """Return a string representation of the Concat object."""
        return f"Concat({self.parts})"

    def treeprint(self, level: int = 0) -> str:
        indent = "  " * level
        header = f"{indent}Concat:"
        children_repr = [part.treeprint(level + 1) for part in self.parts]
        return f"{header}\n" + "\n".join(children_repr)


class IfBreak(Doc):
    """Content that differs based on whether the parent group is broken."""

    def __init__(self, break_contents: DocType, flat_contents: DocType) -> None:
        """Initialize an IfBreak object."""
        self.break_contents: DocType = break_contents
        self.flat_contents: DocType = flat_contents

    def __str__(self) -> str:
        """Return a string representation of the IfBreak object."""
        return f"IfBreak({self.break_contents}, {self.flat_contents})"

    def treeprint(self, level: int = 0) -> str:
        indent = "  " * level
        header = f"{indent}IfBreak:"
        break_repr: list[str] = [f"{indent}  break_contents:"]
        break_repr.append(self.break_contents.treeprint(level + 2))

        flat_repr: list[str] = [f"{indent}  flat_contents:"]
        flat_repr.append(self.flat_contents.treeprint(level + 2))

        return f"{header}\n" + "\n".join(break_repr) + "\n" + "\n".join(flat_repr)


class Align(Doc):
    """Alignment relative to the current indentation level."""

    def __init__(self, contents: DocType, n: Optional[int] = None) -> None:
        """Initialize an Align object."""
        self.contents: DocType = contents
        self.n: Optional[int] = (
            n  # Number of spaces, or null to use current indentation level
        )

    def __str__(self) -> str:
        """Return a string representation of the Align object."""
        return f"Align({self.n}, {self.contents})"

    def treeprint(self, level: int = 0) -> str:
        indent = "  " * level
        header = f"{indent}Align(n={self.n}):"
        children_repr: list[str] = [self.contents.treeprint(level + 1)]
        return f"{header}\n" + "\n".join(children_repr)
