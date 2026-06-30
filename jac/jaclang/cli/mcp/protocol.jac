obj McpEngine {
    has resources: object,
        tools: object,
        prompts: object,
        instructions: str = "";

    def handle_message(msg: dict) -> dict | None;
    def _dispatch(method: str, params: dict) -> dict;
    def _initialize(params: dict) -> dict;
    def _list_resources -> dict;
    def _read_resource(params: dict) -> dict;
    def _list_tools -> dict;
    def _call_tool(params: dict) -> dict;
    def _list_prompts -> dict;
    def _get_prompt(params: dict) -> dict;
}

def build_engine(instructions: str = "") -> McpEngine;

def serve_stdio(engine: McpEngine) -> None;

def serve_streamable_http(engine: McpEngine, host: str, port: int) -> None;

def serve_sse(engine: McpEngine, host: str, port: int) -> None;
