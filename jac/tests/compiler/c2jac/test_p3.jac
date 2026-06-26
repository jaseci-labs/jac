"""P3 phase-exit: Tier-B sidecar report + post-format comment injection."""

import json;
import re;
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.report { report_json }
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

test "report_json produces valid JSON" {
    (jac_str, tags) = _transpile("union U { int i; float f; };\nint x;");
    js = report_json("test.c", tags);
    parsed = json.loads(js);
    assert isinstance(parsed, dict);
}

test "report_json has required fields" {
    (jac_str, tags) = _transpile("union U { int i; float f; };\nint x;");
    parsed = json.loads(report_json("test.c", tags));
    assert parsed["version"] == 1;
    assert parsed["input"] == "test.c";
    assert "tier_b_sites" in parsed;
    assert isinstance(parsed["tier_b_sites"], list);
}

test "report_json tier_b_sites have c_line idiom reason snippet" {
    (jac_str, tags) = _transpile("union U { int i; float f; };\nint x;");
    parsed = json.loads(report_json("test.c", tags));
    sites = parsed["tier_b_sites"];
    assert len(sites) > 0;
    site = sites[0];
    assert "c_line" in site;
    assert "idiom" in site;
    assert "reason" in site;
    assert "snippet" in site;
}

test "Tier-A-only file has zero tier_b_sites" {
    src = "int add(int a, int b) { return a + b; }\nint main(void) { return add(1, 2); }";
    (jac_str, tags) = _transpile(src);
    parsed = json.loads(report_json("test.c", tags));
    assert parsed["tier_b_sites"] == [] , f"Expected no Tier-B sites, got: {parsed[
        'tier_b_sites'
    ]}";
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

test "Tier-B output carries a header pointing at the sidecar" {
    (jac_str, tags) = transpile_c_str("union U { int i; float f; };", "u.c");
    assert jac_str.startswith("# c2jac:") , f"Expected header first:\n{jac_str[:120]}";
    assert "best-effort (Tier-B)" in jac_str;
    assert "u.c2jac.report.json" in jac_str , f"Header should name the sidecar:\n{jac_str[:120]}";
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
