"""Tests for [placement.pins]: config-driven placement pinning (#7772).

The pins table in jac.toml is the placement escape hatch: it feeds
ElementSummary.pinned exactly like a source marker did, so the solver
treats config-pinned elements as immovable and the modkey invalidates
when the pins change.
"""

import os;
import tempfile;
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.placement.placement_pins {
    config_module_pin,
    config_pin_for,
    pins_digest,
    placement_pins_muted
}
import from jaclang.compiler.driver.program { JacProgram }


def _write(dirpath: str, name: str, text: str) -> str {
    path = os.path.join(dirpath, name);
    os.makedirs(os.path.dirname(path), exist_ok=True);
    with open(path, "w") as f {
        f.write(text);
    }
    return path;
}


def _element(mod: uni.Module, name: str) -> (uni.ContextAwareNode | None) {
    for stmt in mod.body {
        names: list[str] = [];
        if isinstance(stmt, uni.Ability) and isinstance(stmt.name_ref, uni.Name) {
            names = [stmt.name_ref.value];
        } elif isinstance(stmt, (uni.Archetype, uni.Enum)) {
            names = [stmt.name.value];
        } elif isinstance(stmt, uni.GlobalVars) {
            for assign in stmt.assignments {
                names += [
                    t.value
                    for t in assign.target
                    if isinstance(t, uni.Name)
                ];
            }
        } elif isinstance(stmt, uni.Import) {
            names = [
                item.name.value
                for item in stmt.items
                if isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)
            ];
        }
        if name in names and isinstance(stmt, uni.ContextAwareNode) {
            return stmt;
        }
    }
    return None;
}


"""Where an element landed, with `+server` when it also keeps a server copy."""
def _placed(mod: uni.Module, name: str) -> str {
    elem = _element(mod, name);
    if elem is None {
        return "missing";
    }
    return str(elem.code_context) + ("+server" if elem.codespace_dual else "");
}


test "a client pin lands where it is pinned and pulls what it uses" {
    # (label, pins, files, compiled file, expected placement per element)
    rows: list[tuple[str, str, dict[str, str], str, dict[str, str]]] = [
        (
            "a pin moves an element the solver would leave on the server",
            "\"app.helper\" = \"client\"\n",
            {
                "app.jac": "def helper(x: int) -> int { return x * 7; }\n\n"
                "def:pub use_it(x: int) -> int { return helper(x); }\n"
            },
            "app.jac",
            {"helper": "client", "use_it": "server"}
        ),
        (
            "what a pin uses is shared with the server code that also uses it",
            "\"app.show\" = \"client\"\n",
            {
                "app.jac": "enum Color: int { RED, GREEN }\n\n"
                "def twice(n: int) -> int { return n * 2; }\n\n"
                "def show -> int { return twice(int(Color.GREEN)); }\n\n"
                "def:pub count -> int { return int(Color.RED); }\n",
                "api.jac": "import from app { twice }\n\n"
                "def:pub doubled -> int { return twice(3); }\n"
            },
            "app.jac",
            {
                "show": "client",
                "twice": "client+server",
                "Color": "client+server",
                "count": "server"
            }
        ),
        (
            "a glob that calls a client-only function keeps no server copy",
            "\"app.make\" = \"client\"\n\"app.show\" = \"client\"\n",
            {
                "app.jac": "def make -> int { return 3; }\n\n"
                "glob value: int = make();\n\n"
                "def show -> int { return value; }\n\n"
                "def:pub ping -> int { return 1; }\n"
            },
            "app.jac",
            {"value": "client"}
        ),
        (
            "the same through a helper placed after the glob",
            "\"later.make_two\" = \"client\"\n\"later.view\" = \"client\"\n",
            {
                "later.jac": "glob total: int = helper();\n\n"
                "def helper -> int { return make_two(); }\n\n"
                "def make_two -> int { return 2; }\n\n"
                "def view -> int { return total; }\n\n"
                "def:pub ping -> int { return 1; }\n"
            },
            "later.jac",
            {"total": "client"}
        ),
        (
            "a pinned function pulls the import it uses, client only when only it reads it",
            "\"main.app\" = \"client\"\n\"components.*\" = \"client\"\n",
            {
                "components/Hello.jac": "def:pub Hello() -> JsxElement {\n"
                "    return <div>hi</div>;\n}\n",
                "main.jac": "import from components.Hello { Hello }\n\n"
                "def:pub app() -> JsxElement {\n    return <Hello />;\n}\n"
            },
            "main.jac",
            {"app": "client", "Hello": "client"}
        )
    ];
    for (label, pins, files, target, expected) in rows {
        with tempfile.TemporaryDirectory() as tmpdir {
            _write(
                tmpdir,
                "jac.toml",
                "[project]\nname = \"pins\"\n\n[placement.pins]\n" + pins
            );
            for (name, text) in files.items() {
                _write(tmpdir, name, text);
            }
            prog = JacProgram();
            mod = prog.compile(os.path.join(tmpdir, target), no_cgen=True);
            assert not prog.errors_had , f"{label}: {[
                str(e) for e in prog.errors_had
            ]}";
            placed = {name: _placed(mod, name) for name in expected};
            assert placed == expected , f"{label}: {placed}";
        }
    }
}


