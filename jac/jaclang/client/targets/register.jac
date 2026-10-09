import from jaclang.client.targets.registry { get_target_registry }
import from jaclang.client.targets.web_target { WebTarget }
import from jaclang.client.targets.static_target { StaticTarget }
import from jaclang.client.targets.desktop.desktop_target { DesktopTarget }
import from jaclang.client.targets.mobile_target { MobileTarget }
import from jaclang.client.targets.bun_target { BunTarget }

def register_targets {
    registry = get_target_registry();
    registry.register(WebTarget());
    registry.register(StaticTarget());
    registry.register(DesktopTarget());
    registry.register(MobileTarget());
    registry.register(BunTarget());
}
