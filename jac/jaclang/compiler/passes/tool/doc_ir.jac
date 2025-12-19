"""Document Intermediate Representation (DocIR) classes."""
import from typing { TYPE_CHECKING, Union }

with entry {
    if TYPE_CHECKING {
        import jaclang.pycore.unitree as uni;
    }
}

# Define DocType for self-referential typing
glob DocType = Union[
    ('Doc', 'Text', 'Line', 'Group', 'Indent', 'Concat', 'IfBreak', 'Align')
];

"""Base class for document parts."""
class Doc {
    def __str__(self: Doc) -> str;
    def __repr__(self: Doc) -> str;
    def treeprint(self: Doc, level: int = 0) -> str;
}

"""Simple text content."""
class Text(Doc) {
    def init(self: Text, text: str, source_token: (uni.Token | None) = None) -> None;
    def __str__(self: Text) -> str;
    def treeprint(self: Text, level: int = 0) -> str;
}

"""Represents a line break that can be preserved or flattened."""
class Line(Doc) {
    def init(
        self: Line, hard: bool = False, literal: bool = False, tight: bool = False
    ) -> None;

    def __str__(self: Line) -> str;
    def treeprint(self: Line, level: int = 0) -> str;
}

"""A group that can be printed flat or broken into multiple lines."""
class Group(Doc) {
    def init(
        self: Group,
        contents: DocType,
        break_contiguous: bool = False,
        id: (str | None) = None,
        ast_node: (uni.UniNode | None) = None
    ) -> None;

    def __str__(self: Group) -> str;
    def treeprint(self: Group, level: int = 0) -> str;
}

"""Indented content."""
class Indent(Doc) {
    def init(
        self: Indent, contents: DocType, ast_node: (uni.UniNode | None) = None
    ) -> None;

    def __str__(self: Indent) -> str;
    def treeprint(self: Indent, level: int = 0) -> str;
}

"""A sequence of doc parts."""
class Concat(Doc) {
    def init(
        self: Concat, parts: list[DocType], ast_node: (uni.UniNode | None) = None
    ) -> None;

    def __str__(self: Concat) -> str;
    def treeprint(self: Concat, level: int = 0) -> str;
}

"""Content that differs based on whether the parent group is broken."""
class IfBreak(Doc) {
    def init(self: IfBreak, break_contents: DocType, flat_contents: DocType) -> None;
    def __str__(self: IfBreak) -> str;
    def treeprint(self: IfBreak, level: int = 0) -> str;
}

"""Alignment relative to the current indentation level."""
class Align(Doc) {
    def init(self: Align, contents: DocType, n: (int | None) = None) -> None;
    def __str__(self: Align) -> str;
    def treeprint(self: Align, level: int = 0) -> str;
}
