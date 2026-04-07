import fnmatch;

obj PermissionRule {
    has tool: str = "*",
        pattern: str = "*",
        action: str = "ask";  # "allow" | "deny" | "ask"
}

obj PermissionEngine {
    has rules: list = [],
        always_allowed: dict = {};

    def init_defaults() -> None;
    def check(tool_id: str, resource: str = "") -> str;
    def remember_allow(tool_id: str, pattern: str = "*") -> None;
    def enable_web_mode() -> None;
}

glob permission_engine: PermissionEngine = PermissionEngine();
