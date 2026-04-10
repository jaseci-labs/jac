"""Implementations for DashboardPage."""

impl DashboardPage.get_first_report(spawn_res: Any) -> dict {
    if spawn_res {
        reps = spawn_res["reports"] if "reports" in spawn_res else [];
        if reps and len(reps) > 0 {
            return reps[0];
        }
    }
    return {
        "ok": False,
        "tool": "",
        "data": {},
        "error": {"message": "No response from server"}
    };
}

impl DashboardPage.busy(tool: str) -> bool {
    return loading == tool;
}

impl DashboardPage.pretty_json(val: Any) -> str {
    return JSON.stringify(val, null, 2);
}

impl DashboardPage.connect_notice(res: dict, url: str) -> str {
    if res["ok"] {
        return "Connected to " + url;
    }
    err = res["error"] if "error" in res else {};
    msg: str = str(err["message"]) if "message" in err else "unknown error";
    return "Connection failed: " + msg;
}

impl DashboardPage.connect -> None {
    loading = "connect";
    url = server_url or DEFAULT_URL;
    res = get_first_report(await root spawn set_mcp_server(server_url=url));
    connected = res["ok"];
    notice = connect_notice(res, url);
    loading = "";
}

impl DashboardPage.disconnect -> None {
    connected = False;
    current_result = {};
    active_tool = "";
    notice = "Disconnected.";
}

impl DashboardPage.start_notice(tool: str) -> str {
    notices: dict = {
        "validate_jac": "Validating Jac code...",
        "check_syntax": "Checking syntax...",
        "format_jac": "Formatting code...",
        "py_to_jac": "Converting Python to Jac...",
        "get_ast_tree": "Generating AST...",
        "get_ast_json": "Generating AST...",
        "explain_error": "Explaining error...",
        "list_examples": "Fetching example list...",
        "get_example": "Loading example...",
        "search_docs": "Searching documentation...",
        "jac_to_js": "Transpiling Jac to JavaScript...",
        "jac_to_py": "Transpiling Jac to Python...",
        "run_jac": "Running Jac code...",
        "lint_jac": "Linting Jac code...",
        "graph_visualize": "Generating graph...",
        "list_commands": "Fetching command list...",
        "get_command": "Loading command details...",
        "execute_command": "Executing command...",
        "understand_jac_and_jaseci": "Loading Jac & Jaseci guide...",
        "get_resource": "Fetching resource..."
    };
    return notices[tool] if tool in notices else "Running...";
}

impl DashboardPage.success_notice(tool: str, res: dict) -> str {
    data = res["data"] if "data" in res else {};
    if tool in ["validate_jac", "check_syntax"] {
        errors: list = data["errors"] if "errors" in data else [];
        return "No errors found."
            if len(errors) == 0
            else (str(len(errors)) + " error(s) found.");
    } elif tool == "format_jac" {
        return "Code formatted successfully.";
    } elif tool == "py_to_jac" {
        return "Converted to Jac successfully.";
    } elif tool in ["get_ast_tree", "get_ast_json"] {
        return "AST generated.";
    } elif tool == "explain_error" {
        title: str = str(data["title"]) if "title" in data else "";
        return ("Explained: " + title) if title else "Explanation ready.";
    } elif tool == "list_examples" {
        cats = data["categories"]
            if "categories" in data
            else (data["examples"] if "examples" in data else data);
        return str(len(cats)) + " examples available.";
    } elif tool == "get_example" {
        content: str = str(data["content"]) if "content" in data else "";
        file_count: int = len(
            [
                p
                for p in content.split("\n--- ")
                if p
            ]
        )
            if content
            else 0;
        return str(file_count) + " file(s) loaded.";
    } elif tool == "search_docs" {
        results: list = data["results"] if "results" in data else [];
        return str(len(results)) + " result(s) found."
            if len(results) > 0
            else "No results found.";
    } elif tool == "jac_to_js" {
        warnings_js: list = data["warnings"] if "warnings" in data else [];
        return "Transpiled successfully."
            if len(warnings_js) == 0
            else (str(len(warnings_js)) + " warning(s).");
    } elif tool == "jac_to_py" {
        warnings: list = data["warnings"] if "warnings" in data else [];
        return "Transpiled successfully."
            if len(warnings) == 0
            else (str(len(warnings)) + " warning(s).");
    } elif tool == "run_jac" {
        exit_code: int = data["exit_code"] if "exit_code" in data else -1;
        return "Exited " + str(exit_code) + (
            " — success." if exit_code == 0 else " — failed."
        );
    } elif tool == "lint_jac" {
        violations: list = data["violations"] if "violations" in data else [];
        return "No violations found."
            if len(violations) == 0
            else (str(len(violations)) + " violation(s) found.");
    } elif tool == "graph_visualize" {
        graph: str = str(data["graph"]) if "graph" in data else "";
        return "Graph generated." if graph else "No graph output.";
    } elif tool == "list_commands" {
        total: int = data["total"] if "total" in data else 0;
        return str(total) + " commands available.";
    } elif tool == "get_command" {
        cmd_name: str = str(data["name"]) if "name" in data else "";
        return "Details loaded: " + cmd_name
            if cmd_name
            else "Command details loaded.";
    } elif tool == "execute_command" {
        success: bool = data["success"] if "success" in data else False;
        exit_code: int = data["exit_code"] if "exit_code" in data else -1;
        return "Exited " + str(exit_code) + (
            " — success." if success else " — failed."
        );
    } elif tool == "understand_jac_and_jaseci" {
        km: str = str(data["knowledge_map"]) if "knowledge_map" in data else "";
        return "Guide loaded (" + str(len(km.split("\n"))) + " lines)."
            if km
            else "Guide loaded.";
    } elif tool == "get_resource" {
        uri: str = str(data["uri"]) if "uri" in data else "";
        return "Loaded: " + uri if uri else "Resource loaded.";
    }
    return "Done.";
}

