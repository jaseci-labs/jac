import os;
import from pathlib { Path }

glob DOCS_DIR: str = "jac/jaclang/cli/docs",
     GUIDES_DIR: str = "jac/jaclang/cli/skills",
     EXAMPLES_DIR: str = "jac/examples",
     SKIP_EXAMPLES: list[str] = ["jac/examples/jaclang_org/"],
     READ_LIMIT: int = 12000,
     TOOLBOX: dict[str, any] = {};

def agent_catalog(repo_root: Path) -> list[IndexDoc];

def open_toolbox(repo_root: Path, catalog: list[IndexDoc], note: Callable) -> None;

def _toolbox_note(text: str) -> None;

def _repo_path(doc: IndexDoc) -> str;

def search_jac(query: str) -> list[str];

def read_jac_file(path: str) -> str;

def read_jac_guide(name: str) -> str;

def list_jac_guides -> list[str];

sem search_jac = "Search the official Jac documentation, the jac guide skills and the example projects in the jac repository. Returns up to 6 hits, each as 'path: title: excerpt'.";
sem search_jac.query = "What to look for, in a few words.";
sem read_jac_file = "Read one file from the jac repository: a docs page, a guide or an example. Use a path from search_jac, without the #anchor.";
sem read_jac_file.path = "The repository path, for example jac/jaclang/cli/docs/reference/language/walkers.md.";
sem read_jac_guide = "Read a jac guide skill by name, for example jac-has-fields. Guides are curated, version-matched Jac coding guidance.";
sem read_jac_guide.name = "The guide name from list_jac_guides.";
sem list_jac_guides = "List the names of the jac guide skills bundled with this release.";
