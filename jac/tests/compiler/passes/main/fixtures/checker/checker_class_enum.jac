"""Tests for class-based enum type checking (StrEnum, IntEnum)."""
import from enum { StrEnum, IntEnum }

class BaseClass(StrEnum) {}
class BaseClass2(IntEnum) {}
class Tokens(BaseClass) {
    with entry {
        FLOAT = '1';
        LSQUARE = 'LSQUARE';
        RSQUARE = 'RSQUARE';
    }
}

glob a: Tokens = Tokens.FLOAT,
     c: str = Tokens.FLOAT,
     d: int = Tokens.FLOAT;

class Tokens2(BaseClass2) {
    with entry {
        FLOAT = '1';  # Error: Cannot assign <class str> to enum member 'FLOAT' of type <class int>
        LSQUARE = 'LSQUARE';  # Error: Cannot assign <class str> to enum member 'LSQUARE' of type <class int>
        RSQUARE = 'RSQUARE';  # Error: Cannot assign <class str> to enum member 'RSQUARE' of type <class int>
    }
}
# Valid: StrEnum member is assignable to str
# Error: Cannot assign <Tokens.FLOAT> to <class int>
