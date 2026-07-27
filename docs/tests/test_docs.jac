"""Unit tests for documentation build infrastructure."""

import os;

import from pathlib { Path }
import from jaclang.cli.registry { get_registry }
import jaclang.cli.commands.execution;

"""Retrieve all Markdown files in the docs directory."""
def get_md_files -> list[str] {
    docs_dir = Path(os.path.dirname(__file__)).parent / "docs";
    return [str(f) for f in sorted(docs_dir.rglob("*.md"))];
}

"""The docs that describe how jac behaves *today*.

Release notes and the breaking-changes log are excluded: their job is to record
what a release shipped and what a later release took away, so naming a removed
flag is the point rather than a mistake.
"""
def get_current_md_files -> list[str] {
    return [
        f
        for f in get_md_files()
        if "release_notes" not in Path(f).parts
        and Path(f).name != "breaking-changes.md"
    ];
}

"""Every flag `jac start` actually accepts, as it would be spelled in the docs."""
def start_flags -> set[str] {
    spec = get_registry().get("start");
    assert spec is not None , "the 'start' command is not registered";
    flags: set[str] = set();
    for arg in spec.get_all_args() {
        flags.add(f"--{arg.name}");
    }
    return flags;
}

test "all markdown files are valid" {
    md_files = get_md_files();
    assert len(md_files) > 0 , "No markdown files found in docs directory";

    for md_file in md_files {
        assert os.path.exists(md_file) , f"File not found: {md_file}";

        file_size = os.path.getsize(md_file);
        assert file_size > 0 , f"Empty file: {md_file}";

        try {
            with open(md_file, encoding="utf-8") as f {
                content = f.read().strip();
                assert content , f"No content: {md_file}";
                non_empty_lines = [
                    line
                    for line in content.splitlines()
                    if line.strip()
                ];
                assert non_empty_lines , f"Only whitespace: {md_file}";
            }
        } except UnicodeDecodeError {
            assert False , f"Encoding issue: {md_file}";
        } except PermissionError {
            assert False , f"Permission denied: {md_file}";
        }
    }
}

test "docs do not describe the removed image-build pipeline" {
    # The Docker image-build pipeline (build, registry push, and local-cluster
    # image loading) was deleted; the copy-source "no-image" path is the only
    # one that ships. Docs kept advertising the removed surface, sending people
    # after a --build flag, config keys, and modules that are not in the tree.
    assert "--build" not in start_flags() , "jac start grew a --build flag; drop it from `removed` below";
    removed = [
        "--build",
        "_cluster_detect",
        "_image_build",
        "image_registry",
        "docker_image_name",
        "kind load",
        "k3d image import",
        "minikube docker-env",
        "minikube image load"
    ];

    stale: list[str] = [];
    for md_file in get_current_md_files() {
        with open(md_file, encoding="utf-8") as f {
            lines = f.read().splitlines();
        }
        for (idx, line) in enumerate(lines) {
            for token in removed {
                if token in line {
                    stale.append(f"{md_file}:{idx + 1}: {token}");
                }
            }
        }
    }

    assert not stale , (
        "docs reference an image-build pipeline that no longer exists:\n" + "\n".join(
            stale
        )
    );
}
