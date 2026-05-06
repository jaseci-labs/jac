"""Fixture for permission-denial diagnostic tests.

Walkers exercise the three cross-user write paths (edge create, field
mutation, delete) plus diagnostic inspection. Each `try_*` walker prints
one line per diagnostic emitted, in the form
`DIAG:<operation>:<target_type>:<required>:<actual>` so the test runner
can parse it back.
"""

import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

node Profile {
    has tag: str = "";
}

walker create_other_root {
    can enter with Root entry {
        other_root = Root().__jac__;
        Jac.save(other_root);
        print(other_root.id);
    }
}

walker create_profile {
    has tag: str = "";

    can enter with Root entry {
        p = here ++> Profile(tag=self.tag);
        print(p[0].__jac__.id);
    }
}

walker grant_profile_to {
    has requestor_id: str, level: str = "READ";

    can enter with Root entry {
        for p in [here-->] {
            Jac.allow_root(p, UUID(self.requestor_id), self.level);
        }
    }
}

def _print_diagnostics -> None {
    ctx = Jac.get_context();
    for d in ctx.diagnostics {
        print(
            "DIAG:" + d.operation + ":" + d.target_type + ":" + d.required.name + ":" + d.actual.name
        );
    }
    ctx.diagnostics.clear();
}

walker try_edge_write {
    has target_id: str;

    can enter with Root entry {
        target = & (self.target_id);
        # Cross-user edge write: here = current user's root (writeable),
        # target = foreign Profile (denied without ConnectPerm grant).
        here ++> target;
        _print_diagnostics();
    }
}

walker try_field_write {
    has target_id: str, new_tag: str;

    can enter with Root entry {
        target = & (self.target_id);
        target.tag = self.new_tag;
        # Force commit so persist-time access check fires.
        Jac.commit();
        _print_diagnostics();
    }
}

walker try_delete {
    has target_id: str;

    can enter with Root entry {
        target = & (self.target_id);
        del target;
        _print_diagnostics();
    }
}

walker check_profile_tag {
    has target_id: str;

    can enter with Root entry {
        target = & (self.target_id);
        print(target.tag);
    }
}
