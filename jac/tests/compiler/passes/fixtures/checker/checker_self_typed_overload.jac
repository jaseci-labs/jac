"""#8982 item 12: the receiver picks the `self`-typed overload, and a declared
local keeps its annotation over a literal-typed right-hand side."""

def edit(text: str) -> list[str] {
    lines = text.split("\n");
    lines.insert(0, str(1));
    typed: list[str] = text.split("\n");
    typed.insert(0, str(1));
    stripped = text.rstrip();
    stripped = stripped + "!";
    return lines + typed;
}

def literal_receiver -> list[str] {
    parts: list[str] = "a,b,c".split(",");
    parts.append(str(len(parts)));
    return parts;
}
