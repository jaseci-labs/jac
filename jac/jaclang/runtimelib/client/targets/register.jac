import from jaclang.runtimelib.client.targets.registry { get_target_registry }
import from jaclang.runtimelib.client.targets.web_target { WebTarget }
import from jaclang.runtimelib.client.targets.pwa_target { PWATarget }
import from jaclang.runtimelib.client.targets.static_target { StaticTarget }
import from jaclang.runtimelib.client.targets.mobile_target { MobileTarget }
import from jaclang.runtimelib.client.targets.desktop.native_desktop_target {
    NativeDesktopTarget
}
import from jaclang.runtimelib.client.targets.desktop.cef_desktop_target {
    CefDesktopTarget
}
import from jaclang.runtimelib.client.targets.react_native_target { ReactNativeTarget }

def register_targets {
    registry = get_target_registry();
    registry.register(WebTarget());
    registry.register(PWATarget());
    registry.register(StaticTarget());
    registry.register(MobileTarget());
    registry.register(NativeDesktopTarget());

    registry.register(CefDesktopTarget());
    registry.register(ReactNativeTarget());
}

def sync_client_target_choices -> None {
    import from jaclang.cli.registry { get_registry }
    import from jaclang.runtimelib.client.targets.registry { get_target_factory }
    registry = get_registry();
    factory = get_target_factory();
    names = factory.get_available_target_names();
    if not names {
        return;
    }
    for cmd_name in ["build", "start"] {
        spec = registry.get(cmd_name);
        if spec is None {
            continue;
        }
        for arg in spec.get_all_args() {
            if arg.name == "client" {
                arg.choices = list(names);
            }
        }
    }
}
