"""Annex discovery lists a directory once until it changes."""
import os;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.compiler.driver.bccache {
    _DIR_LISTINGS,
    _dir_entries,
    discover_annex_files
}

def _settle(directory: str) {
    old = time.time() - 30;
    os.utime(directory, (old, old));
}

test "a settled directory is listed once and rescanned when it changes" {
    with tempfile.TemporaryDirectory() as directory {
        base = Path(directory) / "mod.jac";
        base.write_text("def f -> int { return 1; }\n");
        (Path(directory) / "mod.impl.jac").write_text("impl f -> int { return 1; }\n");
        _settle(directory);
        first = discover_annex_files(str(base));
        assert [os.path.basename(p) for p in first] == ["mod.impl.jac"];
        assert directory in _DIR_LISTINGS , "a settled listing is kept";
        kept = _dir_entries(directory);
        assert kept is _DIR_LISTINGS[directory][1] , "an unchanged directory serves its listing";
        (Path(directory) / "mod.extra.impl.jac").write_text("");
        _settle(directory);
        second = discover_annex_files(str(base));
        assert sorted(os.path.basename(p) for p in second)
            == ["mod.extra.impl.jac", "mod.impl.jac"] , "a changed directory is rescanned";
    }
}

test "a directory that just changed is not cached" {
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "mod.jac").write_text("");
        _DIR_LISTINGS.pop(directory, None);
        assert _dir_entries(directory) == ["mod.jac"];
        assert directory not in _DIR_LISTINGS , (
            "a listing taken inside the settle window could miss a same-tick entry"
        );
        (Path(directory) / "mod.impl.jac").write_text("");
        assert _dir_entries(directory) == ["mod.impl.jac", "mod.jac"];
    }
}

test "a missing or non-directory path lists nothing" {
    with tempfile.TemporaryDirectory() as directory {
        assert _dir_entries(os.path.join(directory, "absent")) is None;
        file_path = Path(directory) / "file.jac";
        file_path.write_text("");
        assert _dir_entries(str(file_path)) is None;
        assert discover_annex_files(str(file_path)) == [];
    }
}
