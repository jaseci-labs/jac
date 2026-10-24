obj McpEngine {
    has resources: ResourceProvider,
        tools: ToolProvider,
        prompts: PromptProvider,
        instructions: str = "";

    def handle_message(msg: dict[str, any]) -> dict[str, any] | None;
    def _dispatch(method: str, params: dict[str, any]) -> dict[str, any];
    def _initialize(params: dict[str, any]) -> dict[str, any];
    def _list_resources -> dict[str, any];
    def _read_resource(params: dict[str, any]) -> dict[str, any];
    def _list_tools -> dict[str, any];
    def _call_tool(params: dict[str, any]) -> dict[str, any];
    def _list_prompts -> dict[str, any];
    def _get_prompt(params: dict[str, any]) -> dict[str, any];
}

def build_engine(instructions: str = "") -> McpEngine;

def serve_stdio(engine: McpEngine) -> None;

def serve_streamable_http(engine: McpEngine, host: str, port: int) -> None;

def serve_sse(engine: McpEngine, host: str, port: int) -> None;
