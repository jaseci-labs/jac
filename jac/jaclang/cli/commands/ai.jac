"""AI command: launch an interactive Jac coding agent in the terminal.

`jac ai` starts a coding agent -- a byLLM ReAct loop wired to file and guide
tools -- that reads, writes, and debugs Jac code in the current project. It is
grounded in the bundled Jac reference guides (the same ones `jac guide` shows),
so the agent self-serves the authoritative spec for idiomatic Jac.

The agent works with any byLLM-compatible model -- local llama.cpp builds or
cloud providers (OpenAI, Anthropic, Gemini, ...). Pick one with `--model`, or
set `[plugins.byllm.model] default_model` in jac.toml; with neither it falls
back to the bundled `local:gemma-4-e4b` so it runs with no API key. Cloud
models read credentials from `[plugins.byllm.model]` in jac.toml (or the usual
provider env vars). byLLM must be installed -- the command reports how to
install it when it is missing.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Launch an interactive Jac coding agent powered by a byLLM model."""
@registry.command(
    name="ai",
    help="Launch an interactive Jac coding agent",
    args=[
        Arg.create(
            "prompt",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Optional one-shot request; omit for an interactive session"
        ),
        Arg.create(
            "model",
            default="",
            help="Model to use, e.g. local:gemma-4-e4b or openai/gpt-4o",
            short="m"
        ),
        Arg.create(
            "n_ctx",
            typ=int,
            default=0,
            help="Context-window size for local models (tokens)"
        ),
        Arg.create(
            "safe",
            kind=ArgKind.FLAG,
            typ=bool,
            default=False,
            help="Confirm every file write and code execution (off by default)"
        ),
        Arg.create(
            "quiet",
            kind=ArgKind.FLAG,
            typ=bool,
            default=False,
            help="Compact output: hide live reasoning, timings, and step detail",
            short="q"
        ),
        Arg.create(
            "ui",
            kind=ArgKind.FLAG,
            typ=bool,
            default=False,
            help="Open the agent in a web UI with a live phase-graph visualizer"
        ),
        Arg.create(
            "tui",
            kind=ArgKind.FLAG,
            typ=bool,
            default=False,
            help="Open the agent in a terminal UI (`--ui` and `--tui` are exclusive)"
        ),
        Arg.create(
            "resume", default="", help="Resume a session by its id (e.g. a3f1c902)"
        ),
        Arg.create(
            "continue",
            kind=ArgKind.FLAG,
            typ=bool,
            default=False,
            help="Resume this project's most recent session",
            short="c",
            dest="continue_last"
        ),
        Arg.create(
            "session",
            default="",
            help="Open or create a named session for this project",
            short=""
            # No short: -s is already taken by --safe (auto-generated). The
            # long form is the only documented usage, so opt out of the
            # first-char auto-short to avoid an argparse conflict.
        ),

    ],
    examples=[
        ("jac ai", "Start a session (uses jac.toml's model, else local default)"),
        ("jac ai \"add a walker to main.jac\"", "Run a single request and exit"),
        ("jac ai -m openai/gpt-4o", "Use a cloud model (key from jac.toml or env)"),
        ("jac ai -m local:gemma-4-e2b", "Use a smaller/faster local model"),
        ("jac ai --n_ctx 32768", "Give the local model a larger context window"),
        ("jac ai --safe", "Approve each file write and command before it runs"),
        (
            "jac ai -q \"fix the build\"",
            "Compact output -- just tool calls and the answer"
        ),
        ("jac ai --ui", "Open a web UI with a live agent phase-graph visualizer"),
        ("jac ai --tui", "Open an in-terminal TUI session"),
        ("jac ai -c", "Resume this project's most recent session"),
        ("jac ai --resume a3f1c902", "Resume a specific session by id"),
        ("jac ai --session refactor", "Open or create a named session"),

    ],
    group="general"
)
def ai(
    prompt: str = "",
    model: str = "",
    n_ctx: int = 0,
    safe: bool = False,
    quiet: bool = False,
    ui: bool = False,
    tui: bool = False,
    resume: str = "",
    continue_last: bool = False,
    session_name: str = ""
) -> int;