impl DashboardPage.strip_bracket_prefix(msg: str) -> str {
    if msg.startswith("[") {
        idx = msg.find("] ");
        if idx >= 0 {
            return msg[idx + 2:];
        }
    }
    return msg;
}

impl DashboardPage.runTool(tool: str, args: dict) -> None {
    loading = tool;
    active_tool = tool;
    notice = start_notice(tool);
    if tool != "graph_visualize" {
        graph_svg = "";
    }
    try {
        spawn_res: Any = None;
        if tool == "validate_jac" {
            spawn_res = await root spawn validate_jac(code=args["code"]);
        } elif tool == "check_syntax" {
            spawn_res = await root spawn check_syntax(code=args["code"]);
        } elif tool == "format_jac" {
            spawn_res = await root spawn format_jac(code=args["code"]);
        } elif tool == "py_to_jac" {
            spawn_res = await root spawn py_to_jac(code=args["code"]);
        } elif tool == "get_ast_tree" {
            spawn_res = await root spawn get_ast(code=args["code"], format="tree");
        } elif tool == "get_ast_json" {
            spawn_res = await root spawn get_ast(code=args["code"], format="json");
        } elif tool == "explain_error" {
            spawn_res = await root spawn explain_error(
                error_message=args["error_message"]
            );
        } elif tool == "list_examples" {
            spawn_res = await root spawn list_examples();
        } elif tool == "get_example" {
            spawn_res = await root spawn get_example(name=args["name"]);
        } elif tool == "search_docs" {
            spawn_res = await root spawn search_docs(query=args["query"]);
        } elif tool == "jac_to_js" {
            spawn_res = await root spawn jac_to_js(code=args["code"]);
        } elif tool == "jac_to_py" {
            spawn_res = await root spawn jac_to_py(code=args["code"]);
        } elif tool == "run_jac" {
            spawn_res = await root spawn run_jac(
                code=args["code"],
                entrypoint=args["entrypoint"],
                timeout=args["timeout"]
            );
        } elif tool == "lint_jac" {
            spawn_res = await root spawn lint_jac(
                code=args["code"], auto_fix=args["auto_fix"]
            );
        } elif tool == "graph_visualize" {
            spawn_res = await root spawn graph_visualize(code=args["code"]);
        } elif tool == "list_commands" {
            spawn_res = await root spawn list_commands();
        } elif tool == "get_command" {
            spawn_res = await root spawn get_command(name=args["name"]);
        } elif tool == "execute_command" {
            spawn_res = await root spawn execute_command(
                command=args["command"], args=args["args"]
            );
        } elif tool == "understand_jac_and_jaseci" {
            spawn_res = await root spawn understand_jac_and_jaseci();
        } elif tool == "get_resource" {
            spawn_res = await root spawn get_resource(uri=args["uri"]);
        } else {
            notice = "Unknown tool: " + tool;
        }
        if spawn_res {
            res = get_first_report(spawn_res);
            current_result = res;
            if res["ok"] {
                notice = success_notice(tool, res);
                if tool == "graph_visualize" {
                    gdata: dict = res["data"] if "data" in res else {};
                    dot: str = str(gdata["graph"]) if "graph" in gdata else "";
                    if dot {
                        _viz_inst: Any = await instance();
                        graph_svg = str(_viz_inst.renderString(dot));
                    }
                }
            } else {
                err = res["error"] if "error" in res else {};
                err_msg: str = str(err["message"]) if "message" in err else "unknown";
                notice = "Error: " + err_msg;
            }
            if tool in ["validate_jac", "check_syntax", "format_jac"] {
                edata: dict = res["data"] if "data" in res else {};
                eerrors: list = edata["errors"] if "errors" in edata else [];
                if len(eerrors) > 0 {
                    first_err = eerrors[0];
                    raw_msg: str = str(first_err["message"])
                        if "message" in first_err
                        else str(first_err);
                    error_message = strip_bracket_prefix(raw_msg);
                } elif not res["ok"] {
                    err2: dict = res["error"] if "error" in res else {};
                    raw_msg2: str = str(err2["message"]) if "message" in err2 else "";
                    if raw_msg2 {
                        error_message = strip_bracket_prefix(raw_msg2);
                    }
                }
            }
        } else {
            notice = "No response from server.";
        }
    } except Exception as e {
        notice = "Error: " + str(e);
    } finally {
        loading = "";
    }
}

