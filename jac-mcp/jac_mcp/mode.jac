"""Mode selection: gates which tools/prompts the MCP server exposes."""

import from typing { Any }

glob VALID_MODES: list[str] = ["lite", "standard", "full"],
     DEFAULT_MODE: str = "full";

"""Resolve active mode from [plugins.mcp] mode; falls back to DEFAULT_MODE."""
def get_mcp_mode -> str;

"""Write mode into the in-memory plugin config (used by the --mode CLI flag)."""
def set_mcp_mode(mode: str) -> None;

"""Tool names hidden in the given mode."""
def disabled_tools_for_mode(mode: str) -> set[str];

"""Prompt names hidden in the given mode."""
def disabled_prompts_for_mode(mode: str) -> set[str];
