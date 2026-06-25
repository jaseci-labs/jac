"""P3 phase-exit: Tier-B sidecar report generation."""

import json;
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.report { report_json }

def _transpile(src: str) -> tuple {
    return transpile_c_str(src, "test.c");
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