impl DashboardPage.renderErr -> JsxElement {
    err = current_result["error"] if "error" in current_result else {};
    msg = err["message"] if "message" in err else "Unknown error";
    return
        <div
            className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 p-3 rounded-lg font-mono"
        >
            {msg}
        </div>;
}

impl DashboardPage.renderEmpty -> JsxElement {
    return
        <div className="text-xs text-zinc-600">
            No result yet.
        </div>;
}

impl DashboardPage.renderValidationOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    errors: list = data["errors"] if "errors" in data else [];
    if len(errors) == 0 {
        return
            <div
                className="flex items-center gap-2 text-xs text-green-400 bg-green-500/10 border border-green-500/20 p-3 rounded-lg"
            >
                <span>
                    ✓
                </span>
                <span>
                    No errors found.
                </span>
            </div>;
    }
    return
        <div className="space-y-1.5">
            {[
                <div
                    key={str(e)}
                    className="text-xs font-mono text-red-400 bg-red-500/10 border border-red-500/20 p-2 rounded-lg"
                >
                    {(
                        "[" + str(e["line"]) + ":" + str(e["col"]) + "] " + str(
                            e["message"]
                        )
                    )
                        if ("line" in e and "col" in e and "message" in e)
                        else str(e)}
                </div> for e in errors
            ]}
        </div>;
}

impl DashboardPage.renderFormatOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data: dict = current_result["data"] if "data" in current_result else {};
    formatted: str = str(data["formatted"]) if "formatted" in data else "";
    changed: bool = data["changed"] if "changed" in data else False;
    if not formatted {
        return
            <div className="text-xs text-zinc-600">
                No output returned.
            </div>;
    }
    return
        <div className="space-y-1">
            <div className="flex items-center justify-between">
                <span
                    className={"text-[10px] " + (
                        "text-green-400" if changed else "text-zinc-500"
                    )}
                >
                    {("Modified" if changed else "No changes")}
                </span>
                <button
                    onClick={lambda { navigator.clipboard.writeText(formatted);output_copied = True;setTimeout(
                        lambda { output_copied = False;}, 2000
                    );}}
                    className={"px-2 py-1 text-[9px] rounded-md border transition " + (
                        "bg-green-500/20 border-green-500/40 text-green-400"
                            if output_copied
                            else "bg-white/5 hover:bg-white/10 border-white/10"
                    )}
                >
                    {"Copied!" if output_copied else "Copy"}
                </button>
            </div>
            <pre
                className="text-[11px] leading-5 text-green-400 max-h-[340px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-white/5 whitespace-pre-wrap break-words"
            >
                {formatted}
            </pre>
        </div>;
}

impl DashboardPage.renderAstOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    out = data["tree"] if "tree" in data else (data["ast"] if "ast" in data else data);
    is_tree: bool = active_tool == "get_ast_tree";
    json_str: str = str(out) if is_tree else pretty_json(out);
    lines: list = json_str.split('\n');
    badge_cls = "text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border " + (
        "text-teal-400 bg-teal-500/10 border-teal-500/20"
            if is_tree
            else "text-indigo-400 bg-indigo-500/10 border-indigo-500/20"
    );
    pre_cls = "text-[11px] leading-5 max-h-[420px] overflow-auto bg-[#070809] rounded-b-lg border-x border-b whitespace-pre-wrap break-words font-mono " + (
        "text-teal-300/80 border-teal-900/40"
            if is_tree
            else "text-indigo-300/80 border-indigo-900/40"
    );
    return
        <div className="rounded-lg overflow-hidden border border-white/[0.06]">
            <div
                className={"flex items-center justify-between px-3 py-2 border-b " + (
                    "bg-teal-950/40 border-teal-900/30"
                        if is_tree
                        else "bg-indigo-950/40 border-indigo-900/30"
                )}
            >
                <div className="flex items-center gap-2.5">
                    <span className={badge_cls}>
                        {"AST TREE" if is_tree else "AST JSON"}
                    </span>
                    <span className="text-[10px] text-zinc-600 font-mono">
                        {str(len(lines)) + " lines"}
                    </span>
                </div>
                <button
                    onClick={lambda { navigator.clipboard.writeText(json_str);ast_copied = True;setTimeout(
                        lambda { ast_copied = False;}, 2000
                    );}}
                    className={"px-2 py-0.5 text-[9px] rounded border transition " + (
                        "bg-green-500/20 border-green-500/30 text-green-400"
                            if ast_copied
                            else "bg-white/[0.04] border-white/10 text-zinc-500 hover:text-zinc-300"
                    )}
                >
                    {"Copied!" if ast_copied else "Copy"}
                </button>
            </div>
            <div className="flex max-h-[420px] overflow-hidden bg-[#070809]">
                <div
                    className={"flex-shrink-0 select-none border-r px-2 py-3 text-right " + (
                        "border-teal-900/30 bg-teal-950/20"
                            if is_tree
                            else "border-indigo-900/30 bg-indigo-950/20"
                    )}
                >
                    {[
                        <div
                            key={str(i)}
                            className={"text-[10px] leading-5 font-mono " + (
                                "text-teal-900" if is_tree else "text-indigo-900"
                            )}
                        >
                            {str(i + 1)}
                        </div> for i in range(len(lines))
                    ]}
                </div>
                <pre className={pre_cls + " flex-1 px-4 py-3"}>
                    {json_str}
                </pre>
            </div>
        </div>;
}

