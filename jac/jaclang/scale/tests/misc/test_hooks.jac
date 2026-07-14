import from jaclang.scale.plugin { JacScalePlugin }
import from jaclang.scale.identity.user_manager { JacScaleUserManager }

test "get user manager implementation" {
    user_manager = JacScalePlugin.get_user_manager(base_path="");
    assert isinstance(user_manager, JacScaleUserManager);
}
