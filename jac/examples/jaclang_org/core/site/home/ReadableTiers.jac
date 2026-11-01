glob _ARCH_LINES: list[str] = [
         "graph import {",
         "    edge AppOverCore: core.* --> cli | desktop | mobile.* | pages.* | web;",
         "    edge CoreInternal: core.* --> core.*;",
         "",
         "    core.install ++> web;",
         "    core.site.home.Home ++> pages.index { Home }",
         "    core.social_graph ++> cli { create_tweet, load_feed }",
         "}",

     ],
     _DECL_LINES: list[str] = [
         "glob API_ROOT: str = \"https://api.github.com/repos/\";",
         "",
         "def headers(agent: str, accept_json: bool = True) -> dict[str, str];",
         "",
         "def fetch(",
         "    url: str, agent: str, accept_json: bool = False, timeout: int = 10",
         ") -> bytes | None;",
         "",
         "def:protect parse_repo_url(url: str) -> tuple[str, str] | None;",

     ],
     _IMPL_LINES: list[str] = [
         "impl headers(agent: str, accept_json: bool = True) -> dict[str, str] {",
         "    h: dict[str, str] = {\"User-Agent\": agent};",
         "    if accept_json {",
         "        h[\"Accept\"] = \"application/vnd.github+json\";",
         "    }",
         "    tok = os.environ.get(\"GITHUB_TOKEN\", \"\");",
         "    if tok {",
         "        h[\"Authorization\"] = \"Bearer \" + tok;",
         "    }",
         "    return h;",
         "}",

     ],
     _SCOPES: list[dict[str, str]] = [
         {
             "tier": "1",
             "name": "Wiring",
             "scope": "one file for the whole project",
             "width": "14%"
         },
         {
             "tier": "2",
             "name": "Declarations",
             "scope": "every module's types and signatures",
             "width": "46%"
         },
         {
             "tier": "3",
             "name": "Implementations",
             "scope": "every body",
             "width": "100%"
         },

     ];

def:pub ScopeBars -> JsxElement;

def:pub CheckLink(text: str) -> JsxElement;

def:pub TierRow(
    tier: str, name: str, question: str, file: str, when: str, lines: list[str]
) -> JsxElement;

def:pub ReadableTiers -> JsxElement;
