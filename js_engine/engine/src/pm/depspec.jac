"""Dependency specifiers, classified like bun's `Dependency.Version.Tag.infer`
and parsed like `Dependency.parseWithTag`.

  "^1.2.3", ">=1 <2", "1.x", "*", ""        → npm range (empty = dist-tag latest)
  "latest", "next", "beta"                  → dist-tag
  "npm:react@^18" / "npm:@scope/x@1"        → npm alias (real name + range/tag)
  "workspace:*" / "workspace:packages/a"    → workspace
  "file:../x", "./x", "../x", "/abs"        → folder (or tarball when it ends in .tgz/.tar.gz/.tar)
  "link:../x"                               → symlink
  "https://…", "http://…"                   → tarball (github URLs → github)
  "git+…", "git://", "github:u/r", "u/r"    → git / github
  "catalog:" / "catalog:name"               → catalog

Behavior flags mirror bun's packed struct (bit1 prod, bit2 optional, bit3 dev,
bit4 peer, bit5 workspace, bit6 bundled) so the sort order can be ported 1:1.
"""

import from engine.src.pm.semver { SemGroup, semver_parse_range }

glob:pub SPEC_NPM: int = 1,
     SPEC_DIST_TAG: int = 2,
     SPEC_WORKSPACE: int = 3,
     SPEC_FOLDER: int = 4,
     SPEC_SYMLINK: int = 5,
     SPEC_TARBALL: int = 6,
     SPEC_GIT: int = 7,
     SPEC_GITHUB: int = 8,
     SPEC_CATALOG: int = 9,
     BEH_PROD: int = 2,
     BEH_OPTIONAL: int = 4,
     BEH_DEV: int = 8,
     BEH_PEER: int = 16,
     BEH_WORKSPACE: int = 32,
     BEH_BUNDLED: int = 64;

obj:pub DepSpec {
    has tag: int = 1,
        literal: str = "",
        name: str = "",
        is_alias: bool = False,
        range: SemGroup = SemGroup(),
        dist_tag: str = "",
        path: str = "",
        owner: str = "",
        repo: str = "",
        committish: str = "";
}

# as written
# real package name (alias target for npm:)

# workspace / folder / symlink / tarball / git payload
# github: owner
# github: repo (".git" stripped); git: the URL without "git+" and "#ref"
# git / github: the ref after '#'
def _last_index(s: str, ch: str) -> int {
    i: int = len(s) - 1;
    while i >= 0 {
        if s[i] == ch {
            return i;
        }
        i = i - 1;
    }
    return -1;
}

"""owner / repo / ref of any GitHub form: `owner/repo#ref`, `github:owner/repo`,
`git+https://github.com/owner/repo.git#ref`, `https://github.com/owner/repo`,
`git@github.com:owner/repo.git`, `git://github.com/owner/repo`."""
def _github_parts(dep: str) -> tuple[str, str, str] {
    s: str = dep;
    if s.startswith("github:") {
        s = s[7:];
    } elif s.startswith("git+") {
        s = s[4:];
    }
    for prefix in [
        "https://github.com/",
        "http://github.com/",
        "git://github.com/",
        "ssh://git@github.com/",
        "git@github.com:",
        "github.com/"
    ] {
        if s.startswith(prefix) {
            s = s[len(prefix):];
            break;
        }
    }
    committish: str = "";
    h: int = _last_index(s, "#");
    if h >= 0 {
        committish = s[h + 1:];
        s = s[0:h];
    }
    if s.endswith(".git") {
        s = s[0:len(s) - 4];
    }
    if s.endswith("/") {
        s = s[0:len(s) - 1];
    }
    slash: int = s.find("/");
    if slash < 0 {
        return ("", s, committish);
    }
    return (s[0:slash], s[slash + 1:], committish);
}

def _is_tarball(s: str) -> bool {
    return s.endswith(".tgz") or s.endswith(".tar.gz") or s.endswith(".tar");
}

"""GitHub shorthand `user/repo[#ref]`: two path segments, no scheme/space."""
def _is_github_shorthand(s: str) -> bool {
    if s == "" or s.find("://") >= 0 or s.find(" ") >= 0 {
        return False;
    }
    body: str = s;
    hash_i: int = body.find("#");
    if hash_i >= 0 {
        body = body[0:hash_i];
    }
    parts: list[str] = body.split("/");
    if len(parts) != 2 {
        return False;
    }
    if parts[0] == "" or parts[1] == "" {
        return False;
    }
    if parts[0].startswith(".") or parts[1].startswith(".") {
        return False;
    }
    if parts[0].startswith("@") {
        return False;
    }
    return True;
}

