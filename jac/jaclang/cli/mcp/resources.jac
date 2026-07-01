import from pathlib { Path }

def find_repo_root -> str | None;

obj ResourceProvider {
    has _resources: dict = {},
        _repo_root: str | None = None,
        _package_dir: str = "";

    def index_resources -> None;
    def _index_grammar -> None;
    def _index_bundled -> None;
    def _index_shared_guides -> None;
    def list_resources -> list[dict[str, str]];
    def read_resource(uri: str) -> str;
    def _read_example(uri: str) -> str;
    def _index_examples_local(examples_dir: Path) -> None;
    def _fetch_github_categories -> list[str];
}
