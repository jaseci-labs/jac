"""Desktop target implementation (PyTauri-based).

This is the canonical `desktop` client target. It does not require a Rust
toolchain on the developer's machine because it uses pytauri-wheel.

It reuses shared helper functions (sidecar bundling, icon generation,
config helpers) from `jac_desktop.helpers.desktop_helpers`.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }
import from jac_client.plugin.src.targets.registry { TargetType }

# `sync_tauri_plugin_npm_dependencies(project_dir)` is exported from
# `impl/pytauri_desktop_target.impl.jac` (defined there with `def ... { body }`).
# DO NOT add a forward `def ... -> None;` declaration here for module-level
# helpers — Jac treats it as an empty-bodied stub that shadows the real
# implementation, causing the function to silently return None at runtime
# (the symptom: `[plugins.desktop].tauri_plugins` never propagates to `[dependencies.npm]`).
"""Desktop build target — Python shell driving Tauri via pytauri-wheel.

Extends `WebTarget` directly; desktop-specific setup/build/dev/start behavior
is fully implemented here.
"""
obj PyTauriDesktopTarget(WebTarget) {
    has name: str = TargetType.DESKTOP.value,
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "plugins.desktop",
        output_dir: Path = Path("src-pytauri/dist");

    """Setup desktop target — scaffold src-pytauri/ Python shell."""
    override def setup(project_dir: Path) -> None;

    """Build desktop app — build web bundle, bundle sidecar, stage app.py."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start desktop dev — vite dev server + sidecar + python app.py."""
    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    """Start desktop app — build web bundle and run python app.py."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
