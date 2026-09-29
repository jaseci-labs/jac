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
