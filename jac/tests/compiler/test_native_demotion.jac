"""Native demotion classification (#8030 B1): a pass crash is an ICE,
not a placement decision. ICE demotions get a distinct coverage outcome
and a loud (non-dim) note; diagnostic demotions stay dim."""

import os;
import from jaclang.jac0core.compiler {
    na_coverage_begin,
    na_coverage_end,
    na_coverage_record,
    na_demotion_note
}


test "ICE note is loud and self-identifies as a compiler bug" {
    (msg, style) = na_demotion_note("m.jac", "AttributeError: width", True);
    assert style != "dim";
    assert "internal" in msg;
    assert "m.jac" in msg;
}


test "diagnostic demotion note stays dim" {
    (msg, style) = na_demotion_note("m.jac", "error[E5092]: nope", False);
    assert style == "dim";
    assert "preferred native" in msg;
}


test "coverage records ice as a distinct sticky outcome" {
    na_coverage_begin();
    key = "/tmp/jac_test_ice_probe.jac";
    na_coverage_record(key, "ice", "AttributeError", "boom");
    na_coverage_record(key, "native");
    snap = na_coverage_end();
    rec = snap[os.path.realpath(key)];
    assert rec["outcome"] == "ice";
    assert rec["code"] == "AttributeError";
}
