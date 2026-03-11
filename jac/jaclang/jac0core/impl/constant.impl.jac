"""Implementation for constant types."""

"""Return the string representation of the token."""
impl Constants.__str__(self: Constants) -> str {
    return self.value;
}

"""Return the string list of token types."""
impl JacSemTokenType.as_str_list -> list {
    return [
        i.name.lower()
        for i in JacSemTokenType
        if i.name
    ];
}

"""Return the string list of token modifiers."""
impl JacSemTokenModifier.as_str_list -> list {
    return [
        i.name.lower()
        for i in JacSemTokenModifier
        if i.name
    ];
}
