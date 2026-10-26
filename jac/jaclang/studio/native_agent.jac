import os;
import re;
import fnmatch;
import logging;
import signal;
import subprocess;
import threading;
import time;
import importlib.util;

glob TOOL_KINDS: dict[str, str] = {
         "read_file": "read",
         "list_dir": "read",
         "search": "search",
         "write_file": "edit",
         "run_command": "execute",
         "find_symbol": "search",
         "symbol_context": "read",
         "symbol_uses": "search",
         "archwire": "search",
         "architecture": "search",
         "insight": "search"
     },
     NOISY_LOGGERS: list[str] = ["LiteLLM", "litellm", "byllm", "httpx", "openai"],
     MAX_TOOL_OUTPUT: int = 20000,
     SIGKILL: int = 9,
     DEFAULT_MODEL: str = "gpt-4o-mini",
     TURN_DOC: str = "Carry out the user's request on this Jac project, then answer in concise markdown.",
     SYSTEM_PROMPT: str = """You are the built-in coding agent of jac hack, working inside a Jac project.
Read code with the tools before you answer; do not guess. Paths are relative to the project root.
Prefer the compiler-aware tools: find_symbol to locate a symbol, symbol_context for its declaration,
impl body and wiring, symbol_uses for its uses, archwire for a module's providers, consumers and rules,
architecture for a package's sub-packages, the wires between them and the cycles among them,
insight for roles, interfaces, rule use, slices, blast radius, clusters, a tour, or the diff since main.
In Jac, imports between project modules are wires in archwire.jac, not import lines in the file.
To change a file, call write_file with the complete new content; the user approves every write and may
reject it with a reason. Keep answers short and concrete.""";

obj NativeAgentSession(AgentSession) {
    has model_name: str = "",
        llm: any = None,
        project_model: any = None,
        history: list[any] = [],
        max_iterations: int = 30,
        command_timeout: float = 120.0,
        auto_approve_commands: bool = False,
        code_intel: any = None,
        _thought: str = "",
        _cancel: bool = False,
        _gen: int = 0,
        _turn: any = None,
        _procs: list[any] = [],
        _calls: dict[str, str] = {};

    override def start(cwd: str, mcp_servers: list[dict[str, any]]) -> None;
    override def prompt(blocks: list[dict[str, any]]) -> None;
    override def cancel -> None;
    override def stop -> None;
    def resolve_llm -> any;
    def quiet_logging -> None;
    def _run_turn(blocks: list[dict[str, any]], gen: int) -> None;
    def _forward(ev: any, gen: int) -> None;
    def _emit_if(gen: int, kind: str, data: dict[str, any]) -> None;
    def _finish(gen: int, reason: str) -> None;
    def make_tools(gen: int = -1) -> list[any];
    def _live(gen: int) -> bool;
    def model -> any;
    def intel -> any;
    def rel(path: str) -> str;
    def inside(path: str) -> bool;
    def t_read_file(path: str, start_line: int, max_lines: int) -> str;
    def t_list_dir(path: str) -> str;
    def t_search(pattern: str, path: str, file_glob: str, max_results: int) -> str;
    def t_write_file(path: str, content: str, gen: int = -1) -> str;
    def t_run_command(command: str, timeout_sec: int, gen: int = -1) -> str;
    def t_find_symbol(query: str, kind: str) -> str;
    def t_symbol_context(key: str) -> str;
    def t_symbol_uses(name: str) -> str;
    def t_archwire(module: str) -> str;
    def t_architecture(scope: str) -> str;
    def t_insight(view: str, key: str) -> str;
}

def friendly_error(e: Exception, model_name: str) -> str;

def tool_title(tool: str, args: any) -> str;

def tool_locations(args: any, root_dir: str) -> list[dict[str, any]];
