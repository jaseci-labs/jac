import from pathlib { Path }
import from typing { Optional }

impl DesktopTarget.setup(project_dir: Path) -> None {}

impl DesktopTarget.engine(project_dir: Path) -> str {
    return get_desktop_config(project_dir).get_engine();
}

impl DesktopTarget.out_dir_for(entry_file: Path, project_dir: Path) -> Path {
    config = get_config_for_dir(str(project_dir));
    if config is None {
        return project_dir / self.output_dir;
    }
    return client_app_dir_for(config, str(entry_file)) / self.output_dir.name;
}

impl DesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import os;

    cfg = get_desktop_config(project_dir);
    choosable = bool(cfg.get_backends());
    if choosable
        and str(JacClientConfig(project_dir).get_api_config().get("base_url") or "") {
        raise ValueError(
            "Desktop configuration error: [client.api] base_url fixes the API base, so [desktop] backends cannot choose one; remove base_url"
        );
    }
    baked = "" if choosable else cfg.get_backend();
    baked = "" if baked == "embedded" else baked;
    prior = os.environ.get(API_BASE_URL_ENV_VAR);
    if baked {
        os.environ[API_BASE_URL_ENV_VAR] = baked;
    } elif choosable {
        os.environ.pop(API_BASE_URL_ENV_VAR, None);
    }
    try {
        web_bundle = super.build(entry_file, project_dir, platform);
    } finally {
        if baked or choosable {
            if prior is None {
                os.environ.pop(API_BASE_URL_ENV_VAR, None);
            } else {
                os.environ[API_BASE_URL_ENV_VAR] = prior;
            }
        }
    }
    out_dir = self.out_dir_for(entry_file, project_dir);
    if self.engine(project_dir) == "cef" {
        import from jaclang.client.targets.desktop.cef_shell { cef_build }
        return cef_build(entry_file, project_dir, out_dir, web_bundle);
    }

    return webview_build(entry_file, project_dir, out_dir, web_bundle);
}

impl DesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    binary = self.build(entry_file, project_dir, None);
    if self.engine(project_dir) == "cef" {
        import from jaclang.client.targets.desktop.cef_shell { cef_start }
        cef_start(binary);
        return;
    }

    webview_start(binary);
}

impl DesktopTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    if self.engine(project_dir) == "cef" {
        import from jaclang.client.targets.desktop.cef_shell { cef_dev_unsupported }
        cef_dev_unsupported();
    }

    webview_dev(
        entry_file,
        project_dir,
        self.out_dir_for(entry_file, project_dir),
        port=port,
        api_port=api_port
    );
}
