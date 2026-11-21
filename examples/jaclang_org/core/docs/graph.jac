import os;
import re;

glob SITE_ORIGIN: str = os.environ.get("JAC_SITE_ORIGIN", "https://www.jaclang.org"),
     INDEX_FILES: list[str] = ["index.md", "SKILL.md"];

node PublicNode {}

edge PublicEdge: PublicNode --> PublicNode {}

node DocsHub(PublicNode) {
    has built_at: str = "";
}

"""What holds pages: a version, and each section in it."""
node DocContainer(PublicNode) {}

"""One version of the docs. It holds nav.json's tree: its sections, nested as
nav.json nests them, and the pages directly in it, all in nav.json's order (the
order of the version's Contains edges and each section's)."""
node DocVersion(DocContainer) {
    has label: str = "",
        version: str = "",
        fetched_at: str = "",
        fingerprint: str = "",
        pages: int = 0;

    def tree -> list[TreeNode];
    def reading_order -> list[DocPage];
}

"""A section of nav.json, holding its pages and the sections nested in it."""
node DocSection(DocContainer) {
    has title: str = "";
}

"""A page, served at its `path`: its file's path in the docs tree without
".md", and without the file's name for a directory's own page."""
node DocPage(PublicNode) {
    has path: str = "",
        title: str = "",
        description: str = "",
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];
}

edge HasHub(PublicEdge): Node --> DocsHub {}

edge HasVersion(PublicEdge): DocsHub --> DocVersion {}

edge Contains(PublicEdge): DocContainer --> DocSection | DocPage {}

edge NextPage(PublicEdge): DocPage --> DocPage {}

"""The titles of the sections a page is in, outermost first: what it gathers
climbing the Contains edges from the page to its version."""
walker trace_sections {
    has titles: list[str] = [];

    can leave_page with DocPage entry;
    can climb with DocSection entry;
}

def sections_of(page: DocPage) -> list[str];

def _teardown_version(v: DocVersion);

def _teardown_hub(hub: DocsHub);

def _sweep_stale(keep: DocsHub);

def _series_of(label: str) -> tuple[int, int] | None;

def _latest_label(labels: list[str]) -> str;

def _version(wanted: str) -> list[DocVersion];

def slugify(t: str) -> str;

def _pretty(name: str) -> str;

def toc_of(text: str) -> list[TocEntry];

"""The name a page has in the graph: its file's stem, or "index" for the files
that are their directory's own page (a skill's SKILL.md is its directory's)."""
def page_name(file: str) -> str;

"""The path a page is served at below its version, from its file's path in the
docs tree: `language/walkers` for language/walkers.md, `start` for
start/index.md, `skills/x` for skills/x/SKILL.md."""
def page_path(rel: str) -> str;

def route_of(version: str, rel: str) -> str;

def rewrite_href(href: str, version: str, cur_dir: str) -> str;

def _get_hub -> DocsHub | None;

def _version_list -> list[VersionInfo];

"""Place a page in a version: down the sections of its `trail`, by title,
making each one it does not find."""
walker place_page {
    has trail: list[str] = [],
        path: str = "",
        title: str = "",
        description: str = "",
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];

    can place with DocContainer entry;
}

"""Fold a version into the sidebar's tree and its reading order, post-order:
each page and section folds itself on exit, once everything below it has."""
walker collect_tree {
    has folded: dict[str, TreeNode] = {},
        folded_seq: dict[str, list[DocPage]] = {},
        tree: list[TreeNode] = [],
        seq: list[DocPage] = [];

    can scan with DocContainer entry;
    can fold_page with DocPage exit;
    can fold_section with DocSection exit;
    can fold_version with DocVersion exit;
    def gather(container: DocContainer) -> tuple[list[TreeNode], list[DocPage]];
}

def:pub docs_status -> DocsStatus;

def:pub doc_tree(version: str = "latest") -> DocTree | None;

"""llms.txt's lines for the tree `nodes` inside the sections `trail`: the
pages directly here under a heading of the trail's titles, then each nested
section under its own."""
def _llms_sections(
    nodes: list[TreeNode], trail: list[str], by_path: dict[str, DocPage], lines: list[str]
);

def _llms_entry(pg: TreeNode, by_path: dict[str, DocPage]) -> str;

def _first_prose(md_lines: list[str]) -> str;

glob LLMS_HEADER: str = ("# jac\n"
    "\n"
    "> jac is a native-first implementation of the Jac language. Its"
    " compiler is written in Jac and compiles itself, and it compiles a Jac"
    " program, with jac's own runtime, into one native executable through"
    " LLVM. One download carries everything a build needs: the compiler, the"
    " runtime, and CPython, Node, Clang and Rust, which run under the"
    " `jac` command too.\n"
    "\n"
    "jac defines the Jac language it compiles. It is not jaseci's `jac`"
    " with another backend: some forms `jac` accepts are errors here, so read"
    " the language pages rather than assuming what `jac` or Python does.\n"
    "\n"
    "Offline access: the same pages ship with every release and"
    " `jac docs` prints them, for exactly the version installed:"
    " `jac docs <word>` looks up a keyword, a grammar rule, a diagnostic"
    " code or a command, and `jac docs search <text>` searches every page."
    " `jac skills` lists playbooks for tasks, and `jac skills <name>`"
    " prints one.\n");

@restspec(method=HTTPMethod.GET, path="/llms.txt", produces="text/plain", envelope=False)
def:pub llms_txt -> str;

"""The page whose path's segments are `asked`, below a version, or, when no page
has that path, the nearest one: the first, in reading order, of those whose
paths share the most leading segments with it (`reach` of them). It walks the
version depth-first, which is reading order."""
walker find_page {
    has asked: list[str] = [],
        page: DocPage | None = None,
        reach: int = -1;

    can enter with DocContainer entry;
    can weigh with DocPage entry;
}

walker:pub doc_page {
    has version: str = "latest",
        path: str = "",
        missing: bool = False,
        reports: list[DocPageView | None] = [];

    can start with Root entry;
    can find with DocVersion entry;
    can deliver with DocPage entry;
}
