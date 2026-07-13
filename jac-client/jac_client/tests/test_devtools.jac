"""Tests for the dev-only devtools overlay: config schema and enablement gating.

The overlay's UI is a client-side (`.cl.jac`) React component verified by the
client bundle build; these tests cover the server-side pieces: that the
`[plugins.client.devtools]` schema is registered and that `is_devtools_enabled`
resolves correctly (env override > explicit config > dev-on / prod-off default).
"""

import os;
import tempfile;
import from pathlib { Path }
import from jac_client.plugin.plugin_config { JacClientPluginConfig }
import from jac_client.plugin.src.config_loader { JacClientConfig }

"""Write a minimal jac.toml (optionally with a devtools block) and return its dir."""
def _make_project(devtools_toml: str = "") -> Path {
    tmp = Path(tempfile.mkdtemp());
    content = "[project]\nname = \"devtools-test\"\nversion = \"1.0.0\"\n" + devtools_toml;
    (tmp / "jac.toml").write_text(content);
    return tmp;
}

"""Clear the JAC_DEVTOOLS env override so each case starts from a known state."""
def _clear_env -> None {
    os.environ.pop("JAC_DEVTOOLS", None);
}

test "devtools section is registered in the client config schema" {
    schema = JacClientPluginConfig.get_config_schema();
    assert "devtools" in schema["options"];
}

test "default: on for a dev serve, stripped from a production build" {
    _clear_env();
    proj = _make_project();
    assert JacClientConfig(proj).is_devtools_enabled(is_production=False) == True;
    assert JacClientConfig(proj).is_devtools_enabled(is_production=True) == False;
}

test "JAC_DEVTOOLS env var overrides in both directions" {
    proj = _make_project();
    os.environ["JAC_DEVTOOLS"] = "0";
    # Off even on a dev serve where the default would be on.
    assert JacClientConfig(proj).is_devtools_enabled(is_production=False) == False;
    os.environ["JAC_DEVTOOLS"] = "1";
    # On even in a production build (the staging opt-in).
    assert JacClientConfig(proj).is_devtools_enabled(is_production=True) == True;
    _clear_env();
}

test "explicit [plugins.client.devtools] enabled wins over the default" {
    _clear_env();
    off_proj = _make_project("[plugins.client.devtools]\nenabled = false\n");
    # Explicitly disabled even on a dev serve.
    assert JacClientConfig(off_proj).is_devtools_enabled(is_production=False) == False;
    on_proj = _make_project("[plugins.client.devtools]\nenabled = true\n");
    # Explicitly enabled even in a production build.
    assert JacClientConfig(on_proj).is_devtools_enabled(is_production=True) == True;
}
