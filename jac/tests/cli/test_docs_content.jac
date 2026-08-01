"""Content-level tests for the bundled documentation corpus.

The corpus at jaclang/cli/docs is the single source for the docs site and
`jac guide`. With no site generator in the loop, these tests carry the
guarantees the old mkdocs strict build provided: every file is real
markdown, internal links (including #anchors) resolve, and the docs do not
describe features the CLI no longer ships.
"""

import os;
import re;
import unicodedata;
import from pathlib { Path }
import from jaclang.cli.guide_store { docs_dir }
import from jaclang.cli.registry { get_registry }
import jaclang.cli.commands.execution;

"""Retrieve all Markdown files in the bundled corpus."""
def get_md_files -> list[str] {
    return [str(f) for f in sorted(docs_dir().rglob("*.md"))];
}

"""The docs that describe how jac behaves *today*.

Release notes and the breaking-changes log are excluded: their job is to
record what a release shipped and what a later release took away, so naming
a removed flag is the point rather than a mistake.
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

"""Slug for a heading, matching how the docs' anchors were authored."""
def slugify(text: str) -> str {
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text);
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode(
        "ascii"
    );
    text = re.sub(r"[^\w\s-]", "", text).strip().lower();
    return re.sub(r"[-\s]+", "-", text);
}

"""Anchors a page defines: heading slugs plus explicit {#id} overrides."""
def collect_anchors(text: str) -> set[str] {
    anchors: set[str] = set();
    fenced = False;
    for line in text.splitlines() {
        if line.strip().startswith("```") {
            fenced = not fenced;
            continue;
        }
        if fenced or not line.startswith("#") {
            continue;
        }
        m = re.match(r"^#{1,6}\s+(.*?)\s*$", line);
        if not m {
            continue;
        }
        heading = m.group(1) as str;
        custom = re.search(r"\{:?\s*#([^\s}]+)[^}]*\}\s*$", heading);
        if custom {
            anchors.add(custom.group(1) as str);
            continue;
        }
        anchors.add(slugify(heading));
    }
    return anchors;
}

"""(target, anchor) pairs for every inline markdown link in the text."""
def collect_links(text: str) -> list[tuple[str, str]] {
    links: list[tuple[str, str]] = [];
    fenced = False;
    for line in text.splitlines() {
        if line.strip().startswith("```") {
            fenced = not fenced;
            continue;
        }
        if fenced {
            continue;
        }
        line = re.sub(r"`[^`]*`", "", line);
        for m in re.finditer(r"\]\(([^)]+)\)", line) {
            inner = (m.group(1) as str).strip();
            if inner.startswith("<") and inner.endswith(">") {
                inner = inner[1:-1];
            }
            inner = inner.split(" ")[0];
            if inner.startswith(("http://", "https://", "mailto:")) {
                continue;
            }
            if "#" in inner {
                (target, anchor) = inner.split("#", 1);
            } else {
                (target, anchor) = (inner, "");
            }
            links.append((target, anchor));
        }
    }
    return links;
}

test "all markdown files are valid" {
    md_files = get_md_files();
    assert len(md_files) > 0 , "No markdown files found in the corpus";

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

test "internal links and anchors resolve within the corpus" {
    corpus_root = docs_dir().resolve();
    pages: dict[str, str] = {};
    for md_file in get_md_files() {
        with open(md_file, encoding="utf-8") as f {
            pages[md_file] = f.read();
        }
    }
    anchors = {path: collect_anchors(text) for (path, text) in pages.items()};

    broken: list[str] = [];
    for (path, text) in pages.items() {
        base = Path(path).parent;
        for (target, anchor) in collect_links(text) {
            if not target {
                dest = Path(path);
            } else {
                dest = (base / target).resolve();
                if corpus_root not in dest.parents {
                    broken.append(f"{path}: link escapes the corpus: {target}");
                    continue;
                }
                if not dest.is_file() {
                    broken.append(f"{path}: broken link: {target}");
                    continue;
                }
            }
            if anchor and str(dest) in anchors {
                known = anchors[str(dest)];
                bare = re.sub(r"_\d+$", "", anchor);
                if anchor not in known and bare not in known {
                    broken.append(f"{path}: broken anchor: {target or ''}#{anchor}");
                }
            }
        }
    }
    assert not broken , "corpus link check failed:\n" + "\n".join(broken);
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
        "docs reference an image-build pipeline that no longer exists:\n"
        + "\n".join(stale)
    );
}
