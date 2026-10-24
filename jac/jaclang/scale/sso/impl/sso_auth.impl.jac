impl sso_host -> str {
    return str(get_scale_config().get_sso_config()['host']);
}

impl configured_platforms -> dict[str, dict[str, str]] {
    sso_config = get_scale_config().get_sso_config();
    platforms: dict[str, dict[str, str]] = {};
    for platform in Platforms {
        key = platform.value.lower();
        platform_config = sso_config.get(key, {});
        if platform.value == Platforms.FIREBASE.value {
            project_id = platform_config.get('project_id', '');
            if not project_id {
                continue;
            }
            platforms[platform.value] = {"project_id": project_id};
        } else {
            client_id = platform_config.get('client_id', '');
            client_secret = platform_config.get('client_secret', '');
            if not client_id or not client_secret {
                continue;
            }
            platforms[platform.value] = {
                "client_id": client_id,
                "client_secret": client_secret
            };
        }
    }
    return platforms;
}

impl SSOAuth.postinit {
    if not self.platforms {
        self.platforms = configured_platforms();
    }
}
