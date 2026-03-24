"""Implementation of MCP tools."""

import from typing { Any }
import re;

"""Return list of available tools with schemas."""
impl ToolProvider.list_tools -> list[dict[str, Any]] {
    return [
        {
            "name": "validate_jac",
            "description": "Validate Jac code with full type checking. IMPORTANT: You MUST call this tool after generating or modifying any Jac code to verify it compiles correctly. Returns structured errors and warnings. If errors are returned, fix the code and re-validate before presenting it to the user.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to validate"
                    },
                    "filename": {
                        "type": "string",
                        "description": "Optional filename for error messages",
                        "default": "snippet.jac"
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "check_syntax",
            "description": "Quick syntax-only check (parse-only, no type checking). Use this for a fast first pass when iterating on code. For final validation, use validate_jac instead.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to check"
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "format_jac",
            "description": "Format Jac code according to standard style. Use this to ensure code follows Jac formatting conventions before presenting it to the user.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to format"
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "py_to_jac",
            "description": "Convert Python code to Jac using the official compiler transpiler. Use this as a starting point when migrating Python code — the output may need manual refinement for idiomatic Jac style.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "python_code": {
                        "type": "string",
                        "description": "Python source code to convert"
                    }
                },
                "required": ["python_code"]
            }
        },
        {
            "name": "explain_error",
            "description": "Explain a Jac compiler error with suggestions and examples. Use this when validate_jac returns errors you need to understand. Returns a structured explanation with the error category, root cause, and corrected code pattern.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "error_message": {
                        "type": "string",
                        "description": "The error message to explain"
                    }
                },
                "required": ["error_message"]
            }
        },
        {
            "name": "list_examples",
            "description": "List available Jac example code categories. Use this to discover working Jac code examples that demonstrate correct patterns before writing new code.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "category": {
                        "type": "string",
                        "description": "Optional category filter"
                    }
                }
            }
        },
        {
            "name": "get_example",
            "description": "Get all .jac files from an example category. Use this to study working code before writing similar functionality — these examples are tested and verified.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Example category name"}
                },
                "required": ["name"]
            }
        },
        {
            "name": "search_docs",
            "description": "Search Jac documentation by keyword. Use this when you are unsure about Jac syntax or features — the results come from the official documentation and are authoritative. Returns ranked snippets with resource URIs.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Search query keywords"},
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of results",
                        "default": 5
                    }
                },
                "required": ["query"]
            }
        },
        {
            "name": "get_ast",
            "description": "Parse Jac code and return AST representation. Useful for understanding code structure.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to parse"
                    },
                    "format": {
                        "type": "string",
                        "description": "Output format: tree or json",
                        "default": "tree",
                        "enum": ["tree", "json"]
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "lint_jac",
            "description": "Lint Jac code to detect style violations, unused symbols, undefined names, unreachable code, and other issues. Supports 30+ lint rules (W3001-W3036). Use auto_fix=true to automatically fix violations and return corrected code.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to lint"
                    },
                    "auto_fix": {
                        "type": "boolean",
                        "description": "Auto-fix lint violations and return corrected code",
                        "default": False
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "jac_to_py",
            "description": "Convert Jac code to Python using the official compiler transpiler. Useful for understanding what Python code Jac compiles to, or for debugging. The output shows the generated Python equivalent of the Jac source.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to convert to Python"
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "jac_to_js",
            "description": "Convert Jac code to JavaScript/ECMAScript using the official compiler transpiler. Critical for jac-client full-stack development to understand what JS is generated from .cl.jac client code.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to convert to JavaScript"
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "run_jac",
            "description": "Execute Jac code and return stdout/stderr output. Use this to verify runtime behavior after validation. Supports running the whole module or a specific entrypoint (walker or function). Code runs in a sandboxed environment with a timeout.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to execute"
                    },
                    "entrypoint": {
                        "type": "string",
                        "description": "Optional specific walker or function to invoke (like jac enter)",
                        "default": ""
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Max execution time in seconds",
                        "default": 10
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "graph_visualize",
            "description": "Execute Jac code and generate a graph visualization of the resulting object-spatial graph. Returns DOT or JSON format. Essential for debugging walker traversal, node connectivity, and data flow in Jac's graph-based programming model.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code that builds a graph"
                    },
                    "format": {
                        "type": "string",
                        "description": "Output format: dot or json",
                        "default": "dot",
                        "enum": ["dot", "json"]
                    },
                    "depth": {
                        "type": "integer",
                        "description": "Max traversal depth (-1 for unlimited)",
                        "default": -1
                    },
                    "bfs": {
                        "type": "boolean",
                        "description": "Use breadth-first search (true) or depth-first (false)",
                        "default": True
                    },
                    "edge_limit": {
                        "type": "integer",
                        "description": "Max edges to include",
                        "default": 512
                    },
                    "node_limit": {
                        "type": "integer",
                        "description": "Max nodes to include",
                        "default": 512
                    }
                },
                "required": ["code"]
            }
        },
        {
            "name": "list_templates",
            "description": "List available Jac project templates for scaffolding new projects with 'jac create'. Returns all registered templates (built-in like 'default' and plugin-provided like 'client') with names and descriptions.",
            "inputSchema": {"type": "object", "properties": {}}
        },
        {
            "name": "create_project",
            "description": "Scaffold a new Jac project from a template. Creates project structure with jac.toml, source files, and .gitignore. Use list_templates first to see available templates. The project is created in the specified directory (or a temp directory by default).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Project name (used as directory name and in jac.toml)"
                    },
                    "template": {
                        "type": "string",
                        "description": "Template to use (e.g., 'default', 'client'). Use list_templates to see options.",
                        "default": "default"
                    },
                    "directory": {
                        "type": "string",
                        "description": "Parent directory where the project will be created. Defaults to system temp directory.",
                        "default": ""
                    }
                },
                "required": ["name"]
            }
        },
        {
            "name": "start_server",
            "description": "Start a Jac REST API server from a .jac file. In normal mode, starts the server as a background process and returns the localhost URL and PID. In faux mode (faux=true), only inspects and returns endpoint documentation without starting the server. The filename must be an absolute path or relative to the MCP server's working directory.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Path to the .jac file to serve"
                    },
                    "port": {
                        "type": "integer",
                        "description": "Port number for the server",
                        "default": 8000
                    },
                    "faux": {
                        "type": "boolean",
                        "description": "If true, only print endpoint docs without starting the server",
                        "default": False
                    }
                },
                "required": ["filename"]
            }
        },

    ];
}

