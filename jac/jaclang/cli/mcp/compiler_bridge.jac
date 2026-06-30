glob MAX_INPUT_SIZE: int = 102400,
     MAX_OUTPUT_SIZE: int = 102400,
     OUTPUT_TRUNCATION_MARKER: str = "\n[... output truncated ...]",
     DEFAULT_TIMEOUT: int = 10;

def run_with_timeout(func: object, timeout: int = 10) -> tuple;

obj CompilerBridge {
    static def parse_snippet(
        code: str, filename: str = "snippet.jac"
    ) -> dict[str, any];

    static def typecheck_snippet(
        code: str, filename: str = "snippet.jac"
    ) -> dict[str, any];

    static def format_snippet(code: str) -> dict[str, any];
    static def py_to_jac(python_code: str) -> dict[str, any];
    static def get_ast_snippet(code: str, fmt: str = "tree") -> dict[str, any];
    static def lint_snippet(code: str, auto_fix: bool = False) -> dict[str, any];
    static def jac_to_py(code: str) -> dict[str, any];
    static def jac_to_js(code: str) -> dict[str, any];
    static def run_snippet(
        code: str, entrypoint: str = "", timeout: int = 10
    ) -> dict[str, any];

    static def graph_viz_snippet(
        code: str,
        format: str = "dot",
        depth: int = -1,
        bfs: bool = True,
        edge_limit: int = 512,
        node_limit: int = 512
    ) -> dict[str, any];

    static def list_templates -> dict[str, any];
    static def create_project(
        name: str, template: str = "cli", directory: str = ""
    ) -> dict[str, any];
}
