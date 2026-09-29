"""The compiler-input rule has two implementations; this holds them to one answer.

`scripts/ci_cache_keys.sh` selects compiler inputs in awk because it runs at
checkout time, before any jac binary exists (the same acyclicity constraint that
keeps the Zig seeds out of the Jac tooling, #8785). `jir.compiler_source_files`
selects them by walking the tree. The two cannot share code, so a drift between
them is only catchable here: if the awk filters stop matching the walk's, CI
cache keys quietly stop tracking compiler identity and every lane starts serving
artifacts from a compiler that is not the one under test.
"""

import subprocess;
import from pathlib { Path }

glob REPO: Path = Path(str(__file__)).resolve().parent.parent.parent.parent;

def _jaclang_tree_is_clean -> bool {
    probe = subprocess.run(
        ["git", "status", "--porcelain", "--", "jac/jaclang"],
        cwd=str(REPO),
        capture_output=True,
        text=True
    );
    return probe.returncode == 0 and not probe.stdout.strip();
}

test "ci_cache_keys.sh selects the same compiler inputs as the compiler does" {
    import from jaclang.compiler.driver.jir { compiler_source_files }
    if not _jaclang_tree_is_clean() {
        # The shell rule reads `git ls-tree HEAD`, so an edited or untracked
        # file under jac/jaclang makes it legitimately disagree with the
        # on-disk walk. CI always runs this against a clean checkout.
        return;
    }
    listed = subprocess.run(
        ["bash", str(REPO / "scripts" / "ci_cache_keys.sh"), "--list-compiler-inputs"],
        cwd=str(REPO),
        capture_output=True,
        text=True
    );
    assert listed.returncode == 0 , listed.stderr;
    shell = set(listed.stdout.split());
    walked = set(compiler_source_files(str(REPO / "jac" / "jaclang")));
    assert shell == walked , (
        "compiler-input rule drift: "
        f"only in ci_cache_keys.sh {sorted(shell - walked)[:5]}, "
        f"only in compiler_source_files {sorted(walked - shell)[:5]}"
    );
}
