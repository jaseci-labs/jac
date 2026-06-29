import from typing { Union }
import type jaclang.jac0core.unitree as uni;

glob DocType = Union[
         ('Doc', 'Text', 'Line', 'Group', 'Indent', 'Concat', 'IfBreak', 'Align')
     ];

obj Doc {
    def __str__ -> str;
    def __repr__ -> str;
    def treeprint(level: int = 0) -> str;
}

obj Text(Doc) {
    has text: str,
        source_token: (uni.Token | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

obj Line(Doc) {
    has hard: bool = False,
        literal: bool = False,
        tight: bool = False;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

obj Group(Doc) {
    has contents: DocType,
        break_contiguous: bool = False,
        id: (str | None) = None,
        ast_node: (uni.UniNode | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

obj Indent(Doc) {
    has contents: DocType,
        ast_node: (uni.UniNode | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

obj Concat(Doc) {
    has parts: list[DocType],
        ast_node: (uni.UniNode | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

obj IfBreak(Doc) {
    has break_contents: DocType,
        flat_contents: DocType;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}

obj Align(Doc) {
    has contents: DocType,
        n: (int | None) = None;

    def __str__ -> str;
    def treeprint(level: int = 0) -> str;
}
