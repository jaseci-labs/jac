impl Align.treeprint(level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Align(n={self.n}):";
    children_repr: list[str] = [self.contents.treeprint(level + 1)];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Align object."""
impl Align.__str__ -> str {
    return f"Align({self.n}, {self.contents})";
}

impl IfBreak.treeprint(level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}IfBreak:";
    break_repr: list[str] = [f"{indent}  break_contents:"];
    break_repr.append(self.break_contents.treeprint(level + 2));
    flat_repr: list[str] = [f"{indent}  flat_contents:"];
    flat_repr.append(self.flat_contents.treeprint(level + 2));
    return header + '\n' + '\n'.join(break_repr) + '\n' + '\n'.join(flat_repr);
}

"""Return a string representation of the IfBreak object."""
impl IfBreak.__str__ -> str {
    return f"IfBreak({self.break_contents}, {self.flat_contents})";
}

impl Concat.treeprint(level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Concat:";
    children_repr = [part.treeprint(level + 1) for part in self.parts];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Concat object."""
impl Concat.__str__ -> str {
    return f"Concat({self.parts})";
}

impl Indent.treeprint(level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Indent:";
    children_repr: list[str] = [self.contents.treeprint(level + 1)];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Indent object."""
impl Indent.__str__ -> str {
    return f"Indent({self.contents})";
}

impl Group.treeprint(level: int = 0) -> str {
    indent = '  ' * level;
    header = f"{indent}Group(id={self.id}, break_contiguous={self.break_contiguous}):";
    children_repr: list[str] = [self.contents.treeprint(level + 1)];
    return header + '\n' + '\n'.join(children_repr);
}

"""Return a string representation of the Group object."""
impl Group.__str__ -> str {
    return f"Group({self.contents})";
}

impl Line.treeprint(level: int = 0) -> str {
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
impl Line.__str__ -> str {
    attrs: list[str] = [];
    if self.hard {
        attrs.append('hard');
    }
    if self.literal {
        attrs.append('literal');
    }
    return f"Line({', '.join(attrs)})";
}

impl Text.treeprint(level: int = 0) -> str {
    indent = '  ' * level;
    token_info = f" [token@L{self.source_token.loc.first_line}]"
    if self.source_token
    else '';
    return f'{indent}Text("{self.text}"){token_info}';
}

"""Return a string representation of the Text object."""
impl Text.__str__ -> str {
    return f'Text("{self.text}")';
}

"""Return an indented string representation of the Doc object."""
impl Doc.treeprint(level: int = 0) -> str {
    indent = '  ' * level;
    return f"{indent}{self.__class__.__name__}";
}

"""Return a string representation of the Doc object."""
impl Doc.__repr__ -> str {
    return self.treeprint();
}

"""Return a string representation of the Doc object."""
impl Doc.__str__ -> str {
    return self.__class__.__name__;
}
