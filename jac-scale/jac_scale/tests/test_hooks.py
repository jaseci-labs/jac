"""Test hook registration for JacScale."""

from jac_scale.plugin import JacScalePlugin
from jac_scale.user_manager import JacScaleUserManager
from jaclang.pycore.runtime import plugin_manager as pm


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
