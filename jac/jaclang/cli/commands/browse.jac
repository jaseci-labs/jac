import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="browse",
    hidden=True,
    help="Headless browser automation over CDP (open, click, snapshot, ...)",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            help="open|navigate|click|type|fill|press|get|eval|wait|scroll|console|snapshot|screenshot|state|sessions|close"
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
        Arg.create(
            "viewport",
            default="1280x720",
            help="Browser window size as WIDTHxHEIGHT (applied at open)"
        ),

    ],
    examples=[
        ("jac browse open example.com", "Launch a browser and navigate"),
        ("jac browse snapshot", "Accessibility tree with @e1/@e2 refs"),
        ("jac browse click @e5", "Click an element by snapshot ref (real input)"),
        ("jac browse fill '#email' you@example.com", "Clear and fill a field"),
        ("jac browse get title", "Read the page title"),
        ("jac browse wait '#app'", "Wait until a selector is actionable"),
        ("jac browse console", "Read buffered console/log output"),
        ("jac browse scroll down", "Scroll the page by ~one viewport"),
        ("jac browse -s work open example.com", "Use an isolated 'work' session"),
        ("jac browse state save auth.json", "Save cookies + localStorage"),
        ("jac browse close", "Close the browser"),

    ],
    group="tools"
)
def browse(
    action: str, args: list = [], session: str = "default", viewport: str = "1280x720"
) -> int;
