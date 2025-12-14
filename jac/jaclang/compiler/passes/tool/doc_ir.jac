"""Document Intermediate Representation (DocIR) classes."""
import from typing { TYPE_CHECKING, Union }

with entry {
    if TYPE_CHECKING {
        import jaclang.pycore.unitree as uni;
    }
    # Define DocType for self-referential typing
    DocType = Union[
        ('Doc', 'Text', 'Line', 'Group', 'Indent', 'Concat', 'IfBreak', 'Align')
    ];
}

"""Base class for document parts."""
class Doc {
    """Return a string representation of the Doc object."""
    def __str__(self: Doc) -> str {
        return self.__class__.__name__;
    }

    """Return a string representation of the Doc object."""
    def __repr__(self: Doc) -> str {
        return self.treeprint();
    }

    """Return an indented string representation of the Doc object."""
    def treeprint(self: Doc, level: int = 0) -> str {
        indent = '  ' * level;
        return f"{indent}{self.__class__.__name__}";
    }
}

"""Simple text content."""
class Text(Doc) {
    """Initialize a Text object."""
    def __init__(
        self: Text, text: str, source_token: (uni.Token | None) = None
    ) -> None {
        self.text = text;
        self.source_token = source_token;
    }

    """Return a string representation of the Text object."""
    def __str__(self: Text) -> str {
        return f'Text("{self.text}")';
    }

    def treeprint(self: Text, level: int = 0) -> str {
        indent = '  ' * level;
        token_info = f" [token@L{self.source_token.loc.first_line}]"
        if self.source_token
        else '';
        return f'{indent}Text("{self.text}"){token_info}';
    }
}

"""Represents a line break that can be preserved or flattened."""
class Line(Doc) {
    """Initialize a Line object."""
    def __init__(
        self: Line, hard: bool = False, literal: bool = False, tight: bool = False
    ) -> None {
        self.hard = hard;
        self.literal = literal;
        self.tight = tight;
    }

    """Return a string representation of the Line object."""
    def __str__(self: Line) -> str {
        attrs: list[str] = [];
        if self.hard {
            attrs.append('hard');
        }
        if self.literal {
            attrs.append('literal');
        }
        return f"Line({', '.join(attrs)})";
    }

    def treeprint(self: Line, level: int = 0) -> str {
        indent = '  ' * level;
        attrs: list[str] = [];
        if self.hard {
            attrs.append('hard=True');
        }
        if self.literal {
            attrs.append('literal=True');
        }
        return f"{indent}Line({', '.join(attrs)})";
    }
}

"""A group that can be printed flat or broken into multiple lines."""
class Group(Doc) {
    """Initialize a Group object."""
    def __init__(
        self: Group,
        contents: DocType,
        break_contiguous: bool = False,
        id: (str | None) = None,
        ast_node: (uni.UniNode | None) = None
    ) -> None {
        self.contents = contents;
        self.break_contiguous = break_contiguous;
        self.id = id;
        self.ast_node = ast_node;
    }

    """Return a string representation of the Group object."""
    def __str__(self: Group) -> str {
        return f"Group({self.contents})";
    }

    def treeprint(self: Group, level: int = 0) -> str {
        indent = '  ' * level;
        header = f"{indent}Group(id={self.id}, break_contiguous={self.break_contiguous}):";
        children_repr: list[str] = [self.contents.treeprint(level + 1)];
        return header + '\n' + '\n'.join(children_repr);
    }
}

"""Indented content."""
class Indent(Doc) {
    """Initialize an Indent object."""
    def __init__(
        self: Indent, contents: DocType, ast_node: (uni.UniNode | None) = None
    ) -> None {
        self.contents = contents;
        self.ast_node = ast_node;
    }

    """Return a string representation of the Indent object."""
    def __str__(self: Indent) -> str {
        return f"Indent({self.contents})";
    }

    def treeprint(self: Indent, level: int = 0) -> str {
        indent = '  ' * level;
        header = f"{indent}Indent:";
        children_repr: list[str] = [self.contents.treeprint(level + 1)];
        return header + '\n' + '\n'.join(children_repr);
    }
}

"""A sequence of doc parts."""
class Concat(Doc) {
    """Initialize a Concat object."""
    def __init__(
        self: Concat, parts: list[DocType], ast_node: (uni.UniNode | None) = None
    ) -> None {
        self.parts = parts;
        self.ast_node = ast_node;
    }

    """Return a string representation of the Concat object."""
    def __str__(self: Concat) -> str {
        return f"Concat({self.parts})";
    }

    def treeprint(self: Concat, level: int = 0) -> str {
        indent = '  ' * level;
        header = f"{indent}Concat:";
        children_repr = [part.treeprint(level + 1) for part in self.parts];
        return header + '\n' + '\n'.join(children_repr);
    }
}

"""Content that differs based on whether the parent group is broken."""
class IfBreak(Doc) {
    """Initialize an IfBreak object."""
    def __init__(
        self: IfBreak, break_contents: DocType, flat_contents: DocType
    ) -> None {
        self.break_contents = break_contents;
        self.flat_contents = flat_contents;
    }

    """Return a string representation of the IfBreak object."""
    def __str__(self: IfBreak) -> str {
        return f"IfBreak({self.break_contents}, {self.flat_contents})";
    }

    def treeprint(self: IfBreak, level: int = 0) -> str {
        indent = '  ' * level;
        header = f"{indent}IfBreak:";
        break_repr: list[str] = [f"{indent}  break_contents:"];
        break_repr.append(self.break_contents.treeprint(level + 2));
        flat_repr: list[str] = [f"{indent}  flat_contents:"];
        flat_repr.append(self.flat_contents.treeprint(level + 2));
        return header + '\n' + '\n'.join(break_repr) + '\n' + '\n'.join(flat_repr);
    }
}

"""Alignment relative to the current indentation level."""
class Align(Doc) {
    """Initialize an Align object."""
    def __init__(self: Align, contents: DocType, n: (int | None) = None) -> None {
        self.contents = contents;
        self.n = n;
    }

    """Return a string representation of the Align object."""
    def __str__(self: Align) -> str {
        return f"Align({self.n}, {self.contents})";
    }

    def treeprint(self: Align, level: int = 0) -> str {
        indent = '  ' * level;
        header = f"{indent}Align(n={self.n}):";
        children_repr: list[str] = [self.contents.treeprint(level + 1)];
        return header + '\n' + '\n'.join(children_repr);
    }
}
