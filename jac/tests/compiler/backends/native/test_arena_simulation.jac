import os;
import re;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR, assert_native_identity }

glob SITE = Path(TESTS_DIR).parent / "examples" / "jaclang_org",
     FIXTURES = Path(TESTS_DIR) / "compiler" / "backends" / "native" / "fixtures";

def arena_fixture(name: str) -> str {
    text = (FIXTURES / (name + ".jac")).read_text();
    found = re.search(r"import from sim \{([^}]*)\}\s*", text);
    assert found , f"{name}.jac does not import from sim";
    names = ", ".join(
        sorted(
            [
                n.strip()
                for n in found.group(1).split(",")
                if n.strip()
            ]
        )
    );
    with tempfile.TemporaryDirectory() as tmp {
        shutil.copytree(
            str(SITE), tmp, ignore=shutil.ignore_patterns(".jac"), dirs_exist_ok=True
        );
        fixture = os.path.join(tmp, "core", "site", "game", name + ".jac");
        with open(fixture, "w") as f {
            f.write(text[:found.start()] + text[found.end():]);
        }
        with open(os.path.join(tmp, "arch.jac"), "a") as f {
            f.write(
                "\nimpl import core.site.game {\n    sim --> core.site.game."
                    + name
                    + " { "
                    + names
                    + " }\n}\n"
            );
        }
        with open(os.path.join(tmp, "jac.toml"), "a") as f {
            f.write(
                "\n[apps."
                    + name
                    + "]\nkind = \"native-binary\"\nentry-point = \"core.site.game."
                    + name
                    + "\"\n\n[apps."
                    + name
                    + ".check.lint]\nignore = [\"no-print\"]\n"
            );
        }
        return assert_native_identity(fixture);
    }
}

test "arena replay preserves the original simulation across memory profiles" {
    assert arena_fixture("arena_replay")
        == (
            "0 0 100000 621189187\n"
            "0 0 82000 1158027131\n"
            "2 0 61883 332907100\n"
            "2 0 16883 1958242580\n"
            "2 0 12433 1715220132\n"
            "2 0 27483 1923114171\n"
        );
}

test "arena jump pools and event generations agree across backends" {
    assert arena_fixture("arena_checks") == "arena checks passed\n";
}
