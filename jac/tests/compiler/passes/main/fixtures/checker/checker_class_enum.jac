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

# Test: Static methods on class-based enums should return their declared return type
class AccessLevel(IntEnum) {
    with entry {
        READ = 1;
        WRITE = 2;
        ADMIN = 3;
    }

    static def cast(level: int | str | None) -> AccessLevel | None {
        return None;
    }

    static def get_default() -> int {
        return 99;
    }
}

# Static method member access (no call) should return FunctionType
glob static_method_ref = AccessLevel.cast;

# Static method call should return the declared return type
glob cast_result: AccessLevel | None = AccessLevel.cast(1);  # OK
glob default_val: int = AccessLevel.get_default();  # OK
glob cast_wrong: int = AccessLevel.cast(1);  # Error: Cannot assign AccessLevel | None to int
glob default_wrong: str = AccessLevel.get_default();  # Error: Cannot assign int to str
