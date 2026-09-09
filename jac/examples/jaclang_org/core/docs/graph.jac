import os;
import re;
import from http { HTTPMethod }

obj TocEntry {
    has level: int = 2,
        text: str = "",
        anchor: str = "";
}

obj Crumb {
    has title: str = "",
        path: str = "";
}

obj PageRef {
    has title: str = "",
        path: str = "";
}

obj TreeNode {
    has kind: str = "page",
        name: str = "",
        title: str = "",
        path: str = "",
        order: int = 9000,
        children: list[TreeNode] = [];
}

obj VersionInfo {
    has label: str = "",
        jac_version: str = "",
        pages: int = 0,
        fetched_at: str = "";
}

obj DocsStatus {
    has ready: bool = False,
        built_at: str = "",
        latest_label: str = "",
        versions: list[VersionInfo] = [];
}

obj DocTree {
    has version: str = "",
        tree: list[TreeNode] = [];
}

obj DocPageView {
    has version: str = "",
        path: str = "",
        title: str = "",
        md_lines: list[str] = [],
        toc: list[TocEntry] = [],
        crumbs: list[Crumb] = [],
        missing: bool = False,
        prev_page: PageRef | None = None,
        next_page: PageRef | None = None;
}

glob SITE_ORIGIN: str = os.environ.get(
         "JAC_SITE_ORIGIN", "https://www.jaclang.org"
     ),
     DIR_TITLES: dict[str, str] = {
         "js": "JS",
         "cli": "CLI",
         "osp": "OSP",
         "api": "API",
         "quick-guide": "Quick Guide"
     };

node PublicNode {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}

edge PublicEdge {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}

node DocsHub(PublicNode) {
    has built_at: str = "";
}

node DocContainer(PublicNode) {}

node DocVersion(DocContainer) {
    has label: str = "",
        jac_version: str = "",
        fetched_at: str = "",
        fingerprint: str = "",
        pages: int = 0;

    def tree -> list[TreeNode];
    def reading_order -> list[DocPage];
}

node DocDir(DocContainer) {
    has name: str = "",
        title: str = "",
        order: int = 9000;
}

node DocPage(PublicNode) {
    has name: str = "",
        title: str = "",
        order: int = 9000,
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];
}

edge HasHub(PublicEdge) {}

edge HasVersion(PublicEdge) {}

edge Contains(PublicEdge) {}

edge NextPage(PublicEdge) {}

walker trace_route {
    has segs: list[str] = [];

    can name_page with DocPage entry;
    can climb_dir with DocDir entry;
    can arrive with DocVersion entry {}
}

def _route_up(target: object) -> str;

def _teardown_version(v: DocVersion);

def _teardown_hub(hub: DocsHub);

def _sweep_stale(keep: DocsHub);

def _series_of(label: str) -> tuple[int, int] | None;

def _latest_label(labels: list[str]) -> str;

def _version(wanted: str) -> list[DocVersion] {
    all_vers = [root.shared-->[?:DocsHub]->:HasVersion:->[?:DocVersion]];
    if wanted == "latest" {
        lab = _latest_label([v.label for v in all_vers]);
        if lab != "" {
            wanted = lab;
        }
    }
    vers = [
        v
        for v in all_vers
        if v.label == wanted
    ];
    if not vers {
        return [];
    }
    best = vers[0];
    for v in vers {
        if v.fetched_at > best.fetched_at {
            best = v;
        }
    }
    return [best];
}

def slugify(t: str) -> str;

def _pretty(name: str) -> str;

def toc_of(text: str) -> list[TocEntry];

def route_of(version: str, rel: str) -> str;

def rewrite_href(href: str, version: str, cur_dir: str) -> str;

def _get_hub -> DocsHub | None;

def _version_list -> list[VersionInfo];

walker place_page {
    has segs: list[str] = [],
        name: str = "",
        title: str = "",
        order: int = 9000,
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];

    can place with DocContainer entry;
}

walker collect_tree {
    has folded: dict[str, TreeNode] = {},
        folded_seq: dict[str, list[DocPage]] = {},
        tree: list[TreeNode] = [],
        seq: list[DocPage] = [];

    can scan with DocContainer entry {
        visit [-->[?:DocDir]];
    }

    can fold_version with DocVersion exit {
        (self.tree, self.seq) = self.fold_children(here);
    }

    can fold_dir with DocDir exit;
    def fold_children(container: object) -> tuple[list[TreeNode], list[DocPage]];
}

def:pub docs_status -> DocsStatus {
    hub = _get_hub();
    if hub is None {
        return DocsStatus();
    }
    infos = _version_list();
    return DocsStatus(
        ready=True,
        built_at=hub.built_at,
        latest_label=_latest_label([v.label for v in infos]),
        versions=infos
    );
}

def:pub doc_tree(version: str = "latest") -> DocTree | None;

def _flatten_tree_pages(nodes: list[TreeNode]) -> list[TreeNode];

def _first_prose(md_lines: list[str]) -> str;

glob LLMS_HEADER: str = (
         "# Jac (the Jaseci stack)\n"
         "\n"
         "> Jac is a programming language designed for humans and AI to build"
         " together. It compiles one Python-like syntax to Python bytecode,"
         " JavaScript, and native machine code, with full access to the PyPI,"
         " npm, and C ecosystems. AI calls (`by llm()`), persistent graphs, REST"
         " APIs, React-style UIs (`cl` code), and Kubernetes deployment are"
         " language features delivered through one self-contained `jac` binary.\n"
         "\n"
         "Key facts: statements end with `;`, blocks use `{ }`, fields are"
         " declared with `has name: type;`, `node`/`edge`/`walker` archetypes"
         " model domains as graphs, the graph under `root` persists"
         " automatically, and `def f(...) -> T by llm();` delegates a function"
         " to an LLM with the return type as the enforced output schema.\n"
         "\n"
         "Offline access: `jac guide` (bundled with the jac binary) serves this"
         " entire documentation set from the command line, and the `jac mcp`"
         " server exposes it to agents as jac://docs/* resources.\n"
     );

@restspec(
    method=HTTPMethod.GET, path="/llms.txt", produces="text/plain", envelope=False
)
def:pub llms_txt -> str;

walker:pub doc_page {
    has version: str = "latest",
        path: str = "",
        segs: list[str] = [],
        route: list[str] = [],
        crumbs: list[Crumb] = [],
        missing: bool = False;

    can start with Root entry;
    can descend with DocContainer entry;
    can note_dir with DocDir entry;
    can deliver with DocPage entry;
    def settle(container: object);
}
