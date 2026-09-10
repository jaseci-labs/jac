"""Fixture for cross-user field-write ACL tests: one Doc shared READ-only."""

import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

node Doc {
    has body: str = "original";
}

def whoami -> dict {
    return {"root": jid(root)};
}

def make_doc -> dict {
    d = Doc();
    root ++> d;
    return {"id": jid(d)};
}

def share_read(id: str, to_root: str) -> dict {
    o = jobj(id);
    Jac.allow_root(o as Doc, UUID(to_root), 'READ');
    return {"ok": True};
}

def write_doc(id: str, body: str) -> dict {
    o = jobj(id);
    if o is None {
        return {"found": False, "body_now": ""};
    }
    (o as Doc).body = body;
    return {"found": True, "body_now": (o as Doc).body};
}

def read_doc(id: str) -> dict {
    o = jobj(id);
    if o is None {
        return {"found": False, "body": ""};
    }
    return {"found": True, "body": (o as Doc).body};
}
