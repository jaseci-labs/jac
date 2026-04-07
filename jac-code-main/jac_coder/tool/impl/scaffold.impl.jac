def _write(base_dir: str, relative_path: str, content: str) -> None {
    full_path = os.path.join(base_dir, relative_path);
    verdict = _check_permission("write_file", full_path);
    if verdict != "allow" {
        raise PermissionError(verdict);
    }
    Path(full_path).parent.mkdir(parents=True, exist_ok=True);
    Path(full_path).write_text(content);
    emit_event(
        "file_written",
        {"path": full_path, "lines": len(content.splitlines()), "source": "scaffold"}
    );
    if os.environ.get("JACCODER_WEB_MODE", "") {
        import time;
        time.sleep(0.3);
    }
}


impl scaffold_project(project_type: str, name: str, directory: str) -> str {
    (directory, err) = sandbox_path(directory);
    if err {
        return err;
    }
    tool_status("scaffold", f"{project_type} project '{name}' in {directory}");

    if not directory {
        return "Error: directory path is required";
    }
    if project_type not in ["frontend", "backend", "fullstack", "ai_agent"] {
        return f"Error: project_type must be one of: frontend, backend, fullstack, ai_agent. Got: {project_type}";
    }

    proj_name: str = name if name else directory.rstrip("/").split("/")[-1];
    if name {
        project_dir = os.path.join(directory, name);
    } else {
        project_dir = directory;
    }

    (project_dir, err) = sandbox_path(project_dir);
    if err {
        return err;
    }

    try {
        os.makedirs(project_dir, exist_ok=True);
        files_created: list = [];

        if project_type == "frontend" {
            files_created = _scaffold_frontend(project_dir, proj_name);
        } elif project_type == "backend" {
            files_created = _scaffold_backend(project_dir, proj_name);
        } elif project_type == "fullstack" {
            files_created = _scaffold_fullstack(project_dir, proj_name);
        } elif project_type == "ai_agent" {
            files_created = _scaffold_ai_agent(project_dir, proj_name);
        }

        result_lines: list = [
            f"Scaffolded {project_type} project '{name}' at {project_dir}",
            ""
        ];
        result_lines.append("Files created:");
        for f in files_created {
            result_lines.append(f"  {f}");
        }
        result_lines.append("");
        result_lines.append("NEXT STEPS:");
        result_lines.append(
            "1. Read the scaffolded .cl.jac and .jac files to learn the correct syntax patterns."
        );
        result_lines.append(
            "2. When creating new components, copy the EXACT syntax from the scaffolded files."
        );
        result_lines.append("3. Build incrementally — add one component at a time.");

        (output, _) = truncate_output("\n".join(result_lines));
        tool_end(f"-> {len(files_created)} files");
        return output;
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Error creating project: {str(e)}";
    }
}


# ===========================================================================
# jac.toml templates
# ===========================================================================

glob _TOML_FRONTEND = '[project]\nname = "__NAME__"\nversion = "1.0.0"\ndescription = "Jac client application"\nentry-point = "main.jac"\n\n[dependencies.npm]\njac-client-node = "1.0.5"\nclsx = "^2.1.1"\ntailwind-merge = "^3.4.0"\ntailwindcss = "^4.1.17"\n\n[dependencies.npm.dev]\n"@jac-client/dev-deps" = "2.0.0"\n\n[serve]\nbase_route_app = "app"\n\n[plugins.client]\n\n[plugins.client.vite]\nplugins = ["tailwindcss()"]\nlib_imports = ["import tailwindcss from \'@tailwindcss/vite\'"]\n\n[plugins.client.app_meta_data]\ntitle = "__NAME__"\n';

glob _TOML_FULLSTACK = '[project]\nname = "__NAME__"\nversion = "1.0.0"\ndescription = "Jac full-stack application"\nentry-point = "main.jac"\n\n[dependencies]\npython-dotenv = ">=1.0.0"\n\n[dependencies.npm]\njac-client-node = "1.0.5"\nclsx = "^2.1.1"\ntailwind-merge = "^3.4.0"\ntailwindcss = "^4.1.17"\n\n[dependencies.npm.dev]\n"@jac-client/dev-deps" = "2.0.0"\n\n[serve]\nbase_route_app = "app"\n\n[plugins.client]\n\n[plugins.client.vite]\nplugins = ["tailwindcss()"]\nlib_imports = ["import tailwindcss from \'@tailwindcss/vite\'"]\n\n[plugins.client.app_meta_data]\ntitle = "__NAME__"\n';

