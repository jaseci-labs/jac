"""Browser automation command: `jac browse <action> [args...]`.

Thin registration layer over jaclang.cli.browser_engine, a zero-dependency
driver that controls headless Chrome/Chromium via the Chrome DevTools Protocol.
The engine module holds the WebSocket/CDP implementation and the command logic.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Drive a headless browser over CDP: navigate, interact, snapshot, screenshot."""
@registry.command(
    name="browse",
    help="Headless browser automation over CDP (open, click, snapshot, ...)",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            help="open|navigate|click|type|fill|press|get|eval|snapshot|screenshot|state|sessions|close"
        ),
        Arg.create(
            "args",
            kind=ArgKind.REMAINDER,
            default=[],
            help="Arguments for the action (selector, url, text, path, ...)"
        ),
        Arg.create(
            "session",
            default="default",
            short="s",
            help="Session name; each session is an isolated browser instance"
        ),

    ],
    examples=[
        ("jac browse open example.com", "Launch a browser and navigate"),
        ("jac browse snapshot", "Accessibility tree with @e1/@e2 refs"),
        ("jac browse click @e5", "Click an element by snapshot ref (real input)"),
        ("jac browse fill '#email' you@example.com", "Clear and fill a field"),
        ("jac browse get title", "Read the page title"),
        ("jac browse -s work open example.com", "Use an isolated 'work' session"),
        ("jac browse state save auth.json", "Save cookies + localStorage"),
        ("jac browse close", "Close the browser"),

    ],
    group="tools"
)
def browse(action: str, args: list = [], session: str = "default") -> int;
