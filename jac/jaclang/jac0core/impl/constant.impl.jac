"""Implementation for constant types."""

"""Return the string representation of the token."""
impl Constants.__str__(self: Constants) -> str {
    return self.value;
}

"""Return the string list of token modifiers."""
impl JacSemTokenModifier.as_str_list -> list[str] {
    return [
        i.name.lower()
        for i in JacSemTokenModifier
        if i.name
    ];
}

impl CodeContext.is_server.getter -> bool {
    return (self == CodeContext.SERVER);
}

impl CodeContext.is_client.getter -> bool {
    return (self == CodeContext.CLIENT);
}

impl CodeContext.is_native.getter -> bool {
    return (self == CodeContext.NATIVE);
}
