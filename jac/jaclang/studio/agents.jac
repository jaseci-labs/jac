import os;
import glob as globmod;
import shutil;
import importlib.util;
import tomllib;

glob BUILTIN_AGENT: str = "jac",
     USER_CONFIG_ENV: str = "JAC_HACK_CONFIG",
     CLAUDE_EXE_ENV: str = "CLAUDE_CODE_EXECUTABLE";

obj AgentSpec {
    has name: str,
        title: str = "",
        command: str = "",
        args: list[str] = [],
        env: dict[str, str] = {},
        kind: str = "acp",
        source: str = "builtin",
        description: str = "";

    def resolved -> str;
    def argv -> list[str];
    def runnable -> bool;
    def reason -> str;
    def to_dict -> dict[str, any];
}

obj AgentRegistry {
    has root_dir: str,
        agents: dict[str, AgentSpec] = {},
        config: dict[str, any] = {},
        default_agent: str = "",
        model: str = "";

    def postinit;
    def _merge(table: dict[str, any], source: str) -> None;
    def names -> list[str];
    def get(name: str) -> (AgentSpec | None);
    def available -> list[str];
    def default_name -> str;
    def describe -> list[dict[str, any]];
    def create_session(
        name: str = "",
        project_model: any = None,
        load_session_id: str = "",
        write_gate: any = None,
        read_hook: any = None
    ) -> AgentSession;
}

def builtin_agents -> dict[str, AgentSpec];

def load_studio_config(root_dir: str) -> dict[str, any];

def read_studio_table(path: str) -> dict[str, any];

def user_config_path -> str;

def find_claude_executable -> str;

def claude_env -> dict[str, str];

impl AgentSpec.resolved -> str {
    if self.kind != "acp" {
        return "";
    }
    if not self.command {
        return "";
    }
    if os.sep in self.command {
        path = os.path.expanduser(self.command);
        return path if os.access(path, os.X_OK) else "";
    }
    return shutil.which(self.command) or "";
}

impl AgentSpec.argv -> list[str] {
    exe = self.resolved() or self.command;
    return [exe, *[str(a) for a in self.args]];
}

impl AgentSpec.runnable -> bool {
    if self.kind == "builtin" {
        return importlib.util.find_spec("litellm") is not None;
    }
    return bool(self.resolved());
}

impl AgentSpec.reason -> str {
    if self.kind == "builtin" {
        if importlib.util.find_spec("litellm") is None {
            return "byllm's model client is not installed; add [byllm] to jac.toml and run `jac install`";
        }
        return "";
    }
    if not self.command {
        return "no command configured";
    }
    if not self.resolved() {
        return f"`{self.command}` not found on PATH";
    }
    return "";
}

impl AgentSpec.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "title": self.title or self.name,
        "kind": self.kind,
        "command": self.command,
        "args": self.args,
        "env": sorted(self.env.keys()),
        "source": self.source,
        "description": self.description,
        "runnable": self.runnable(),
        "path": self.resolved(),
        "reason": self.reason()
    };
}

impl AgentRegistry.postinit {
    self.root_dir = os.path.realpath(self.root_dir);
    self.agents = builtin_agents();
    self.config = load_studio_config(self.root_dir);
    user = read_studio_table(user_config_path());
    proj = read_studio_table(os.path.join(self.root_dir, "jac.toml"));
    self._merge(user, "user");
    self._merge(proj, "project");
    self.default_agent = str(
        proj.get("default_agent") or user.get("default_agent") or ""
    );
    self.model = str(proj.get("model") or user.get("model") or "");
}

impl AgentRegistry._merge(table: dict[str, any], source: str) -> None {
    entries = table.get("agents") or {};
    if not isinstance(entries, dict) {
        return;
    }
    for (name, raw) in entries.items() {
        if not isinstance(raw, dict) {
            continue;
        }
        base = self.agents.get(name);
        cmd = raw.get("command");
        args = raw.get("args");
        if isinstance(cmd, list) and cmd {
            args = [*[str(c) for c in cmd[1:]], *(args or [])];
            cmd = str(cmd[0]);
        }
        if cmd is not None and args is None {
            args = [];
        }
        env = dict(base.env) if base is not None else {};
        for (k, v) in (raw.get("env") or {}).items() {
            env[str(k)] = str(v);
        }
        kind = str(
            raw.get("kind") or ("acp" if cmd is not None or base is None else base.kind)
        );
        self.agents[name] = AgentSpec(
            name=name,
            title=str(raw.get("title") or (base.title if base is not None else name)),
            command=str(cmd if cmd is not None else (base.command if base else "")),
            args=[str(a) for a in args]
                if args is not None
                else (list(base.args) if base is not None else []),
            env=env,
            kind=kind,
            source=source,
            description=str(
                raw.get("description") or (base.description if base is not None else "")
            )
        );
    }
}

impl AgentRegistry.names -> list[str] {
    return list(self.agents.keys());
}

impl AgentRegistry.get(name: str) -> (AgentSpec | None) {
    return self.agents.get(name);
}

impl AgentRegistry.available -> list[str] {
    return [
        n
        for (n, a) in self.agents.items()
        if a.runnable()
    ];
}