glob _TOML_BACKEND = '[project]\nname = "__NAME__"\nversion = "1.0.0"\nentry-point = "main.jac"\n\n[dependencies]\npython-dotenv = ">=1.0.0"\n';

glob _TOML_AGENT = '[project]\nname = "__NAME__"\nversion = "1.0.0"\nentry-point = "main.jac"\n\n[dependencies]\npython-dotenv = ">=1.0.0"\nbyllm = ">=0.1.0"\n';


# ===========================================================================
# CSS template
# ===========================================================================

glob _GLOBAL_CSS = '@import "tailwindcss";\n\n@theme {\n    --color-primary: #3b82f6;\n    --color-primary-foreground: #ffffff;\n    --color-secondary: #64748b;\n    --color-secondary-foreground: #ffffff;\n    --color-background: #f8fafc;\n    --color-surface: #ffffff;\n    --color-surface-hover: #f1f5f9;\n    --color-text-primary: #0f172a;\n    --color-text-secondary: #64748b;\n    --color-border: #e2e8f0;\n    --color-success: #22c55e;\n    --color-warning: #f59e0b;\n    --color-error: #ef4444;\n}\n\n.dark {\n    --color-primary: #60a5fa;\n    --color-primary-foreground: #ffffff;\n    --color-secondary: #94a3b8;\n    --color-secondary-foreground: #ffffff;\n    --color-background: #0f172a;\n    --color-surface: #1e293b;\n    --color-surface-hover: #334155;\n    --color-text-primary: #f1f5f9;\n    --color-text-secondary: #94a3b8;\n    --color-border: #334155;\n    --color-success: #4ade80;\n    --color-warning: #fbbf24;\n    --color-error: #f87171;\n}\n';


# ===========================================================================
# Utility template
# ===========================================================================

glob _UTILS_CL = 'import from "clsx" { clsx }\nimport from "tailwind-merge" { twMerge }\n\ndef:pub cn(input: any) -> str {\n    inputs = [].slice.call(arguments);\n    return twMerge(clsx(inputs));\n}\n';


# ===========================================================================
# Frontend-only scaffold
# ===========================================================================

glob _FRONTEND_MAIN = 'cl import from .components.Layout { Layout }\ncl {\n    def:pub app() -> JsxElement {\n        return <Layout />;\n    }\n}\n';

glob _FRONTEND_HEADER = 'import from ..lib.utils { cn }\n\ndef:pub Header(title: str, theme: str, on_toggle_theme: any) -> JsxElement {\n    return (\n        <header className="border-b border-border px-6 py-4 flex items-center justify-between">\n            <h1 className="text-xl font-bold">{title}</h1>\n            <button onClick={on_toggle_theme}\n                className="px-3 py-1 bg-secondary text-secondary-foreground rounded-lg text-sm">\n                {(theme == "dark") and "Light" or "Dark"}\n            </button>\n        </header>\n    );\n}\n';

glob _FRONTEND_COUNTER = 'import from ..lib.utils { cn }\n\ndef:pub Counter() -> JsxElement {\n    # State\n    has count: int = 0;\n\n    # Handlers\n    def handle_increment() -> None {\n        count = count + 1;\n    }\n\n    # Render\n    return (\n        <button onClick={handle_increment}\n            className="px-4 py-2 bg-primary text-primary-foreground rounded-lg">\n            Count: {str(count)}\n        </button>\n    );\n}\n';

glob _FRONTEND_APP = 'import "..styles.global.css";\nimport from .Header { Header }\nimport from .Counter { Counter }\n\ndef:pub Layout() -> JsxElement {\n    # State\n    has theme: str = "light";\n\n    # Effects\n    can with (theme) entry {\n        if theme == "dark" {\n            document.documentElement.classList.add("dark");\n        } else {\n            document.documentElement.classList.remove("dark");\n        }\n    }\n\n    # Handlers\n    def handle_toggle_theme() -> None {\n        theme = (theme == "dark") and "light" or "dark";\n    }\n\n    # Render\n    return (\n        <div className="min-h-screen bg-background text-text-primary">\n            <Header title="__NAME__" theme={theme} on_toggle_theme={handle_toggle_theme} />\n            <main className="max-w-2xl mx-auto px-4 py-8">\n                <Counter />\n            </main>\n        </div>\n    );\n}\n';


