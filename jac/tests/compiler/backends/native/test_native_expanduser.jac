"""Native home expansion matches POSIX Python for each supported import form."""
import os;
import pwd;
import subprocess;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from tests.support { jac_command }

test "native expanduser handles HOME and account lookups across import forms" {
    user = pwd.getpwuid(os.getuid()).pw_name;
    inputs = [
        "",
        "relative/~",
        "/tmp/~",
        "~",
        "~/",
        "~//x",
        "~/a/../b",
        "~" + user,
        "~" + user + "/a",
        "~jac_no_such_user_3c27c4f6/x"
    ];
    forms = [
        ("import os;", "os.path.expanduser"),
        ("import os as system;", "system.path.expanduser"),
        ("import os.path as paths;", "paths.expanduser"),
        ("import from os.path { expanduser }", "expanduser"),
        ("import from os.path { expanduser as expand }", "expand")
    ];
    with tempfile.TemporaryDirectory() as directory {
        for index in range(len(forms)) {
            (imports, call) = forms[index];
            source = Path(directory) / ("home" + str(index) + ".jac");
            source.write_text(
                imports
                    + "\nwith entry {\n"
                    + "\n".join(
                        [
                            "print(" + call + "(" + repr(value) + "));"
                            for value in inputs
                        ]
                    )
                    + "\n}\n"
            );
            binary = str(Path(directory) / ("home" + str(index)));
            build = subprocess.run(
                jac_command("build", "--native", str(source), "-o", binary),
                capture_output=True,
                text=True,
                timeout=900
            );
            assert build.returncode == 0 , build.stdout + build.stderr;
            for home in [
                None,
                "",
                "/",
                "///",
                "/tmp/jac home///",
                "relative/home",
                "/tmp/ünicode"
            ] {
                env = dict(os.environ);
                if home is None {
                    env.pop("HOME", None);
                } else {
                    env["HOME"] = home;
                }
                with patch.dict(os.environ, env, clear=True) {
                    expected = "\n".join(
                        [os.path.expanduser(value) for value in inputs]
                    )
                        + "\n";
                }
                ran = subprocess.run(
                    [binary], env=env, capture_output=True, text=True, timeout=30
                );
                assert ran.returncode == 0 , ran.stdout + ran.stderr;
                assert ran.stdout == expected , (imports, home, ran.stdout, expected);
            }
        }
    }
}

"""The floor reports the home directory's full length when the caller's buffer
is too small, and user_home, started on a buffer shorter than the path, calls
again with one that fits instead of reporting the account missing."""
test "the floor's home lookup reports the full length to a short buffer" {
    record = pwd.getpwuid(os.getuid());
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "home_len.jac";
        source.write_text(
            "import from c { def __jac_home_dir(name: str, buffer: bytes, size: int) -> int;  }\n"
                + "import from _user_home { user_home }\n"
                + "with entry {\n"
                + "    print(__jac_home_dir(\"\", b\"\\x00\", 1));\n"
                + f"    print(__jac_home_dir({record.pw_name!r}, b\"\\x00\", 1));\n"
                + "    print(__jac_home_dir(\"jac_no_such_user_3c27c4f6\", b\"\\x00\", 1));\n"
                + "    print(user_home(\"\", 2));\n"
                + f"    print(user_home({record.pw_name!r}, 2));\n"
                + "}\n"
        );
        binary = str(Path(directory) / "home_len");
        build = subprocess.run(
            jac_command("build", "--native", str(source), "-o", binary),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert build.returncode == 0 , build.stdout + build.stderr;
        run = subprocess.run([binary], capture_output=True, text=True, timeout=60);
        assert run.returncode == 0 , run.stdout + run.stderr;
        want = str(len(record.pw_dir.encode("utf-8")));
        assert run.stdout.splitlines()
            == [want, want, "-1", record.pw_dir, record.pw_dir] , run.stdout;
    }
}
