import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.archetype { Anchor }
import from uuid { UUID }

node A {
    has val: int;
}

walker check_node {
    can enter with Root entry {
        visit [-->];
    }

    can enter2 with A entry {
        print(here);
    }
}

walker update_node {
    has val: int;

    can enter2 with A entry {
        here.val = self.val;
    }
}

walker update_target_node {
    has val: int;
    has node_id: str;

    can enter with Root entry {
        target_node = & (self.node_id);
        target_node.val = self.val;
    }
}

walker create_node {
    has val: int;

    can enter with Root entry {
        a = A(val=self.val);
        here ++> a;
        print(a.__jac__.id);
    }
}

walker create_other_root {
    can enter with Root entry {
        other_root = Root().__jac__;
        Jac.save(other_root);
        print(other_root.id);
    }
}

walker allow_other_root_access {
    has root_id: str,
        level: int | str = 1,
        via_all: bool = False;

    can enter_root with Root entry {
        if self.via_all {
            Jac.perm_grant(here, self.level);
        } else {
            Jac.allow_root(here, UUID(self.root_id), self.level);
        }
    }

    can enter_nested with A entry {
        if self.via_all {
            Jac.perm_grant(here, self.level);
        } else {
            Jac.allow_root(here, UUID(self.root_id), self.level);
        }
    }
}

walker disallow_other_root_access {
    has root_id: str,
        via_all: bool = False;

    can enter_root with Root entry {
        if self.via_all {
            Jac.perm_revoke(here);
        } else {
            Jac.disallow_root(here, UUID(self.root_id));
        }
    }

    can enter_nested with A entry {
        if self.via_all {
            Jac.perm_revoke(here);
        } else {
            Jac.disallow_root(here, UUID(self.root_id));
        }
    }
}
