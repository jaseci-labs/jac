import "../styles/main.css";
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
    search_docs
}

def:pub DashboardPage -> JsxElement {
    DEFAULT_URL = "http://127.0.0.1:3001/mcp/";

    has current_result: dict = {},
        code: str = "obj Foo { has x: int = 5; }",
        python_input: str = "",
        query: str = "",
        example_name: str = "",
        error_message: str = "",
        server_url: str = "",
        connected: bool = False,
        loading: str = "",
        active_tool: str = "",
        notice: str = "Connect to an MCP server to get started.",
        jac_copied: bool = False,
        output_copied: bool = False,
        ast_copied: bool = False,
        code_scroll: int = 0;
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
    def renderValidationOutput -> JsxElement;
    def renderFormatOutput -> JsxElement;
    def renderAstOutput -> JsxElement;
    def renderExplainOutput -> JsxElement;
    def renderExamplesOutput -> JsxElement;
    def renderGetExampleOutput -> JsxElement;
    def renderSearchDocsOutput -> JsxElement;
    def renderActiveOutput -> JsxElement;

    # Shared style tokens
    inputCls = "w-full bg-zinc-900/80 border border-white/[0.08] rounded-lg px-3 py-2 text-xs text-zinc-200 placeholder-zinc-600 font-mono focus:outline-none focus:border-orange-500/50 focus:bg-zinc-900 transition";
    sectionLabel = "text-[10px] uppercase tracking-[0.2em] text-zinc-500 font-semibold";
    panelCls = "rounded-2xl border border-white/[0.06] bg-zinc-900/40 backdrop-blur-sm p-4 space-y-3 shadow-[0_2px_20px_rgba(0,0,0,0.3)]";
    ghostBtn = "px-3 py-1.5 text-[10px] rounded-lg bg-white/[0.04] hover:bg-white/[0.08] border border-white/[0.08] text-zinc-400 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition";

    return
        <div className="min-h-screen bg-[#0a0a0b] text-zinc-100">
            <div
                className="absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(255,122,24,0.12),transparent)] pointer-events-none"
            />
            <div
                className="absolute inset-0 bg-[radial-gradient(ellipse_60%_40%_at_80%_80%,rgba(120,80,255,0.05),transparent)] pointer-events-none"
            />
            <div className="relative mx-auto max-w-[1600px] px-6 py-5 space-y-5">
                <div
                    className="flex items-center justify-between pb-4 border-b border-white/[0.05]"
                >
                    <div className="flex items-center gap-3">
                        <div>
                            <h1
                                className="text-base font-semibold tracking-tight text-white"
                            >
                                Jac MCP Studio
                            </h1>
                            <p className="text-[10px] text-zinc-600 mt-0">
                                Validate · Format · AST · Convert · Docs
                            </p>
                        </div>
                    </div>
                    <div className="flex items-center gap-2">
                        <div className="relative">
                            <input
                                type="text"
                                value={server_url}
                                onChange={lambda e: Any { server_url = e.target.value;}}
                                placeholder={DEFAULT_URL}
                                className="w-72 bg-zinc-900/60 border border-white/[0.08] rounded-lg px-3 py-1.5 text-xs text-zinc-400 placeholder-zinc-700 font-mono focus:outline-none focus:border-orange-500/40 focus:text-zinc-200 transition"
                            />
                        </div>
                        <button
                            onClick={disconnect if connected else connect}
                            disabled={busy("connect")}
                            className={"px-4 py-1.5 text-xs rounded-lg transition font-medium disabled:opacity-50 disabled:cursor-not-allowed shadow-sm " + (
                                "bg-zinc-800 hover:bg-zinc-700 text-zinc-300 border border-white/[0.08]"
                                    if connected
                                    else "bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-400 hover:to-orange-500 text-white shadow-[0_0_15px_rgba(255,122,24,0.3)]"
                            )}
                        >
                            {"Connecting..."
                                if busy("connect")
                                else ("Disconnect" if connected else "Connect")}
                        </button>
                        <div
                            className={"h-2 w-2 rounded-full flex-shrink-0 transition-colors " + (
                                "bg-green-400 shadow-[0_0_6px_rgba(74,222,128,0.6)]"
                                    if connected
                                    else "bg-zinc-700"
                            )}
                        />
                    </div>
                </div>
                <div className="flex flex-col items-center gap-3 py-6">
                    <div className="flex items-center gap-2 mb-1">
                        <span className="h-px w-8 bg-orange-500/30"/>
                        <p
                            className="text-[10px] text-zinc-600 uppercase tracking-[0.2em] font-medium"
                        >
                            Documentation Search
                        </p>
                        <span className="h-px w-8 bg-orange-500/30"/>
                    </div>
                    <div
                        className="flex w-full max-w-2xl gap-2 p-1 bg-zinc-900/60 border border-white/[0.06] rounded-2xl shadow-[0_4px_30px_rgba(0,0,0,0.4)] backdrop-blur-sm"
                    >
                        <input
                            type="text"
                            value={query}
                            onChange={lambda e: Any { query = e.target.value;}}
                            onKeyPress={lambda e: Any { if e.key == "Enter" {
                                runTool("search_docs", {"query": query});
                            }}}
                            placeholder="Search Jac documentation..."
                            className="flex-1 bg-transparent px-4 py-2 text-sm text-zinc-200 placeholder-zinc-600 focus:outline-none"
                        />
                        <button
                            onClick={lambda { runTool("search_docs", {"query": query});}}
                            disabled={loading != "" or not connected}
                            className={"px-5 py-2 text-sm rounded-xl font-medium transition disabled:opacity-30 disabled:cursor-not-allowed " + (
                                "bg-orange-500/80 animate-pulse text-white"
                                    if busy("search_docs")
                                    else "bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-400 hover:to-orange-500 text-white shadow-[0_0_15px_rgba(255,122,24,0.25)]"
                            )}
                        >
                            {"Searching..." if busy("search_docs") else "Search"}
                        </button>
                    </div>
                </div>
                <div className="grid grid-cols-1 xl:grid-cols-[1fr_320px_1fr] gap-5">
                    <div>
                        <div
                            className="rounded-2xl border border-white/10 bg-zinc-900/90 shadow-[0_20px_60px_rgba(0,0,0,0.45)] overflow-hidden"
                        >
                            <div
                                className="flex items-center justify-between border-b border-white/10 px-4 py-2.5 bg-zinc-900/60"
                            >
                                <div className="flex items-center gap-3">
                                    <div className="flex items-center gap-1.5">
                                        <span
                                            className="h-2.5 w-2.5 rounded-full bg-red-400/80"
                                        />
                                        <span
                                            className="h-2.5 w-2.5 rounded-full bg-yellow-400/80"
                                        />
                                        <span
                                            className="h-2.5 w-2.5 rounded-full bg-green-400/80"
                                        />
                                    </div>
                                    <span
                                        className="text-[11px] font-mono text-zinc-600"
                                    >
                                        main.jac
                                    </span>
                                </div>
                                <div
                                    className="flex flex-wrap justify-end items-center gap-1.5"
                                >
                                    <button
                                        onClick={lambda { runTool(
                                            "validate_jac", {"code": code}
                                        );}}
                                        disabled={loading != "" or not connected}
                                        className={"px-2.5 py-1 text-[10px] rounded-md bg-orange-500 hover:bg-orange-400 text-white disabled:opacity-30 disabled:cursor-not-allowed transition " + (
                                            "animate-pulse"
                                                if busy("validate_jac")
                                                else ""
                                        )}
                                    >
                                        {"Validating..."
                                            if busy("validate_jac")
                                            else "Validate"}
                                    </button>
                                    <button
                                        onClick={lambda { runTool(
                                            "check_syntax", {"code": code}
                                        );}}
                                        disabled={loading != "" or not connected}
                                        className={"px-2.5 py-1 text-[10px] rounded-md border border-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition " + (
                                            "bg-white/20 animate-pulse"
                                                if busy("check_syntax")
                                                else "bg-white/5 hover:bg-white/10"
                                        )}
                                    >
                                        {"Checking..."
                                            if busy("check_syntax")
                                            else "Syntax"}
                                    </button>
                                    <span className="w-px h-3.5 bg-white/10 mx-0.5"/>
                                    <button
                                        onClick={lambda { runTool(
                                            "format_jac", {"code": code}
                                        );}}
                                        disabled={loading != "" or not connected}
                                        className={"px-2.5 py-1 text-[10px] rounded-md border border-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition " + (
                                            "bg-white/20 animate-pulse"
                                                if busy("format_jac")
                                                else "bg-white/5 hover:bg-white/10"
                                        )}
                                    >
                                        {"Formatting..."
                                            if busy("format_jac")
                                            else "Format"}
                                    </button>
                                    <span className="w-px h-3.5 bg-white/10 mx-0.5"/>
                                    <button
                                        onClick={lambda { runTool(
                                            "get_ast_tree", {"code": code}
                                        );}}
                                        disabled={loading != "" or not connected}
                                        className={"px-2.5 py-1 text-[10px] rounded-md border border-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition " + (
                                            "bg-white/20 animate-pulse"
                                                if busy("get_ast_tree")
                                                else "bg-white/5 hover:bg-white/10"
                                        )}
                                    >
                                        {"Parsing..."
                                            if busy("get_ast_tree")
                                            else "AST Tree"}
                                    </button>
                                    <button
                                        onClick={lambda { runTool(
                                            "get_ast_json", {"code": code}
                                        );}}
                                        disabled={loading != "" or not connected}
                                        className={"px-2.5 py-1 text-[10px] rounded-md border border-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition " + (
                                            "bg-white/20 animate-pulse"
                                                if busy("get_ast_json")
                                                else "bg-white/5 hover:bg-white/10"
                                        )}
                                    >
                                        {"Parsing..."
                                            if busy("get_ast_json")
                                            else "AST JSON"}
                                    </button>
                                </div>
                            </div>
                            <div className="flex min-h-[520px] bg-[#0d0e10]">
                                <div
                                    className="overflow-hidden select-none flex-shrink-0 border-r border-white/5 w-10"
                                >
                                    <div
                                        style={{
                                            "transform": "translateY(-" + str(
                                                code_scroll
                                            ) + "px)",
                                            "paddingTop": "1rem"
                                        }}
                                    >
                                        {[
                                            <div
                                                key={n}
                                                className="text-[11px] leading-6 font-mono text-right pr-2 text-zinc-600"
                                            >
                                                {n}
                                            </div>
                                            for n in range(1, code.count('\n') + 3)
                                        ]}
                                    </div>
                                </div>
                                <textarea
                                    value={code}
                                    onChange={lambda e: Any { code = e.target.value;}}
                                    onScroll={lambda e: Any { code_scroll = e.target.scrollTop;}}
                                    spellCheck={False}
                                    className="flex-1 resize-none bg-[#0d0e10] pl-3 pr-4 py-4 font-mono text-xs leading-6 text-zinc-100 outline-none placeholder-zinc-700"
                                    placeholder="# Paste your Jac code here..."
                                />
                            </div>
                        </div>
                    </div>
                    <div
                        className="space-y-4 xl:sticky xl:top-6 xl:max-h-[calc(100vh-5rem)] xl:overflow-y-auto xl:pr-1"
                    >
                        <div className={panelCls}>
                            <div className="flex items-center justify-between">
                                <div className={sectionLabel}>
                                    Python to Jac
                                </div>
                                <button
                                    onClick={lambda { runTool(
                                        "py_to_jac", {"code": python_input}
                                    );}}
                                    disabled={loading != "" or not connected}
                                    className={"px-3 py-1.5 text-[10px] rounded-lg text-white disabled:opacity-30 disabled:cursor-not-allowed transition " + (
                                        "bg-purple-500 animate-pulse"
                                            if busy("py_to_jac")
                                            else "bg-purple-600 hover:bg-purple-500"
                                    )}
                                >
                                    {"Converting..."
                                        if busy("py_to_jac")
                                        else "Convert"}
                                </button>
                            </div>
                            <textarea
                                value={python_input}
                                onChange={lambda e: Any { python_input = e.target.value;}}
                                rows={5}
                                spellCheck={False}
                                className={inputCls + " resize-y"}
                                placeholder="# Paste Python code to convert to Jac..."
                            />
                            {active_tool == "py_to_jac"
                            and current_result
                            and "data" in current_result
                            and "jac_code" in current_result["data"]
                            and <div className="space-y-2 pt-1">
                                <div className="flex items-center justify-between">
                                    <span
                                        className="text-[10px] text-zinc-500 uppercase tracking-wider"
                                    >
                                        Converted Jac
                                    </span>
                                    <button
                                        onClick={lambda { navigator.clipboard.writeText(
                                            current_result["data"]["jac_code"]
                                        );jac_copied = True;setTimeout(
                                            lambda { jac_copied = False;}, 2000
                                        );}}
                                        className={"px-2 py-1 text-[9px] rounded-md border transition " + (
                                            "bg-green-500/20 border-green-500/40 text-green-400"
                                                if jac_copied
                                                else "bg-white/5 hover:bg-white/10 border-white/10"
                                        )}
                                    >
                                        {"Copied!" if jac_copied else "Copy"}
                                    </button>
                                </div>
                                <pre
                                    className="text-[11px] text-green-400 max-h-[280px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-white/5 whitespace-pre-wrap break-words"
                                >
                                    {current_result["data"]["jac_code"]}
                                </pre>
                                {"warnings" in current_result["data"]
                                and len(current_result["data"]["warnings"]) > 0
                                and <div className="space-y-1 pt-1">
                                    <span
                                        className="text-[10px] text-yellow-500 uppercase tracking-wider"
                                    >
                                        Warnings
                                    </span>
                                    {[
                                        <div
                                            key={str(w)}
                                            className="text-xs font-mono text-yellow-400 bg-yellow-500/10 border border-yellow-500/20 p-2 rounded-lg"
                                        >
                                            {str(w)}
                                        </div>
                                        for w in current_result["data"]["warnings"]
                                    ]}
                                </div>}
                            </div>}
                        </div>
                        <div className={panelCls}>
                            <div className="flex items-center justify-between">
                                <div className={sectionLabel}>
                                    Explain Error
                                </div>
                            </div>
                            <input
                                type="text"
                                value={error_message}
                                onChange={lambda e: Any { error_message = e.target.value;}}
                                placeholder="Paste an error message..."
                                className={inputCls}
                            />
                            <button
                                onClick={lambda { runTool(
                                    "explain_error", {"error_message": error_message}
                                );}}
                                disabled={loading != "" or not connected}
                                className={ghostBtn + (
                                    " animate-pulse" if busy("explain_error") else ""
                                )}
                            >
                                {"Running..." if busy("explain_error") else "Explain"}
                            </button>
                        </div>
                        <div className={panelCls}>
                            <div className={sectionLabel}>
                                Examples
                            </div>
                            <button
                                onClick={lambda { runTool("list_examples", {});}}
                                disabled={loading != "" or not connected}
                                className={ghostBtn + (
                                    " animate-pulse" if busy("list_examples") else ""
                                )}
                            >
                                {"Running..."
                                    if busy("list_examples")
                                    else "List Examples"}
                            </button>
                            <div className="flex gap-2">
                                <input
                                    type="text"
                                    value={example_name}
                                    onChange={lambda e: Any { example_name = e.target.value;}}
                                    placeholder="Category name..."
                                    className={inputCls + " flex-1"}
                                />
                                <button
                                    onClick={lambda { runTool(
                                        "get_example", {"name": example_name}
                                    );}}
                                    disabled={loading != "" or not connected}
                                    className={ghostBtn + " whitespace-nowrap" + (
                                        " animate-pulse" if busy("get_example") else ""
                                    )}
                                >
                                    {"Running..."
                                        if busy("get_example")
                                        else "Get Example"}
                                </button>
                            </div>
                        </div>
                    </div>
                    <div className="space-y-4 xl:sticky xl:top-6">
                        <div className={panelCls}>
                            <div className="flex items-center justify-between">
                                <div className={sectionLabel}>
                                    Output
                                </div>
                                <div className="flex items-center gap-2">
                                    {loading != ""
                                    and <span
                                        className="h-1.5 w-1.5 rounded-full bg-orange-400 animate-pulse"
                                    />}
                                    <span className="text-[11px] text-zinc-400">
                                        {notice}
                                    </span>
                                </div>
                            </div>
                            {active_tool != ""
                            and <div
                                className="flex items-center gap-2 border-b border-white/5 pb-2"
                            >
                                <span
                                    className="h-1.5 w-1.5 rounded-full bg-orange-500/70 flex-shrink-0"
                                />
                                <span className="text-[10px] font-mono text-zinc-500">
                                    {active_tool}
                                </span>
                            </div>}
                            {renderActiveOutput()}
                        </div>
                    </div>
                </div>
            </div>
        </div>;
}
