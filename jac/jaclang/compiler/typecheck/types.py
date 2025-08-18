"""This file contains common types for the typecheck internal use."""

# We're using protocol to make the type check package loosely coupled
# with the jaclang core implementation to treat it like a blackbox
# while maintaining the "interaction api".
from typing import Protocol


class Uri(Protocol):
    """Represents a Uniform Resource Identifier (URI)."""

    pass


class Symbol(Protocol):
    """Represents a symbol in the symbol table."""

    pass


class SymbolTable(Protocol):
    """Represents a symbol table for storing and looking up symbols."""

    def lookup(self, name: str) -> Symbol | None:
        """Look up a symbol by name in the symbol table."""
        ...
