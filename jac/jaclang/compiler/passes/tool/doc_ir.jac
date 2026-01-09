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

"""Base obj for document parts."""
obj Doc {
    def __str__ -> str;
    def __repr__ -> str;
    def treeprint(level: int = 0) -> str;
}

"""Simple text content."""
obj Text(Doc) {
    has text: str,
        source_token: (uni.Token | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

"""Represents a line break that can be preserved or flattened."""
obj Line(Doc) {
    has hard: bool = False,
        literal: bool = False,
        tight: bool = False;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

"""A group that can be printed flat or broken into multiple lines."""
obj Group(Doc) {
    has contents: DocType,
        break_contiguous: bool = False,
        id: (str | None) = None,
        ast_node: (uni.UniNode | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

"""Indented content."""
obj Indent(Doc) {
    has contents: DocType,
        ast_node: (uni.UniNode | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

"""A sequence of doc parts."""
obj Concat(Doc) {
    has parts: list[DocType],
        ast_node: (uni.UniNode | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

"""Content that differs based on whether the parent group is broken."""
obj IfBreak(Doc) {
    has break_contents: DocType,
        flat_contents: DocType;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

"""Alignment relative to the current indentation level."""
obj Align(Doc) {
    has contents: DocType,
        n: (int | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}
