def register_targets {
    registry = get_target_registry();
    registry.register(WebTarget());
    registry.register(StaticTarget());
    registry.register(DesktopTarget());
    registry.register(MobileTarget());
}