"""Call a tool by name with arguments."""
impl ToolProvider.call_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    try {
        if name == "validate_jac" {
            code = arguments.get("code", "");
            filename = arguments.get("filename", "snippet.jac");
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return CompilerBridge.typecheck_snippet(code, filename);
        } elif name == "check_syntax" {
            code = arguments.get("code", "");
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return CompilerBridge.parse_snippet(code);
        } elif name == "format_jac" {
            code = arguments.get("code", "");
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return CompilerBridge.format_snippet(code);
        } elif name == "py_to_jac" {
            python_code = arguments.get("python_code", "");
            if not python_code {
                return {"error": "Missing required argument: python_code"};
            }
            return CompilerBridge.py_to_jac(python_code);
        } elif name == "explain_error" {
            error_message = arguments.get("error_message", "");
            if not error_message {
                return {"error": "Missing required argument: error_message"};
            }
            return explain_error(error_message);
        } elif name == "list_examples" {
            category = arguments.get("category");
            return list_examples(category);
        } elif name == "get_example" {
            example_name = arguments.get("name", "");
            if not example_name {
                return {"error": "Missing required argument: name"};
            }
            return get_example(example_name);
        } elif name == "search_docs" {
            query = arguments.get("query", "");
            limit = arguments.get("limit", 5);
            if not query {
                return {"error": "Missing required argument: query"};
            }
            return search_docs(query, limit);
        } elif name == "get_ast" {
            code = arguments.get("code", "");
            fmt = arguments.get("format", "tree");
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return get_ast(code, fmt);
        } elif name == "lint_jac" {
            code = arguments.get("code", "");
            auto_fix = arguments.get("auto_fix", False);
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return lint_jac(code, auto_fix);
        } elif name == "jac_to_py" {
            code = arguments.get("code", "");
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return jac_to_py(code);
        } elif name == "jac_to_js" {
            code = arguments.get("code", "");
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return jac_to_js(code);
        } elif name == "run_jac" {
            code = arguments.get("code", "");
            entrypoint = arguments.get("entrypoint", "");
            timeout = arguments.get("timeout", 10);
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return run_jac(code, entrypoint, timeout);
        } elif name == "graph_visualize" {
            code = arguments.get("code", "");
            fmt = arguments.get("format", "dot");
            depth = arguments.get("depth", -1);
            bfs = arguments.get("bfs", True);
            edge_limit = arguments.get("edge_limit", 512);
            node_limit = arguments.get("node_limit", 512);
            if not code {
                return {"error": "Missing required argument: code"};
            }
            return graph_visualize(code, fmt, depth, bfs, edge_limit, node_limit);
        } elif name == "list_templates" {
            return list_templates();
        } elif name == "create_project" {
            proj_name = arguments.get("name", "");
            template = arguments.get("template", "default");
            directory = arguments.get("directory", "");
            if not proj_name {
                return {"error": "Missing required argument: name"};
            }
            return create_project(proj_name, template, directory);
        } elif name == "start_server" {
            srv_filename = arguments.get("filename", "");
            port = arguments.get("port", 8000);
            faux = arguments.get("faux", False);
            if not srv_filename {
                return {"error": "Missing required argument: filename"};
            }
            return start_server(srv_filename, port, faux);
        } else {
            return {"error": f"Unknown tool: {name}"};
        }
    } except Exception as e {
        return {"error": f"Tool execution failed: {str(e)}"};
    }
}