impl DashboardPage.renderExplainOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    title = data["title"] if "title" in data else "";
    explanation = data["explanation"] if "explanation" in data else "";
    example = data["example"] if "example" in data else "";
    return
        <div className="space-y-3">
            {title
            and <p className="text-sm font-semibold text-white">
                {title}
            </p>}{explanation
            and <p className="text-xs text-zinc-400 leading-relaxed">
                {explanation}
            </p>}{example
            and <pre
                className="text-[11px] text-zinc-300 max-h-[200px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-white/5"
            >
                {example}
            </pre>}
        </div>;
}

impl DashboardPage.renderExamplesOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    cats = data
        if Array.isArray(data)
        else (
            data["categories"]
                if "categories" in data
                else (data["examples"] if "examples" in data else [])
        );
    if len(cats) == 0 {
        return
            <div className="text-xs text-zinc-500">
                No categories found.
            </div>;
    }
    return
        <div className="flex flex-wrap gap-1.5">
            {[
                <button
                    key={c["name"]}
                    onClick={lambda { example_name = str(c["name"]);runTool(
                        "get_example", {"name": str(c["name"])}
                    );}}
                    className="px-2 py-0.5 text-[11px] rounded-full bg-orange-500/15 border border-orange-500/30 text-orange-300 hover:bg-orange-500/30 transition cursor-pointer"
                >
                    {c["name"]}
                </button> for c in cats
            ]}
        </div>;
}

impl DashboardPage.renderGetExampleOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    content: str = str(data["content"]) if "content" in data else "";
    if not content {
        return
            <div className="text-xs text-zinc-500">
                No content found.
            </div>;
    }
    sections: list = [
        s
        for s in content.split("\n--- ")
        if s.trim()
    ];
    ex_name: str = str(data["name"]) if "name" in data else "";
    return
        <div className="space-y-3">
            {ex_name
            and <div className="flex items-center gap-2 mb-1">
                <span
                    className="text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border text-orange-400 bg-orange-500/10 border-orange-500/20"
                >
                    EXAMPLE
                </span>
                <span className="text-[11px] font-mono text-zinc-300">
                    {ex_name}
                </span>
                <span className="text-[10px] text-zinc-600">
                    {str(len(sections)) + " file(s)"}
                </span>
            </div>}{[
                <div
                    key={s.split("\n")[0]}
                    className="rounded-lg overflow-hidden border border-white/[0.06]"
                >
                    <div
                        className="flex items-center justify-between px-3 py-2 bg-orange-950/20 border-b border-orange-900/20"
                    >
                        <div className="flex items-center gap-2.5">
                            <span
                                className="text-[9px] font-mono font-semibold px-1.5 py-0.5 rounded border text-orange-400/80 bg-orange-500/10 border-orange-500/20"
                            >
                                JAC
                            </span>
                            <span className="text-[11px] font-mono text-zinc-300">
                                {s.split("\n")[0].replace(" ---", "")}
                            </span>
                            <span className="text-[10px] text-zinc-600">
                                {str(
                                    s.split("\n").slice(1).join("\n").split("\n").length
                                ) + " lines"}
                            </span>
                        </div>
                        <button
                            onClick={lambda { navigator.clipboard.writeText(
                                s.split("\n").slice(1).join("\n")
                            );}}
                            className="px-2 py-1 text-[9px] rounded-md border transition bg-white/5 hover:bg-white/10 border-white/10"
                        >
                            Copy
                        </button>
                    </div>
                    <pre
                        className="text-[11px] leading-5 text-orange-100/70 max-h-[300px] overflow-auto bg-[#070809] p-3 whitespace-pre-wrap break-words font-mono"
                    >
                        {s.split("\n").slice(1).join("\n")}
                    </pre>
                </div> for s in sections
            ]}
        </div>;
}

