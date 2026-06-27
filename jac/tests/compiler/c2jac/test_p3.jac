"""P3 phase-exit: Tier-B detection + post-format comment injection."""

import re;
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.jac0core.program { JacProgram }

def _transpile(src: str) -> tuple {
    return transpile_c_str(src, "test.c");
}

def _parses(jac_str: str) -> bool {
    # The emitted Jac must always parse — Tier-B is "valid but maybe wrong",
    # never invalid (§8.2 validity invariant).
    prog = JacProgram();
    prog.compile(use_str=jac_str, file_path="emitted.jac");
    return len(prog.errors_had) == 0;
}

test "Union yields at least one Tier-B entry" {
    (jac_str, tags) = _transpile("union U { int i; float f; };\nint x;");
    assert len(tags.tier_b_entries()) > 0 , "Expected Tier-B entries for Union";
}

test "Tier-B entries carry c_line and an explained reason" {
    (jac_str, tags) = _transpile("union U { int i; float f; };\nint x;");
    sites = tags.tier_b_entries();
    assert len(sites) > 0;
    site = sites[0];
    assert site.c_line > 0 , f"Expected a real C line, got {site.c_line}";
    assert site.idiom is not None;
}

test "Tier-A-only file has zero Tier-B entries" {
    src = "int add(int a, int b) { return a + b; }\nint main(void) { return add(1, 2); }";
    (jac_str, tags) = _transpile(src);
    assert tags.tier_b_entries() == [] , f"Expected no Tier-B sites, got: {tags.tier_b_entries()}";
}

test "representation-changing cast is flagged Tier-B (not silently dropped)" {
    # (int)f truncates; the emitted Jac drops the cast, so it must be reported.
    (jac_str, tags) = _transpile("int trunc(float f) { return (int)f; }");
    sites = tags.tier_b_entries();
    assert len(sites) == 1 , f"Expected the cast flagged, got {len(sites)}";
    assert "cast" in sites[0].reason.lower();
}

test "pointer cast is NOT flagged (stays Tier-A)" {
    # (char*)0 doesn't change the emitted value — must not be over-reported.
    (jac_str, tags) = _transpile("int f(void) { char *p = (char*)0; return 0; }");
    assert tags.tier_b_entries() == [] , "Pointer casts should stay Tier-A";
}

test "comma expression drops side effects → Tier-B" {
    (jac_str, tags) = _transpile("int comma(int a, int b) { return (a++, b); }");
    sites = tags.tier_b_entries();
    assert len(sites) == 1 , f"Expected comma flagged, got {len(sites)}";
    assert "comma" in sites[0].reason.lower();
}

test "comma expression with pure leading operand stays Tier-A" {
    # `(a, b)` — the leading operand `a` is a side-effect-free read, so dropping
    # it changes nothing; only the final value matters. Must not be over-flagged.
    (jac_str, tags) = _transpile("int comma(int a, int b) { return (a, b); }");
    sites = tags.tier_b_entries();
    assert [
        s.reason
        for s in sites
        if "comma" in s.reason.lower()
    ] == [] , f"Pure comma operand should stay Tier-A, got {[s.reason for s in sites]}";
}

test "comma expression flags only the impure leading operand" {
    # `(a, f(), b)` — `a` is pure (droppable), `f()` has a side effect (not). The
    # count in the verdict must reflect only the impure operand.
    (jac_str, tags) = _transpile(
        "int f(void); int comma(int a, int b) { return (a, f(), b); }"
    );
    sites = [
        s
        for s in tags.tier_b_entries()
        if "comma" in s.reason.lower()
    ];
    assert len(sites) == 1 , f"Expected one comma flag, got {len(sites)}";
    assert "1 leading" in sites[0].reason , f"Expected count of 1, got: {sites[
        0
    ].reason}";
}

test "designated initializer drops field name → Tier-B" {
    src = "struct P { int x; int y; }; struct P mk(void) { struct P p = {.y = 4, .x = 3}; return p; }";
    (jac_str, tags) = _transpile(src);
    reasons = [s.reason for s in tags.tier_b_entries()];
    assert any("designated initializer" in r for r in reasons) , f"Expected designated-init flag, got {reasons}";
}

# ---------------------------------------------------------------------------- #
# §7/§9.2a — post-format Tier-B comment injection                              #
# ---------------------------------------------------------------------------- #
test "surrogate emits a valid int-line marker (not re-sliced C text)" {
    # A union has no Jac analog → surrogate. The marker carries the C line as an
    # INT arg; a string Constant would be re-sliced from the C source into invalid
    # Jac (e.g. `__c2jac_unsupported__(U { int i; )`).
    (jac_str, tags) = _transpile("union U { int i; float f; };\nint x;");
    assert re.search(r"__c2jac_unsupported__\(\d+\)", jac_str) is not None , f"Expected int-line surrogate marker:\n{jac_str}";
    assert _parses(jac_str) , f"Emitted Jac must parse (§8.2):\n{jac_str}";
}

test "Tier-B output carries a self-contained header" {
    (jac_str, tags) = transpile_c_str("union U { int i; float f; };", "u.c");
    assert jac_str.startswith("# c2jac:") , f"Expected header first:\n{jac_str[:120]}";
    assert "best-effort (Tier-B)" in jac_str;
    # The header is the authoritative record — it must NOT defer to a sidecar file.
    assert "report.json" not in jac_str , f"Header must not reference a sidecar:\n{jac_str[:120]}";
    assert re.search(r"#\s+L\d+\s+", jac_str) is not None , f"Header should list sites by C line:\n{jac_str[:200]}";
}

test "surrogate lines get an inline BEST-EFFORT note" {
    (jac_str, tags) = _transpile("union U { int i; float f; };");
    marker_lines = [
        l
        for l in jac_str.split("\n")
        if "__c2jac_unsupported" in l
    ];
    assert len(marker_lines) >= 1 , "Expected at least one surrogate line";
    for l in marker_lines {
        assert "# c2jac: BEST-EFFORT" in l , f"Surrogate line missing inline note: {l}";
    }
}

test "faithful Tier-B site (cast) is surfaced in the header, no inline marker" {
    # (int)f is elided faithfully → `return f;` with no surrogate call, so its only
    # in-file visibility is the header summary.
    (jac_str, tags) = _transpile("int trunc(float f){return (int)f;}");
    assert "__c2jac_unsupported" not in jac_str , f"Faithful cast must not emit a surrogate:\n{jac_str}";
    header = jac_str.split("def ")[0];
    assert header.startswith("# c2jac:");
    assert "cast" in header , f"Expected the cast site in the header:\n{header}";
    assert _parses(jac_str);
}

test "Tier-A-only output has no header and no notes" {
    (jac_str, tags) = _transpile("int add(int a,int b){return a+b;}");
    assert not jac_str.startswith("#") , f"Unexpected header on Tier-A output:\n{jac_str}";
    assert "BEST-EFFORT" not in jac_str;
    assert _parses(jac_str);
}
