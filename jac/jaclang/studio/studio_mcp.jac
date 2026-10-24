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

impl StudioTool.spec -> dict[str, any] {
    return {
        "name": self.name,
        "description": self.description,
        "inputSchema": self.schema or {"type": "object", "properties": {}}
    };
}

impl studio_tools -> list[StudioTool] {
    key_prop = {"type": "string", "description": KEY_HELP};
    return [
        StudioTool(
            name="studio_selection",
            method="selection",
            description="What the user has selected in jac hack right now. Returns: `tray`, the context tray (modules, symbols and wires the user deliberately picked for you, each with key, kind and location); `code`, the file open in the code view with the cursor line/column, its module, and the symbol under the cursor; `wiring_module`, the module focused in the wiring view. Call this first whenever the user says 'this', 'here', 'the selected code', 'what I picked', or refers to code without naming it. The keys it returns are accepted by every other studio_* tool."
        ),
        StudioTool(
            name="studio_focus",
            method="focus",
            description="Show the user a module, symbol or file location in jac hack: opens it in the code view (at `line` if given, otherwise at the declaration) and focuses its module in the wiring view, with an optional one-sentence `note` in the status bar. Use it to point at the code you are explaining, asking about, or about to change. It changes no files and returns once the studio has moved.",
            schema={
                "type": "object",
                "properties": {
                    "key": key_prop,
                    "line": {
                        "type": "integer",
                        "description": "1-based line to put the cursor on (optional)."
                    },
                    "note": {
                        "type": "string",
                        "description": "Short note shown to the user in the status bar (optional)."
                    }
                },
                "required": ["key"]
            }
        ),
        StudioTool(
            name="studio_wiring",
            method="wiring",
            description="The archwire neighbourhood of a module or symbol, from jac hack's live project model. In this codebase imports are not written in files: they are wires in archwire.jac (`provider ++> consumer { names }`), governed by rules between top-level packages. For a module: `providers` (modules that feed it and the names each provides), `consumers` (modules that use it and which of its names), the `rules` that govern it, and its top-level `symbols`. For a symbol: its declaration and impl locations, `imported_by` (modules that import it by name), `walkers` that traverse it (nodes/edges) or what it `traverses` (walkers), its members, and its module's wiring. Use this instead of grepping for imports before moving, renaming, deleting or adding a dependency on code.",
            schema={
                "type": "object",
                "properties": {"key": key_prop},
                "required": ["key"]
            }
        ),
        StudioTool(
            name="studio_rules",
            method="rules",
            description="Archwire rule coverage for the whole project: each rule (`edge Name: sources --> targets { names }`) with its sources, targets, name payload, and how many modules and wires it governs, plus `unruled_cross_package_wires` (wires between different top-level packages that no rule admits). Check this before adding a wire between packages: such a wire needs a rule whose sources match the provider and whose targets match the consumer, and a rule with a names payload only admits those names."
        ),
        StudioTool(
            name="studio_graph",
            method="graph",
            description="The archwire graph at one level of the package hierarchy, for reasoning about architecture rather than single imports. `scope` is a package (its sub-packages and modules become the groups), a module or symbol (shown among its siblings), or empty for the whole project. Groups come providers first, each with its layer (0 = fed by nothing at this level), module count, governing rules and whether it sits in a cycle; `edges` are wire counts between groups, and `backward` marks wires where a later group feeds an earlier one, which are what keep the level from being cleanly layered. `parent` is the scope one level up. Use it before moving code between packages or untangling a cycle.",
            schema={
                "type": "object",
                "properties": {
                    "scope": {
                        "type": "string",
                        "description": "A package such as `jaclang.compiler`, a module or symbol key, or empty for the whole project."
                    }
                }
            }
        ),
        StudioTool(
            name="studio_insight",
            method="insight",
            description="Higher-level readings of the archwire graph. `view` is one of: `roles` (sorts the modules under `key` into foundations, hubs, integrators, entry points, relays and leaves by how they are wired; read foundations first), `interface` (the names that cross the boundary of the package or module `key`, each with its outside users, plus hints such as single-user names), `rules` (each archwire rule against the wires it admits: unused rules, permissions used by one wire, violations), `slice` (what the module `key` rests on, step by step, split into what loads at import time and what loads only inside functions), `blast` (what depends on a module or a single name `key`, with the exact direct users), `clusters` (natural clusters of the modules under `key` versus the declared packages, and modules that look misplaced), `tour` (an onboarding tour of `key` in markdown), `diff` (how the architecture changed since the git revision `key`, default the upstream main: wires, rules, new backward dependencies and cycles).",
            schema={
                "type": "object",
                "properties": {
                    "view": {
                        "type": "string",
                        "enum": [
                            "roles",
                            "interface",
                            "rules",
                            "slice",
                            "blast",
                            "clusters",
                            "tour",
                            "diff"
                        ]
                    },
                    "key": {
                        "type": "string",
                        "description": "A package, module or symbol key (for diff, a git revision); empty means the whole project."
                    }
                },
                "required": ["view"]
            }
        ),
        StudioTool(
            name="studio_symbol",
            method="symbol",
            description="One module or symbol in detail: kind, signature, docstring, members, and its source. For abilities and archetypes whose bodies live in `impl` blocks (often in a separate .impl.jac file) it returns the declaration `source` and the `impl_source` together, so you do not have to find and read both files. For a module it lists the module's symbols and wiring counts. Prefer this over reading whole files when you need one declaration.",
            schema={
                "type": "object",
                "properties": {"key": key_prop},
                "required": ["key"]
            }
        ),
        StudioTool(
            name="studio_search",
            method="search",
            description="Fuzzy search jac hack's project model for modules and symbols (archetypes, abilities, fields) by name or dotted key. Returns keys with kind, file, line and signature; pass a key to studio_symbol, studio_wiring or studio_focus for more.",
            schema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Name, partial name or dotted key, e.g. `Runner.start` or `jobs`."
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum results (default 20, max 200)."
                    }
                },
                "required": ["query"]
            }
        ),
        StudioTool(
            name="studio_link_plan",
            method="link_plan",
            description="Tell jac hack which code each step of your current plan touches, so the user sees it next to the plan and can jump to it. Call it after you publish or update a plan. `step` is the plan entry's 0-based index (or its exact text); `keys` are studio model keys or file paths. Returns the resolved keys and any it could not match.",
            schema={
                "type": "object",
                "properties": {
                    "entries": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "step": {
                                    "type": ["integer", "string"],
                                    "description": "0-based plan entry index, or the entry's text."
                                },
                                "keys": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Model keys or file paths this step touches."
                                }
                            },
                            "required": ["step", "keys"]
                        }
                    }
                },
                "required": ["entries"]
            }
        )
    ];
}

