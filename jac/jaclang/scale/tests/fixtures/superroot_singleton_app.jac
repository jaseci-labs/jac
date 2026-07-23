"""Fixture: concurrent find-or-create of a singleton on the shared system root.

App pattern from issue #7605. Module import runs in system context, where
`root` IS the system root: the bootstrap captures its id, grants public
WRITE so request walkers may attach children, and commits. Request walkers
(which run on the guest root) then resolve the system root by the captured
id and race to find-or-create the singleton. Only public builtins are used
(jid / jobj / grant / commit).
"""

glob SYSTEM_ROOT_ID: str = "";

node Hub {
    has label: str = "singleton";
}

walker:pub touch_hub {
    can go with entry {
        sys = jobj(id=SYSTEM_ROOT_ID);
        if sys is None {
            report {"error": "system root unreachable"};
            return;
        }
        hubs = [sys-->[?:Hub]];
        if not hubs {
            sys ++> Hub();
            hubs = [sys-->[?:Hub]];
        }
        report {"count": len(hubs)};
    }
}

walker:pub count_hubs {
    can go with entry {
        sys = jobj(id=SYSTEM_ROOT_ID);
        if sys is None {
            report {"error": "system root unreachable"};
            return;
        }
        report {"count": len([sys-->[?:Hub]])};
    }
}

with entry {
    SYSTEM_ROOT_ID = jid(root);
    grant(root, level=WritePerm);
    commit();
}
