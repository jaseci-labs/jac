"""Browser Web Storage globals resolve to the `Storage` ambient type.

`localStorage` and `sessionStorage` are ambient browser globals available
to all frontend Jac modules. Accessing their real API surface
(getItem/setItem/removeItem/clear/key) must type-check cleanly — no E1032
(unknown attribute on an Unknown type) and no W1051 (expression type
could not be resolved).

A bogus attribute must still raise E1030 ("Type Storage has no attribute"),
proving the global is genuinely typed as `Storage` rather than silenced as
Unknown.
"""

with entry {
    # OK: real Storage API surface — must not emit E1032 / W1051.
    saved: str | None = localStorage.getItem("user");
    localStorage.setItem("user", "alice");
    localStorage.removeItem("user");
    localStorage.clear();
    first: str | None = localStorage.key(0);
    sessionStorage.setItem("tab", "1");

    # Error: `Storage` has no `getItm` member (typo) — exactly one E1030.
    bad = localStorage.getItm("user");
}
