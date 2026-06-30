obj ToolProvider {
    def list_tools -> list[dict[str, any]];
    def call_tool(name: str, arguments: dict[str, any]) -> dict[str, any];
}

def explain_error(error_message: str) -> dict[str, any];

def list_examples(category: str | None = None) -> dict[str, any];

def get_example(name: str) -> dict[str, any];

def search_docs(query: str, limit: int = 5) -> dict[str, any];

def get_ast(code: str, fmt: str = "tree") -> dict[str, any];

def lint_jac(code: str, auto_fix: bool = False) -> dict[str, any];

def jac_to_py(code: str) -> dict[str, any];

def jac_to_js(code: str) -> dict[str, any];

def run_jac(code: str, entrypoint: str = "", timeout: int = 10) -> dict[str, any];

def graph_visualize(
    code: str,
    format: str = "dot",
    depth: int = -1,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512
) -> dict[str, any];

def list_commands -> dict[str, any];

def get_command(name: str) -> dict[str, any];

def execute_command(
    command: str, args: list[str] | None = None, timeout: int = 30
) -> dict[str, any];

def understand_jac_and_jaseci -> dict[str, any];

def get_resource(uri: str) -> dict[str, any];
