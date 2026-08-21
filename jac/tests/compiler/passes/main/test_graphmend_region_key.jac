"""The region cache key derives from the module's reachability closure, so it
is stable across load orders, indifferent to unrelated modules, and moves
exactly when a module that feeds the region changes; the guard-lowering
decision derives from the same closure instead of accumulated program state."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from tests.support { code_mentions_symbol as _mentions_symbol }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.jir { get_module_cache_path }
import from jaclang.project.config { JacConfig }
import jaclang.project.config as config_mod;

glob KEY_ENTRY_SRC = "import torch;\n"
         + "import from usedmod { used_helper }\n\n"
         + "@torch.compile()\n"
         + "def f(x: any, mask: torch.Tensor) -> any {\n"
         + "    x = torch.relu(used_helper(x));\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"mask must be all true\");\n"
         + "    }\n"
         + "    return torch.sin(x) * 2.0;\n"
         + "}\n",
     KEY_ENTRY_EDIT_SRC = "import torch;\n"
         + "import from usedmod { used_helper }\n\n"
         + "@torch.compile()\n"
         + "def f(x: any, mask: torch.Tensor) -> any {\n"
         + "    x = torch.relu(used_helper(x));\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"mask must hold no false entry\");\n"
         + "    }\n"
         + "    return torch.sin(x) * 2.0;\n"
         + "}\n",
     KEY_USED_SRC = "import torch;\n\n"
         + "def used_helper(x: any) -> any {\n"
         + "    print(\"USED\", x);\n"
         + "    return torch.relu(x);\n"
         + "}\n",
     KEY_UNREL_SRC = "import torch;\n\n"
         + "def unrel_guard(x: any, mask: torch.Tensor) -> any {\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"unrel mask must be all true\");\n"
         + "    }\n"
         + "    return torch.sin(x);\n"
         + "}\n\n"
         + "def unrel_noisy(x: any) -> any {\n"
         + "    print(\"UNREL\", x);\n"
         + "    return x;\n"
         + "}\n";

"""An entry, the helper its region reaches, and a torch module nothing touches."""
def _mk_key_project(tmp: str) -> tuple[str, str, str] {
    with open(os.path.join(tmp, "jac.toml"), "w") as fh {
        fh.write(
            "[project]\nname = \"gmregionkey\"\nversion = \"0.1.0\"\n"
                + "entry-point = \"main.jac\"\n"
        );
    }
    main_path = os.path.join(tmp, "main.jac");
    with open(main_path, "w") as fh {
        fh.write(KEY_ENTRY_SRC);
    }
    used_path = os.path.join(tmp, "usedmod.jac");
    with open(used_path, "w") as fh {
        fh.write(KEY_USED_SRC);
    }
    unrel_path = os.path.join(tmp, "unrel.jac");
    with open(unrel_path, "w") as fh {
        fh.write(KEY_UNREL_SRC);
    }
    return (main_path, used_path, unrel_path);
}

test "an unrelated torch module in the program does not move the cache key" {
    # Run B loads an unrelated module first; the entry and helper artifacts
    # cached by run A must still hit, since nothing in their closure changed.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, used_path, unrel_path) = _mk_key_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            assert prog_a.get_bytecode(main_path) is not None;
            code_used_a = prog_a.get_bytecode(used_path);
            assert code_used_a is not None;
            assert _mentions_symbol(code_used_a, "__jac_se_emit__");
            prog_b = JacProgram();
            assert prog_b.get_bytecode(unrel_path) is not None;
            code_main_b = prog_b.get_bytecode(main_path);
            assert code_main_b is not None;
            assert main_path not in prog_b.mod.hub , (
                "an unrelated module in the program moved the entry's cache key"
            );
            code_used_b = prog_b.get_bytecode(used_path);
            assert code_used_b is not None;
            assert used_path not in prog_b.mod.hub , (
                "an unrelated module in the program moved the helper's cache key"
            );
            assert _mentions_symbol(code_used_b, "__jac_se_emit__");
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "the cache key is stable across module load orders" {
    # Same module set, permuted load order: the helper's key may not depend on
    # what happened to be compiled into the program first.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, used_path, unrel_path) = _mk_key_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            assert prog_a.get_bytecode(main_path) is not None;
            assert prog_a.get_bytecode(used_path) is not None;
            prog_c = JacProgram();
            assert prog_c.get_bytecode(main_path) is not None;
            assert prog_c.get_bytecode(unrel_path) is not None;
            code_used_c = prog_c.get_bytecode(used_path);
            assert code_used_c is not None;
            assert used_path not in prog_c.mod.hub , (
                "a permuted load order moved the helper's cache key"
            );
            assert _mentions_symbol(code_used_c, "__jac_se_emit__");
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "editing a module that feeds the region invalidates the dependent" {
    # The helper's own source is unchanged; only the entry that feeds its
    # region moved, so the helper must recompile rather than hit.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, used_path, unrel_path) = _mk_key_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            assert prog_a.get_bytecode(main_path) is not None;
            assert prog_a.get_bytecode(used_path) is not None;
            with open(main_path, "w") as fh {
                fh.write(KEY_ENTRY_EDIT_SRC);
            }
            prog_d = JacProgram();
            assert prog_d.get_bytecode(main_path) is not None;
            code_used_d = prog_d.get_bytecode(used_path);
            assert code_used_d is not None;
            assert used_path in prog_d.mod.hub , (
                "a feeder edit must invalidate the dependent's cached artifact"
            );
            assert _mentions_symbol(code_used_d, "__jac_se_emit__");
        }
    } finally {
        config_mod._config = old_config;
    }
}

glob WRAP_NET_SRC = "import torch;\n\n"
         + "def net_helper(x: any) -> any {\n"
         + "    print(\"NET-HELPER\", x);\n"
         + "    return x * 2.0;\n"
         + "}\n\n"
         + "class Net(torch.nn.Module) {\n"
         + "    def forward(self: any, x: any, mask: torch.Tensor) -> any {\n"
         + "        if not mask.all() {\n"
         + "            raise ValueError(\"net mask must be all true\");\n"
         + "        }\n"
         + "        return net_helper(torch.relu(x));\n"
         + "    }\n"
         + "}\n",
     WRAP_ENTRY_SRC = "import torch;\n"
         + "import from netmod { Net }\n\n"
         + "glob model = torch.compile(Net());\n";

"""A wrap-site entry module and the model module holding the guard."""
def _mk_wrap_project(tmp: str) -> tuple[str, str] {
    with open(os.path.join(tmp, "jac.toml"), "w") as fh {
        fh.write(
            "[project]\nname = \"gmwrapkey\"\nversion = \"0.1.0\"\n"
                + "entry-point = \"entry.jac\"\n"
        );
    }
    entry_path = os.path.join(tmp, "entry.jac");
    with open(entry_path, "w") as fh {
        fh.write(WRAP_ENTRY_SRC);
    }
    net_path = os.path.join(tmp, "netmod.jac");
    with open(net_path, "w") as fh {
        fh.write(WRAP_NET_SRC);
    }
    return (entry_path, net_path);
}

test "a guard lowers the same when the wrapping entry is a cache hit" {
    # Run 2 recompiles only the model module while the wrapping entry hits the
    # cache; the guard's fate may not depend on which artifacts were hits.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (entry_path, net_path) = _mk_wrap_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog1 = JacProgram();
            assert prog1.get_bytecode(entry_path) is not None;
            code_net1 = prog1.get_bytecode(net_path);
            assert code_net1 is not None;
            assert _mentions_symbol(code_net1, "_assert_async") , (
                "the cold compile order must lower the covered guard"
            );
            net_cache = get_module_cache_path(net_path);
            assert net_cache.exists();
            net_cache.unlink();
            prog2 = JacProgram();
            assert prog2.get_bytecode(entry_path) is not None;
            code_net2 = prog2.get_bytecode(net_path);
            assert code_net2 is not None;
            assert _mentions_symbol(code_net2, "__jac_se_emit__");
            assert _mentions_symbol(code_net2, "_assert_async") , (
                "the guard's fate changed because the wrapping entry was a "
                + "cache hit instead of a compile"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

glob BROKEN_TORCH_SRC = "import torch;\n\n"
         + "def broken(x: any) -> any {\n"
         + "    return torch.relu(x;\n"
         + "}\n";

"""Count the alerts recorded against `path` in `prog`."""
def _target_errors(prog: JacProgram, path: str) -> int {
    real = os.path.realpath(path);
    n = 0;
    for e in prog.errors_had {
        try {
            p = os.path.realpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if p == real {
            n += 1;
        }
    }
    return n;
}

test "a broken torch source reports its errors exactly once through the probe" {
    # The probe parses the target speculatively and trims the alerts it added;
    # the real compile must then report them once, neither zero nor twice.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            with open(os.path.join(tmpdir, "jac.toml"), "w") as fh {
                fh.write(
                    "[project]\nname = \"gmbroken\"\nversion = \"0.1.0\"\n"
                        + "entry-point = \"broken.jac\"\n"
                );
            }
            broken_path = os.path.join(tmpdir, "broken.jac");
            with open(broken_path, "w") as fh {
                fh.write(BROKEN_TORCH_SRC);
            }
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_on = JacProgram();
            assert prog_on.get_bytecode(broken_path) is None;
            n_on = _target_errors(prog_on, broken_path);
            assert n_on > 0 , (
                "a broken source must still report its errors after the probe"
            );
            config_mod._config = JacConfig.from_toml_str("[run]\ngraphmend = false\n");
            prog_off = JacProgram();
            assert prog_off.get_bytecode(broken_path) is None;
            n_off = _target_errors(prog_off, broken_path);
            assert n_on == n_off , (
                f"the probe changed the error count: {n_on} with the probe, "
                + f"{n_off} without"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "a wrap seen only through facts materialization covers the guard" {
    # The entry is parsed into the hub by the claim walk, never compiled; the
    # lowering decision must derive from that closure, not from compile events.
    import from tests.support { graphmend_compile_opts as _compile_opts }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.compiler.passes.main.graphmend.scope_facts { claim_path }
    with TemporaryDirectory() as tmpdir {
        tmpdir = os.path.realpath(tmpdir);
        (entry_path, net_path) = _mk_wrap_project(tmpdir);
        prog = JacProgram();
        assert claim_path(prog, entry_path) , "the wrap entry must claim itself";
        (net_src, _bc) = _compile_opts(
            net_path, CompileOptions(graphmend=True, type_check=False), prog
        );
        assert "torch._assert_async(mask.all(), " in net_src , (
            "a wrap visible in the hub must cover the guard without a compile"
        );
        assert "raise ValueError" not in net_src;
    }
}