"""Explain a compiler error with suggestions and examples."""
impl explain_error(error_message: str) -> dict[str, Any] {
    msg_lower = error_message.lower();
    error_patterns: list[tuple] = [
        (
            r"unexpected token|expected.*got|syntax error",
            "Syntax Error",
            "The code contains a syntax error. Common causes: missing semicolons, missing braces, or using Python syntax instead of Jac syntax.",
            "# Jac requires semicolons and braces:\nobj Foo {\n    has x: int = 5;\n}"
        ),
        (
            r"undefined name|not defined|name.*is not defined",
            "Undefined Name",
            "A variable or symbol is referenced but not defined. Check imports, spelling, and scope.",
            "# Import what you need:\nimport from os { path }"
        ),
        (
            r"type.*mismatch|incompatible.*type|cannot assign.*to",
            "Type Mismatch",
            "Types don't match. Ensure assignments, arguments, and returns match declared types.",
            "has x: int = 5;  # OK\n# has z: int = \"oops\";  # ERROR"
        ),
        (
            r"cannot find module|no module|module not found|import error",
            "Import Error",
            "Module not found. Use Jac import syntax: 'import from module { name }'.",
            "import from os { path }\nimport from typing { Any }"
        ),
        (
            r"has no attribute|attribute.*not found|no member",
            "Attribute Error",
            "Object doesn't have the attribute. Check archetype definition.",
            "obj Foo {\n    has x: int = 5;\n}"
        ),
        (
            r"class|def __init__|self\.",
            "Python Syntax Detected",
            "Detected Python syntax. Use 'obj' not 'class', 'has' not 'self.x', 'can' for methods.",
            "# obj Foo { has x: int = 5; }  # NOT: class Foo: ..."
        ),

    ];
    for (pattern, title, explanation, example) in error_patterns {
        if re.search(pattern, msg_lower) {
            return {
                "title": title,
                "explanation": explanation,
                "suggestion": "Review the error and apply the pattern shown in the example.",
                "example": example,
                "docs_uri": "jac://guide/pitfalls"
            };
        }
    }
    return {
        "title": "Compilation Error",
        "explanation": f"The compiler reported: {error_message}",
        "suggestion": "Check Jac syntax reference. Common issues: missing semicolons, wrong import syntax.",
        "example": "",
        "docs_uri": "jac://guide/pitfalls"
    };
}

