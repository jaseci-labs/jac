import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, HookContext }
import from jaclang.jac0core.runtime { hookimpl }

glob registry = get_registry(),
     _PENDING_THEME: dict = {};

class JacShadcnPlugin {
    @hookimpl
    static def create_cmd -> None;

    @hookimpl
    static def register_project_template -> dict[str, any] | None;
}

def _handle_shadcn_add(ctx: HookContext) -> None;

def _handle_shadcn_remove(ctx: HookContext) -> None;

def _handle_create_theme(ctx: HookContext) -> None;

def _shadcn_post_create(project_path: any, project_name: str) -> None;

def _build_shadcn_template_info -> dict[str, any] | None;

@registry.command(
    name="retheme",
    help="Re-theme a jac-shadcn project: regenerate global.css from [jac-shadcn]",
    args=[
        Arg.create(
            "style", typ=str, default=None, help="Component style preset", short=""
        ),
        Arg.create(
            "baseColor", typ=str, default=None, help="Base neutral palette", short=""
        ),
        Arg.create("theme", typ=str, default=None, help="Accent color theme", short=""),
        Arg.create("font", typ=str, default=None, help="Font family", short=""),
        Arg.create(
            "radius", typ=str, default=None, help="Border radius preset", short=""
        ),
        Arg.create(
            "menuAccent",
            typ=str,
            default=None,
            help="Menu accent (subtle|bold)",
            short=""
        ),
        Arg.create(
            "menuColor", typ=str, default=None, help="Menu color scheme", short=""
        )
    ],
    examples=[
        ("jac retheme", "Regenerate global.css from the current [jac-shadcn] config"),
        ("jac retheme --theme rose --font inter", "Switch accent + font in place"),
        ("jac retheme --style mira", "Switch style and re-resolve installed components")
    ],
    group="project",
    source="jac-shadcn"
)
def retheme(
    style: str | None = None,
    baseColor: str | None = None,
    theme: str | None = None,
    font: str | None = None,
    radius: str | None = None,
    menuAccent: str | None = None,
    menuColor: str | None = None
) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jaclang.cli.shadcn.theme_handler { retheme_project }

    config = get_config();
    overrides: dict = {
        "style": style,
        "baseColor": baseColor,
        "theme": theme,
        "font": font,
        "radius": radius,
        "menuAccent": menuAccent,
        "menuColor": menuColor
    };
    try {
        return 0 if retheme_project(config, overrides) else 1;
    } except Exception as e {
        console.error("Retheme failed: " + str(e));
        return 1;
    }
}
