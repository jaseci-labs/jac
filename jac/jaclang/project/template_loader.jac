import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.project.template_registry { ProjectTemplate, template_kind_for }

def load_template_from_directory(
    template_dir: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate;

def bundle_template(template_dir: Path, output_path: Path) -> None;

def load_template_from_json(
    json_path: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate;

def resolve_post_create_hook(hook_path: str) -> Callable | None;

def scaffold_app(
    project_root: str, name: str, kind: str, path: str, template: ProjectTemplate
) -> list[str];

def template_app_table(template: ProjectTemplate) -> dict[str, any];

def migrate_implicit_app(lines: list[str], base: JacConfig) -> str;

def _append_overlay_tables(
    lines: list[str], parts: tuple[str, ...], table: dict[str, any]
) -> None;
