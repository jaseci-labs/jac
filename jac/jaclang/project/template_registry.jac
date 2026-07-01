import from typing { Callable }
import from pathlib { Path }

obj ProjectTemplate {
    has name: str,
        description: str,
        config: dict[str, any],
        files: dict[str, str],
        kind: str = "cli",
        is_default_for_kind: bool = True,
        directories: list[str] = [],
        root_gitignore_entries: list[str] = [],
        post_create: Callable | None = None;

    def to_dict -> dict[str, any];
}

obj TemplateRegistry {
    has _templates: dict[str, ProjectTemplate] = {};

    def register(template_info: dict[str, any]) -> None;
    def get(name: str) -> ProjectTemplate | None;
    def get_by_kind(kind: str) -> ProjectTemplate | None;
    def get_default -> ProjectTemplate;
    def list_templates -> list[tuple[str, str]];
    def list_kinds -> list[tuple[str, str]];
    def has_template(name: str) -> bool;
    def is_empty -> bool;
    def clear -> None;
}

glob _registry: TemplateRegistry | None = None;

def get_template_registry -> TemplateRegistry;

def initialize_template_registry -> None;
