glob VERB_BUDGET: int = 28,
     TOMBSTONED_VERBS: dict[str, str] = {
         "add": "jac install <pkg>",
         "format": "jac fmt",
         "lint": "jac check --lint",
         "deps": "jac install --plan",
         "script": "jac x <name>",
         "jacpack": "jac create --pack <dir>",
         "enter": "jac run --entry <name> <file>",
         "debug": "jac run --debug <file>",
         "bundle": "jac build [--as jab|sealed|binary|wheel|npm]",
         "eject": "jac build --as source",
         "js": "jac tool jac2js <file>",
         "jac2py": "jac tool jac2py <file>",
         "py2jac": "jac tool py2jac <file>",
         "jac2js": "jac tool jac2js <file>",
         "grammar": "jac tool grammar",
         "destroy": "jac scale destroy <file.jac>",
         "status": "jac scale status <file.jac>"
     },
     GROUP_DISPLAY: dict[str, str] = {
         "execution": "Program Execution",
         "analysis": "Code Analysis",
         "transform": "Code Transformation",
         "project": "Project Management",
         "tools": "Development Tools",
         "config": "Configuration",
         "build": "Build",
         "db": "Database",
         "microservices": "Microservices",
         "general": "General"
     },
     GROUP_ORDER: list[str] = [
         "execution",
         "analysis",
         "transform",
         "project",
         "tools",
         "config",
         "build",
         "db",
         "microservices",
         "general"
     ],
     TIER_SECTIONS: dict[str, str] = {
         "core": "Common commands",
         "learn": "Learn & build with AI"
     },
     TIER_ORDER: list[str] = ["core", "learn"];

obj CommandMeta {
    has name: str,
        help: str,
        group: str,
        tier: str,
        hidden: bool,
        handler_module: str,
        handler_name: str,
        needs: list[str] = [];
}

def validate_manifest -> list[str];
def get_command_meta(name: str) -> CommandMeta | None;
def iter_command_meta(include_hidden: bool = False) -> list[CommandMeta];
def known_command_names(include_hidden: bool = False) -> set[str];
def get_groups -> list[str];
