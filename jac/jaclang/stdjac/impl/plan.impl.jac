impl remote_url(space: str) -> str {
    from_env = os.environ.get("JAC_REMOTE_" + space.upper(), "");
    if from_env {
        return from_env;
    }
    config = get_config();
    if config is None {
        return "";
    }
    for app in config.apps.values() {
        remote = app.overlays.get("remote") if isinstance(app.overlays, dict) else None;
        if isinstance(remote, dict) and space in remote {
            return str(remote[space]);
        }
    }
    return "";
}

impl setting_of(key: str, otherwise: str) -> str {
    config = get_config();
    if config is None {
        return otherwise;
    }
    held: any = config._raw_data;
    for part in key.split(".") {
        if not isinstance(held, dict) or part not in held {
            return otherwise;
        }
        held = held[part];
    }
    if held is None or isinstance(held, (dict, list)) {
        return otherwise;
    }
    return str(held);
}
