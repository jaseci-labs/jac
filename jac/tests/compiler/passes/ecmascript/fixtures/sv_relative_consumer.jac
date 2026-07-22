"""Dual-role server module: serves its own walkers AND consumes a sibling
microservice through a *relative* `sv import` (#6507).

`sign_guestbook` / `get_guestbook` are this module's own endpoints; the
`sv import from .sv_relative_provider` makes it also a server->server consumer.
Before #6507 the relative module name (`.sv_relative_provider`) was recorded as
the binding key while the Python stub generator looked it up bare
(`sv_relative_provider`); the mismatch dropped to a plain `from
.sv_relative_provider import ...`, which fails at load time and silently took
every endpoint of this module down with it.
"""

sv import from .sv_relative_provider { analyze, Analyze, AnalyticsReport }

glob _signatures: list[str] = [];

walker:pub sign_guestbook {
    has name: str;

    can run with Root entry {
        _signatures.append(self.name);
        report {"ok": True, "count": len(_signatures)};
    }
}

walker:pub get_guestbook {
    can run with Root entry {
        report _signatures;
    }
}
