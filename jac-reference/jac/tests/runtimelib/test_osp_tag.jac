"""ASCII compiler type tags retain their values across compiler backends."""

import from jaclang.runtime.osp_tag { stable_osp_tag }

test "bounded tag arithmetic matches known reference hashes" {
    # Generated with the original unbounded FNV-1a calculation, masked to 53 bits.
    # Fixed vectors let this test itself run with native checked integers.
    for (name, expected) in [
        ("", 5239054864098085),
        ("Alert", 3459937832554201),
        ("Module", 4351073476296893),
        ("Symbol", 1077154556107505),
        ("TreeWalker", 500708216478327),
        ("ASTValidationPass", 1000785363432933),
        ("SymTabBuildPass", 4500574274975052)
    ] {
        actual = stable_osp_tag(name);
        assert actual == expected , f"{name}: expected {expected}, got {actual}";
    }
}