"""bun's Tag.infer."""
def:pub depspec_infer(dep: str) -> int {
    if dep == "" {
        return SPEC_DIST_TAG;
    }
    c: str = dep[0];
    if c == "=" or c == ">" or c == "<" or c == "^" or c == "*" or c == "|" {
        return SPEC_NPM;
    }
    if c == "." or c == "/" {
        if _is_tarball(dep) {
            return SPEC_TARBALL;
        }
        return SPEC_FOLDER;
    }
    if c == "~" {
        if len(dep) > 1 and dep[1] == "/" {
            if _is_tarball(dep) {
                return SPEC_TARBALL;
            }
            return SPEC_FOLDER;
        }
        return SPEC_NPM;
    }
    if c >= "0" and c <= "9" {
        if _is_tarball(dep) {
            return SPEC_TARBALL;
        }
        return SPEC_NPM;
    }
    if dep.startswith("file:") {
        if _is_tarball(dep) {
            return SPEC_TARBALL;
        }
        return SPEC_FOLDER;
    }
    if dep.startswith("catalog:") {
        return SPEC_CATALOG;
    }
    if dep.startswith("git") {
        rest: str = dep[3:];
        if rest.startswith("://") {
            body: str = rest[3:];
            if body.startswith("github.com/") and _is_github_shorthand(body[11:]) {
                return SPEC_GITHUB;
            }
            return SPEC_GIT;
        }
        if rest.startswith("+ssh:") or rest.startswith("+file:") {
            return SPEC_GIT;
        }
        if rest.startswith("+http") {
            body2: str = rest[5:];
            if body2.startswith("://") {
                body2 = body2[3:];
            } elif body2.startswith("s://") {
                body2 = body2[4:];
            }
            if body2.startswith("github.com/") and _is_github_shorthand(body2[11:]) {
                return SPEC_GITHUB;
            }
            return SPEC_GIT;
        }
        if rest.startswith("hub:") {
            if _is_github_shorthand(rest[4:]) {
                return SPEC_GITHUB;
            }
        }
    }
    if dep.startswith("http") {
        u: str = dep[4:];
        if u.startswith("://") {
            u = u[3:];
        } elif u.startswith("s://") {
            u = u[4:];
        }
        if u.startswith("github.com/") {
            p: str = u[11:];
            if p.find("/tarball/") >= 0 or p.find("/archive/") >= 0 {
                return SPEC_TARBALL;
            }
            if _is_github_shorthand(p) {
                return SPEC_GITHUB;
            }
        }
        return SPEC_TARBALL;
    }
    if dep.startswith("ssh") {
        return SPEC_GIT;
    }
    if dep.startswith("link:") {
        return SPEC_SYMLINK;
    }
    if dep.startswith("npm:") and len(dep) > 4 {
        remain: str = dep[4:];
        if remain.startswith("@") {
            remain = remain[1:];
        }
        at: int = remain.find("@");
        if at >= 0 {
            return depspec_infer(remain[at + 1:]);
        }
        return SPEC_NPM;
    }
    if c == "v" {
        if _is_tarball(dep) {
            return SPEC_TARBALL;
        }
        if _is_github_shorthand(dep) {
            return SPEC_GITHUB;
        }
        if len(dep) == 1 {
            return SPEC_DIST_TAG;
        }
        return SPEC_NPM;
    }
    if dep.startswith("workspace:") {
        return SPEC_WORKSPACE;
    }
    if c == "x" or c == "X" {
        if len(dep) == 1 {
            return SPEC_NPM;
        }
        if len(dep) > 1
            and (dep[1] == "." or dep[1] == "x" or dep[1] == "X" or dep[1] == "*") {
            return SPEC_NPM;
        }
    }
    if _is_tarball(dep) {
        return SPEC_TARBALL;
    }
    if _is_github_shorthand(dep) {
        return SPEC_GITHUB;
    }
    return SPEC_DIST_TAG;
}

"""Split "npm:<name>@<rest>" → (name, rest); rest "" when absent."""
def _split_alias(dep: str) -> tuple[str, str] {
    s: str = dep[4:];
    start: int = 0;
    if s.startswith("@") {
        start = 1;
    }
    at: int = s.find("@", start);
    if at < 0 {
        return (s, "");
    }
    return (s[0:at], s[at + 1:]);
}

