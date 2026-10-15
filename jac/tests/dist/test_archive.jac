import io;
import os;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.archive { extract_tar_gz, tar_gz_dir }
import from jaclang.packages.artifact { pack_source_tree }

test "archives retain empty directories and directory links without duplicate members" {
    with tempfile.TemporaryDirectory() as directory {
        base = Path(directory);
        source = base / "source";
        (source / "data" / "empty").mkdir(parents=True);
        (source / "data" / "value.txt").write_text("value", encoding="utf-8");
        (source / "alias").symlink_to("data", target_is_directory=True);
        data = tar_gz_dir(source);
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive {
            names = archive.getnames();
            assert sorted(names) == ["alias", "data", "data/empty", "data/value.txt"];
            assert archive.getmember("data/empty").isdir();
            assert archive.getmember("alias").issym();
            assert archive.getmember("alias").linkname == "data";
        }
        restored = base / "restored";
        extract_tar_gz(data, restored);
        assert (restored / "data" / "empty").is_dir();
        assert (restored / "alias").is_symlink();
        assert (restored / "alias" / "value.txt").read_text(encoding="utf-8")
            == "value";
    }
}

test "archive metadata remains deterministic for directories and files" {
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory);
        (source / "empty").mkdir();
        (source / "value.txt").write_text("value", encoding="utf-8");
        first = tar_gz_dir(source);
        os.utime(source / "empty", (1000000000, 1000000000));
        os.utime(source / "value.txt", (1000000000, 1000000000));
        assert tar_gz_dir(source) == first;
        with tarfile.open(fileobj=io.BytesIO(first), mode="r:gz") as archive {
            for member in archive.getmembers() {
                assert member.mtime == 0 and member.uid == 0 and member.gid == 0;
                assert member.uname == "" and member.gname == "";
            }
        }
    }
}

test "source packages retain empty output directories after staging and extraction" {
    with tempfile.TemporaryDirectory() as directory {
        base = Path(directory);
        source = base / "source";
        (source / "output").mkdir(parents=True);
        (source / "jac.toml").write_text(
            '[project]\nname = "acme/example"\nversion = "1.0.0"\n', encoding="utf-8"
        );
        restored = base / "restored";
        extract_tar_gz(pack_source_tree(source), restored);
        (restored / "output" / "result.txt").write_text("ready", encoding="utf-8");
        assert (restored / "output" / "result.txt").read_text(encoding="utf-8")
            == "ready";
    }
}
