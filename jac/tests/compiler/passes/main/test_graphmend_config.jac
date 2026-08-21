"""Per-transform disable options, threaded from the CLI and jac.toml to per-pass gating."""
import os;
import from tests.support {
    GRAPHMEND_FIXTURES as FIXTURES,
    graphmend_compile_opts as _compile_opts
}
import from jaclang.jac0core.compile_options { CompileOptions }

"""Compile a checked-in fixture under graphmend with a disable list and
return its generated Python source."""
def _pysrc(name: str, disable: list) -> str {
    return _compile_opts(
        os.path.join(FIXTURES, name),
        CompileOptions(graphmend=True, graphmend_disable=disable, type_check=False)
    )[0];
}

test "disabling trap leaves guards unlowered while where and defer still fire" {
    src = _pysrc("val_guard_all.jac", ["trap"]);
    assert "raise ValueError" in src;
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "torch.where(" in _pysrc("where_return.jac", ["trap"]);
    assert "__jac_se_emit__(print, " in _pysrc("side_effect.jac", ["trap"]);
}

test "disabling where leaves branches intact while trap and defer still fire" {
    src = _pysrc("where_return.jac", ["where"]);
    assert "torch.where(" not in src;
    assert "if " in src;
    assert "torch._assert_async(" in _pysrc("val_guard_all.jac", ["where"]);
    assert "__jac_se_emit__(print, " in _pysrc("side_effect.jac", ["where"]);
}

test "disabling defer leaves side effects eager while trap and where still fire" {
    src = _pysrc("side_effect.jac", ["defer"]);
    assert "__jac_se_emit__" not in src;
    assert "__jac_se_guard__" not in src;
    assert "print(x)" in src;
    assert "torch._assert_async(" in _pysrc("val_guard_all.jac", ["defer"]);
    assert "torch.where(" in _pysrc("where_return.jac", ["defer"]);
}

test "an empty disable list keeps every transform active" {
    assert "torch._assert_async(" in _pysrc("val_guard_all.jac", []);
    assert "torch.where(" in _pysrc("where_return.jac", []);
    assert "__jac_se_emit__(print, " in _pysrc("side_effect.jac", []);
}

test "the run command bridges the graphmend flags that remain to jac.toml" {
    import from jaclang.cli.manifest { get_command_meta }
    meta = get_command_meta("run");
    assert meta is not None;
    by_name = {a.name: a for a in meta.args};
    assert "graphmend" not in by_name;
    assert "graphmend_scope" not in by_name;
    gd = by_name.get("graphmend_disable");
    assert gd is not None;
    assert gd.config_key == "run.graphmend_disable";
}

test "the run section of jac.toml carries the graphmend keys" {
    import from jaclang.project.config { JacConfig }
    cfg = JacConfig.from_toml_str(
        "[run]\ngraphmend = false\ngraphmend_disable = \"trap\"\n"
    );
    assert cfg.run.graphmend is False;
    assert cfg.run.graphmend_disable == "trap";
}

test "run graphmend is an off switch that reads as on when absent" {
    import from jaclang.project.config { JacConfig }
    assert JacConfig.from_toml_str("[project]\nname = \"p\"\n").run.graphmend is True;
    assert JacConfig.from_toml_str("[run]\nmain = true\n").run.graphmend is True;
    assert JacConfig.from_toml_str("[run]\ngraphmend = false\n").run.graphmend is False;
}

"""A jac.toml written against the earlier tri-state keeps its meaning."""
test "the legacy mode spellings still resolve to the boolean gate" {
    import from jaclang.project.config { JacConfig }
    for spelled in ["true", "\"on\"", "\"auto\""] {
        cfg = JacConfig.from_toml_str(f"[run]\ngraphmend = {spelled}\n");
        assert cfg.run.graphmend is True , f"{spelled} must leave graphmend on";
    }
    assert JacConfig.from_toml_str("[run]\ngraphmend = \"off\"\n").run.graphmend
        is False;
}

test "explicit cli flags beat jac.toml which beats built-in defaults" {
    import from jaclang.cli.dispatch { _apply_config_defaults }
    import from jaclang.cli.manifest { get_command_meta }
    import from jaclang.project.config { JacConfig }
    meta = get_command_meta("run");
    cfg = JacConfig.from_toml_str("[run]\ngraphmend_disable = \"trap\"\n");
    at_defaults = {"graphmend_disable": ""};
    _apply_config_defaults(cfg, meta, at_defaults);
    assert at_defaults["graphmend_disable"] == "trap";
    explicit = {"graphmend_disable": "where"};
    _apply_config_defaults(cfg, meta, explicit);
    assert explicit["graphmend_disable"] == "where";
    silent = {"graphmend_disable": ""};
    _apply_config_defaults(
        JacConfig.from_toml_str("[run]\nmain = true\n"), meta, silent
    );
    assert silent["graphmend_disable"] == "";
}

test "the cli disable flag reaches the compile options carrier" {
    import jaclang.cli.commands.execution as execution;
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.project.config { JacConfig }
    import jaclang.project.config as config_mod;
    old_config = config_mod._config;
    try {
        config_mod._config = JacConfig.from_toml_str("[run]\nmain = true\n");
        gm_on = execution._apply_graphmend(" trap , defer ");
        assert CompileOptions().graphmend_disable == ["trap", "defer"];
        assert gm_on is True;
    } finally {
        config_mod._config = old_config;
    }
}
