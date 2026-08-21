"""P2 acceptance tests for jaseci-labs/jac#8144 (BunHost PERSIST tier).

Derived from PLAN.md Priority 2 only — not from implementation internals.
"""

import from jaclang.jac0core.host {
    HOST_BUN,
    HOST_BROWSER,
    HOST_CAPABILITIES,
    HOST_CPYTHON,
    HOST_JS_GLOBALS,
    HOST_NPM,
    HOST_PERSIST,
    HOST_RN,
    host_provides_kind
}


test "bun capability table gains PERSIST alongside JS host capabilities" {
    caps = HOST_CAPABILITIES[HOST_BUN];
    assert HOST_NPM in caps;
    assert HOST_JS_GLOBALS in caps;
    assert HOST_PERSIST in caps , (
        "P2: bun host must advertise PERSIST once BunStore lands"
    );
    assert HOST_CAPABILITIES[HOST_BUN] == ['NPM', 'JS_GLOBALS', 'PERSIST'];
}

test "host_provides_kind exposes PERSIST on bun only among JS hosts" {
    assert host_provides_kind(HOST_BUN, HOST_PERSIST);
    assert host_provides_kind(HOST_CPYTHON, HOST_PERSIST);
    for kind in [HOST_BROWSER, HOST_RN] {
        assert not host_provides_kind(kind, HOST_PERSIST) , (
            f"{kind} must stay DOM/JS-only without a Store"
        );
    }
}

test "PERSIST is no longer exclusive to the CPython host row" {
    persist_hosts: list[str] = [];
    for kind in HOST_CAPABILITIES {
        caps = HOST_CAPABILITIES[kind];
        if HOST_PERSIST in caps {
            persist_hosts.append(kind);
        }
    }
    assert HOST_BUN in persist_hosts;
    assert HOST_CPYTHON in persist_hosts;
    assert len(persist_hosts) == 2 , (
        f"expected exactly cpython + bun Store hosts, got {persist_hosts}"
    );
}
