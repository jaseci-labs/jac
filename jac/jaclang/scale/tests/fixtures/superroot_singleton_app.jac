"""Fixture: concurrent find-or-create of a singleton on the shared system root.

App pattern from issue #7605: every request resolves the system root by its
well-known id, looks up a singleton Hub under it, and creates one when
absent. The module-level bootstrap runs in system context at import time and
grants public WRITE on the system root so unauthenticated request walkers
may attach children — the same bootstrap shape production apps use for
shared singletons. Only public builtins are used (jobj / grant / commit).
"""

glob SYSTEM_ROOT_ID = "00000000-0000-0000-0000-000000000000";

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
    grant(jobj(id=SYSTEM_ROOT_ID), level=WritePerm);
    commit();
}
