"""Frozen sidecar plugin registration driven by [plugins.desktop.plugins]."""

from __future__ import annotations

import importlib
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pluggy import PluginManager


@dataclass(frozen=True, slots=True)
class FrozenPluginSpec:
    """How to register one Jac plugin in a PyInstaller-frozen sidecar."""

    module_path: str
    class_name: str
    entry_name: str
    config_key: str | None = None


# Primary ``jac`` entry point name per sidecar config key (distribution name
# normalized with underscores). Used when resolving from entry-point metadata.
_PRIMARY_ENTRY_BY_CONFIG_KEY: dict[str, str] = {
    "jac_scale": "scale",
    "byllm": "byllm",
    "jac_mcp": "mcp",
    "jac_coder": "coder",
}

# Fallback specs when entry-point metadata is unavailable inside a frozen binary.
_FALLBACK_REGISTRY: dict[str, FrozenPluginSpec] = {
    "jac_scale": FrozenPluginSpec("jac_scale.plugin", "JacCmd", "scale", "jac_scale"),
    "byllm": FrozenPluginSpec("byllm.plugin", "JacRuntime", "byllm", "byllm"),
    "jac_mcp": FrozenPluginSpec("jac_mcp.plugin", "JacCmd", "mcp", "jac_mcp"),
    "jac_coder": FrozenPluginSpec("jac_coder.plugin", "JacCmd", "coder", "jac_coder"),
}

# Always bundled — not controlled by [plugins.desktop.plugins].
_CORE_PLUGINS: tuple[FrozenPluginSpec, ...] = (
    FrozenPluginSpec("jac_client.plugin.client", "JacClient", "serve"),
)


def _normalize_config_key(name: str) -> str:
    return name.replace("-", "_").lower()


def _default_plugins_config() -> dict[str, bool]:
    return {
        "jac_scale": True,
        "byllm": True,
        "jac_coder": True,
        "jac_mcp": True,
    }


def _is_enabled(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() not in ("false", "0", "no", "off", "")
    return bool(value)


def _jac_toml_candidates(base_path: Path | None) -> list[Path]:
    candidates: list[Path] = []
    if base_path is not None:
        candidates.append(base_path / "jac.toml")
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        candidates.append(Path(meipass) / "jac.toml")
    return candidates


def load_sidecar_plugins_config(base_path: Path | None = None) -> dict[str, bool]:
    """Merge defaults with [plugins.desktop.plugins] from bundled jac.toml."""
    merged: dict[str, object] = dict(_default_plugins_config())
    for path in _jac_toml_candidates(base_path):
        if not path.is_file():
            continue
        try:
            import tomllib

            with open(path, "rb") as handle:
                data = tomllib.load(handle)
        except Exception as exc:
            sys.stderr.write(
                f"[sidecar] failed to load plugin config from {path}: {exc}\n"
            )
            continue
        desktop = data.get("plugins", {}).get("desktop", {})
        if not isinstance(desktop, dict):
            continue
        raw = desktop.get("plugins", {})
        if isinstance(raw, dict):
            merged.update(raw)
        break
    return {str(key): _is_enabled(value) for key, value in merged.items()}


def _parse_entry_point_value(value: str) -> tuple[str, str] | None:
    module_path, sep, class_name = value.partition(":")
    if not sep or not module_path or not class_name:
        return None
    return module_path, class_name


def _build_registry_from_entry_points() -> dict[str, FrozenPluginSpec]:
    """Build config-key registry from installed ``jac`` entry points."""
    registry: dict[str, FrozenPluginSpec] = {}
    try:
        from importlib.metadata import entry_points

        eps = entry_points(group="jac")
    except Exception as exc:
        sys.stderr.write(f"[sidecar] failed to discover jac entry points: {exc}\n")
        return registry

    for ep in eps:
        dist = getattr(ep, "dist", None)
        dist_name = getattr(dist, "name", "") if dist else ""
        if not dist_name:
            continue
        config_key = _normalize_config_key(dist_name)
        primary = _PRIMARY_ENTRY_BY_CONFIG_KEY.get(config_key)
        if primary is not None and ep.name != primary:
            continue
        if primary is None and (
            ep.name.endswith("_plugin_config") or ep.name.endswith("_plugin")
        ):
            continue
        parsed = _parse_entry_point_value(ep.value)
        if parsed is None:
            continue
        module_path, class_name = parsed
        registry[config_key] = FrozenPluginSpec(
            module_path=module_path,
            class_name=class_name,
            entry_name=ep.name,
            config_key=config_key,
        )
    return registry


def _resolve_registry() -> dict[str, FrozenPluginSpec]:
    dynamic = _build_registry_from_entry_points()
    resolved = dict(_FALLBACK_REGISTRY)
    resolved.update(dynamic)
    return resolved


def resolve_frozen_plugin_specs(
    plugins_config: dict[str, bool] | None = None,
    base_path: Path | None = None,
) -> list[FrozenPluginSpec]:
    """Return plugin specs to register for a frozen sidecar launch."""
    if plugins_config is None:
        plugins_config = load_sidecar_plugins_config(base_path)

    registry = _resolve_registry()
    specs: list[FrozenPluginSpec] = list(_CORE_PLUGINS)

    for config_key, enabled in plugins_config.items():
        if not enabled:
            continue
        spec = registry.get(config_key)
        if spec is None:
            continue
        specs.append(spec)

    # Preserve order while dropping duplicates (core client first).
    seen: set[tuple[str, str, str]] = set()
    unique: list[FrozenPluginSpec] = []
    for spec in specs:
        key = (spec.module_path, spec.class_name, spec.entry_name)
        if key in seen:
            continue
        seen.add(key)
        unique.append(spec)
    return unique


def _register_spec(plugin_manager: PluginManager, spec: FrozenPluginSpec) -> None:
    label = spec.config_key or spec.entry_name
    try:
        mod = importlib.import_module(spec.module_path)
        cls = getattr(mod, spec.class_name)
        if plugin_manager.is_registered(cls):
            return
        plugin_manager.register(cls, name=spec.entry_name)
        sys.stderr.write(f"[sidecar] Registered {label} plugin\n")
    except ImportError as exc:
        import traceback

        sys.stderr.write(f"[sidecar] {label} not bundled: {exc}\n")
        traceback.print_exc(file=sys.stderr)
    except Exception as exc:
        import traceback

        sys.stderr.write(f"[sidecar] {label} registration error: {exc}\n")
        traceback.print_exc(file=sys.stderr)


def register_frozen_plugins(
    plugin_manager: PluginManager,
    *,
    plugins_config: dict[str, bool] | None = None,
    base_path: Path | None = None,
) -> None:
    """Register Jac plugins manually for PyInstaller frozen apps.

    Entry point discovery fails in frozen apps, so enabled plugins from
    ``[plugins.desktop.plugins]`` are registered explicitly. ``jac_client`` is
    always registered as a core dependency.
    """
    for spec in resolve_frozen_plugin_specs(plugins_config, base_path):
        _register_spec(plugin_manager, spec)