impl DashboardPage.renderSearchDocsOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    matches = data
        if Array.isArray(data)
        else (data["results"] if "results" in data else []);
    if len(matches) == 0 {
        return
            <div className="text-xs text-zinc-500">
                No results found.
            </div>;
    }
    return
        <div className="space-y-3">
            {[
                <div
                    key={m["uri"] if "uri" in m else str(m)}
                    className="border-l-2 border-orange-500/60 pl-3 py-2 space-y-1"
                >
                    <div className="flex items-center justify-between gap-2">
                        <p className="text-xs font-medium text-zinc-200">
                            {m["title"] if "title" in m else ""}
                        </p>
                        {("score" in m)
                        and <span className="text-[10px] text-zinc-500 flex-shrink-0">
                            {str(m["score"])}
                        </span>}
                    </div>
                    {("description" in m)
                    and <p className="text-[10px] text-zinc-500">
                        {m["description"]}
                    </p>}
                    {("snippet" in m)
                    and <p
                        className="text-[11px] text-zinc-400 font-mono leading-5 whitespace-pre-wrap"
                    >
                        {m["snippet"]}
                    </p>}
                    <button
                        onClick={lambda { resource_uri = str(m["uri"])
                            if "uri" in m
                            else "";runTool(
                            "get_resource",
                            {"uri": str(m["uri"]) if "uri" in m else ""}
                        );}}
                        disabled={loading != "" or not connected}
                        className="text-[10px] font-mono text-orange-400/70 hover:text-orange-300 hover:underline disabled:opacity-50 disabled:cursor-not-allowed text-left transition"
                    >
                        {m["uri"] if "uri" in m else ""}
                    </button>
                </div> for m in matches
            ]}
        </div>;
}

impl DashboardPage.renderJacToJsOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    js_code: str = str(data["js_code"]) if "js_code" in data else "";
    warnings: list = data["warnings"] if "warnings" in data else [];
    if not js_code and len(warnings) == 0 {
        return
            <div className="text-xs text-zinc-500">
                No output returned.
            </div>;
    }
    return
        <div className="space-y-3">
            {js_code
            and <div className="space-y-1">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <span
                            className="text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border text-amber-400 bg-amber-500/10 border-amber-500/20"
                        >
                            JAVASCRIPT
                        </span>
                        <span className="text-[10px] text-zinc-600 font-mono">
                            {str(len(js_code.split("\n"))) + " lines"}
                        </span>
                    </div>
                    <button
                        onClick={lambda { navigator.clipboard.writeText(js_code);output_copied = True;setTimeout(
                            lambda { output_copied = False;}, 2000
                        );}}
                        className={"px-2 py-1 text-[9px] rounded-md border transition " + (
                            "bg-green-500/20 border-green-500/40 text-green-400"
                                if output_copied
                                else "bg-white/5 hover:bg-white/10 border-white/10"
                        )}
                    >
                        {"Copied!" if output_copied else "Copy"}
                    </button>
                </div>
                <pre
                    className="text-[11px] leading-5 text-amber-300/80 max-h-[420px] overflow-auto bg-[#070809] p-3 rounded-lg border border-amber-900/30 whitespace-pre-wrap break-words font-mono"
                >
                    {js_code}
                </pre>
            </div>}{len(warnings) > 0
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-yellow-600 font-semibold"
                >
                    {str(len(warnings)) + " warning(s)"}
                </div>
                {[
                    <div
                        key={str(w)}
                        className="text-[11px] font-mono text-yellow-400 bg-yellow-500/10 border border-yellow-500/20 p-2 rounded-lg"
                    >
                        {str(w)}
                    </div> for w in warnings
                ]}
            </div>}
        </div>;
}

