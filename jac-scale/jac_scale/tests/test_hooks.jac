"""Test hook registration for JacScale."""

import from jac_scale.plugin { JacScalePlugin }
import from jac_scale.user_manager { JacScaleUserManager }
import from jaclang.jac0core.runtime { plugin_manager as pm }

test "get user manager implementation" {
    user_manager = JacScalePlugin.get_user_manager(base_path="");
    assert isinstance(user_manager, JacScaleUserManager);
}

test "hook registration" {
    plugin = JacScalePlugin();

    if not pm.is_registered(plugin) {
        pm.register(plugin);
    }

    hook_impls = pm.hook.get_user_manager.get_hookimpls();

    found = False;
    for impl in hook_impls {
        if (
            impl.plugin_name == "scale"
            or isinstance(impl.plugin, JacScalePlugin)
            or impl.function.__qualname__ == "JacScalePlugin.get_user_manager"
        ) {
            found = True;
            break;
        }
    }

    assert found , "JacScalePlugin.get_user_manager not found in hook implementations";
}