# ===========================================================================
# Fullstack scaffold
# ===========================================================================

glob _FULLSTACK_MAIN = 'import from uuid { uuid4 }\nimport from datetime { datetime }\n\n\nnode Item {\n    has id: str = "";\n    has name: str;\n    has description: str = "";\n    has created_at: str = "";\n\n    def postinit {\n        if not self.id { self.id = str(uuid4()); }\n        if not self.created_at { self.created_at = datetime.now().isoformat(); }\n    }\n}\n\n\ndef:pub get_items() -> list {\n    return [{"id": i.id, "name": i.name, "description": i.description}\n            for i in [root()-->][?:Item];\n}\n\n\ndef:pub add_item(name: str, description: str = "") -> dict {\n    item = (root() ++> Item(name=name, description=description))[0];\n    return {"id": item.id, "name": item.name, "description": item.description};\n}\n\n\ndef:pub delete_item(id: str) -> dict {\n    for item in [root()-->][?:Item] {\n        if item.id == id {\n            root() del--> item;\n            return {"deleted": id};\n        }\n    }\n    return {"error": "not found"};\n}\n\n\ncl import from .components.Layout { Layout }\ncl {\n    def:pub app() -> JsxElement {\n        return <Layout />;\n    }\n}\n';

glob _FULLSTACK_HOOK = 'sv import from ..main { get_items, add_item, delete_item }\n\ndef:pub useItems() -> dict {\n    # State\n    has items: list = [];\n    has loading: bool = True;\n    has error: str = "";\n\n    # Fetch data on mount\n    async can with entry {\n        try {\n            result = await get_items();\n            items = result or [];\n        } except Exception as e {\n            error = str(e);\n        }\n        loading = False;\n    }\n\n    # Handlers\n    async def handle_add(name: str, description: str = "") -> None {\n        if not name { return; }\n        result = await add_item(name, description);  # positional args only — kwargs broken in .cl.jac\n        if result and not result.error {\n            items = items + [result];\n        }\n    }\n\n    async def handle_delete(id: str) -> None {\n        result = await delete_item(id);  # positional args only — kwargs broken in .cl.jac\n        if result and not result.error {\n            items = [i for i in items if i["id"] != id];\n        }\n    }\n\n    return {\n        "items": items,\n        "loading": loading,\n        "error": error,\n        "handleAdd": handle_add,\n        "handleDelete": handle_delete\n    };\n}\n';

glob _FULLSTACK_HEADER = 'import from ..lib.utils { cn }\n\ndef:pub Header(title: str, theme: str, on_toggle_theme: any) -> JsxElement {\n    return (\n        <header className="border-b border-border px-6 py-4 flex items-center justify-between">\n            <h1 className="text-xl font-bold">{title}</h1>\n            <button onClick={on_toggle_theme}\n                className="px-3 py-1 bg-secondary text-secondary-foreground rounded-lg text-sm">\n                {(theme == "dark") and "Light" or "Dark"}\n            </button>\n        </header>\n    );\n}\n';

glob _FULLSTACK_ITEMLIST = 'import from ..lib.utils { cn }\nimport from ..hooks.useItems { useItems }\nimport from .ItemCard { ItemCard }\n\ndef:pub ItemList() -> JsxElement {\n    # Fetch data\n    data = useItems();\n    items = data["items"] or [];\n\n    # State\n    has input_value: str = "";\n\n    # Handlers\n    def handle_input_change(e: any) -> None {\n        input_value = e.target.value;\n    }\n\n    def handle_add() -> None {\n        if input_value {\n            data["handleAdd"](input_value);\n            input_value = "";\n        }\n    }\n\n    def handle_key_down(e: any) -> None {\n        if e.key == "Enter" {\n            e.preventDefault();\n            handle_add();\n        }\n    }\n\n    # Guard\n    if data["loading"] {\n        return <p className="text-text-secondary text-center py-8">Loading...</p>;\n    }\n\n    # Render\n    return (\n        <div>\n            {data["error"] and (\n                <p className="text-error mb-4">{data["error"]}</p>\n            )}\n            <div className="flex gap-2 mb-6">\n                <input\n                    value={input_value}\n                    onChange={handle_input_change}\n                    onKeyDown={handle_key_down}\n                    placeholder="Add an item..."\n                    className="flex-1 px-4 py-2 border border-border rounded-lg bg-surface"\n                />\n                <button onClick={handle_add}\n                    className="px-4 py-2 bg-primary text-primary-foreground rounded-lg flex items-center gap-1">\n                    + Add\n                </button>\n            </div>\n            {len(items) == 0 and (\n                <p className="text-text-secondary text-center py-8">No items yet. Add one above!</p>\n            )}\n            <div className="space-y-2">\n                {[\n                    <ItemCard key={item["id"]} item={item} on_delete={data["handleDelete"]} />\n                    for item in items\n                ]}\n            </div>\n        </div>\n    );\n}\n';

