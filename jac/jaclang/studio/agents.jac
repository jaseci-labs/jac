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
