"""Exercise the release workflow's actual matrix planner without GitHub access."""

import json;
import os;
import re;
import subprocess;
import tempfile;
import textwrap;
import from pathlib { Path }

test "stable and dev matrices build one official binary per platform" {
    repo_root = Path(__file__).resolve().parents[3];
    workflow = (repo_root / ".github/workflows/build-binaries.yml").read_text();
    step = workflow.split("      - name: Select build legs for the channel\n", 1)[1];
    script = textwrap.dedent(
        re.split(
            r"\n  [a-z][a-z-]*:\n", step.split("        run: |\n", 1)[1], maxsplit=1
        )[0]
    );
    for channel in ["release", "dev"] {
        for (only, tag, count, success) in [
            ("", "v0.37.1", 3, True),
            ("macos-x86_64", "v0.37.1", 1, True),
            ("linux-x86_64", "", 1, True),
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
                    assert "runtime" not in leg and "asset_platform" not in leg;
                    if not leg.get("manual") and not leg.get("optional") {
                        required.append(leg["platform"]);
                    }
                }
                assert len(set(leg["platform"] for leg in legs)) == count;
                assert values["required"].split() == required;
                assert json.loads(values["platforms"])
                    == [leg["platform"] for leg in legs];
            }
        }
    }
}
