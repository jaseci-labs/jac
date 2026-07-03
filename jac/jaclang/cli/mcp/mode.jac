glob VALID_MODES: list[str] = ["lite", "standard", "full"],
     DEFAULT_MODE: str = "full";

def get_mcp_mode -> str;

def set_mcp_mode(mode: str) -> None;

def disabled_tools_for_mode(mode: str) -> set[str];

def disabled_prompts_for_mode(mode: str) -> set[str];
