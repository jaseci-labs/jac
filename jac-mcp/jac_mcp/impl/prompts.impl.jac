"""Implementation of MCP prompt templates."""

import from typing { Any }

"""Load a resource's content, returning empty string if unavailable."""
impl load_resource_content(uri: str) -> str {
    import from jac_mcp.resources { ResourceProvider }
    rp = ResourceProvider();
    rp.index_resources();
    content = rp.read_resource(uri);
    if content.startswith("Error:") {
        return "";
    }
    return content;
}

"""Build system prompt with pitfalls and optional extra resources."""
impl build_system_prompt(extra_uris: list[str] = []) -> str {
    parts: list[str] = [
        "You are an expert Jac programmer. Follow Jac syntax rules exactly.",
        "",
        "## Key Jac Pitfalls",
        load_resource_content("jac://guide/pitfalls"),

    ];
    for uri in extra_uris {
        content = load_resource_content(uri);
        if content {
            parts.append(f"\n## Reference: {uri}\n{content}");
        }
    }
    return "\n".join(parts);
}

"""Return list of available prompts."""
impl PromptProvider.list_prompts -> list[dict[str, Any]] {
    return [
        {
            "name": "write_module",
            "description": "Generate a new Jac module with optional .impl.jac file",
            "arguments": [
                {"name": "name", "description": "Module name", "required": True},
                {
                    "name": "purpose",
                    "description": "What the module does",
                    "required": True
                },
                {
                    "name": "has_impl",
                    "description": "Include .impl.jac (true/false)",
                    "required": False
                },

            ]
        },
        {
            "name": "write_impl",
            "description": "Generate .impl.jac file for existing declarations",
            "arguments": [
                {
                    "name": "declarations",
                    "description": "Content of the .jac declaration file",
                    "required": True
                },

            ]
        },
        {
            "name": "write_walker",
            "description": "Generate a walker with visit logic",
            "arguments": [
                {"name": "name", "description": "Walker name", "required": True},
                {
                    "name": "purpose",
                    "description": "What the walker does",
                    "required": True
                },
                {
                    "name": "node_types",
                    "description": "Node types to traverse",
                    "required": True
                },

            ]
        },
        {
            "name": "write_node",
            "description": "Generate a node archetype with has declarations",
            "arguments": [
                {"name": "name", "description": "Node name", "required": True},
                {
                    "name": "fields",
                    "description": "Field definitions",
                    "required": True
                },

            ]
        },
        {
            "name": "write_test",
            "description": "Generate test blocks for a module",
            "arguments": [
                {
                    "name": "module_name",
                    "description": "Module to test",
                    "required": True
                },
                {
                    "name": "functions_to_test",
                    "description": "Functions/abilities to test",
                    "required": True
                },

            ]
        },
        {
            "name": "write_ability",
            "description": "Generate an ability (method) implementation",
            "arguments": [
                {"name": "name", "description": "Ability name", "required": True},
                {
                    "name": "signature",
                    "description": "Type signature",
                    "required": True
                },
                {"name": "purpose", "description": "What it does", "required": True},

            ]
        },
        {
            "name": "debug_error",
            "description": "Debug a Jac compilation error",
            "arguments": [
                {
                    "name": "error_output",
                    "description": "The error message(s)",
                    "required": True
                },
                {
                    "name": "code",
                    "description": "The code that caused the error",
                    "required": True
                },

            ]
        },
        {
            "name": "fix_type_error",
            "description": "Fix a type checking error in Jac code",
            "arguments": [
                {
                    "name": "error_output",
                    "description": "The type error message",
                    "required": True
                },
                {
                    "name": "code",
                    "description": "The code with the type error",
                    "required": True
                },

            ]
        },
        {
            "name": "migrate_python",
            "description": "Convert Python code to idiomatic Jac",
            "arguments": [
                {
                    "name": "python_code",
                    "description": "Python source code to convert",
                    "required": True
                },

            ]
        },

    ];
}

"""Get a prompt by name with arguments."""
impl PromptProvider.get_prompt(name: str, arguments: dict[str, str]) -> dict[str, Any] {
    if name == "write_module" {
        return _prompt_write_module(arguments);
    } elif name == "write_impl" {
        return _prompt_write_impl(arguments);
    } elif name == "write_walker" {
        return _prompt_write_walker(arguments);
    } elif name == "write_node" {
        return _prompt_write_node(arguments);
    } elif name == "write_test" {
        return _prompt_write_test(arguments);
    } elif name == "write_ability" {
        return _prompt_write_ability(arguments);
    } elif name == "debug_error" {
        return _prompt_debug_error(arguments);
    } elif name == "fix_type_error" {
        return _prompt_fix_type_error(arguments);
    } elif name == "migrate_python" {
        return _prompt_migrate_python(arguments);
    } else {
        return {
            "description": f"Unknown prompt: {name}",
            "messages": [
                {"role": "user", "content": f"Unknown prompt template: {name}"}
            ]
        };
    }
}

