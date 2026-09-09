"""Variant agreement: X.native.jac must expose the public surface of X.jac.

The react-native target swaps a module for its `.native.jac` sibling, so the
two have to agree on names, declaration kinds, parameters and annotations.
Every disagreement is one E5105 on the variant; a module without a sibling
never pays for the check, and compiling both sides of a pair in one program
reports each disagreement once.
"""

import os;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.variant_agreement_pass {
    public_surface,
    variant_sibling
}

glob BASE: str = (
         "def greet(name: str) -> str { return name; }\n"
         + "def :priv hidden -> int { return 1; }\n"
         + "def _internal -> int { return 0; }\n"
         + "obj Card { has title: str = \"\", count: int = 0; }\n"
         + "enum Mode { A, B }\n"
         + "glob LIMIT: int = 3;\n"
     ),
     DRIFTED: str = (
         "def greet(name: int) -> str { return str(name); }\n"
         + "obj Card { has title: str = \"\"; }\n"
         + "def Mode -> int { return 1; }\n"
         + "def extra -> int { return 2; }\n"
     );


def _write(root_dir: str, rel: str, text: str) -> str {
    path = os.path.join(root_dir, rel);
    with open(path, "w") as f {
        f.write(text);
    }
    return path;
}


def _e5105(prog: JacProgram) -> list {
    return [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5105"
    ];
}


def _msgs(prog: JacProgram) -> str {
    return "\n".join(str(e) for e in prog.errors_had);
}


test "a module without a sibling is not checked" {
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, "jac.toml", '[project]\nname = "variants"\n');
        main = _write(tmp, "main.jac", BASE);
        assert variant_sibling(main) is None;
        assert variant_sibling(main[:-4] + ".impl.jac") is None , "annexes never pair";
        prog = JacProgram();
        prog.compile(main, options=CompileOptions(no_cgen=True));
        assert not _e5105(prog) , _msgs(prog);
    }
}


test "an agreeing variant is clean from either side" {
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, "jac.toml", '[project]\nname = "variants"\n');
        base = _write(tmp, "widget.jac", BASE);
        variant = _write(tmp, "widget.native.jac", BASE);
        assert variant_sibling(base) == variant;
        assert variant_sibling(variant) == base;
        for path in (base, variant) {
            prog = JacProgram();
            prog.compile(path, options=CompileOptions(no_cgen=True));
            assert not _e5105(prog) , _msgs(prog);
        }
    }
}


test "every disagreement is one E5105 on the variant" {
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, "jac.toml", '[project]\nname = "variants"\n');
        _write(tmp, "widget.jac", BASE);
        variant = _write(tmp, "widget.native.jac", DRIFTED);
        prog = JacProgram();
        prog.compile(variant, options=CompileOptions(no_cgen=True));
        errs = _e5105(prog);
        assert len(errs) == 5 , f"expected 5 disagreements, got:\n{_msgs(prog)}";
        for e in errs {
            assert e.loc.mod_path == variant , "E5105 lands on the variant";
            assert "'widget.native.jac' disagrees with 'widget.jac'" in e.msg , e.msg;
        }
        joined = "\n".join(e.msg for e in errs);
        assert "on 'greet'" in joined and "name: int" in joined , joined;
        assert "on 'Card'" in joined and "count: int" in joined , joined;
        assert "on 'Mode'" in joined
            and "ability" in joined
            and "enum" in joined , joined;
        assert "on 'extra'" in joined and "not a public symbol" in joined , joined;
        assert "on 'LIMIT'" in joined and "missing from the variant" in joined , joined;
    }
}


test "checking the base reports on the variant, and only once per program" {
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, "jac.toml", '[project]\nname = "variants"\n');
        base = _write(tmp, "widget.jac", BASE);
        variant = _write(tmp, "widget.native.jac", DRIFTED);
        prog = JacProgram();
        prog.compile(base, options=CompileOptions(no_cgen=True));
        errs = _e5105(prog);
        assert len(errs) == 5 , f"expected 5 disagreements from the base side, got:\n{_msgs(
            prog
        )}";
        assert all(e.loc.mod_path == variant for e in errs) , "always on the variant";
        prog.compile(variant, options=CompileOptions(no_cgen=True));
        assert len(_e5105(prog)) == 5 , (
            f"compiling the other side must not duplicate:\n{_msgs(prog)}"
        );
    }
}


test "the public surface skips private and underscore names" {
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, "jac.toml", '[project]\nname = "variants"\n');
        main = _write(tmp, "main.jac", BASE);
        mod = JacProgram().compile(main, options=CompileOptions(no_cgen=True));
        surface = public_surface(mod);
        assert sorted(surface) == ["Card", "LIMIT", "Mode", "greet"] , sorted(surface);
        assert surface["greet"][0] == "ability";
        assert surface["greet"][1] == "(name: str) -> str" , surface["greet"][1];
        assert surface["Card"][0] == "obj";
        assert surface["Card"][1] == "{title: str, count: int}" , surface["Card"][1];
        assert surface["Mode"][0] == "enum";
        assert surface["LIMIT"][0] == "glob" and surface["LIMIT"][1] == "int";
    }
}