"""Parse a specifier written for dependency `alias` (the key in package.json)."""
def:pub depspec_parse(alias: str, dep: str) -> DepSpec {
    spec: DepSpec = DepSpec(literal=dep, name=alias);
    spec.tag = depspec_infer(dep);
    if spec.tag == SPEC_NPM {
        input: str = dep;
        if dep.startswith("npm:") {
            a: tuple[str, str] = _split_alias(dep);
            spec.name = a[0];
            spec.is_alias = True;
            input = a[1];
        }
        if len(input) > 1 and input[0] == "v" {
            input = input[1:];
        }
        spec.range = semver_parse_range(input);
        return spec;
    }
    if spec.tag == SPEC_DIST_TAG {
        tag: str = dep;
        if dep.startswith("npm:") and len(dep) > 4 {
            a2: tuple[str, str] = _split_alias(dep);
            spec.name = a2[0];
            spec.is_alias = True;
            tag = a2[1];
        }
        if tag == "" {
            tag = "latest";
        }
        spec.dist_tag = tag;
        return spec;
    }
    if spec.tag == SPEC_WORKSPACE {
        spec.path = dep[10:];
        return spec;
    }
    if spec.tag == SPEC_FOLDER {
        p: str = dep;
        if p.startswith("file:") {
            p = p[5:];
        }
        spec.path = p;
        return spec;
    }
    if spec.tag == SPEC_SYMLINK {
        spec.path = dep[5:];
        return spec;
    }
    if spec.tag == SPEC_GITHUB {
        g: tuple[str, str, str] = _github_parts(dep);
        spec.owner = g[0];
        spec.repo = g[1];
        spec.committish = g[2];
        spec.path = dep;
        return spec;
    }
    if spec.tag == SPEC_GIT {
        u: str = dep;
        if u.startswith("git+") {
            u = u[4:];
        }
        h2: int = _last_index(u, "#");
        if h2 >= 0 {
            spec.committish = u[h2 + 1:];
            u = u[0:h2];
        }
        spec.repo = u;
        spec.path = u;
        return spec;
    }
    spec.path = dep;
    return spec;
}

"""bun's Behavior.cmp: workspace < dev < optional < prod < peer; -1/0/1."""
def:pub behavior_cmp(a: int, b: int) -> int {
    if a == b {
        return 0;
    }
    a_ws: bool = (a & BEH_WORKSPACE) != 0;
    b_ws: bool = (b & BEH_WORKSPACE) != 0;
    if a_ws != b_ws {
        return -1 if a_ws else 1;
    }
    a_dev: bool = (a & BEH_DEV) != 0;
    b_dev: bool = (b & BEH_DEV) != 0;
    if a_dev != b_dev {
        return -1 if a_dev else 1;
    }
    a_opt: bool = (a & BEH_OPTIONAL) != 0 and (a & BEH_PEER) == 0;
    b_opt: bool = (b & BEH_OPTIONAL) != 0 and (b & BEH_PEER) == 0;
    if a_opt != b_opt {
        return -1 if a_opt else 1;
    }
    a_prod: bool = (a & BEH_PROD) != 0;
    b_prod: bool = (b & BEH_PROD) != 0;
    if a_prod != b_prod {
        return -1 if a_prod else 1;
    }
    a_peer: bool = (a & BEH_PEER) != 0;
    b_peer: bool = (b & BEH_PEER) != 0;
    if a_peer != b_peer {
        return -1 if a_peer else 1;
    }
    return 0;
}

"""bun's Dependency.isLessThan: behavior, then name (byte order)."""
def:pub dep_less_than(
    a_behavior: int, a_name: str, b_behavior: int, b_name: str
) -> bool {
    c: int = behavior_cmp(a_behavior, b_behavior);
    if c != 0 {
        return c < 0;
    }
    return a_name < b_name;
}

def:pub behavior_is_optional_peer(b: int) -> bool {
    return (b & BEH_PEER) != 0 and (b & BEH_OPTIONAL) != 0;
}
def:pub behavior_is_peer(b: int) -> bool {
    return (b & BEH_PEER) != 0;
}
def:pub behavior_is_dev(b: int) -> bool {
    return (b & BEH_DEV) != 0;
}
def:pub behavior_is_bundled(b: int) -> bool {
    return (b & BEH_BUNDLED) != 0;
}
def:pub behavior_is_workspace(b: int) -> bool {
    return (b & BEH_WORKSPACE) != 0;
}
def:pub behavior_is_optional(b: int) -> bool {
    return (b & BEH_OPTIONAL) != 0 and (b & BEH_PEER) == 0;
}

"""package.json group name for a behavior (lockfile INFO / workspaces section)."""
def:pub behavior_group(b: int) -> str {
    if (b & BEH_PEER) != 0 {
        return "peerDependencies";
    }
    if (b & BEH_OPTIONAL) != 0 {
        return "optionalDependencies";
    }
    if (b & BEH_DEV) != 0 {
        return "devDependencies";
    }
    if (b & BEH_PROD) != 0 {
        return "dependencies";
    }
    return "";
}

def:pub behavior_for_group(group: str) -> int {
    if group == "dependencies" {
        return BEH_PROD;
    }
    if group == "devDependencies" {
        return BEH_DEV;
    }
    if group == "optionalDependencies" {
        return BEH_OPTIONAL;
    }
    if group == "peerDependencies" {
        return BEH_PEER;
    }
    if group == "workspaces" {
        return BEH_WORKSPACE;
    }
    return 0;
}