impl StudioMcp.postinit {
    self.tools = studio_tools();
}

impl StudioMcp.bridge -> BridgeClient {
    path = self.socket_path
        or os.environ.get(SOCKET_ENV, "")
        or find_studio_socket(self.root_dir or os.getcwd());
    if self.client is None or self.client.path != path {
        self.client = BridgeClient(path=path);
    }
    return self.client;
}

impl StudioMcp.handle(msg: dict[str, any]) -> (dict[str, any] | None) {
    method = msg.get("method");
    has_id = "id" in msg;
    mid = msg.get("id");
    params = msg.get("params");
    if not isinstance(params, dict) {
        params = {};
    }
    if not isinstance(method, str) {
        if has_id {
            return {
                "jsonrpc": "2.0",
                "id": mid,
                "error": {"code": -32600, "message": "Invalid Request"}
            };
        }
        return None;
    }
    result: any = None;
    if method == "initialize" {
        asked = params.get("protocolVersion");
        result = {
            "protocolVersion": asked if asked in MCP_PROTOCOLS else MCP_PROTOCOL,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "jac-hack", "version": STUDIO_MCP_VERSION},
            "instructions": STUDIO_INSTRUCTIONS
        };
    } elif method == "ping" or method.startswith("notifications/") {
        result = {};
    } elif method == "tools/list" {
        result = {"tools": [t.spec() for t in self.tools]};
    } elif method == "resources/list" {
        result = {"resources": []};
    } elif method == "prompts/list" {
        result = {"prompts": []};
    } elif method == "tools/call" {
        name = params.get("name");
        args = params.get("arguments");
        if not isinstance(name, str) or not name {
            return {
                "jsonrpc": "2.0",
                "id": mid,
                "error": {"code": -32602, "message": "missing required param 'name'"}
            }
                if has_id
                else None;
        }
        result = self.call_tool(name, args if isinstance(args, dict) else {});
    } else {
        if not has_id {
            return None;
        }
        return {
            "jsonrpc": "2.0",
            "id": mid,
            "error": {"code": -32601, "message": f"Method not found: {method}"}
        };
    }
    if not has_id {
        return None;
    }
    return {"jsonrpc": "2.0", "id": mid, "result": result};
}