glob _FULLSTACK_APP = 'import "..styles.global.css";\nimport from .Header { Header }\nimport from .ItemList { ItemList }\n\ndef:pub Layout() -> JsxElement {\n    # State\n    has theme: str = "light";\n\n    # Effects\n    can with (theme) entry {\n        if theme == "dark" {\n            document.documentElement.classList.add("dark");\n        } else {\n            document.documentElement.classList.remove("dark");\n        }\n    }\n\n    # Handlers\n    def handle_toggle_theme() -> None {\n        theme = (theme == "dark") and "light" or "dark";\n    }\n\n    # Render\n    return (\n        <div className="min-h-screen bg-background text-text-primary">\n            <Header title="__NAME__" theme={theme} on_toggle_theme={handle_toggle_theme} />\n            <main className="max-w-2xl mx-auto px-4 py-8">\n                <ItemList />\n            </main>\n        </div>\n    );\n}\n';


glob _FULLSTACK_ITEMCARD = 'def:pub ItemCard(item: dict, on_delete: any) -> JsxElement {\n    # Guard props\n    itemId = item["id"] or "";\n    name = item["name"] or "";\n    description = item["description"] or "";\n\n    # Handlers\n    def handle_delete() -> None {\n        on_delete(itemId);\n    }\n\n    # Render\n    return (\n        <div className="flex items-center justify-between p-3 bg-surface border border-border rounded-lg">\n            <div>\n                <span className="font-medium">{name}</span>\n                {description and (\n                    <p className="text-sm text-text-secondary mt-1">{description}</p>\n                )}\n            </div>\n            <button onClick={handle_delete}\n                className="text-error hover:opacity-75">\n                ×\n            </button>\n        </div>\n    );\n}\n';


# ===========================================================================
# Backend-only scaffold
# ===========================================================================

glob _BACKEND_MAIN = 'import from uuid { uuid4 }\nimport from datetime { datetime }\n\n\nnode Item {\n    has id: str = "";\n    has name: str;\n    has description: str = "";\n    has created_at: str = "";\n\n    def postinit {\n        if not self.id { self.id = str(uuid4()); }\n        if not self.created_at { self.created_at = datetime.now().isoformat(); }\n    }\n}\n\n\ndef:pub get_items() -> list {\n    return [{"id": i.id, "name": i.name, "description": i.description}\n            for i in [root()-->][?:Item];\n}\n\n\ndef:pub add_item(name: str, description: str = "") -> dict {\n    item = (root() ++> Item(name=name, description=description))[0];\n    return {"id": item.id, "name": item.name, "description": item.description};\n}\n\n\ndef:pub delete_item(id: str) -> dict {\n    for item in [root()-->][?:Item] {\n        if item.id == id {\n            root() del--> item;\n            return {"deleted": id};\n        }\n    }\n    return {"error": "not found"};\n}\n';


# ===========================================================================
# AI Agent scaffold
# ===========================================================================

glob _AGENT_MAIN = 'import os;\nimport from dotenv { load_dotenv }\nimport from byllm.lib { Model }\n\nwith entry {\n    load_dotenv(override=True);\n}\n\nglob model_name: str = os.environ.get("MODEL", "gpt-4o");\nglob llm = Model(model_name=model_name);\n';

glob _AGENT_NODES = 'node Router {\n    def classify(message: str, chat_history: list[dict]) -> str\n        by llm(method="Reason", temperature=0.1);\n}\n\n\nnode Handler {\n    def respond(message: str, chat_history: list[dict]) -> str\n        by llm(tools=[], messages=chat_history,\n               max_react_iterations=10, temperature=0.2);\n}\n\n\nwalker:pub interact {\n    has message: str;\n    has session_id: str = "";\n    has chat_history: list[dict] = [];\n\n    obj __specs__ { static has methods: list = ["post"]; }\n\n    can init with Root entry;\n    can route with Router entry;\n    can handle with Handler entry;\n}\n';

