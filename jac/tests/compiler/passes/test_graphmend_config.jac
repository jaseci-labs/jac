"""Per-transform disable options, threaded from the CLI and jac.toml to per-pass gating."""
import os;
import from tests.support {
    GRAPHMEND_FIXTURES as FIXTURES,
    graphmend_compile_opts as _compile_opts
}
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    graphmend_disable_override,
    override_graphmend_disable
}

"""Compile a checked-in fixture under graphmend with a disable list and
return its generated Python source."""
def _pysrc(name: str, disable: list[str]) -> str {
    return _compile_opts(
        os.path.join(FIXTURES, name),
        CompileOptions(graphmend=True, graphmend_disable=disable)
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
    assert meta is not None;
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
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.project.config { JacConfig }
    import jaclang.project.config as config_mod;
    old_config = config_mod._config;
    try {
        config_mod._config = JacConfig.from_toml_str("[run]\nmain = true\n");
        gm_on = execution._apply_graphmend(" trap , defer ");
        assert CompileOptions().graphmend_disable == ["trap", "defer"];
        assert gm_on is True;
    } finally {
        override_graphmend_disable([]);
        config_mod._config = old_config;
    }
}

test "the cli disable flag reaches every run path and survives config rediscovery" {
    import tempfile;
    import jaclang.cli.commands.execution as execution;
    import jaclang.project.config as config_mod;
    import from unittest.mock { patch }
    seen: list[(list[str] | None)] = [];
    restored: list[str] = [];
    def _capture(*a: any, **k: any) -> int {
        config_mod.get_config(force_discover=True);
        seen.append(CompileOptions().graphmend_disable);
        return 0;
    }
    saved = (
        config_mod._config,
        config_mod._config_explicit,
        config_mod._config_by_root
    );
    try {
        with tempfile.TemporaryDirectory() as tmp {
            path = os.path.join(tmp, "model.jac");
            with open(path, "w") as fh {
                fh.write("def start {}\n");
            }
            override_graphmend_disable(["trap"]);
            with patch.object(execution, "_invoke_entrypoint", _capture), patch.object(
                execution, "debug", _capture
            ) {
                assert execution.run(
                    target=path, graphmend_disable="where", entry_name="start"
                )
                    == 0;
                assert execution.run(
                    target=path, graphmend_disable="where", debug_mode=True
                )
                    == 0;
            }
            restored = graphmend_disable_override();
        }
    } finally {
        override_graphmend_disable([]);
        (config_mod._config, config_mod._config_explicit, config_mod._config_by_root) = saved;
    }
    assert seen == [["where"], ["where"]];
    assert restored == ["trap"] , "a run must hand back the override it found";
}

test "a session reset clears the cli disable override" {
    import from jaclang.runtime.runtime { JacRuntime }
    try {
        override_graphmend_disable(["trap"]);
        JacRuntime.reset_process_state(clear_modules=False);
        assert graphmend_disable_override() == [];
    } finally {
        override_graphmend_disable([]);
    }
}

test "explicit compile options decide the transforms the compile runs" {
    import shutil;
    import tempfile;
    import from jaclang.compiler.driver.program { JacProgram }
    import from tests.support { GRAPHMEND_FIXTURES, code_mentions_symbol }
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(os.path.realpath(tmp), "guard.jac");
        shutil.copy(os.path.join(GRAPHMEND_FIXTURES, "val_guard_all.jac"), path);
        prog = JacProgram();
        code = prog._get_compiler().get_bytecode(
            full_target=path,
            target_program=prog,
            options=CompileOptions(graphmend=True, graphmend_disable=["trap"])
        );
        assert code is not None;
        assert not code_mentions_symbol(code, "_assert_async") , (
            "the explicit trap disable was ignored by the compile"
        );
    }
}

test "a module compiled under other graphmend settings is not reused from memory" {
    import shutil;
    import tempfile;
    import from jaclang.compiler.driver.program { JacProgram }
    import from tests.support { GRAPHMEND_FIXTURES, code_mentions_symbol }
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(os.path.realpath(tmp), "guard.jac");
        shutil.copy(os.path.join(GRAPHMEND_FIXTURES, "val_guard_all.jac"), path);
        prog = JacProgram();
        compiler = prog._get_compiler();
        plain = compiler.get_bytecode(
            full_target=path,
            target_program=prog,
            options=CompileOptions(graphmend=False)
        );
        assert (plain is not None) and not code_mentions_symbol(plain, "_assert_async");
        lowered = compiler.get_bytecode(
            full_target=path,
            target_program=prog,
            options=CompileOptions(graphmend=True, graphmend_disable=[])
        );
        assert (lowered is not None)
            and code_mentions_symbol(lowered, "_assert_async") , (
            "the untransformed compile was reused with graphmend on"
        );
        for opts in [
            CompileOptions(graphmend=True, graphmend_disable=["trap"]),
            CompileOptions(graphmend=False)
        ] {
            code = compiler.get_bytecode(
                full_target=path, target_program=prog, options=opts
            );
            assert code is not None;
            assert not code_mentions_symbol(code, "_assert_async") , (
                f"the first compile was reused under graphmend={opts.graphmend} "
                f"disable={opts.graphmend_disable}"
            );
        }
    }
}

test "a file edited to use torch is probed from its new source" {
    import shutil;
    import tempfile;
    import from jaclang.compiler.driver.program { JacProgram }
    import from tests.support { GRAPHMEND_FIXTURES, code_mentions_symbol }
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(os.path.realpath(tmp), "guard.jac");
        with open(path, "w") as fh {
            fh.write("def f(x: int) -> int {\n    return x;\n}\n");
        }
        prog = JacProgram();
        compiler = prog._get_compiler();
        opts = CompileOptions(graphmend=True, graphmend_disable=[]);
        first = compiler.get_bytecode(
            full_target=path, target_program=prog, options=opts
        );
        assert first is not None;
        stamp = os.path.getmtime(path) + 10;
        shutil.copy(os.path.join(GRAPHMEND_FIXTURES, "val_guard_all.jac"), path);
        os.utime(path, (stamp, stamp));
        code = compiler.get_bytecode(
            full_target=path, target_program=prog, options=opts
        );
        assert (code is not None) and code_mentions_symbol(code, "_assert_async") , (
            "the probe read the tree from before the edit and left graphmend off"
        );
    }
}
