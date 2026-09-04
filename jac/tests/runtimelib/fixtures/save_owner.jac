"""Fixture for owner-bound save tests.

Walkers mint a group root, create content owned by it, and read it back from
other roots, so the tests can prove ownership plus the root-grant cascade
end to end through the CLI runner.
"""

import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

node Item {
    has label: str = "";
}

walker create_other_root {
    can enter with Root entry {
        other_root = Root().__jac__;
        Jac.save(other_root);
        print(other_root.id);
    }
}

walker mint_org_root {
    can enter with Root entry {
        org = Root();
        Jac.save(org);
        Jac.allow_root(org, here.__jac__.id, "WRITE");
        Jac.commit();
        print(org.__jac__.id);
    }
}

walker create_for_org {
    has org_id: str,
        label: str;

    can enter with Root entry {
        it = Item(label=self.label);
        try {
            Jac.save(it, owner=UUID(self.org_id));
            print("ITEM:" + str(it.__jac__.id));
            print("OWNER:" + str(Jac.owner_of(it)));
        } except PermissionError {
            print("DENIED:create_for_org");
        } except ValueError as e {
            print("INVALID:" + str(e));
        }
    }
}

walker grant_on_org {
    has org_id: str,
        member_id: str,
        level: str;

    can enter with Root entry {
        org = &(self.org_id);
        Jac.allow_root(org, UUID(self.member_id), self.level);
        print("granted");
    }
}

def _as_item(v: any) -> Item {
    return v;
}

walker read_item {
    has item_id: str;

    can enter with Root entry {
        it = Jac.get_object(self.item_id);
        if it is None {
            print("READ:none");
        } else {
            print("READ:" + _as_item(it).label);
        }
    }
}

walker try_reown {
    has item_id: str,
        org_id: str;

    can enter with Root entry {
        found: any = Jac.get_object(self.item_id);
        try {
            Jac.save(found, owner=UUID(self.org_id));
            print("REOWN:allowed");
        } except ValueError {
            print("REOWN:refused");
        }
    }
}
