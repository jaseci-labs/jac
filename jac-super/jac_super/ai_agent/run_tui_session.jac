"""Launch an NA-native TUI session for `jac ai --tui`."""

import from jaclang.cli.agent_api { AgentRequest }

def run_tui_session(req: AgentRequest) -> int;
