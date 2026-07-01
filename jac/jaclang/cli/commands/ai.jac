import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

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

    ],
    group="general"
)
def ai(
    prompt: str = "",
    model: str = "",
    n_ctx: int = 0,
    safe: bool = False,
    quiet: bool = False,
    ui: bool = False
) -> int;
