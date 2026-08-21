"""The compiled region bounds every rewrite; unreached code stays byte-identical."""
import ast;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from tests.support {
    GRAPHMEND_FIXTURES as FIXTURES,
    code_mentions_symbol as _mentions_symbol,
    graphmend_break_kinds as _break_kinds,
    graphmend_compile_opts as _compile_opts,
    graphmend_pysrc as _pysrc
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.project.config { JacConfig }
import jaclang.project.config as config_mod;

"""Unparse one named function out of generated Python source."""
def _fn_src(src: str, name: str) -> str {
    tree = ast.parse(src);
    for nd in ast.walk(tree) {
        if isinstance(nd, ast.FunctionDef) and (nd.name == name) {
            return ast.unparse(nd);
        }
    }
    return "";
}

"""Compile a fixture with default (auto) options and return its Python source."""
def _auto_pysrc(name: str) -> str {
    return _compile_opts(os.path.join(FIXTURES, name))[0];
}

"""Compile a fixture in an existing program and return its Python source."""
def _pysrc_in(prog: JacProgram, name: str) -> str {
    return _compile_opts(
        os.path.join(FIXTURES, name),
        CompileOptions(graphmend=True, type_check=False),
        prog
    )[0];
}

test "an unreachable sibling keeps every transformable pattern untouched" {
    src_on = _pysrc("region_unreachable_sibling.jac", True);
    src_off = _pysrc("region_unreachable_sibling.jac", False);
    # The entry chain is transformed as usual.
    assert "torch._assert_async(mask.all()" in _fn_src(src_on, "entry");
    assert "__jac_se_emit__" in _fn_src(src_on, "entry");
    # The sibling holds a lowerable guard, a data-dependent branch, and a
    # print, yet none of them may move: it is byte-identical to graphmend-off.
    assert _fn_src(src_on, "orphan") == _fn_src(src_off, "orphan");
    assert _fn_src(src_on, "orphan_leaf") == _fn_src(src_off, "orphan_leaf");
    assert "raise ValueError('orphan mask must be all true')" in src_on;
    assert "print('ORPHAN-EFFECT', y)" in src_on;
    assert "torch.where" not in src_on;
}

test "detection tags nothing outside the compiled region" {
    kinds = sorted(_break_kinds("region_unreachable_sibling.jac"));
    assert kinds == ["side_effect", "val_guard"];
}

test "a torch module without torch compile compiles byte identical" {
    src_on = _pysrc("region_no_compile.jac", True);
    src_off = _pysrc("region_no_compile.jac", False);
    src_auto = _auto_pysrc("region_no_compile.jac");
    assert src_on == src_off;
    assert src_auto == src_off;
    assert _break_kinds("region_no_compile.jac") == [];
}

test "a decorated entry chain is transformed at depth" {
    src = _pysrc("region_chain.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "deep");
    assert "print('DEEP-EFFECT'" not in src;
}

test "a cross module helper is transformed when its entry is in the hub" {
    prog = JacProgram();
    _pysrc_in(prog, "region_xmod_entry.jac");
    src = _pysrc_in(prog, "region_xmod_helper.jac");
    assert "__jac_se_emit__" in _fn_src(src, "far_helper");
    assert "print('FAR-ORPHAN', x)" in _fn_src(src, "far_orphan");
}

test "a relative import named like a stdlib module keeps its call edge" {
    # The sibling json.jac only shares a stdlib name: its import is relative,
    # which the deny list exempts for class lookups and must exempt for
    # ability lookups the same way.
    prog = JacProgram();
    _pysrc_in(prog, os.path.join("region_relstd", "entry.jac"));
    src = _pysrc_in(prog, os.path.join("region_relstd", "json.jac"));
    assert "__jac_se_emit__" in _fn_src(src, "near_helper");
}

test "a wrapped entry function is transformed through the wrap" {
    src = _pysrc("region_wrap_fn.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "wrapped");
}

test "a wrap entry callee is transformed at depth" {
    src = _pysrc("region_wrap_fn.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "wrap_helper");
    assert _break_kinds("region_wrap_fn.jac") == ["side_effect", "side_effect"];
}

test "a wrapped class compiles forward only" {
    # torch.compile(Model()) compiles forward; sibling methods stay eager. The
    # region is forward plus its call edges, never the whole class.
    src_on = _pysrc("region_wrap_cls.jac", True);
    src_off = _pysrc("region_wrap_cls.jac", False);
    assert "__jac_se_emit__" in _fn_src(src_on, "cls_helper");
    assert _fn_src(src_on, "side_step") == _fn_src(src_off, "side_step");
    assert "print('SIDE-STEP', x)" in src_on;
}

test "a seeded forward reaches a method through the self call and no further" {
    prog = JacProgram();
    src = _pysrc_in(prog, "region_self_method.jac");
    assert "__jac_se_emit__" in _fn_src(src, "step");
    assert "print('UNUSED-EFFECT', x)" in _fn_src(src, "unused");
    assert "__jac_se_emit__" not in _fn_src(src, "unused");
}

test "a seeded forward reaches an inherited method through the base chain" {
    # `helper` is declared on the base class only, so the self-call resolves
    # only if the walk follows the base chain. `base_orphan` sits beside it and
    # is called by nothing: the edge is the call, not the declaring class.
    src_on = _pysrc("region_inherited.jac", True);
    src_off = _pysrc("region_inherited.jac", False);
    assert "__jac_se_emit__" in _fn_src(src_on, "helper");
    assert _fn_src(src_on, "base_orphan") == _fn_src(src_off, "base_orphan");
    assert "print('BASE-ORPHAN', x)" in src_on;
}

test "a submodule attribute call reaches the held archetype's method" {
    # `self.blk` is proven to hold a Block by the constructor assignment, so
    # `self.blk.project(...)` is a region edge. `self.opaque` is assigned a call
    # that resolves to no class, so `self.opaque.spare(...)` proves nothing.
    src_on = _pysrc("region_submodule_attr.jac", True);
    src_off = _pysrc("region_submodule_attr.jac", False);
    assert "__jac_se_emit__" in _fn_src(src_on, "project");
    assert _fn_src(src_on, "spare") == _fn_src(src_off, "spare");
    assert "print('BLOCK-SPARE', x)" in src_on;
}

test "a submodule attribute call dispatches to the held class's forward" {
    # `Mixin.forward` is no seed of its own: the mixin has no Module base and
    # the class that does declares no forward. The call joins it to the region
    # through the constructor binding plus the base chain.
    src_on = _pysrc("region_submod_forward.jac", True);
    src_off = _pysrc("region_submod_forward.jac", False);
    assert "__jac_se_emit__(print, ('MIXIN-FORWARD'" in src_on;
    assert _fn_src(src_on, "mixin_orphan") == _fn_src(src_off, "mixin_orphan");
    assert "print('MIXIN-ORPHAN', x)" in src_on;
}

glob CACHE_ENTRY_SRC = "import torch;\n"
         + "import from usedmod { used_helper }\n\n"
         + "@torch.compile()\n"
         + "def f(x: any, mask: torch.Tensor) -> any {\n"
         + "    x = torch.relu(used_helper(x));\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"mask must be all true\");\n"
         + "    }\n"
         + "    return torch.sin(x) * 2.0;\n"
         + "}\n",
     CACHE_USED_SRC = "import torch;\n\n"
         + "def used_helper(x: any) -> any {\n"
         + "    print(\"USED\", x);\n"
         + "    return torch.relu(x);\n"
         + "}\n",
     CACHE_CONF_SRC = "import torch;\n\n"
         + "def conf_guard(x: any, mask: torch.Tensor) -> any {\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"conf mask must be all true\");\n"
         + "    }\n"
         + "    return torch.sin(x);\n"
         + "}\n\n"
         + "def conf_noisy(x: any) -> any {\n"
         + "    print(\"CONF\", x);\n"
         + "    return x;\n"
         + "}\n";

"""One entry module, one helper it reaches, one torch-importing module nothing
reaches."""
def _mk_region_project(tmp: str) -> tuple[str, str, str] {
    with open(os.path.join(tmp, "jac.toml"), "w") as fh {
        fh.write(
            "[project]\nname = \"gmregion\"\nversion = \"0.1.0\"\n"
                + "entry-point = \"main.jac\"\n"
        );
    }
    main_path = os.path.join(tmp, "main.jac");
    with open(main_path, "w") as fh {
        fh.write(CACHE_ENTRY_SRC);
    }
    used_path = os.path.join(tmp, "usedmod.jac");
    with open(used_path, "w") as fh {
        fh.write(CACHE_USED_SRC);
    }
    conf_path = os.path.join(tmp, "confmod.jac");
    with open(conf_path, "w") as fh {
        fh.write(CACHE_CONF_SRC);
    }
    return (main_path, used_path, conf_path);
}

test "an entry-less torch module shares its cache artifact with off" {
    # Every module in the package imports torch, so auto engages GraphMend on
    # all of them, but only the entry chain has a compiled region. The
    # entry-less module compiles byte-identical to off, so after one engaged
    # compile stamps the artifact, auto and off runs share the same cache slot
    # in both directions.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, used_path, conf_path) = _mk_region_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_main = prog_a.get_bytecode(main_path);
            code_conf = prog_a.get_bytecode(conf_path);
            assert code_main is not None and code_conf is not None;
            assert prog_a.mod.hub;
            assert _mentions_symbol(code_main, "_assert_async");
            assert not _mentions_symbol(code_conf, "__jac_se_emit__");
            prog_b = JacProgram();
            code_b = prog_b.get_bytecode(conf_path);
            assert code_b is not None;
            assert not prog_b.mod.hub , (
                "a second auto run must hit the stamped shared artifact"
            );
            config_mod._config = JacConfig.from_toml_str("[run]\ngraphmend = false\n");
            prog_off = JacProgram();
            code_off = prog_off.get_bytecode(conf_path);
            assert code_off is not None;
            assert not prog_off.mod.hub , (
                "an off run must share the entry-less module's artifact"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "a reached helper module keeps its own gm cache variant" {
    # The helper the entry reaches IS transformed, so its artifact must stay
    # variant-keyed: an off run may not reuse it and recompiles untransformed.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, used_path, conf_path) = _mk_region_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_main = prog_a.get_bytecode(main_path);
            code_used = prog_a.get_bytecode(used_path);
            assert code_main is not None and code_used is not None;
            assert _mentions_symbol(code_used, "__jac_se_emit__") , (
                "the reached helper must be transformed in realistic order"
            );
            config_mod._config = JacConfig.from_toml_str("[run]\ngraphmend = false\n");
            prog_off = JacProgram();
            code_off = prog_off.get_bytecode(used_path);
            assert code_off is not None;
            assert prog_off.mod.hub , (
                "an off run must not reuse the transformed helper artifact"
            );
            assert not _mentions_symbol(code_off, "__jac_se_emit__");
        }
    } finally {
        config_mod._config = old_config;
    }
}

glob REACH_ENTRY_SRC = "import torch;\n"
         + "import from ..reached { reach_helper }\n\n"
         + "@torch.compile()\n"
         + "def `entry(x: any) -> any {\n"
         + "    return torch.sin(reach_helper(x));\n"
         + "}\n",
     REACH_USED_SRC = "import torch;\n\n"
         + "def reach_helper(x: any) -> any {\n"
         + "    print(\"REACHED\", x);\n"
         + "    return torch.relu(x);\n"
         + "}\n";

"""An entry in a subpackage reaching a helper above that package: the region
walk follows the from-import, the claim walk, bounded by the entry's package,
does not, so the helper's own file and configuration say nothing about which
side of the region it landed on."""
def _mk_reach_project(tmp: str) -> tuple[(str, str)] {
    with open(os.path.join(tmp, "jac.toml"), "w") as fh {
        fh.write("[project]\nname = \"gmreach\"\nversion = \"0.1.0\"\n");
    }
    os.mkdir(os.path.join(tmp, "app"));
    with open(os.path.join(tmp, "app", "__init__.jac"), "w") as fh {
        fh.write("");
    }
    entry_path = os.path.join(tmp, "app", "entry.jac");
    with open(entry_path, "w") as fh {
        fh.write(REACH_ENTRY_SRC);
    }
    used_path = os.path.join(tmp, "reached.jac");
    with open(used_path, "w") as fh {
        fh.write(REACH_USED_SRC);
    }
    return (entry_path, used_path);
}

test "a helper with no region is not served the region artifact" {
    # Run A is one program, importer first, the order a real run imports in.
    # Run B is a fresh program on purpose: a separate process compiling the
    # helper alone, sharing only the warm cache, with no region at all.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (entry_path, used_path) = _mk_reach_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_entry = prog_a.get_bytecode(entry_path);
            code_used = prog_a.get_bytecode(used_path);
            assert code_entry is not None and code_used is not None;
            assert _mentions_symbol(code_used, "__jac_se_emit__") , (
                "the reached helper must be transformed in realistic order"
            );
            prog_b = JacProgram();
            code_b = prog_b.get_bytecode(used_path);
            assert code_b is not None;
            assert not _mentions_symbol(code_b, "__jac_se_emit__") , (
                "a compile with no region must not be served the region artifact"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "a region member is not served the entry-less artifact" {
    # The reverse direction. The first program compiles the helper alone, so
    # its artifact is the untransformed one; the second is a fresh program
    # compiling the entry first, where the helper IS a region member.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (entry_path, used_path) = _mk_reach_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_alone = JacProgram();
            code_alone = prog_alone.get_bytecode(used_path);
            assert code_alone is not None;
            assert not _mentions_symbol(code_alone, "__jac_se_emit__");
            prog_b = JacProgram();
            code_entry = prog_b.get_bytecode(entry_path);
            code_used = prog_b.get_bytecode(used_path);
            assert code_entry is not None and code_used is not None;
            assert _mentions_symbol(code_used, "__jac_se_emit__") , (
                "a region member must not be served the entry-less artifact"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}
