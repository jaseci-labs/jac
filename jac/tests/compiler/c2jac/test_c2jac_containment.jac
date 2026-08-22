"""c2jac containment unit + multi-TU provenance (fidelity bands / project mode).

Covers:
  - function quarantine for hole/behavior sites (trap stub, no mid-body landmine)
  - style sites (W4201) do not quarantine
  - machine-readable sidecar JSON
  - --project multi-TU lift with cross-TU import wiring + aggregate report
"""

import json;
import os;
import tempfile;
import from jaclang.compiler.cfront.lift { lift_c_str, render_c2jac_report }
import from jaclang.compiler.cfront.report {
    build_c2jac_report,
    write_c2jac_report,
    report_sidecar_path
}
import from jaclang.compiler.cfront.project { lift_c_project }
import from jaclang.compiler.cfront.fidelity {
    FidelityBand,
    fidelity_band,
    band_quarantines
}
import from tests.compiler.c2jac.support {
    FIXTURES,
    recompile_errors as _recompile
}

test "fidelity band table splits style behavior and hole" {
    assert fidelity_band(4201) == FidelityBand.STYLE;
    assert fidelity_band(4205) == FidelityBand.BEHAVIOR;
    assert fidelity_band(4206) == FidelityBand.BEHAVIOR;
    # W4208 residual for-lowering lossiness (e.g. unmappable cond) is BEHAVIOR.
    assert fidelity_band(4208) == FidelityBand.BEHAVIOR;
    assert fidelity_band(4290) == FidelityBand.HOLE;
    assert band_quarantines(FidelityBand.BEHAVIOR);
    assert band_quarantines(FidelityBand.HOLE);
    assert not band_quarantines(FidelityBand.STYLE);
}

test "hole site quarantines the containing function as a call-time trap" {
    src = """
int clean(int x) { return x + 1; }
int dirty(int n) {
    int i = 0;
    int sum = 0;
loop:
    if (i < n) {
        sum += i;
        i++;
        goto loop;
    }
    return sum;
}
""";
    res = lift_c_str(src, "quarantine_hole.c");
    out = res.module.unparse(requires_format=True);
    assert "def clean(" in out;
    assert "return (x + 1)" in out or "return x + 1" in out;
    assert "def dirty(" in out;
    assert "raise" in out;
    assert "quarantined function 'dirty'" in out;
    assert "__c_unsupported__" not in out;
    assert res.quarantined_functions == ["dirty"];
    assert any([d[0] == "W4290" for d in res.diags]);
    assert _recompile(out, "quarantine_hole") == [];
}

test "style cast elision does not quarantine the function" {
    src = "int f(int a){ char c = (char)a; return c; }\n";
    res = lift_c_str(src, "style_cast.c");
    out = res.module.unparse(requires_format=True);
    assert res.quarantined_functions == [];
    assert len(res.diags) == 1;
    assert res.diags[0][0] == "W4201";
    assert res.sites[0].band == "style";
    assert "raise" not in out;
    assert "c =" in out or "c:" in out;
}

test "behavior static-local persistence quarantines the function" {
    src = "int counter(void){ static int n = 0; n = n + 1; return n; }\n";
    res = lift_c_str(src, "behavior_static.c");
    out = res.module.unparse(requires_format=True);
    assert res.quarantined_functions == ["counter"];
    assert res.diags[0][0] == "W4206";
    assert res.sites[0].band == "behavior";
    assert res.sites[0].quarantined;
    assert "quarantined function 'counter'" in out;
}

test "behavior volatile drop quarantines the function" {
    src = "int load(int *p){ volatile int v = *p; return v; }\n";
    res = lift_c_str(src, "behavior_volatile.c");
    out = res.module.unparse(requires_format=True);
    assert "W4205" in [d[0] for d in res.diags] , res.diags;
    assert "load" in res.quarantined_functions;
    assert "quarantined function 'load'" in out;
}

test "sidecar JSON records band and quarantined functions" {
    src = "int dirty(void){ goto done; done: return 0; }\n";
    res = lift_c_str(src, "side.c");
    out_dir = tempfile.mkdtemp();
    jac_path = os.path.join(out_dir, "side.jac");
    with open(jac_path, "w") as f {
        f.write(res.module.unparse(requires_format=True));
    }
    rep = build_c2jac_report(
        source="side.c",
        output=jac_path,
        sites=res.sites,
        quarantined=res.quarantined_functions,
        lenient=True
    );
    side = write_c2jac_report(jac_path, rep);
    assert side == report_sidecar_path(jac_path);
    data = json.load(open(side));
    assert data["version"] == 1;
    assert (data["tier_b_count"] as int) >= 1;
    assert "dirty" in (data["quarantined_functions"] as list);
    assert data["sites"][0]["band"] in ("hole", "behavior");
    assert data["sites"][0]["quarantined"] == True;
    # human header still renders
    assert "[W4290]" in render_c2jac_report(res.diags) or "[W" in render_c2jac_report(
        res.diags
    );
}

test "project mode wires cross-TU imports and writes aggregate report" {
    src_dir = os.path.join(FIXTURES, "project");
    out_dir = tempfile.mkdtemp();
    result = lift_c_project(src_dir, out_dir);
    names = sorted([os.path.basename(p) for p in result.outputs]);
    assert names == ["leaf.jac", "main.jac"] , names;
    main = open(os.path.join(out_dir, "main.jac")).read();
    leaf = open(os.path.join(out_dir, "leaf.jac")).read();
    assert "import from leaf { leaf_add }" in main , main;
    assert "def leaf_add(" in leaf;
    assert "def main_sum(" in main;
    assert result.registry.get("leaf_add") == "leaf";
    assert os.path.isfile(result.aggregate_path);
    agg = json.load(open(result.aggregate_path));
    assert agg["version"] == 1;
    assert agg["tier_b_total"] == 0;
    assert len(agg["files"] as list) == 2;
    # per-file sidecars exist
    assert os.path.isfile(os.path.join(out_dir, "main.c2jac.report.json"));
    assert os.path.isfile(os.path.join(out_dir, "leaf.c2jac.report.json"));
    assert _recompile(main, "project_main") == [];
    assert _recompile(leaf, "project_leaf") == [];
}
