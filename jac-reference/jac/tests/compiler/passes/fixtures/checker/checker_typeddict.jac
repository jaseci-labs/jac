"""TypedDict support: keyed subscript, dict methods, and inheritance.

The first block is all valid (zero errors). The trailing block triggers
exactly two errors: an unknown-key access (E1043) plus the resulting
return-type mismatch (E1002).
"""
import from typing { TypedDict }

class Base(TypedDict) {
    has id: str;
}

class UserDoc(Base) {
    has role: str,
        age: int,
        tags: list[str];
}

# --- Valid: keyed subscript resolves to the declared field type ---
def role_of(u: UserDoc) -> str {
    return u['role'];
}

def age_of(u: UserDoc) -> int {
    return u['age'];
}

# Inherited field resolves through the TypedDict base.
def id_of(u: UserDoc) -> str {
    return u['id'];
}

def tags_of(u: UserDoc) -> list[str] {
    return u['tags'];
}

# --- Valid: dict methods on a TypedDict ---
def get_no_default(u: UserDoc) -> str | None {
    return u.get('role');
}

def get_with_default(u: UserDoc) -> str {
    return u.get('role', 'guest');
}

def setdefault_field(u: UserDoc) -> int {
    return u.setdefault('age', 0);
}

# Distinct keys must resolve to distinct field types: with literal
# discrimination, 'role' picks the str overload and 'age' the int one.
def get_str_key(u: UserDoc) -> str {
    return u.get('role', 'guest');
}

def get_int_key(u: UserDoc) -> int {
    return u.get('age', 0);
}

def keys_of(u: UserDoc) -> list[str] {
    return list(u.keys());
}

# --- Valid: construction from a matching dict literal ---
def make -> UserDoc {
    d: UserDoc = {'id': '1', 'role': 'admin', 'age': 30, 'tags': []};
    return d;
}

# --- Invalid: unknown key -> E1043, and the Unknown return -> E1002 ---
def bad_key(u: UserDoc) -> str {
    return u['missing'];
}

with entry {
    print("typeddict checker fixture");
}
