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
    with open(path, "w") as f {
        f.write(text);
    }
    return path;
}


def _stamp_of(mod: uni.Module, name: str) -> str {
    for stmt in mod.body {
        if (
            isinstance(stmt, uni.Ability)
            and isinstance(stmt.name_ref, uni.Name)
            and stmt.name_ref.value == name
        ) {
            return str(stmt.code_context);
        }
    }
    return "missing";
}


test "config pin moves an element the solver would leave on the server" {
    with tempfile.TemporaryDirectory() as tmpdir {
        _write(
            tmpdir,
            "jac.toml",
            "[project]\nname = \"pins\"\n\n"
            "[placement.pins]\n\"app.helper\" = \"client\"\n"
        );
        app = _write(
            tmpdir,
            "app.jac",
            "def helper(x: int) -> int { return x * 7; }\n\n"
            "def:pub use_it(x: int) -> int { return helper(x); }\n"
        );
        prog = JacProgram();
        mod = prog.compile(app, no_cgen=True);
        assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
        assert _stamp_of(mod, "helper") == "client" , (
            "config-pinned element must be stamped to its pinned space"
        );
        assert _stamp_of(mod, "use_it") == "server";
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
        with patch.dict(os.environ, {"JAC_IGNORE_PLACEMENT_PINS": "1"}) {
            assert placement_pins_muted();
            assert config_pin_for(pinned, "helper") == config_pin_for(plain, "helper");
            assert config_module_pin(pinned) == config_module_pin(plain) == "";
            assert pins_digest(pinned) == pins_digest(plain) , (
                "a muted project must digest like an empty [placement.pins] table"
            );
            prog = JacProgram();
            mod = prog.compile(pinned, no_cgen=True);
            assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
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
