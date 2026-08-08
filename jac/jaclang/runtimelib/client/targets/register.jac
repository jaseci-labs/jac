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
    try {
        import from jaclang.runtimelib.client.targets.android_target { AndroidTarget }
        registry.register(AndroidTarget());
    } except ImportError as e {
        import from jaclang.cli.console { console }
        console.warning(
            f"  Android (Compose) target unavailable ({e}). "
            "Install optional Android deps or fix the import error."
        );
    }
}

def sync_client_target_choices {
    import from jaclang.cli.registry { get_registry }
    import from jaclang.runtimelib.client.targets.registry { TargetType }
    registry = get_registry();
    names = [t.value for t in TargetType];
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
