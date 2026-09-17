"""Exercise the release workflow's actual matrix planner without GitHub access."""

import json;
import os;
import subprocess;
import tempfile;
import textwrap;
import from pathlib { Path }

test "stable and dev matrices require both runtime variants" {
    repo_root = Path(__file__).resolve().parents[3];
    workflow = (repo_root / ".github/workflows/build-binaries.yml").read_text();
    step = workflow.split("      - name: Select build legs for the channel\n", 1)[1];
    script = textwrap.dedent(
        step.split("        run: |\n", 1)[1].split("\n  build:", 1)[0]
    );
    for channel in ["release", "dev"] {
        for (only, tag, count, success) in [
            ("", "v0.37.1", 6, True),
            ("macos-x86_64", "v0.37.1", 2, True),
            ("linux-x86_64", "", 2, True),
            ("linux-x86_64", "v0.37.1", 0, False),
            ("typo", "", 0, False)
        ] {
            with tempfile.TemporaryDirectory() as tmp {
                output = Path(tmp) / "output";
                env = dict(os.environ);
                env.update(
                    {
                        "CHANNEL": channel,
                        "ONLY": only,
                        "TAG": tag,
                        "GITHUB_OUTPUT": str(output)
                    }
                );
                res = subprocess.run(
                    ["bash", "-c", script], env=env, capture_output=True, text=True
                );
                assert (res.returncode == 0) == success , res.stdout + res.stderr;
                if not success {
                    continue;
                }
                values = dict(
                    line.split("=", 1) for line in output.read_text().splitlines()
                );
                legs = json.loads(values["include"]);
                assert len(legs) == count;
                required = [];
                for leg in legs {
                    native = leg["runtime"] == "jacpython";
                    assert leg["jacpython"] == ("1" if native else "0");
                    assert leg["asset_platform"]
                        == leg["platform"] + ("-jacpython" if native else "");
                    if not leg.get("manual") and not leg.get("optional") {
                        required.append(leg["asset_platform"]);
                    }
                }
                assert set(leg["runtime"] for leg in legs) == {"cpython", "jacpython"};
                assert len(set(leg["asset_platform"] for leg in legs)) == count;
                assert values["required"].split() == required;
            }
        }
    }
}
