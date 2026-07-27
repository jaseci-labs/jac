"""Dual-role server module (#6507).

It is reached by the browser as a cl->sv endpoint provider (its walkers are
`sv import`ed by `dualrole_frontend.cl.jac`) AND it is itself a server->server
consumer of `dualrole_analytics` via a *relative* `sv import`. Before the fix,
that one outgoing relative `sv import` lowered to a plain `from
.dualrole_analytics import ...`, which crashed the module at load time and
silently dropped `sign_guestbook` / `get_guestbook` from the API.

The walker bodies deliberately do NOT call into analytics, so registering and
invoking them never triggers a provider subprocess spawn — the analytics
binding only has to compile to a lazy HTTP stub for the module to load cleanly.
"""

sv import from .dualrole_analytics { Analyze, AnalyticsReport }

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