impl AgentRegistry.default_name -> str {
    configured = self.default_agent;
    if configured
        and configured in self.agents
        and self.agents[configured].runnable() {
        return configured;
    }
    claude = self.agents.get("claude");
    if claude is not None and claude.runnable() {
        return "claude";
    }
    return BUILTIN_AGENT;
}

impl AgentRegistry.describe -> list[dict[str, any]] {
    dflt = self.default_name();
    rows: list[dict[str, any]] = [];
    for a in self.agents.values() {
        d = a.to_dict();
        d["default"] = a.name == dflt;
        if a.kind == "builtin" {
            d["model"] = self.model
                or os.environ.get("BYLLM_DEFAULT_MODEL", "")
                or "byllm default";
        }
        rows.append(d);
    }
    return rows;
}

impl AgentRegistry.create_session(
    name: str = "",
    project_model: any = None,
    load_session_id: str = "",
    write_gate: any = None,
    read_hook: any = None
) -> AgentSession {
    name = name or self.default_name();
    spec = self.agents.get(name);
    if spec is None {
        raise KeyError(
            f"unknown agent '{name}'; known agents: {', '.join(self.names())}"
        );
    }
    if not spec.runnable() {
        raise RuntimeError(f"agent '{name}' cannot run: {spec.reason()}");
    }
    sess: AgentSession;
    if spec.kind == "builtin" {
        sess = NativeAgentSession(
            name=name,
            root_dir=self.root_dir,
            model_name=self.model,
            project_model=project_model
        );
    } else {
        env = dict(spec.env);
        if name == "claude" or "claude-code-acp" in " ".join(spec.args) {
            for (k, v) in claude_env().items() {
                env.setdefault(k, v);
            }
        }
        sess = AcpSession(
            name=name,
            root_dir=self.root_dir,
            command=spec.argv(),
            env=env,
            load_session_id=load_session_id
        );
    }
    sess.write_gate = write_gate;
    sess.read_hook = read_hook;
    return sess;
}

impl builtin_agents -> dict[str, AgentSpec] {
    return {
        "claude": AgentSpec(
            name="claude",
            title="Claude Code",
            command="npx",
            args=["-y", "@zed-industries/claude-code-acp"],
            description="Claude Code through its ACP adapter"
        ),
        "gemini": AgentSpec(
            name="gemini",
            title="Gemini CLI",
            command="gemini",
            args=["--experimental-acp"],
            description="Gemini CLI in ACP mode"
        ),
        "codex": AgentSpec(
            name="codex",
            title="Codex",
            command="npx",
            args=["-y", "@zed-industries/codex-acp"],
            description="OpenAI Codex through its ACP adapter"
        ),
        BUILTIN_AGENT: AgentSpec(
            name=BUILTIN_AGENT,
            title="Jac (byllm)",
            kind="builtin",
            description="The built-in byllm agent with compiler-aware tools"
        )
    };
}

impl load_studio_config(root_dir: str) -> dict[str, any] {
    merged: dict[str, any] = {};
    for path in [user_config_path(), os.path.join(root_dir, "jac.toml")] {
        table = read_studio_table(path);
        for (k, v) in table.items() {
            if k == "agents" and isinstance(v, dict) {
                agents = dict(merged.get("agents") or {});
                agents.update(v);
                merged["agents"] = agents;
            } else {
                merged[k] = v;
            }
        }
    }
    return merged;
}

impl read_studio_table(path: str) -> dict[str, any] {
    if not path or not os.path.isfile(path) {
        return {};
    }
    try {
        with open(path, "rb") as f {
            data = tomllib.load(f);
        }
    } except (OSError, tomllib.TOMLDecodeError) {
        return {};
    }
    table = data.get("hack") or {};
    return table if isinstance(table, dict) else {};
}

impl user_config_path -> str {
    cfg_path = os.environ.get(USER_CONFIG_ENV, "");
    if cfg_path {
        return os.path.expanduser(cfg_path);
    }
    return os.path.join(os.path.expanduser("~"), ".jac", "hack.toml");
}

impl find_claude_executable -> str {
    on_path = shutil.which("claude");
    if on_path {
        return on_path;
    }
    pattern = os.path.join(
        os.path.expanduser("~"),
        ".vscode",
        "extensions",
        "anthropic.claude-code-*",
        "resources",
        "native-binary",
        "claude"
    );
    found = [
        p
        for p in globmod.glob(pattern)
        if os.access(p, os.X_OK)
    ];
    if not found {
        return "";
    }
    def ver_key(p: str) -> list[int] {
        ext = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(p))));
        ver = ext.split("anthropic.claude-code-", 1)[-1].split("-", 1)[0];
        out: list[int] = [];
        for part in ver.split(".") {
            out.append(int(part) if part.isdigit() else 0);
        }
        return out;
    }
    found.sort(key=ver_key);
    return found[-1];
}

impl claude_env -> dict[str, str] {
    if os.environ.get(CLAUDE_EXE_ENV) {
        return {};
    }
    exe = find_claude_executable();
    return {CLAUDE_EXE_ENV: exe} if exe else {};
}
