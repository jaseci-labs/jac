import "../styles/main.css";
import from "@viz-js/viz" { instance }
import from "@monaco-editor/react" { Editor as MonacoEditor }
sv import from ..main {
    set_mcp_server,
    validate_jac,
    check_syntax,
    format_jac,
    py_to_jac,
    get_ast,
    explain_error,
    list_examples,
    get_example,
    search_docs,
    jac_to_js,
    jac_to_py,
    run_jac,
    lint_jac,
    understand_jac_and_jaseci,
    get_resource,
    graph_visualize,
    list_commands,
    get_command,
    execute_command
}

def:pub DashboardPage(onBack: Any = None) -> JsxElement {
    DEFAULT_URL = "http://127.0.0.1:3001/mcp/";

    has current_result: dict = {},
        code: str = """obj Greeter {
    has name: str = 'World';

    def greet -> str {
        return 'Hello, ' + self.name + '!';
    }
}

with entry {
    g = Greeter(name='Jac');
    print(g.greet());
}""",
        python_input: str = "",
        query: str = "",
        example_name: str = "",
        resource_uri: str = "",
        command_name: str = "",
        command_target: str = "",
        command_args: str = "",
        error_message: str = "",
        server_url: str = "",
        connected: bool = False,
        loading: str = "",
        active_tool: str = "",
        notice: str = "Connect to an MCP server to get started.",
        output_copied: bool = False,
        ast_copied: bool = False,
        jac_copied: bool = False,
        graph_svg: str = "",
        lint_auto_fix: bool = False,
        run_entrypoint: str = "",
        run_timeout: int = 30,
        palette_open: bool = False,
        palette_query: str = "",
        palette_extra: str = "";

    #  Method declarations -- bodies are in Dashboard.impl.jac
    def get_first_report(spawn_res: Any) -> dict;
    def busy(tool: str) -> bool;
    def pretty_json(val: Any) -> str;
    def connect_notice(res: dict, url: str) -> str;
    async def connect -> None;
    def disconnect -> None;
    def start_notice(tool: str) -> str;
    def success_notice(tool: str, res: dict) -> str;
    def strip_bracket_prefix(msg: str) -> str;
    async def runTool(tool: str, args: dict) -> None;
    # Output renderers
    def renderErr -> JsxElement;
    def renderEmpty -> JsxElement;
    def renderUnderstandOutput -> JsxElement;
    def renderResourceOutput -> JsxElement;
    def renderJacToJsOutput -> JsxElement;
    def renderJacToPyOutput -> JsxElement;
    def renderPyToJacOutput -> JsxElement;
    def renderRunOutput -> JsxElement;
    def renderLintOutput -> JsxElement;
    def renderGraphVisualizeOutput -> JsxElement;
    def renderListCommandsOutput -> JsxElement;
    def renderGetCommandOutput -> JsxElement;
    def renderExecuteCommandOutput -> JsxElement;
    def renderValidationOutput -> JsxElement;
    def renderFormatOutput -> JsxElement;
    def renderAstOutput -> JsxElement;
    def renderExplainOutput -> JsxElement;
    def renderExamplesOutput -> JsxElement;
    def renderGetExampleOutput -> JsxElement;
    def renderSearchDocsOutput -> JsxElement;
    def renderActiveOutput -> JsxElement;
    def renderDock -> JsxElement;
    def renderPalette -> JsxElement;

    # Shared style tokens
    inputCls = "w-full bg-zinc-900/80 border border-white/[0.08] rounded-lg px-3 py-2 text-xs text-zinc-200 placeholder-zinc-600 font-mono focus:outline-none focus:border-orange-500/50 focus:bg-zinc-900 transition";
    ghostBtn = "px-3 py-1.5 text-[10px] rounded-lg bg-white/[0.04] hover:bg-white/[0.08] border border-white/[0.08] text-zinc-400 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition";

    return
        <div className="min-h-screen flex flex-col bg-[#0a0a0b] text-zinc-100">
            <div
                className="absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(255,122,24,0.09),transparent)] pointer-events-none"
            />
            <div
                className="absolute inset-0 bg-[radial-gradient(ellipse_60%_40%_at_80%_80%,rgba(120,80,255,0.04),transparent)] pointer-events-none"
            />
            <header
                className="relative flex-shrink-0 flex items-center justify-between px-6 h-14 border-b border-white/[0.05] bg-[#0a0a0b]/80 backdrop-blur-sm z-10"
            >
                <div className="flex items-center gap-4">
                    {onBack
                    and <button
                        onClick={onBack}
                        className="flex items-center gap-1.5 text-[10px] text-zinc-600 hover:text-zinc-300 transition-colors"
                    >
                        <span>
                            <-
                        </span>
                        <span>
                            Home
                        </span>
                    </button>}
                    <div className="flex items-center gap-2.5">
                        <div
                            className="h-6 w-6 rounded-lg bg-gradient-to-br from-orange-400 to-orange-600 flex items-center justify-center flex-shrink-0 shadow-[0_0_12px_rgba(255,122,24,0.4)]"
                        >
                            <span
                                className="text-[10px] font-bold text-white leading-none"
                            >
                                J
                            </span>
                        </div>
                        <div>
                            <h1
                                className="text-sm font-semibold tracking-tight text-white leading-none"
                            >
                                Jac MCP Studio
                            </h1>
                            <p
                                className="text-[9px] text-zinc-600 mt-0.5 leading-none tracking-wide"
                            >
                                19 tools · command palette
                            </p>
                        </div>
                    </div>
                </div>
                <div className="flex items-center gap-2.5">
                    <input
                        type="text"
                        value={server_url}
                        onChange={lambda e: Any { server_url = e.target.value;}}
                        placeholder={DEFAULT_URL}
                        className="w-64 bg-transparent border border-white/[0.06] rounded-lg px-3 py-1.5 text-[11px] text-zinc-500 placeholder-zinc-700 font-mono focus:outline-none focus:border-orange-500/30 focus:text-zinc-300 transition"
                    />
                    <button
                        onClick={disconnect if connected else connect}
                        disabled={busy("connect")}
                        className={"px-3.5 py-1.5 text-[11px] rounded-lg font-medium transition disabled:opacity-50 disabled:cursor-not-allowed " + (
                            "bg-zinc-800 hover:bg-zinc-700 text-zinc-400 border border-white/[0.06]"
                                if connected
                                else "bg-orange-500 hover:bg-orange-400 text-white shadow-[0_0_20px_rgba(255,122,24,0.25)]"
                        )}
                    >
                        {"Connecting..."
                            if busy("connect")
                            else ("Disconnect" if connected else "Connect")}
                    </button>
                    <div
                        className={"h-1.5 w-1.5 rounded-full flex-shrink-0 transition-colors duration-500 " + (
                            "bg-green-400 shadow-[0_0_6px_rgba(74,222,128,0.5)]"
                                if connected
                                else "bg-zinc-700"
                        )}
                    />
                </div>
            </header>
            <div
                className="relative flex-1 mx-auto w-full max-w-[1600px] px-6 pt-5 pb-5 flex gap-5 min-h-0"
            >
                <div
                    className="w-1/2 flex flex-col rounded-2xl border border-white/[0.08] bg-zinc-900/90 shadow-[0_20px_60px_rgba(0,0,0,0.5)] overflow-hidden min-h-0"
                >
                    <div
                        className="flex-shrink-0 flex items-center justify-between border-b border-white/[0.06] px-4 py-2.5 bg-zinc-900/50"
                    >
                        <div className="flex items-center gap-3">
                            <div className="flex items-center gap-1.5">
                                <span
                                    className="h-2.5 w-2.5 rounded-full bg-red-400/60"
                                />
                                <span
                                    className="h-2.5 w-2.5 rounded-full bg-yellow-400/60"
                                />
                                <span
                                    className="h-2.5 w-2.5 rounded-full bg-green-400/60"
                                />
                            </div>
                            <span className="text-[11px] font-mono text-zinc-600">
                                main.jac
                            </span>
                        </div>
                        <div className="flex items-center gap-2">
                            {loading != ""
                            and <div className="flex items-center gap-1.5 mr-3">
                                <span
                                    className="h-1.5 w-1.5 rounded-full bg-orange-400 animate-pulse"
                                />
                                <span
                                    className="text-[10px] text-zinc-500 font-mono max-w-[200px] truncate"
                                >
                                    {notice}
                                </span>
                            </div>}
                            <button
                                onClick={lambda { runTool(
                                    "run_jac",
                                    {
                                        "code": code,
                                        "entrypoint": run_entrypoint,
                                        "timeout": run_timeout
                                    }
                                );}}
                                disabled={loading != "" or not connected}
                                className={"flex items-center gap-1.5 px-3 py-1.5 text-[11px] rounded-lg font-medium border transition disabled:opacity-30 disabled:cursor-not-allowed " + (
                                    "bg-green-500/20 border-green-500/30 text-green-300 animate-pulse"
                                        if busy("run_jac")
                                        else "bg-green-500/10 border-green-500/20 text-green-400 hover:bg-green-500/20 hover:border-green-500/30"
                                )}
                            >
                                <span>
                                    ▶
                                </span>
                                <span>
                                    {"Running..." if busy("run_jac") else "Run"}
                                </span>
                            </button>
                            <button
                                onClick={lambda { runTool(
                                    "validate_jac", {"code": code}
                                );}}
                                disabled={loading != "" or not connected}
                                className={"flex items-center gap-1.5 px-3 py-1.5 text-[11px] rounded-lg font-medium border transition disabled:opacity-30 disabled:cursor-not-allowed " + (
                                    "bg-orange-500/20 border-orange-500/30 text-orange-300 animate-pulse"
                                        if busy("validate_jac")
                                        else "bg-orange-500/10 border-orange-500/20 text-orange-400 hover:bg-orange-500/20 hover:border-orange-500/30"
                                )}
                            >
                                <span>
                                    {"·" if busy("validate_jac") else "✓"}
                                </span>
                                <span>
                                    {"Validating..."
                                        if busy("validate_jac")
                                        else "Validate"}
                                </span>
                            </button>
                            <button
                                onClick={lambda { palette_open = True;palette_query = "";palette_extra = "";}}
                                disabled={not connected}
                                className="flex items-center gap-1.5 px-3 py-1.5 text-[11px] rounded-lg font-medium border border-white/[0.08] bg-white/[0.03] hover:bg-white/[0.07] text-zinc-400 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition"
                            >
                                <span>
                                    Tools
                                </span>
                                <span
                                    className="text-zinc-500 text-[12px] leading-none"
                                >
                                    ▾
                                </span>
                            </button>
                        </div>
                    </div>
                    <div
                        className="flex-shrink-0 px-4 py-1.5 border-b border-white/[0.03] bg-zinc-900/30 truncate"
                    >
                        <span className="text-[10px] text-zinc-600 leading-none">
                            Jac Editor — most tools use this code. For Python → Jac, open{" "}
                        </span>
                        <span
                            className="text-[10px] text-orange-500/60 font-medium leading-none"
                        >
                            Tools ▾ → Python to Jac
                        </span>
                        <span className="text-[10px] text-zinc-600 leading-none">
                            {" "}for a dedicated input.
                        </span>
                    </div>
                    <div className="flex flex-1 min-h-[440px]">
                        <MonacoEditor
                            height="100%"
                            width="100%"
                            language="javascript"
                            theme="vs-dark"
                            value={code}
                            onChange={lambda val: Any { code = val or "";}}
                            options={{
                                "fontSize": 12,
                                "fontFamily": "ui-monospace, 'JetBrains Mono', 'Fira Code', monospace",
                                "lineHeight": 22,
                                "minimap": {"enabled": False},
                                "scrollBeyondLastLine": False,
                                "lineNumbers": "on",
                                "renderLineHighlight": "line",
                                "tabSize": 4,
                                "insertSpaces": True,
                                "wordWrap": "off",
                                "padding": {"top": 16, "bottom": 16},
                                "overviewRulerBorder": False,
                                "hideCursorInOverviewRuler": True,
                                "scrollbar": {
                                    "verticalScrollbarSize": 6,
                                    "horizontalScrollbarSize": 6
                                },
                                "bracketPairColorization": {"enabled": True},
                                "guides": {"bracketPairs": True}
                            }}
                        />
                    </div>
                </div>
                {renderDock()}
            </div>
            {palette_open and renderPalette()}
        </div>;
}