glob _AGENT_IMPL = 'sem Router.classify = """Return exactly one label: HANDLE or DONE.\nIf the user needs a response, return HANDLE.\nIf the conversation is complete, return DONE.""";\n\n\nsem Handler.respond = """You are a helpful AI assistant.\nAnswer the user\'s questions clearly and concisely.""";\n\n\nimpl interact.init with Root entry {\n    visit [-->][?:Router] else {\n        router = (here ++> Router())[0];\n        router ++> Handler();\n        visit router;\n    };\n}\n\n\nimpl interact.route with Router entry {\n    label = here.classify(\n        message=self.message,\n        chat_history=self.chat_history\n    ).strip().upper();\n\n    if "DONE" in label {\n        disengage;\n    } else {\n        visit [-->][?:Handler];\n    }\n}\n\n\nimpl interact.handle with Handler entry {\n    response = here.respond(\n        message=self.message,\n        chat_history=self.chat_history\n    );\n    report {"response": response};\n}\n';


# ===========================================================================
# Scaffold functions
# ===========================================================================

def _scaffold_frontend(project_dir: str, name: str) -> list {
    files: list = [];
    _write(project_dir, "jac.toml", _TOML_FRONTEND.replace("__NAME__", name));
    files.append("jac.toml");
    _write(project_dir, "main.jac", _FRONTEND_MAIN);
    files.append("main.jac");
    _write(project_dir, "components/Header.cl.jac", _FRONTEND_HEADER);
    files.append("components/Header.cl.jac");
    _write(project_dir, "components/Counter.cl.jac", _FRONTEND_COUNTER);
    files.append("components/Counter.cl.jac");
    _write(project_dir, "components/Layout.cl.jac", _FRONTEND_APP.replace("__NAME__", name));
    files.append("components/Layout.cl.jac");
    _write(project_dir, "lib/utils.cl.jac", _UTILS_CL);
    files.append("lib/utils.cl.jac");
    _write(project_dir, "styles/global.css", _GLOBAL_CSS);
    files.append("styles/global.css");
    return files;
}


def _scaffold_backend(project_dir: str, name: str) -> list {
    files: list = [];
    _write(project_dir, "jac.toml", _TOML_BACKEND.replace("__NAME__", name));
    files.append("jac.toml");
    _write(project_dir, "main.jac", _BACKEND_MAIN);
    files.append("main.jac");
    return files;
}


def _scaffold_fullstack(project_dir: str, name: str) -> list {
    files: list = [];
    _write(project_dir, "jac.toml", _TOML_FULLSTACK.replace("__NAME__", name));
    files.append("jac.toml");
    _write(project_dir, "main.jac", _FULLSTACK_MAIN);
    files.append("main.jac");
    _write(project_dir, "hooks/useItems.cl.jac", _FULLSTACK_HOOK);
    files.append("hooks/useItems.cl.jac");
    _write(project_dir, "components/Header.cl.jac", _FULLSTACK_HEADER);
    files.append("components/Header.cl.jac");
    _write(project_dir, "components/ItemList.cl.jac", _FULLSTACK_ITEMLIST);
    files.append("components/ItemList.cl.jac");
    _write(project_dir, "components/ItemCard.cl.jac", _FULLSTACK_ITEMCARD);
    files.append("components/ItemCard.cl.jac");
    _write(project_dir, "components/Layout.cl.jac", _FULLSTACK_APP.replace("__NAME__", name));
    files.append("components/Layout.cl.jac");
    _write(project_dir, "lib/utils.cl.jac", _UTILS_CL);
    files.append("lib/utils.cl.jac");
    _write(project_dir, "styles/global.css", _GLOBAL_CSS);
    files.append("styles/global.css");
    return files;
}


def _scaffold_ai_agent(project_dir: str, name: str) -> list {
    files: list = [];
    _write(project_dir, "jac.toml", _TOML_AGENT.replace("__NAME__", name));
    files.append("jac.toml");
    _write(project_dir, "main.jac", _AGENT_MAIN);
    files.append("main.jac");
    _write(project_dir, "nodes.jac", _AGENT_NODES);
    files.append("nodes.jac");
    _write(project_dir, "impl/nodes.impl.jac", _AGENT_IMPL);
    files.append("impl/nodes.impl.jac");
    _write(project_dir, ".env", 'MODEL=gpt-4o\nOPENAI_API_KEY=your-api-key-here\n');
    files.append(".env");
    return files;
}
