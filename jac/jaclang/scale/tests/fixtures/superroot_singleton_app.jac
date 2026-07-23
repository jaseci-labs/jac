"""Fixture: concurrent find-or-create of a singleton anchored to system_root."""
import from jaclang { JacRuntimeInterface as Jac }

node Hub {
    has label: str = "community";
}

walker:pub touch_hub {
    can go with entry {
        sys = Jac.get_context().system_root.archetype;
        hubs = [
            n
            for n in [sys-->]
            if isinstance(n, Hub)
        ];
        if not hubs {
            h = Hub(label="community");
            sys ++> h;
            hubs = [h];
        }
        report {"hubs": len(hubs)};
    }
}

walker:pub count_hubs {
    can go with entry {
        sys = Jac.get_context().system_root.archetype;
        hubs = [
            n
            for n in [sys-->]
            if isinstance(n, Hub)
        ];
        report {"hubs": len(hubs)};
    }
}

with entry {
    sys_root = Jac.get_context().system_root.archetype;
    grant(sys_root, level=WritePerm);
}
