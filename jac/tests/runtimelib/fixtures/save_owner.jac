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

glob HOOK_CALLS: list[int] = [0];

# The creator-owned recipe from RFC #8332: the record stays owned by whoever
# made it, and this hook grants each caller whatever they hold on the org root.
node OrgDoc {
    has org_id: str = "",
        label: str = "";

    def __jac_access__ -> any {
        HOOK_CALLS[0] += 1;
        org = Jac.get_context().mem.get(UUID(self.org_id));
        if org is None {
            return AccessLevel.NO_ACCESS;
        }
        return Jac.check_access_level(org);
    }
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
            save(it, owner=UUID(self.org_id));
            print("ITEM:" + str(it.__jac__.id));
            print("OWNER:" + str(Jac.owner_of(it)));
        } except PermissionError {
            print("DENIED:create_for_org");
            print("PERSISTENT:" + str(it.__jac__.persistent));
        } except ValueError as e {
            print("INVALID:" + str(e));
            print("PERSISTENT:" + str(it.__jac__.persistent));
        }
    }
}

walker create_plain {
    has label: str;

    can enter with Root entry {
        it = Item(label=self.label);
        save(it);
        print("ITEM:" + str(it.__jac__.id));
        print("OWNER:" + str(Jac.owner_of(it)));
    }
}

walker create_org_doc {
    has org_id: str,
        label: str;

    can enter with Root entry {
        doc = OrgDoc(org_id=self.org_id, label=self.label);
        save(doc);
        print("DOC:" + str(doc.__jac__.id));
        print("OWNER:" + str(Jac.owner_of(doc)));
    }
}

walker revoke_on_org {
    has org_id: str,
        member_id: str;

    can enter with Root entry {
        org = &(self.org_id);
        Jac.disallow_root(org, UUID(self.member_id));
        print("revoked");
    }
}

walker level_of {
    has anchor_id: str;

    can enter with Root entry {
        anchor = Jac.get_context().mem.get(UUID(self.anchor_id));
        if anchor is None {
            print("LEVEL:missing");
            return;
        }
        print("LEVEL:" + Jac.check_access_level(anchor).name);
    }
}

walker count_hook_calls {
    has anchor_id: str;

    can enter with Root entry {
        anchor = Jac.get_context().mem.get(UUID(self.anchor_id));
        if anchor is None {
            print("HOOK_CALLS:missing");
            return;
        }
        HOOK_CALLS[0] = 0;
        for _ in range(3) {
            Jac.check_access_level(anchor);
        }
        print("HOOK_CALLS:" + str(HOOK_CALLS[0]));
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