test "module-glob pin matches every element of the module" {
    with tempfile.TemporaryDirectory() as tmpdir {
        _write(
            tmpdir,
            "jac.toml",
            "[project]\nname = \"pins\"\n\n"
            "[placement.pins]\n\"kernels.*\" = \"server\"\n"
        );
        sub = os.path.join(tmpdir, "kernels");
        os.makedirs(sub);
        kf = _write(sub, "fft.jac", "def fft(x: int) -> int { return x; }\n");
        assert config_pin_for(kf, "fft") == "server";
        assert config_pin_for(kf, "anything") == "server";
        other = _write(tmpdir, "other.jac", "def f -> int { return 1; }\n");
        assert config_pin_for(other, "f") == "";
    }
}


test "module pin registers as a server anchor" {
    with tempfile.TemporaryDirectory() as tmpdir {
        _write(
            tmpdir,
            "jac.toml",
            "[project]\nname = \"pins\"\n\n" "[placement.pins]\napp = \"server\"\n"
        );
        app = _write(tmpdir, "app.jac", "def f -> int { return 1; }\n");
        assert config_module_pin(app) == "server";
        digest = pins_digest(app);
        assert "app" in digest and "server" in digest , (
            "pins must serialize into the modkey digest"
        );
    }
}


test "invalid pin space fails loudly" {
    with tempfile.TemporaryDirectory() as tmpdir {
        _write(
            tmpdir,
            "jac.toml",
            "[project]\nname = \"pins\"\n\n" "[placement.pins]\napp = \"browser\"\n"
        );
        app = _write(tmpdir, "app.jac", "def f -> int { return 1; }\n");
        raised = False;
        try {
            config_module_pin(app);
        } except ValueError {
            raised = True;
        }
        assert raised , "an unknown space name must raise, not silently no-op";
    }
}


