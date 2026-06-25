"""Tests for jac_scale.inprocess helpers (no socket, backend-free where possible)."""

import from jaclang.cli.commands.cli_helpers { module_stem_from_file }


test "module stem strips compound codespace suffixes" {
    assert module_stem_from_file("/app/main.sv.jac") == "main";
    assert module_stem_from_file("/app/main.cl.jac") == "main";
    assert module_stem_from_file("/app/main.na.jac") == "main";
    assert module_stem_from_file("/app/main.jac") == "main";
}
