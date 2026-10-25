test "code blocks are the jac fences, in order" {
    md = "intro\n\n```jac\nwith entry { print(1); }\n```\n\n```bash\njac run x.jac\n```\n\n```jac\nnode A {}\n```\n";
    assert code_blocks(md) == ["with entry { print(1); }", "node A {}"];
}

test "runnable programs run and server or llm code is only checked" {
    assert block_mode("with entry { print(1); }") == "run";
    assert block_mode("node A {}") == "check";
    assert block_mode("walker:pub w { can go with Root entry {} }\nwith entry {}")
        == "check";
    assert block_mode("def f -> str by llm();\nwith entry { print(f()); }") == "check";
}

test "a correct program passes and a broken one reports why" {
    good = verify_block(
        0,
        "node Item {\n    has label: str = \"one\";\n}\n\nwith entry {\n    print(Item().label);\n}"
    );
    assert good.ok , good.detail;
    assert good.mode == "run";
    bad = verify_block(1, "with entry {\n    print(undefined_name_here);\n}");
    assert not bad.ok;
    assert bad.detail != "";
}

def _sandboxed -> bool;

impl _sandboxed -> bool {
    import shutil;
    import sys;
    return (sys.platform == "darwin" and shutil.which("sandbox-exec") is not None)
        or (sys.platform.startswith("linux") and shutil.which("bwrap") is not None);
}

test "generated code cannot read or write outside its work dir or reach the network" {
    import os;
    import tempfile;
    if os.environ.get(SANDBOX_ENV, "") == "none" {
        return;
    }
    secret = tempfile.NamedTemporaryFile(
        "w", suffix=".txt", prefix="ninjaclaw-secret-", delete=False
    );
    secret.write("TOP-SECRET-VALUE");
    secret.close();
    escape = os.path.join(tempfile.gettempdir(), "ninjaclaw-escape-check.txt");
    try {
        read = verify_block(
            0, 'with entry {\n    print(open("' + secret.name + '").read());\n}'
        );
        wrote = verify_block(
            1,
            'with entry {\n    open("'
                + escape
                + '", "w").write("x");\n    print("wrote");\n}'
        );
        net = verify_block(
            2,
            'import socket;\n\nwith entry {\n    s = socket.create_connection(("1.1.1.1", 80), timeout=5);\n    print("connected");\n}'
        );
        if _sandboxed() {
            assert not read.ok and "TOP-SECRET-VALUE" not in read.detail , read.detail;
            assert not wrote.ok and not os.path.exists(escape) , wrote.detail;
            assert not net.ok , net.detail;
        } else {
            for b in [read, wrote, net] {
                assert not b.ok and "no sandbox is available" in b.detail , b.detail;
            }
        }
    } finally {
        os.unlink(secret.name);
        if os.path.exists(escape) {
            os.unlink(escape);
        }
    }
}

test "the linux sandbox shares nothing writable but the work dir and its cache" {
    import from pathlib { Path }
    work = Path("/tmp/ninjaclaw-w");
    cache = Path("/srv/knowledge/sandbox-cache");
    args = bwrap_args(work, cache);
    assert "--unshare-all" in args and "--die-with-parent" in args;
    binds = [
        args[i + 1]
        for i in range(len(args) - 1)
        if args[i] == "--bind"
    ];
    assert sorted(binds) == sorted([str(cache), str(work)]) , binds;
    assert "/"
        not in [
            args[i + 1]
            for i in range(len(args) - 1)
            if args[i] in ("--bind", "--ro-bind")
        ];
}

test "the macOS profile lets the work dir and cache win over the hidden examples" {
    import from pathlib { Path }
    profile = seatbelt_profile(Path("/w"), Path("/c"));
    lines = profile.splitlines();
    assert lines[1] == "(deny default)";
    assert "network" not in profile;
    assert '(subpath "/w")' in lines[-1] and '(subpath "/c")' in lines[-1];
}

test "blocks past the job's deadline are reported, not run" {
    import time;
    was = WARMED.get("done");
    WARMED["done"] = True;
    try {
        blocks = verify_markdown(
            "```jac\nwith entry {\n    print(1);\n}\n```\n",
            lambda (phase: str, text: str) {},
            time.monotonic() - 1.0
        );
    } finally {
        if was {
            WARMED["done"] = True;
        } else {
            WARMED.pop("done", None);
        }
    }
    assert len(blocks) == 1 and not blocks[0].ok;
    assert "out of time" in blocks[0].detail;
}
