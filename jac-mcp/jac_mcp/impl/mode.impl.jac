"""Implementation of mode resolution."""

import from jaclang.project.config { get_config, set_config, JacConfig }
import logging;

glob _logger = logging.getLogger("jac_mcp.mode");

impl get_mcp_mode -> str {
    jac_cfg = get_config();
    candidate = "";
    if jac_cfg {
        cfg = jac_cfg.get_plugin_config("mcp");
        candidate = str(cfg.get("mode", ""));
    }
    if not candidate {
        return DEFAULT_MODE;
    }
    if candidate in VALID_MODES {
        return candidate;
    }
    _logger.warning(
        f"unknown mode `{candidate}`, falling back to `{DEFAULT_MODE}` (valid: {VALID_MODES})"
    );
    return DEFAULT_MODE;
}

impl set_mcp_mode(mode: str) -> None {
    jac_cfg = get_config();
    if jac_cfg is None {
        jac_cfg = JacConfig();
        set_config(jac_cfg);
    }
    mcp = jac_cfg.plugins.setdefault("mcp", {});
    if mode {
        mcp["mode"] = mode;
    } else {
        mcp.pop("mode", None);
    }
}

# Placeholder: populated by follow-up PRs once per-mode surfaces are decided.
impl disabled_tools_for_mode(mode: str) -> set[str] {
    _ = mode;
    return set();
}

impl disabled_prompts_for_mode(mode: str) -> set[str] {
    _ = mode;
    return set();
}