impl DashboardPage.renderJacToPyOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    python_code: str = str(data["python_code"]) if "python_code" in data else "";
    warnings: list = data["warnings"] if "warnings" in data else [];
    if not python_code and len(warnings) == 0 {
        return
            <div className="text-xs text-zinc-500">
                No output returned.
            </div>;
    }
    return
        <div className="space-y-3">
            <div className="space-y-1">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <span
                            className="text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border text-blue-400 bg-blue-500/10 border-blue-500/20"
                        >
                            PYTHON
                        </span>
                        <span className="text-[10px] text-zinc-600 font-mono">
                            {str(len(python_code.split("\n"))) + " lines"}
                        </span>
                    </div>
                    <button
                        onClick={lambda { navigator.clipboard.writeText(python_code);output_copied = True;setTimeout(
                            lambda { output_copied = False;}, 2000
                        );}}
                        className={"px-2 py-1 text-[9px] rounded-md border transition " + (
                            "bg-green-500/20 border-green-500/40 text-green-400"
                                if output_copied
                                else "bg-white/5 hover:bg-white/10 border-white/10"
                        )}
                    >
                        {"Copied!" if output_copied else "Copy"}
                    </button>
                </div>
                <pre
                    className="text-[11px] leading-5 text-blue-300/80 max-h-[420px] overflow-auto bg-[#070809] p-3 rounded-lg border border-blue-900/30 whitespace-pre-wrap break-words font-mono"
                >
                    {python_code}
                </pre>
            </div>
            {len(warnings) > 0
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-yellow-600 font-semibold"
                >
                    {str(len(warnings)) + " warning(s)"}
                </div>
                {[
                    <div
                        key={str(w)}
                        className="text-[11px] font-mono text-yellow-400 bg-yellow-500/10 border border-yellow-500/20 p-2 rounded-lg"
                    >
                        {str(w)}
                    </div> for w in warnings
                ]}
            </div>}
        </div>;
}

impl DashboardPage.renderRunOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    exit_code: int = data["exit_code"] if "exit_code" in data else -1;
    stdout: str = str(data["stdout"]) if "stdout" in data else "";
    stderr: str = str(data["stderr"]) if "stderr" in data else "";
    error: str = str(data["error"]) if "error" in data and data["error"] else "";
    success: bool = exit_code == 0;
    return
        <div className="space-y-3">
            <div className="flex items-center gap-2">
                <span
                    className={"text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border " + (
                        "text-green-400 bg-green-500/10 border-green-500/20"
                            if success
                            else "text-red-400 bg-red-500/10 border-red-500/20"
                    )}
                >
                    {"exit " + str(exit_code)}
                </span>
                {error
                and <span className="text-[10px] text-red-400 font-mono">
                    {error}
                </span>}
            </div>
            {stdout
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold"
                >
                    stdout
                </div>
                <pre
                    className="text-[11px] leading-5 text-green-300/80 max-h-[340px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-white/5 whitespace-pre-wrap break-words font-mono"
                >
                    {stdout}
                </pre>
            </div>}
            {stderr
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-red-600 font-semibold"
                >
                    stderr
                </div>
                <pre
                    className="text-[11px] leading-5 text-red-300/80 max-h-[200px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-red-500/10 whitespace-pre-wrap break-words font-mono"
                >
                    {stderr}
                </pre>
            </div>}
        </div>;
}

impl DashboardPage.renderLintOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    violations: list = data["violations"] if "violations" in data else [];
    fixed_code: str = str(data["fixed_code"])
        if "fixed_code" in data and data["fixed_code"]
        else "";
    changed: bool = data["changed"] if "changed" in data else False;
    if len(violations) == 0 and not fixed_code {
        return
            <div
                className="flex items-center gap-2 text-xs text-green-400 bg-green-500/10 border border-green-500/20 p-3 rounded-lg"
            >
                <span>
                    ✓
                </span>
                <span>
                    No lint violations found.
                </span>
            </div>;
    }
    return
        <div className="space-y-3">
            {len(violations) > 0
            and <div className="space-y-1.5">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-yellow-600 font-semibold"
                >
                    {str(len(violations)) + " violation(s)"}
                </div>
                {[
                    <div
                        key={str(v)}
                        className="text-xs font-mono text-yellow-400 bg-yellow-500/10 border border-yellow-500/20 p-2 rounded-lg"
                    >
                        {(
                            "[" + str(v["line"]) + ":" + str(v["col"]) + "] " + str(
                                v["message"]
                            )
                        )
                            if ("line" in v and "col" in v and "message" in v)
                            else (str(v["message"]) if "message" in v else str(v))}
                    </div> for v in violations
                ]}
            </div>}{fixed_code
            and <div className="space-y-1">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <div
                            className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold"
                        >
                            Fixed Code
                        </div>
                        {changed
                        and <span
                            className="text-[9px] font-mono text-green-400 bg-green-500/10 border border-green-500/20 px-1.5 py-0.5 rounded"
                        >
                            modified
                        </span>}
                    </div>
                    <button
                        onClick={lambda { code = fixed_code;}}
                        className="px-2 py-1 text-[9px] rounded-md border transition bg-orange-500/10 hover:bg-orange-500/20 border-orange-500/30 text-orange-400"
                    >
                        Apply to Editor
                    </button>
                </div>
                <pre
                    className="text-[11px] leading-5 text-green-400 max-h-[300px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-white/5 whitespace-pre-wrap break-words font-mono"
                >
                    {fixed_code}
                </pre>
            </div>}
        </div>;
}

