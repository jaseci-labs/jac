"""A small wired project the studio tests share, with known answers.

core feeds app and app feeds cli, but one wire runs back from app.views to
core.store and no rule admits it: a backward dependency, a cycle between app
and core, and an E2099 violation. core.log reaches app.api only through a wire
scoped to the serve function, so it loads on demand and not at import time.
core.fmt is used only by app modules, so it looks misplaced in core. The rule
Unused admits nothing.
"""
import from pathlib { Path }

glob SHOP_ARCHWIRE: str = """graph import {
    edge CoreFeedsApp: core.* --> app.* | cli;
    edge AppFeedsCli: app.* --> cli;
    edge Unused: core.* --> tools.*;

    core.util ++> core.models | core.store { slug }
    core.models ++> core.store | app.views { Item, Order }
    core.store ++> app.views | app.api { load, save }
    core.log ++> app.api.serve { log }
    core.fmt ++> app.views | app.api | app.admin { money }
    core.fmt ++> app.views { cents }
    app.views ++> cli { render }
    app.api ++> cli { serve }
    app.views ++> core.store { render }
}
""",
     SHOP_FILES: dict[str, str] = {
         "jac.toml": "[project]\nname = \"shop\"\n",
         "core/util.jac": "def slug(s: str) -> str {\n    return s.lower();\n}\n",
         "core/models.jac": "obj Item {\n    has name: str = \"\";\n\n    def label -> str;\n}\n\nobj Order {\n    has count: int = 0;\n}\n",
         "core/store.jac": "def load -> int {\n    return 0;\n}\n\ndef save(n: int) -> int {\n    return n;\n}\n",
         "core/log.jac": "def log(msg: str) -> str {\n    return msg;\n}\n",
         "core/fmt.jac": "def money(n: int) -> str {\n    return str(n);\n}\n\ndef cents(n: int) -> int {\n    return n * 100;\n}\n",
         "app/views.jac": "def render(n: int) -> str {\n    return str(n);\n}\n",
         "app/api.jac": "def serve -> int {\n    return 1;\n}\n",
         "app/admin.jac": "def panel -> str {\n    return \"admin\";\n}\n",
         "cli.jac": "with entry {\n    print(1);\n}\n"
     };

def make_shop(base: Path) -> Path;

impl make_shop(base: Path) -> Path {
    base.mkdir(parents=True, exist_ok=True);
    (base / "archwire.jac").write_text(SHOP_ARCHWIRE);
    for (rel, text) in SHOP_FILES.items() {
        target = base / rel;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(text);
    }
    return base;
}