test "JAC_IGNORE_PLACEMENT_PINS mutes pins to the empty-table baseline" {
    import from unittest.mock { patch }
    with tempfile.TemporaryDirectory() as tmpdir {
        _write(
            tmpdir,
            "jac.toml",
            "[project]\nname = \"pins\"\n\n"
            "[placement.pins]\n\"app.helper\" = \"client\"\n"
        );
        pinned = _write(
            tmpdir,
            "app.jac",
            "def helper(x: int) -> int { return x * 7; }\n\n"
            "def:pub use_it(x: int) -> int { return helper(x); }\n"
        );
        plain_dir = os.path.join(tmpdir, "plain");
        os.makedirs(plain_dir);
        _write(
            plain_dir,
            "jac.toml",
            "[project]\nname = \"plain\"\n\n" "[placement.pins]\n"
        );
        plain = _write(plain_dir, "app.jac", "def helper -> int { return 1; }\n");
        prog = JacProgram();
        with patch.dict(os.environ, {"JAC_IGNORE_PLACEMENT_PINS": "0"}) {
            warm_mod = prog.compile(pinned, no_cgen=True);
            assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
            assert _stamp_of(warm_mod, "helper") == "client" , (
                "the initial compile must warm the cache with the configured pin"
            );
        }
        with patch.dict(os.environ, {"JAC_IGNORE_PLACEMENT_PINS": "1"}) {
            assert placement_pins_muted();
            assert config_pin_for(pinned, "helper") == config_pin_for(plain, "helper");
            assert config_module_pin(pinned) == config_module_pin(plain) == "";
            assert pins_digest(pinned) == pins_digest(plain) , (
                "a muted project must digest like an empty [placement.pins] table"
            );
            # A new program instance exercises the already-warmed disk cache.
            muted_prog = JacProgram();
            mod = muted_prog.compile(pinned, no_cgen=True);
            assert not muted_prog.errors_had , f"{[
                str(e) for e in muted_prog.errors_had
            ]}";
            assert _stamp_of(mod, "helper") == "server" , (
                "muted pins must leave the solver free to place the element"
            );
        }
    }
}


test "falsy JAC_IGNORE_PLACEMENT_PINS values keep pins authoritative" {
    import from unittest.mock { patch }
    with tempfile.TemporaryDirectory() as tmpdir {
        _write(
            tmpdir,
            "jac.toml",
            "[project]\nname = \"pins\"\n\n" "[placement.pins]\napp = \"server\"\n"
        );
        app = _write(tmpdir, "app.jac", "def f -> int { return 1; }\n");
        with patch.dict(os.environ, {"JAC_IGNORE_PLACEMENT_PINS": "0"}) {
            os.environ.pop("JAC_IGNORE_PLACEMENT_PINS", None);
            assert not placement_pins_muted();
            assert config_module_pin(app) == "server" , (
                "an unset env var must not mute pins"
            );
        }
        for value in ["0", "false", "off", "no", "  "] {
            with patch.dict(os.environ, {"JAC_IGNORE_PLACEMENT_PINS": value}) {
                assert not placement_pins_muted() , f"{value!r} must parse as falsy";
                assert config_module_pin(app) == "server" , (
                    f"env value {value!r} must not mute pins"
                );
            }
        }
    }
}


test "JAC_IGNORE_PLACEMENT_PINS mutes app override pins from a warm workspace" {
    import from unittest.mock { patch }
    with tempfile.TemporaryDirectory() as tmpdir {
        _write(
            tmpdir,
            "jac.toml",
            "[project]\nname = \"pins\"\ndefault-app = \"web\"\n\n"
            "[apps.web]\nkind = \"web-app\"\nentry-point = \"app\"\n\n"
            "[apps.web.placement.pins]\n\"app.helper\" = \"client\"\n"
        );
        app = _write(
            tmpdir,
            "app.jac",
            "def helper(x: int) -> int { return x * 7; }\n\n"
            "def:pub use_it(x: int) -> int { return helper(x); }\n"
        );
        prog = JacProgram();
        with patch.dict(os.environ, {"JAC_IGNORE_PLACEMENT_PINS": "0"}) {
            assert config_pin_for(app, "helper") == "client";
            warm_mod = prog.compile(app, no_cgen=True);
            assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
            assert _stamp_of(warm_mod, "helper") == "client";
        }
        with patch.dict(os.environ, {"JAC_IGNORE_PLACEMENT_PINS": "1"}) {
            assert config_pin_for(app, "helper") == "";
            # Keep the workspace warm while making this a fresh compiler run.
            muted_prog = JacProgram();
            mod = muted_prog.compile(app, no_cgen=True);
            assert not muted_prog.errors_had , f"{[
                str(e) for e in muted_prog.errors_had
            ]}";
            assert _stamp_of(mod, "helper") == "server" , (
                "muted app override pins must not survive a warm workspace/cache"
            );
        }
    }
}
