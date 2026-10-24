"""TypedDict assignment: what a TypedDict parameter accepts.

The first block is all valid (zero errors). The trailing block triggers
exactly six E1053 errors, one per rejected argument.
"""
import from typing { TypedDict }

class Base(TypedDict) {
    has id: str;
}

class UserDoc(Base) {
    has role: str;
}

class Wider(TypedDict) {
    has id: str,
        role: str,
        extra: int;
}

class Holder(TypedDict) {
    has user: UserDoc,
        n: int;
}

class Chain(TypedDict) {
    has next: Chain | None;
}

class Link(TypedDict) {
    has next: Link | None;
}

def role_of(u: UserDoc) -> str {
    return u['role'];
}

def id_of(u: Base) -> str {
    return u['id'];
}

def maybe_role(u: UserDoc | None) -> str {
    return u['role'] if u else '';
}

# --- Valid: TypedDicts and matching dict literals ---
def make -> UserDoc {
    return {'id': '1', 'role': 'admin'};
}

# A recursive TypedDict compares with a structurally equal one without
# looping forever.
def relink(c: Chain) -> Link {
    return c;
}

def directory -> dict[str, UserDoc] {
    docs: dict[str, UserDoc] = {'alice': {'id': '1', 'role': 'admin'}};
    roster: list[UserDoc] = [{'id': '2', 'role': 'guest'}];
    docs['bob'] = roster[0];
    return docs;
}

def valid -> int {
    u: UserDoc = {'id': '1', 'role': 'admin'};
    role_of(u);
    id_of(u);
    w: Wider = {'id': '1', 'role': 'admin', 'extra': 1};
    role_of(w);
    role_of({'id': '1', 'role': 'admin'});
    maybe_role({'id': '1', 'role': 'admin'});
    maybe_role(None);
    h: Holder = {'user': {'id': '1', 'role': 'admin'}, 'n': 1};
    return h['n'];
}

# --- Invalid: each argument is rejected with E1053 ---
def invalid {
    role_of(1);
    role_of('admin');
    b: Base = {'id': '1'};
    role_of(b);
    role_of({'id': '1', 'role': 3});
    role_of({'id': '1', 'bogus': 'admin'});
    plain: dict[str, str] = {'id': '1', 'role': 'admin'};
    role_of(plain);
}

with entry {
    print("typeddict assignment checker fixture");
}
