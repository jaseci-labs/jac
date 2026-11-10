"""Fixture for membership tests: every walker runs as one real root, so each
call is a separate request with its own principal set."""

import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

node Workspace(Root) {
    has name: str = "";
}

node Doc {
    has title: str = "";
}

def _node(node_id: str) -> Node {
    found: any = Jac.get_context().mem.get(UUID(node_id));
    return found.archetype;
}

def _say(key: str, fn: any) {
    try {
        print(key + ":" + str(fn()));
    } except PermissionError as e {
        print(key + ":DENIED " + str(e));
    } except (ValueError, TypeError) as e {
        print(key + ":INVALID " + str(e));
    } except RuntimeError as e {
        print(key + ":REFUSED " + str(e));
    }
}

walker new_user {
    can enter with Root entry {
        user = Root().__jac__;
        Jac.save(user);
        Jac.commit();
        print(user.id);
    }
}

walker new_org {
    has name: str;

    can enter with Root entry {
        org = Workspace(name=self.name);
        save(org);
        print(org.__jac__.id);
    }
}

walker add_doc {
    has parent_id: str,
        title: str;

    can enter with Root entry {
        parent = _node(self.parent_id);
        doc = Doc(title=self.title);
        def attach -> str {
            parent ++> doc;
            return str(doc.__jac__.id);
        }
        _say("DOC", attach);
        print("OWNER:" + str(Jac.owner_of(doc)));
    }
}

walker share {
    has target_id: str,
        who_id: str,
        level: str;

    can enter with Root entry {
        def run -> any {
            return set_access(_node(self.target_id), self.who_id, self.level);
        }
        _say("SET", run);
    }
}

walker unshare {
    has target_id: str,
        who_id: str;

    can enter with Root entry {
        def run -> any {
            return clear_access(_node(self.target_id), self.who_id);
        }
        _say("CLEAR", run);
    }
}

walker make_public {
    has target_id: str,
        level: str;

    can enter with Root entry {
        def run -> any {
            return grant(_node(self.target_id), self.level);
        }
        _say("GRANT", run);
    }
}

walker level_of {
    has node_id: str;

    can enter with Root entry {
        anchor: any = Jac.get_context().mem.get(UUID(self.node_id));
        print("LEVEL:" + Jac.check_access_level(anchor).name);
    }
}

walker owner_of {
    has node_id: str;

    can enter with Root entry {
        target: any = _node(self.node_id);
        print("OWNER:" + str(Jac.owner_of(target)));
    }
}

"""Count what a typed hop (SQL path) and an untyped hop (object path) return."""
walker visible {
    has hub_id: str;

    can enter with Root entry {
        hub = _node(self.hub_id);
        print("TYPED:" + str(len([hub-->][?:Doc])));
        print("UNTYPED:" + str(len([hub-->])));
    }
}

walker my_groups {
    can enter with Root entry {
        names = sorted([type(g).__name__ for g in [root->:Member:->]]);
        print("GROUPS:" + ",".join(names));
    }
}

walker connect_member {
    has group_id: str;

    can enter with Root entry {
        found: any = Jac.get_context().mem.get(UUID(self.group_id));
        target: any = found.archetype;
        kind: any = Member;
        def link -> str {
            Jac.connect(root, target, kind);
            return "linked";
        }
        _say("CONNECT", link);
    }
}

walker promote_self {
    has group_id: str;

    can enter with Root entry {
        for e in [edge root->:Member:->] {
            if str(e.__jac__.target.id) == self.group_id {
                e.level = 3;
            }
        }
        Jac.commit();
        print("DONE");
    }
}

walker delete_own_edge {
    has group_id: str;

    can enter with Root entry {
        def drop -> str {
            for e in [edge root->:Member:->] {
                if str(e.__jac__.target.id) == self.group_id {
                    del e;
                }
            }
            return "deleted";
        }
        _say("DELETE", drop);
    }
}

walker edit_doc {
    has doc_id: str,
        title: str;

    can enter with Root entry {
        doc: any = _node(self.doc_id);
        doc.title = self.title;
        print("EDIT:done");
    }
}

"""What the store holds, read as the system, so a dropped write shows."""
walker true_title {
    has doc_id: str;

    can enter with Root entry {
        found: any = Jac.get_context().mem.get(UUID(self.doc_id));
        print("TRUE:" + ("GONE" if found is None else str(found.archetype.title)));
    }
}

walker delete_node {
    has node_id: str;

    can enter with Root entry {
        target: any = _node(self.node_id);
        def run -> str {
            Jac.destroy(target);
            return "ok";
        }
        _say("DEL", run);
    }
}

walker collect {
    has titles: list[str] = [];

    can on_doc with Doc entry {
        self.titles.append(here.title);
        visit [-->];
    }
}

"""Spawn a walker below the hub and list the titles it reaches."""
walker walk_titles {
    has hub_id: str;

    can enter with Root entry {
        hub = _node(self.hub_id);
        w = collect();
        for n in [hub-->] {
            n spawn w;
        }
        print("WALK:" + ",".join(sorted(w.titles)));
        print("FOUND:" + str(len([hub-->[?:Doc, title=="Budget"]])));
    }
}

"""The member list as the caller sees it: who:level, sorted."""
walker members_of {
    has group_id: str;

    can enter with Root entry {
        group = _node(self.group_id);
        rows = sorted([m.who() + ":" + str(m.level) for m in [edge group<-:Member:<-]]);
        print("MEMBERS:" + ",".join(rows));
    }
}

walker share_in_one_request {
    has target_id: str,
        who_id: str;

    can enter with Root entry {
        target = _node(self.target_id);
        set_access(target, self.who_id, "WRITE");
        set_access(target, self.who_id, "READ");
        clear_access(target, self.who_id);
        set_access(target, self.who_id, "CONNECT");
        print("EDGES:" + str(len([edge target<-:Member:<-])));
    }
}
