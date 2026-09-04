"""Fixture for caller-aware access policy tests.

TeamDoc grants WRITE to roots listed as editors and READ to everyone else,
the owner included, so the tests can prove a per-caller role decides at the
traversal seam with no endpoint checks anywhere.
"""

import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

node TeamDoc {
    has body: str = "original",
        editors: list[str] = [];

    def __jac_access_for__(caller: UUID) -> (AccessLevel | None) {
        if str(caller) in self.editors {
            return AccessLevel.WRITE;
        }
        return AccessLevel.READ;
    }
}

node PlainDoc {
    has body: str = "original";
}

walker create_other_root {
    can enter with Root entry {
        other_root = Root().__jac__;
        Jac.save(other_root);
        print(other_root.id);
    }
}

walker create_doc {
    has editors_csv: str = "";

    can enter with Root entry {
        eds = self.editors_csv.split(",") if self.editors_csv else [];
        d = here ++> TeamDoc(editors=eds);
        print(d.__jac__.id);
    }
}

walker create_plain {
    can enter with Root entry {
        d = here ++> PlainDoc();
        print(d.__jac__.id);
    }
}

obj HasBody {
    has body: str = "";
}

def _as_doc(v: any) -> HasBody {
    return v;
}

walker write_doc {
    has target_id: str,
        body: str;

    can enter with Root entry {
        found = Jac.get_object(self.target_id);
        if found is None {
            print("WRITE:unreachable");
            return;
        }
        _as_doc(found).body = self.body;
        Jac.commit();
        print("WRITE:done");
    }
}

walker read_doc {
    has target_id: str;

    can enter with Root entry {
        found = Jac.get_object(self.target_id);
        if found is None {
            print("READ:none");
        } else {
            print("READ:" + _as_doc(found).body);
        }
    }
}
