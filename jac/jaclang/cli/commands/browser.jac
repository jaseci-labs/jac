"""Browser automation command: `jac browser <action> [args...]`.

Thin registration layer over jaclang.cli.browser_engine, a zero-dependency
driver that controls headless Chrome/Chromium via the Chrome DevTools Protocol.
The engine module holds the WebSocket/CDP implementation and the command logic.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Drive a headless browser over CDP: navigate, interact, snapshot, screenshot."""
@registry.command(
    name="browser",
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
        ("jac browser open example.com", "Launch a browser and navigate"),
        ("jac browser snapshot", "Accessibility tree with @e1/@e2 refs"),
        ("jac browser click @e5", "Click an element by snapshot ref (real input)"),
        ("jac browser fill '#email' you@example.com", "Clear and fill a field"),
        ("jac browser get title", "Read the page title"),
        ("jac browser -s work open example.com", "Use an isolated 'work' session"),
        ("jac browser state save auth.json", "Save cookies + localStorage"),
        ("jac browser close", "Close the browser"),

    ],
    group="tools"
)
def browser(action: str, args: list = [], session: str = "default") -> int;
