"""Implementation of jac-shadcn plugin hooks."""

import json;
import from pathlib { Path }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, HookContext }

impl JacShadcnPlugin.create_cmd -> None {
    registry = get_registry();

    registry.extend_command(
        command_name="add",
        args=[
            Arg.create(
                "shadcn",
                typ=bool,
                default=False,
                help="Add shadcn UI component(s) from registry"
            ),

        ],
        pre_hook=_handle_shadcn_add,
        source="jac-shadcn"
    );

    registry.extend_command(
        command_name="remove",
        args=[
            Arg.create(
                "shadcn",
                typ=bool,
                default=False,
                help="Remove shadcn UI component(s)"
            ),

        ],
        pre_hook=_handle_shadcn_remove,
        source="jac-shadcn"
    );
}

impl JacShadcnPlugin.register_project_template -> dict | None {
    template_path = Path(__file__).parent.parent / "templates" / "jac-shadcn.jacpack";
    if template_path.exists() {
        try {
            with open(template_path, "r") as f {
                return json.load(f);
            }
        } except Exception {
            return _get_default_template();
        }
    }
    return _get_default_template();
}

impl _handle_shadcn_add(ctx: HookContext) -> None {
    if not ctx.get_arg("shadcn", False) {
        return;
    }

    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jac_shadcn.shadcn_handler { add_shadcn_components }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create --use jac-shadcn' first."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error(
            "No components specified",
            hint="Usage: jac add --shadcn button card dialog"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    try {
        result = add_shadcn_components(config, packages);
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0 if result else 1);
    } except Exception as e {
        console.error("Failed to add components: " + str(e));
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

impl _handle_shadcn_remove(ctx: HookContext) -> None {
    if not ctx.get_arg("shadcn", False) {
        return;
    }

    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jac_shadcn.shadcn_handler { remove_shadcn_components }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create --use jac-shadcn' first."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error(
            "No components specified", hint="Usage: jac remove --shadcn button"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    try {
        result = remove_shadcn_components(config, packages);
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0 if result else 1);
    } except Exception as e {
        console.error("Failed to remove components: " + str(e));
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

impl _get_default_template -> dict {
    return {
        "name": "jac-shadcn",
        "description": "Jac project with shadcn UI components and theming",
        "config": {
            "name": "{{name}}",
            "entry_point": "main.jac",
            "jac-shadcn": {
                "style": "nova",
                "baseColor": "neutral",
                "theme": "neutral",
                "font": "figtree",
                "radius": "default",
                "menuAccent": "subtle",
                "menuColor": "default",
                "registry": "https://jac-shadcn.jaseci.org"
            },
            "dependencies": {
                "npm": {
                    "clsx": "^2.1.1",
                    "tailwind-merge": "^3.5.0",
                    "tw-animate-css": "^1.4.0"
                }
            }
        },
        "files": {
            "main.jac": "import from .app { app }\n\ncl import from \".app\" { app }\ncl import \".global.css\";\n\ncl {\n    def:pub App() -> JsxElement {\n        return <div className=\"min-h-screen bg-background text-foreground flex items-center justify-center\">\n            <h1 className=\"text-2xl font-bold\">Welcome to {{name}}</h1>\n        </div>;\n    }\n}\n",
            "global.css": "@import \"tailwindcss\";\n@import \"tw-animate-css\";\n\n@custom-variant dark (&:is(.dark *));\n\n:root {\n  --background: oklch(1 0 0);\n  --foreground: oklch(0.145 0 0);\n  --primary: oklch(0.205 0 0);\n  --primary-foreground: oklch(0.985 0 0);\n  --secondary: oklch(0.97 0 0);\n  --secondary-foreground: oklch(0.205 0 0);\n  --muted: oklch(0.97 0 0);\n  --muted-foreground: oklch(0.556 0 0);\n  --accent: oklch(0.97 0 0);\n  --accent-foreground: oklch(0.205 0 0);\n  --destructive: oklch(0.577 0.245 27.325);\n  --border: oklch(0.922 0 0);\n  --input: oklch(0.922 0 0);\n  --ring: oklch(0.708 0 0);\n  --radius: 0.625rem;\n  --font-sans: 'Figtree Variable', sans-serif;\n}\n",
            "lib/utils.cl.jac": "cl import from \"clsx\" { clsx }\ncl import from \"tailwind-merge\" { twMerge }\n\ndef:pub cn(...inputs: Any) -> str {\n    return twMerge(clsx(inputs));\n}\n"
        },
        "directories": ["components", "components/ui", "lib"],
        "root_gitignore_entries": [".jac/", "node_modules/"]
    };
}
