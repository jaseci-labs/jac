"""Implementation of MCP tools."""

import from typing { Any }
import re;

"""Return list of available tools with schemas."""
impl ToolProvider.list_tools -> list[dict[str, Any]] {
    return [
        {
            "name": "validate_jac",
            "description": "Validate Jac code with full type checking. Returns structured errors and warnings.",
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
            "description": "Quick syntax check (parse-only, no type checking). Faster than validate_jac.",
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
            "description": "Format Jac code according to standard style.",
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
            "description": "Convert Python code to Jac. Returns converted code with warnings.",
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
            "description": "Explain a Jac compiler error with suggestions and examples.",
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
            "description": "List available Jac example code categories.",
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
            "description": "Get all .jac files from an example category.",
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
            "description": "Search Jac documentation by keyword. Returns ranked snippets with resource URIs.",
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
            "description": "Parse Jac code and return AST representation.",
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
    result = CompilerBridge.parse_snippet(code);
    if not result.get("valid", False) {
        return {
            "error": "Parse failed",
            "errors": result.get("errors", []),
            "ast": None
        };
    }
    return {
        "ast": "Parsed successfully. Use validate_jac for detailed analysis.",
        "valid": True
    };
}
