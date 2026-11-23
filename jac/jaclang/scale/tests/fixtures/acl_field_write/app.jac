"""Fixture for cross-user field-write ACL tests: one Doc shared READ-only."""

import from jaclang { JacRuntime as Jac }

node Doc {
    has body: str = "original";
}

def:protect whoami -> dict[str, any] {
    return {"root": jid(root)};
}

def:protect make_doc -> dict[str, any] {
    d = Doc();
    root ++> d;
    return {"id": jid(d)};
}

def:protect share_read(id: str, to_root: str) -> dict[str, any] {
    o = jobj(id);
    set_access(o as Doc, to_root, 'READ');
    return {"ok": True};
}

def:protect write_doc(id: str, body: str) -> dict[str, any] {
    o = jobj(id);
    if o is None {
        return {"found": False, "body_now": ""};
    }
    (o as Doc).body = body;
    return {"found": True, "body_now": (o as Doc).body};
}

def:protect read_doc(id: str) -> dict[str, any] {
    o = jobj(id);
    if o is None {
        return {"found": False, "body": ""};
    }
    return {"found": True, "body": (o as Doc).body};
}

def:protect add_child(parent_id: str) -> dict[str, any] {
    parent = jobj(parent_id) as Doc;
    child = Doc(body="child");
    parent ++> child;
    return {"id": jid(child)};
}

def:protect share(id: str, to_root: str, level: str) -> dict[str, any] {
    set_access(jobj(id) as Doc, to_root, level);
    return {"ok": True};
}

def:protect unshare(id: str, who: str) -> dict[str, any] {
    clear_access(jobj(id) as Doc, who);
    return {"ok": True};
}

"""Everything shared with the caller: the targets of their own Member edges."""
def:protect shared_with_me -> dict[str, any] {
    return {"ids": sorted([jid(n) for n in [root->:Member:->]])};
}
