import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR, assert_native_identity }

def arena_fixture(name: str) -> str {
    game = Path(TESTS_DIR).parent
        / "examples"
        / "jaclang_org"
        / "core"
        / "site"
        / "game";
    with tempfile.TemporaryDirectory() as tmp {
        shutil.copytree(str(game), tmp, dirs_exist_ok=True);
        fixture = os.path.join(tmp, name + ".jac");
        shutil.copyfile(
            os.path.join(
                TESTS_DIR, "compiler", "backends", "native", "fixtures", name + ".jac"
            ),
            fixture
        );
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