impl DashboardPage.renderGraphVisualizeOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    graph: str = str(data["graph"]) if "graph" in data else "";
    program_output: str = str(data["program_output"])
        if "program_output" in data
        else "";
    if not graph {
        return
            <div className="text-xs text-zinc-500">
                No graph output returned.
            </div>;
    }
    return
        <div className="space-y-3">
            {graph_svg
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold"
                >
                    Graph
                </div>
                <div
                    className="overflow-auto max-h-[400px] bg-white rounded-lg p-3 border border-white/10"
                    dangerouslySetInnerHTML={{"__html": graph_svg}}
                />
            </div>}
            <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold"
                >
                    DOT Source
                </div>
                <pre
                    className="text-[11px] leading-5 text-teal-300/80 max-h-[200px] overflow-auto bg-[#070809] p-3 rounded-lg border border-teal-900/30 whitespace-pre-wrap break-words font-mono"
                >
                    {graph}
                </pre>
            </div>
            {program_output
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold"
                >
                    Program Output
                </div>
                <pre
                    className="text-[11px] leading-5 text-zinc-300 max-h-[200px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-white/5 whitespace-pre-wrap break-words font-mono"
                >
                    {program_output}
                </pre>
            </div>}
        </div>;
}

impl DashboardPage.renderListCommandsOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    total: int = data["total"] if "total" in data else 0;
    commands: list = data["commands"] if "commands" in data else [];
    if len(commands) == 0 {
        return
            <div className="text-xs text-zinc-500">
                No commands found.
            </div>;
    }
    groups: list = data["groups"] if "groups" in data else [];
    return
        <div className="space-y-3">
            <div className="flex items-center gap-2">
                <span
                    className="text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border text-zinc-400 bg-zinc-500/10 border-zinc-500/20"
                >
                    {str(total) + " COMMANDS"}
                </span>
            </div>
            {[
                <div key={g} className="space-y-1">
                    <div
                        className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold pt-1"
                    >
                        {g}
                    </div>
                    <div className="flex flex-wrap gap-1">
                        {[
                            <button
                                key={str(cmd["name"]) if "name" in cmd else str(cmd)}
                                onClick={lambda { command_name = str(cmd["name"])
                                    if "name" in cmd
                                    else "";runTool(
                                    "get_command",
                                    {"name": str(cmd["name"]) if "name" in cmd else ""}
                                );}}
                                disabled={loading != "" or not connected}
                                className="px-2 py-0.5 text-[11px] rounded-md bg-zinc-800 hover:bg-zinc-700 border border-white/[0.08] text-zinc-300 hover:text-white disabled:opacity-30 transition font-mono"
                            >
                                {str(cmd["name"]) if "name" in cmd else ""}
                            </button>
                            for cmd in commands
                            if ("group" in cmd and cmd["group"] == g)
                        ]}
                    </div>
                </div> for g in groups
            ]}
        </div>;
}

impl DashboardPage.renderGetCommandOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    cmd_name: str = str(data["name"]) if "name" in data else "";
    help_text: str = str(data["help"]) if "help" in data else "";
    group: str = str(data["group"]) if "group" in data else "";
    source: str = str(data["source"]) if "source" in data else "";
    args: list = data["args"] if "args" in data else [];
    return
        <div className="space-y-3">
            <div className="flex items-center gap-2 flex-wrap">
                <span
                    className="text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border text-orange-400 bg-orange-500/10 border-orange-500/20"
                >
                    {cmd_name}
                </span>
                <span
                    className="text-[9px] font-mono px-2 py-0.5 rounded-md border text-zinc-500 bg-zinc-800/50 border-white/[0.06]"
                >
                    {group}
                </span>
                <span
                    className="text-[9px] font-mono px-2 py-0.5 rounded-md border text-zinc-600 bg-zinc-800/30 border-white/[0.04]"
                >
                    {source}
                </span>
            </div>
            {help_text
            and <p className="text-xs text-zinc-400 leading-relaxed">
                {help_text}
            </p>}
            {len(args) > 0
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold"
                >
                    Arguments
                </div>
                {[
                    <div
                        key={str(a["name"]) if "name" in a else str(a)}
                        className="flex items-start gap-2 text-[11px] py-1 border-b border-white/[0.04]"
                    >
                        <span className="font-mono text-orange-300/80 flex-shrink-0">
                            {str(a["name"]) if "name" in a else ""}
                        </span>
                        <span className="text-zinc-500">
                            {str(a["help"]) if "help" in a else ""}
                        </span>
                    </div> for a in args
                ]}
            </div>}
            <button
                onClick={lambda { runTool(
                    "execute_command", {"command": cmd_name, "args": []}
                );}}
                disabled={loading != "" or not connected}
                className={ghostBtn + (
                    " animate-pulse" if busy("execute_command") else ""
                )}
            >
                {"Running..." if busy("execute_command") else "Execute " + cmd_name}
            </button>
        </div>;
}

