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
    if tool == "validate_jac" {
        return "Validating Jac code...";
    } elif tool == "check_syntax" {
        return "Checking syntax...";
    } elif tool == "format_jac" {
        return "Formatting code...";
    } elif tool == "py_to_jac" {
        return "Converting Python to Jac...";
    } elif tool in ["get_ast_tree", "get_ast_json"] {
        return "Generating AST...";
    } elif tool == "explain_error" {
        return "Explaining error...";
    } elif tool == "list_examples" {
        return "Fetching example list...";
    } elif tool == "get_example" {
        return "Loading example...";
    } elif tool == "search_docs" {
        return "Searching documentation...";
    }
    return "Running...";
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
        }
        if spawn_res {
            res = get_first_report(spawn_res);
            current_result = res;
            if res["ok"] {
                notice = success_notice(tool, res);
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
        <div className="text-xs text-zinc-600">No result yet.</div>;
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
                <span>✓</span>
                <span>No errors found.</span>
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
            <div className="text-xs text-zinc-600">No output returned.</div>;
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
                    onClick={lambda {
                        navigator.clipboard.writeText(formatted);
                        output_copied = True;
                        setTimeout(lambda { output_copied = False; }, 2000);
                    }}
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
                    onClick={lambda {
                        navigator.clipboard.writeText(json_str);
                        ast_copied = True;
                        setTimeout(lambda { ast_copied = False; }, 2000);
                    }}
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
                <pre className={pre_cls + " flex-1 px-4 py-3"}>{json_str}</pre>
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
            {title and <p className="text-sm font-semibold text-white">{title}</p>}{explanation
            and <p className="text-xs text-zinc-400 leading-relaxed">{explanation}</p>}{example
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
            <div className="text-xs text-zinc-500">No categories found.</div>;
    }
    return
        <div className="flex flex-wrap gap-1.5">
            {[
                <button
                    key={c["name"]}
                    onClick={lambda {
                        example_name = str(c["name"]);
                        runTool("get_example", {"name": str(c["name"])});
                    }}
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
            <div className="text-xs text-zinc-500">No content found.</div>;
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
                <span className="text-[11px] font-mono text-zinc-300">{ex_name}</span>
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
                            ); }}
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
            <div className="text-xs text-zinc-500">No results found.</div>;
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
                    and <p className="text-[10px] text-zinc-500">{m["description"]}</p>}
                    {("snippet" in m)
                    and <p
                        className="text-[11px] text-zinc-400 font-mono leading-5 whitespace-pre-wrap"
                    >
                        {m["snippet"]}
                    </p>}
                    <p className="text-[10px] font-mono text-orange-400/70">
                        {m["uri"] if "uri" in m else ""}
                    </p>
                </div> for m in matches
            ]}
        </div>;
}

impl DashboardPage.renderActiveOutput -> JsxElement {
    if active_tool in ["validate_jac", "check_syntax"] {
        return renderValidationOutput();
    } elif active_tool == "format_jac" {
        return renderFormatOutput();
    } elif active_tool in ["get_ast_tree", "get_ast_json"] {
        return renderAstOutput();
    } elif active_tool == "explain_error" {
        return renderExplainOutput();
    } elif active_tool == "list_examples" {
        return renderExamplesOutput();
    } elif active_tool == "get_example" {
        return renderGetExampleOutput();
    } elif active_tool == "search_docs" {
        return renderSearchDocsOutput();
    }
    return
        <div className="text-xs text-zinc-600">Run a tool to see output here.</div>;
}
