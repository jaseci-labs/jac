"""Shared base configuration loader for build targets (desktop, mobile, …).

Both DesktopConfig and MobileConfig share identical init, _get_jac_config, and
load logic — only the TOML section key differs.  This base class captures that
shared code so each concrete config only has to implement the target-specific
parts.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig, get_config }

"""Abstract base for target configuration loaders.

Concrete subclasses must implement _section_key() and get_default_config().
The load() method uses _section_key() to read the right TOML section.
"""
class TargetConfig {
    has project_dir: Path | None = None,
        _config: dict[str, Any] | None = None,
        _jac_config: JacConfig | None = None;

    """Initialize with an optional project directory (defaults to cwd)."""
    def init(self: TargetConfig, project_dir: Path | None = None) -> None;

    """Return the top-level TOML section key for this target (e.g. 'mobile')."""
    def _section_key(self: TargetConfig) -> str abs;

    """Return the default configuration dict for this target."""
    def get_default_config(self: TargetConfig) -> dict[str, Any] abs;

    """Return (or lazily load) the root JacConfig instance."""
    def _get_jac_config(self: TargetConfig) -> JacConfig;

    """Load and cache configuration, merging defaults with jac.toml values."""
    def load(self: TargetConfig) -> dict[str, Any];
}