impl DashboardPage.renderExecuteCommandOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    success: bool = data["success"] if "success" in data else False;
    exit_code: int = data["exit_code"] if "exit_code" in data else -1;
    stdout: str = str(data["stdout"]) if "stdout" in data else "";
    stderr: str = str(data["stderr"]) if "stderr" in data else "";
    cmd: str = str(data["command"]) if "command" in data else "";
    return
        <div className="space-y-3">
            <div className="flex items-center gap-2 flex-wrap">
                {cmd
                and <span
                    className="text-[9px] font-mono text-zinc-500 bg-zinc-800/50 border border-white/[0.06] px-2 py-0.5 rounded-md"
                >
                    {cmd}
                </span>}
                <span
                    className={"text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border " + (
                        "text-green-400 bg-green-500/10 border-green-500/20"
                            if success
                            else "text-red-400 bg-red-500/10 border-red-500/20"
                    )}
                >
                    {"exit " + str(exit_code)}
                </span>
            </div>
            {stdout
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-zinc-600 font-semibold"
                >
                    stdout
                </div>
                <pre
                    className="text-[11px] leading-5 text-green-300/80 max-h-[280px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-white/5 whitespace-pre-wrap break-words font-mono"
                >
                    {stdout}
                </pre>
            </div>}
            {stderr
            and <div className="space-y-1">
                <div
                    className="text-[9px] uppercase tracking-[0.15em] text-red-600 font-semibold"
                >
                    stderr
                </div>
                <pre
                    className="text-[11px] leading-5 text-red-300/80 max-h-[200px] overflow-auto bg-[#0d0e10] p-3 rounded-lg border border-red-500/10 whitespace-pre-wrap break-words font-mono"
                >
                    {stderr}
                </pre>
            </div>}
        </div>;
}

impl DashboardPage.renderUnderstandOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    content: str = str(data["knowledge_map"]) if "knowledge_map" in data else "";
    if not content {
        return
            <div className="text-xs text-zinc-500">
                No content returned.
            </div>;
    }
    return
        <pre
            className="text-[11px] leading-5 text-zinc-300 max-h-[520px] overflow-auto bg-[#0d0e10] p-4 rounded-lg border border-white/5 whitespace-pre-wrap break-words font-mono"
        >
            {content}
        </pre>;
}

impl DashboardPage.renderResourceOutput -> JsxElement {
    if not current_result {
        return renderEmpty();
    }
    if not current_result["ok"] {
        return renderErr();
    }
    data = current_result["data"] if "data" in current_result else {};
    content: str = str(data["content"]) if "content" in data else "";
    uri: str = str(data["uri"]) if "uri" in data else "";
    if not content {
        return
            <div className="text-xs text-zinc-500">
                No content returned.
            </div>;
    }
    return
        <div className="space-y-3">
            {uri
            and <div className="flex items-center gap-2">
                <span
                    className="text-[9px] font-mono font-semibold px-2 py-0.5 rounded-md border text-orange-400 bg-orange-500/10 border-orange-500/20"
                >
                    RESOURCE
                </span>
                <span className="text-[11px] font-mono text-zinc-400">
                    {uri}
                </span>
            </div>}
            <pre
                className="text-[11px] leading-5 text-zinc-300 max-h-[480px] overflow-auto bg-[#0d0e10] p-4 rounded-lg border border-white/5 whitespace-pre-wrap break-words font-mono"
            >
                {content}
            </pre>
        </div>;
}

impl DashboardPage.renderActiveOutput -> JsxElement {
    renderers: dict = {
        "validate_jac": renderValidationOutput,
        "check_syntax": renderValidationOutput,
        "format_jac": renderFormatOutput,
        "get_ast_tree": renderAstOutput,
        "get_ast_json": renderAstOutput,
        "explain_error": renderExplainOutput,
        "list_examples": renderExamplesOutput,
        "get_example": renderGetExampleOutput,
        "search_docs": renderSearchDocsOutput,
        "jac_to_js": renderJacToJsOutput,
        "jac_to_py": renderJacToPyOutput,
        "run_jac": renderRunOutput,
        "lint_jac": renderLintOutput,
        "graph_visualize": renderGraphVisualizeOutput,
        "list_commands": renderListCommandsOutput,
        "get_command": renderGetCommandOutput,
        "execute_command": renderExecuteCommandOutput,
        "understand_jac_and_jaseci": renderUnderstandOutput,
        "get_resource": renderResourceOutput
    };
    if active_tool in renderers {
        return renderers[active_tool]();
    }
    return
        <div className="text-xs text-zinc-600">
            Run a tool to see output here.
        </div>;
}
