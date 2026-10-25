import os;
import sys;
import json;

glob STUDIO_MCP_VERSION: str = "0.1.0",
     MCP_PROTOCOL: str = "2025-06-18",
     MCP_PROTOCOLS: list[str] = ["2025-06-18", "2025-03-26", "2024-11-05"],
     KEY_HELP: str = "A studio model key: a module (`core.jobs`), a symbol (`core.jobs.Runner`, `core.jobs.Runner.start`), a `jac://sym/<key>` URI, or a file path with an optional `:line` (resolves to the innermost symbol at that line).",
     STUDIO_INSTRUCTIONS: str = "These tools connect you to jac hack, the terminal workspace the user is driving you from. The studio keeps a live, compiler-built model of this Jac project: every module, archetype, ability and field, and the archwire graph (in this codebase imports are wires declared in archwire.jac files, not import statements in the code). Use studio_selection to see what the user is pointing at, studio_wiring / studio_rules before changing dependencies, studio_graph to see the architecture a package level at a time, studio_insight for roles, interfaces, rule use, slices, blast radius, clusters, a tour or the architecture diff since main, studio_symbol to read a declaration together with its impl, studio_focus to show the user code you are discussing, and studio_link_plan to tie your plan steps to the code they touch.";

obj StudioTool {
    has name: str,
        description: str,
        method: str,
        schema: dict[str, any] = {};

    def spec -> dict[str, any];
}

obj StudioMcp {
    has socket_path: str = "",
        root_dir: str = "",
        tools: list[StudioTool] = [],
        client: (BridgeClient | None) = None;

    def postinit;
    def bridge -> BridgeClient;
    def handle(msg: dict[str, any]) -> (dict[str, any] | None);
    def call_tool(name: str, args: dict[str, any]) -> dict[str, any];
    def tool_params(tool: StudioTool, args: dict[str, any]) -> dict[str, any];
}

def studio_tools -> list[StudioTool];

def serve_studio_mcp(socket_path: str, root_dir: str) -> int;

def tool_text(payload: any, is_error: bool = False) -> dict[str, any];
