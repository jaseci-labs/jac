import from pathlib { Path }
import from typing { Optional }

impl DesktopTarget.setup(project_dir: Path) -> None {}

impl DesktopTarget.engine(project_dir: Path) -> str {
    import from jaclang.client.desktop_config { get_desktop_config }
    return get_desktop_config(project_dir).get_engine();
}

impl DesktopTarget.out_dir_for(entry_file: Path, project_dir: Path) -> Path {
    import from jaclang.client.targets.registry { client_app_dir_for }
    import from jaclang.project.config { get_config_for_dir }
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
    import from jaclang.client.desktop_config { get_desktop_config }
    import from jaclang.client.vite_bundler { API_BASE_URL_ENV_VAR }
    backend = get_desktop_config(project_dir).get_backend();
    prior = os.environ.get(API_BASE_URL_ENV_VAR);
    if backend != "embedded" {
        os.environ[API_BASE_URL_ENV_VAR] = backend;
    }
    try {
        web_bundle = super.build(entry_file, project_dir, platform);
    } finally {
        if backend != "embedded" {
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
    import from jaclang.client.targets.desktop.webview_shell { webview_build }
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
    import from jaclang.client.targets.desktop.webview_shell { webview_start }
    webview_start(binary);
}

impl DesktopTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    if self.engine(project_dir) == "cef" {
        import from jaclang.client.targets.desktop.cef_shell { cef_dev_unsupported }
        cef_dev_unsupported();
    }
    import from jaclang.client.targets.desktop.webview_shell { webview_dev }
    webview_dev(
        entry_file,
        project_dir,
        self.out_dir_for(entry_file, project_dir),
        port=port,
        api_port=api_port
    );
}
