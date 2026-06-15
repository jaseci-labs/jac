"""Jac Super AI plugin -- `run_ai_agent` hook for future AI extensions."""
import from jaclang.jac0core.runtime { hookimpl, plugin_manager }

class JacSuperAiPlugin {
    @hookimpl
    static def run_ai_agent(req: object) -> int | None;
}

with entry {
    plugin_manager.register(JacSuperAiPlugin());
}
