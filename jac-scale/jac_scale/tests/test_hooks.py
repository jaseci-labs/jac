"""Test hook registration for JacScale."""

import os
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

from jac_scale.config_loader import get_scale_config, reset_scale_config
from jac_scale.plugin import JacScalePlugin, _scale_pre_hook
from jac_scale.user_manager import JacScaleUserManager
from jaclang.cli.command import HookContext
from jaclang.jac0core.runtime import plugin_manager as pm


def test_get_user_manager_implementation():
    """Test that the plugin method returns the correct class instance."""
    # It returns an Instance, as seen in plugin.jac implementation
    user_manager = JacScalePlugin.get_user_manager(base_path="")
    assert isinstance(user_manager, JacScaleUserManager)


def test_hook_registration():
    """Test that the hook is registered with Jac plugin manager."""
    # Create plugin instance
    plugin = JacScalePlugin()

    # Register manually for the test
    if not pm.is_registered(plugin):
        pm.register(plugin)

    # Check hook implementations
    hook_impls = pm.hook.get_user_manager.get_hookimpls()

    # Verify our plugin's method is in the implementations
    found = False
    for impl in hook_impls:
        # Check if the function belongs to our plugin class or module
        if (
            impl.plugin_name == "scale"
            or isinstance(impl.plugin, JacScalePlugin)
            or impl.function.__qualname__ == "JacScalePlugin.get_user_manager"
        ):
            found = True
            break

    assert found, "JacScalePlugin.get_user_manager not found in hook implementations"


def test_scale_pre_hook_config_discovery_with_absolute_path():
    """Test --scale loads jac.toml from target directory, not CWD."""
    with tempfile.TemporaryDirectory() as temp_dir:
        # Setup target with distinctive config
        target_dir = Path(temp_dir) / "target"
        target_dir.mkdir()
        (target_dir / "jac.toml").write_text(
            "[plugins.scale.kubernetes]\napp_name = 'correct-app'"
        )
        (target_dir / "test.jac").write_text("with entry { }")

        # Setup CWD with wrong config
        cwd_dir = Path(temp_dir) / "cwd"
        cwd_dir.mkdir()
        (cwd_dir / "jac.toml").write_text(
            "[plugins.scale.kubernetes]\napp_name = 'wrong-app'"
        )

        original_cwd = os.getcwd()
        try:
            os.chdir(cwd_dir)
            reset_scale_config()

            mock_ctx = MagicMock(spec=HookContext)
            mock_ctx.get_arg.side_effect = lambda n, d=None: {
                "scale": True,
                "filename": str(target_dir / "test.jac"),
                "build": False,
                "experimental": False,
                "target": "kubernetes",
            }.get(n, d)

            with (
                patch("jac_scale.plugin.UtilityFactory.create_logger"),
                patch("jac_scale.plugin.DeploymentTargetFactory.create") as m,
            ):
                m.return_value.deploy.return_value = MagicMock(success=True)
                _scale_pre_hook(mock_ctx)

                assert (
                    get_scale_config().get_kubernetes_config()["app_name"]
                    == "correct-app"
                )
        finally:
            os.chdir(original_cwd)
            reset_scale_config()
