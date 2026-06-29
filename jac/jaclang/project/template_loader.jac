import from typing { Callable }
import from pathlib { Path }
import from jaclang.project.template_registry { ProjectTemplate }

def load_template_from_directory(
    template_dir: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate;

def bundle_template(template_dir: Path, output_path: Path) -> None;

def load_template_from_json(
    json_path: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate;

def resolve_post_create_hook(hook_path: str) -> Callable | None;
