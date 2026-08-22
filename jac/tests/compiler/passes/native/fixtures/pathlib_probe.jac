import os;
import from pathlib { Path }

obj Holder {
    has where: Path = Path("");
}

def show(p: Path) {
    print(f"{p}|{p.name}|{p.stem}|{p.parent}");
}

with entry {
    with open("/tmp/jac_pathlib_probe.txt", "w") as f {
        f.write("hello");
    }
    _ = os.system("mkdir -p /tmp/jac_pathlib_probe_dir/sub");
    _ = os.system("ln -sfn /tmp/jac_pathlib_probe_dir /tmp/jac_pathlib_probe_link");

    show(Path(""));
    show(Path("."));
    show(Path("/"));
    show(Path("//"));
    show(Path("///"));
    show(Path("a"));
    show(Path("a/b"));
    show(Path("a//b"));
    show(Path("./a"));
    show(Path("a/"));
    show(Path("/a/b/"));
    show(Path("a/../b"));
    show(Path(".."));
    show(Path("a/./b"));
    show(Path("/a"));
    show(Path("a/b.txt"));
    show(Path("a/.bashrc"));
    show(Path("a/b.tar.gz"));
    show(Path("a/b."));
    show(Path("a/."));
    show(Path("x.y/z"));

    print(str(Path("a") / "b"));
    print(str(Path("a") / "/b"));
    print(str(Path("") / "b"));
    print(str(Path("/") / "b"));
    print(str(Path("a") / ""));
    print(str(Path("a") / "b/c"));
    print(str(Path("/tmp") / "jac_pathlib_probe.txt"));

    print(Path("/tmp/jac_pathlib_probe.txt").exists());
    print(Path("/tmp/jac_pathlib_probe_dir").exists());
    print(Path("/tmp/jac_pathlib_missing_zz").exists());
    print(Path("/tmp/jac_pathlib_probe.txt").is_dir());
    print(Path("/tmp/jac_pathlib_probe_dir").is_dir());
    print(Path("/tmp/jac_pathlib_missing_zz").is_dir());

    print(str(Path("/tmp/./jac_pathlib_probe_dir/../jac_pathlib_probe.txt").resolve()));
    print(str(Path("/tmp/jac_pathlib_probe_link/sub").resolve()));
    print(str(Path("/tmp/jac_pathlib_probe_dir/sub/..").resolve()));

    if Path("a/b") {
        print("truthy-nonempty");
    }
    if Path("") {
        print("truthy-empty");
    }

    h = Holder();
    print(f"holder={h.where}");
    h.where = Path("/tmp") / "jac_pathlib_probe_dir";
    print(f"holder={h.where}|{h.where.name}");
    print(h.where.is_dir());
    print(str(Path(str(h.where.parent))));
    print(str(Path(Path("a//b/c"))));
    print(str(Path(Path("/tmp")) / "x"));
}
