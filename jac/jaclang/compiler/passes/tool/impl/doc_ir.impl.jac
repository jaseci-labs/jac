impl Align.treeprint(self: Align, level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Align(n={self.n}):";
    children_repr: list[str] = [self.contents.treeprint(level + 1)];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Align object."""
impl Align.__str__(self: Align) -> str {
    return f"Align({self.n}, {self.contents})";
}

"""Initialize an Align object."""
impl Align.init(self: Align, contents: DocType, n: (int | None) = None) -> None {
    self.contents = contents;
    self.n = n;
}

impl IfBreak.treeprint(self: IfBreak, level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}IfBreak:";
    break_repr: list[str] = [f"{indent}  break_contents:"];
    break_repr.append(self.break_contents.treeprint(level + 2));
    flat_repr: list[str] = [f"{indent}  flat_contents:"];
    flat_repr.append(self.flat_contents.treeprint(level + 2));
    return header + '\n' + '\n'.join(break_repr) + '\n' + '\n'.join(flat_repr);
}

"""Return a string representation of the IfBreak object."""
impl IfBreak.__str__(self: IfBreak) -> str {
    return f"IfBreak({self.break_contents}, {self.flat_contents})";
}

"""Initialize an IfBreak object."""
impl IfBreak.init(
    self: IfBreak, break_contents: DocType, flat_contents: DocType
) -> None {
    self.break_contents = break_contents;
    self.flat_contents = flat_contents;
}

impl Concat.treeprint(self: Concat, level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Concat:";
    children_repr = [part.treeprint(level + 1) for part in self.parts];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Concat object."""
impl Concat.__str__(self: Concat) -> str {
    return f"Concat({self.parts})";
}

"""Initialize a Concat object."""
impl Concat.init(
    self: Concat, parts: list[DocType], ast_node: (uni.UniNode | None) = None
) -> None {
    self.parts = parts;
    self.ast_node = ast_node;
}

impl Indent.treeprint(self: Indent, level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Indent:";
    children_repr: list[str] = [self.contents.treeprint(level + 1)];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Indent object."""
impl Indent.__str__(self: Indent) -> str {
    return f"Indent({self.contents})";
}

"""Initialize an Indent object."""
impl Indent.init(
    self: Indent, contents: DocType, ast_node: (uni.UniNode | None) = None
) -> None {
    self.contents = contents;
    self.ast_node = ast_node;
}

impl Group.treeprint(self: Group, level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Group(id={self.id}, break_contiguous={self.break_contiguous}):";
    children_repr: list[str] = [self.contents.treeprint(level + 1)];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Group object."""
impl Group.__str__(self: Group) -> str {
    return f"Group({self.contents})";
}

"""Initialize a Group object."""
impl Group.init(
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

impl Line.treeprint(self: Line, level: int = 0) -> str {
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

"""Return a string representation of the Line object."""
impl Line.__str__(self: Line) -> str {
    attrs: list[str] = [];
    if self.hard {
        attrs.append('hard');
    }
    if self.literal {
        attrs.append('literal');
    }
    return f"Line({', '.join(attrs)})";
}

"""Initialize a Line object."""
impl Line.init(
    self: Line, hard: bool = False, literal: bool = False, tight: bool = False
) -> None {
    self.hard = hard;
    self.literal = literal;
    self.tight = tight;
}

impl Text.treeprint(self: Text, level: int = 0) -> str {
    indent = '  ' * level;
    token_info = f" [token@L{self.source_token.loc.first_line}]"
    if self.source_token
    else '';
    return f'{indent}Text("{self.text}"){token_info}';
}

"""Return a string representation of the Text object."""
impl Text.__str__(self: Text) -> str {
    return f'Text("{self.text}")';
}

"""Initialize a Text object."""
impl Text.init(self: Text, text: str, source_token: (uni.Token | None) = None) -> None {
    self.text = text;
    self.source_token = source_token;
}

"""Return an indented string representation of the Doc object."""
impl Doc.treeprint(self: Doc, level: int = 0) -> str {
    indent = '  ' * level;
    return f"{indent}{self.__class__.__name__}";
}

"""Return a string representation of the Doc object."""
impl Doc.__repr__(self: Doc) -> str {
    return self.treeprint();
}

"""Return a string representation of the Doc object."""
impl Doc.__str__(self: Doc) -> str {
    return self.__class__.__name__;
}
