"""Tests for multi-mode sidecar functionality."""

import sys;
import os;


test "register_frozen_plugins function exists" {
    """Verify _register_frozen_plugins is importable."""
    import from jac_client.plugin.src.targets.desktop.sidecar.main {
        _register_frozen_plugins
    }
    assert _register_frozen_plugins is not None;
    assert callable(_register_frozen_plugins);
}


test "run_jac_cli function exists" {
    """Verify _run_jac_cli is importable."""
    import from jac_client.plugin.src.targets.desktop.sidecar.main {
        _run_jac_cli
    }
    assert _run_jac_cli is not None;
    assert callable(_run_jac_cli);
}


test "sidecar main function exists" {
    """Verify main() is importable."""
    import from jac_client.plugin.src.targets.desktop.sidecar.main {
        main
    }
    assert main is not None;
    assert callable(main);
}


test "plugin list covers all required plugins" {
    """Verify the plugin registration list includes scale, client, byllm."""
    import from jac_client.plugin.src.targets.desktop.sidecar.main {
        _register_frozen_plugins
    }
    import inspect;
    source = inspect.getsource(_register_frozen_plugins);
    assert "jac_scale.plugin" in source,
        "Missing jac_scale.plugin in plugin list";
    assert "jac_client.plugin.client" in source,
        "Missing jac_client.plugin.client in plugin list";
    assert "byllm.plugin" in source,
        "Missing byllm.plugin in plugin list";
}


test "env loading from MEIPASS in main" {
    """Verify main.py loads .env from _MEIPASS."""
    import inspect;
    import from jac_client.plugin.src.targets.desktop.sidecar.main { main }
    source = inspect.getsource(main);
    assert "_MEIPASS" in source,
        "main() should reference _MEIPASS for .env loading";
    assert "load_dotenv" in source or "dotenv" in source or ".env" in source,
        "main() should load .env from bundled location";
}