"""List available example categories."""
impl list_examples(category: str | None = None) -> dict[str, Any] {
    import from jac_mcp.resources { ResourceProvider }
    rp = ResourceProvider();
    rp.index_resources();
    examples: list[dict[str, str]] = [];
    for (uri, info) in rp._resources.items() {
        if uri.startswith("jac://examples/") and uri != "jac://examples/index" {
            cat_name = uri.split("/")[-1];
            if category is None or category == cat_name {
                examples.append(
                    {
                        "name": cat_name,
                        "uri": uri,
                        "description": info.get("description", "")
                    }
                );
            }
        }
    }
    # If no individual examples found, try lazy GitHub fetch (PyPI install)
    if not examples and "jac://examples/index" in rp._resources {
        categories = rp._fetch_github_categories();
        for cat_name in categories {
            if category is None or category == cat_name {
                examples.append(
                    {
                        "name": cat_name,
                        "uri": f"jac://examples/{cat_name}",
                        "description": f"Example Jac code for {cat_name}"
                    }
                );
            }
        }
    }
    return {"examples": sorted(examples, key=lambda x : x["name"])};
}

"""Get all files from an example category."""
impl get_example(name: str) -> dict[str, Any] {
    import from jac_mcp.resources { ResourceProvider }
    rp = ResourceProvider();
    rp.index_resources();
    uri = f"jac://examples/{name}";
    content = rp.read_resource(uri);
    if content.startswith("Error:") {
        return {"error": content};
    }
    return {"name": name, "content": content};
}

"""Search documentation by keywords."""
impl search_docs(query: str, limit: int = 5) -> dict[str, Any] {
    import from jac_mcp.resources { ResourceProvider }
    rp = ResourceProvider();
    rp.index_resources();
    keywords = [
        w.lower()
        for w in query.split()
        if len(w) > 2
    ];
    if not keywords {
        return {"results": []};
    }
    scored: list[tuple] = [];
    for (uri, info) in rp._resources.items() {
        if info.get("_is_dir") or uri == "jac://examples/index" {
            continue;
        }

        file_path = info.get("path");
        if not file_path {
            continue;
        }

        try {
            with open(file_path, "r") as f {
                content = f.read().lower();
            }
        } except Exception {
            continue;
        }

        score = 0.0;
        for kw in keywords {
            count = content.count(kw);
            if count > 0 {
                score += count;
            }
        }

        if score > 0 {
            snippet = "";
            for kw in keywords {
                idx = content.find(kw);
                if idx >= 0 {
                    start = max(0, idx - 100);
                    end = min(len(content), idx + 100);
                    snippet = content[start:end].strip();
                    break;
                }
            }
            scored.append(
                (
                    score,
                    {
                        "uri": uri,
                        "title": info.get("name", ""),
                        "description": info.get("description", ""),
                        "snippet": snippet[:200],
                        "score": score
                    }
                )
            );
        }
    }
    scored.sort(key=lambda x : -x[0]);
    results = [item[1] for item in scored[:limit]];
    return {"results": results};
}

"""Parse code and return AST info."""
impl get_ast(code: str, fmt: str = "tree") -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.get_ast_snippet(code, fmt);
}

"""Lint Jac code with optional auto-fix."""
impl lint_jac(code: str, auto_fix: bool = False) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.lint_snippet(code, auto_fix);
}

"""Convert Jac code to Python."""
impl jac_to_py(code: str) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.jac_to_py(code);
}

"""Convert Jac code to JavaScript."""
impl jac_to_js(code: str) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.jac_to_js(code);
}

"""Execute Jac code and return output."""
impl run_jac(code: str, entrypoint: str = "", timeout: int = 10) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.run_snippet(code, entrypoint, timeout);
}

"""Generate graph visualization from Jac code."""
impl graph_visualize(
    code: str,
    format: str = "dot",
    depth: int = -1,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512
) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.graph_viz_snippet(
        code, format, depth, bfs, edge_limit, node_limit
    );
}

"""List available Jac project templates."""
impl list_templates -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.list_templates();
}

"""Create a new Jac project from a template."""
impl create_project(
    name: str, template: str = "default", directory: str = ""
) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.create_project(name, template, directory);
}

"""Start a Jac REST API server."""
impl start_server(
    filename: str, port: int = 8000, faux: bool = False
) -> dict[str, Any] {
    import from jac_mcp.compiler_bridge { CompilerBridge }
    return CompilerBridge.start_server(filename, port, faux);
}