def _prompt_write_module(args: dict[str, str]) -> dict[str, Any] {
    mod_name = args.get("name", "module");
    purpose = args.get("purpose", "");
    has_impl = args.get("has_impl", "true").lower() in ("true", "1", "yes");

    system = build_system_prompt(["jac://guide/patterns"]);
    user_msg = f"Generate a Jac module named '{mod_name}' that {purpose}.";
    if has_impl {
        user_msg += "\nInclude both the declaration file (.jac) and the implementation file (.impl.jac).";
        user_msg += "\nIn the .jac file, method signatures should end with ';'.";
        user_msg += "\nIn the .impl.jac file, use 'impl ClassName.method(...) { body }' syntax.";
    }

    return {
        "description": f"Generate Jac module: {mod_name}",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_write_impl(args: dict[str, str]) -> dict[str, Any] {
    declarations = args.get("declarations", "");
    system = build_system_prompt(["jac://guide/patterns"]);
    user_msg = f"Generate the .impl.jac file for these declarations:\n\n```jac\n{declarations}\n```";
    user_msg += "\n\nUse 'impl ClassName.method(...) {{ body }}' syntax for each method.";

    return {
        "description": "Generate .impl.jac implementation",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_write_walker(args: dict[str, str]) -> dict[str, Any] {
    name = args.get("name", "my_walker");
    purpose = args.get("purpose", "");
    node_types = args.get("node_types", "");

    system = build_system_prompt(["jac://docs/osp", "jac://guide/patterns"]);
    user_msg = f"Generate a walker named '{name}' that {purpose}, traversing node types: {node_types}.";
    user_msg += "\nUse 'visit [-->]' for traversal and proper Jac walker syntax.";

    return {
        "description": f"Generate walker: {name}",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_write_node(args: dict[str, str]) -> dict[str, Any] {
    name = args.get("name", "MyNode");
    fields = args.get("fields", "");

    system = build_system_prompt(["jac://docs/osp"]);
    user_msg = f"Generate a node archetype named '{name}' with fields: {fields}.";
    user_msg += "\nUse 'has' declarations with type annotations.";

    return {
        "description": f"Generate node: {name}",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_write_test(args: dict[str, str]) -> dict[str, Any] {
    module_name = args.get("module_name", "");
    functions_to_test = args.get("functions_to_test", "");

    system = build_system_prompt(["jac://guide/patterns"]);
    user_msg = f"Generate test blocks for module '{module_name}' covering: {functions_to_test}.";
    user_msg += '\nUse Jac test block syntax: test "description" {{ assertions; }}';

    return {
        "description": f"Generate tests for: {module_name}",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_write_ability(args: dict[str, str]) -> dict[str, Any] {
    name = args.get("name", "");
    signature = args.get("signature", "");
    purpose = args.get("purpose", "");

    system = build_system_prompt(["jac://docs/functions-objects"]);
    user_msg = f"Generate an ability named '{name}' with signature '{signature}' that {purpose}.";

    return {
        "description": f"Generate ability: {name}",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_debug_error(args: dict[str, str]) -> dict[str, Any] {
    error_output = args.get("error_output", "");
    code = args.get("code", "");

    system = build_system_prompt();
    user_msg = f"Debug this Jac compilation error:\n\n```\n{error_output}\n```";
    user_msg += f"\n\nIn this code:\n\n```jac\n{code}\n```";
    user_msg += "\n\nExplain the error, identify the root cause, and provide the corrected code.";

    return {
        "description": "Debug compilation error",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_fix_type_error(args: dict[str, str]) -> dict[str, Any] {
    error_output = args.get("error_output", "");
    code = args.get("code", "");

    system = build_system_prompt(["jac://docs/primitives"]);
    user_msg = f"Fix this type error:\n\n```\n{error_output}\n```";
    user_msg += f"\n\nIn this code:\n\n```jac\n{code}\n```";
    user_msg += "\n\nExplain the type mismatch and provide corrected code.";

    return {
        "description": "Fix type error",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}

def _prompt_migrate_python(args: dict[str, str]) -> dict[str, Any] {
    python_code = args.get("python_code", "");

    system = build_system_prompt(
        ["jac://docs/python-integration", "jac://guide/patterns"]
    );
    user_msg = f"Convert this Python code to idiomatic Jac:\n\n```python\n{python_code}\n```";
    user_msg += "\n\nUse obj instead of class, has instead of self.x, can for methods, semicolons, braces, and Jac import syntax.";

    return {
        "description": "Migrate Python to Jac",
        "messages": [{"role": "user", "content": f"{system}\n\n{user_msg}"}]
    };
}