impl StudioMcp.call_tool(name: str, args: dict[str, any]) -> dict[str, any] {
    tool: (StudioTool | None) = None;
    for t in self.tools {
        if t.name == name {
            tool = t;
        }
    }
    if tool is None {
        return tool_text(
            f"Unknown tool '{name}'. Available: "
                + ", ".join([t.name for t in self.tools]),
            True
        );
    }
    try {
        params = self.tool_params(tool, args);
        return tool_text(self.bridge().call(tool.method, params));
    } except (BridgeUnavailable, BridgeError, ValueError) as e {
        return tool_text(str(e), True);
    } except Exception as e {
        return tool_text(f"{name} failed: {type(e).__name__}: {e}", True);
    }
}

impl StudioMcp.tool_params(tool: StudioTool, args: dict[str, any]) -> dict[str, any] {
    for req in tool.schema.get("required", []) {
        if req not in args or args[req] in [None, ""] {
            raise ValueError(f"{tool.name} needs '{req}'.");
        }
    }
    if tool.method == "link_plan" {
        entries = args.get("entries");
        if not isinstance(entries, list) {
            raise ValueError(
                "studio_link_plan needs 'entries': a list of {step, keys}."
            );
        }
        clean: list[dict[str, any]] = [];
        for e in entries {
            if not isinstance(e, dict) or "step" not in e {
                raise ValueError("each entry needs 'step' and 'keys'.");
            }
            keys = e.get("keys") or [];
            if isinstance(keys, str) {
                keys = [keys];
            }
            clean.append({"step": e["step"], "keys": [str(k) for k in keys]});
        }
        return {"entries": clean};
    }
    params: dict[str, any] = {};
    for (k, v) in args.items() {
        if k in tool.schema.get("properties", {}) {
            params[k] = v;
        }
    }
    if "line" in params {
        try {
            params["line"] = int(params["line"]);
        } except (TypeError, ValueError) {
            raise ValueError("'line' must be an integer.") from None;
        }
    }
    if "limit" in params {
        try {
            params["limit"] = int(params["limit"]);
        } except (TypeError, ValueError) {
            raise ValueError("'limit' must be an integer.") from None;
        }
    }
    return params;
}

impl tool_text(payload: any, is_error: bool = False) -> dict[str, any] {
    text = payload
        if isinstance(payload, str)
        else json.dumps(payload, indent=1, `default=str);
    d: dict[str, any] = {"content": [{"type": "text", "text": text}]};
    if is_error {
        d["isError"] = True;
    }
    return d;
}

impl serve_studio_mcp(socket_path: str, root_dir: str) -> int {
    srv = StudioMcp(socket_path=socket_path, root_dir=root_dir);
    stdin = sys.stdin.buffer;
    stdout = sys.stdout.buffer;
    def write(payload: any) {
        stdout.write((json.dumps(payload) + "\n").encode("utf-8"));
        stdout.flush();
    }
    while True {
        line = stdin.readline();
        if not line {
            break;
        }
        text = line.decode("utf-8", "replace").strip();
        if not text {
            continue;
        }
        try {
            msg = json.loads(text);
        } except ValueError {
            write(
                {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": "Parse error"}
                }
            );
            continue;
        }
        msgs = msg if isinstance(msg, list) else [msg];
        replies: list[dict[str, any]] = [];
        for m in msgs {
            r = srv.handle(m) if isinstance(m, dict) else None;
            if r is not None {
                replies.append(r);
            }
        }
        if replies {
            write(replies if isinstance(msg, list) else replies[0]);
        }
    }
    return 0;
}
