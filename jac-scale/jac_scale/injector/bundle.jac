"""Reusable source bundling: pack a project into a tar.gz, content-address it,
and resolve the in-pod install specs.

Transport-independent: the PvcInjector places the bundle on a shared PVC, but the
packing rules (exclude build artifacts and secrets, sanitize jac.toml) are the
same regardless of how the bytes travel. Content-addressing the archive by sha256
gives immutable, cacheable bundle keys so a pod restart can never read a mutated
bundle.
"""

import io;
import hashlib;
import tarfile;
import from pathlib { Path }

# Pod-side contract shared with the injector's init container. The bundle is
# unpacked onto APP_VOLUME_NAME at APP_MOUNT_PATH; the shared runtime bootstrap
# (in a dedicated init container) installs jac under JAC_HOME, which lives on the
# same shared volume so the built/installed toolchain survives into the app
# container. JAC_ZIG_VERSION tracks jac/build.zig.zon's minimum_zig_version
# (single source of truth for the experimental zig fetch).
glob APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     JAC_HOME: str = "/app/.jachome",
     JAC_ZIG_VERSION: str = "0.16.0";

# Directories never shipped into the cluster: build output, caches, vendored
# deps, VCS metadata, virtualenvs.
glob _EXCLUDE_DIRS: set[str] = {
         ".jac",
         "__pycache__",
         "node_modules",
         ".git",
         "dist",
         "build",
         ".venv",
         "venv",
         ".mypy_cache",
         ".pytest_cache"
     };
# Secret-bearing files are never packed. The raw jac.toml is excluded (it can
# hold creds under [plugins.scale]); a [plugins.scale]-stripped copy is added
# back by pack_source so pods still get the app + client-build config.
glob _EXCLUDE_FILES: set[str] = {
         ".env",
         "jac.toml",
         "id_rsa",
         "id_dsa",
         "id_ecdsa",
         "id_ed25519"
     };
glob _EXCLUDE_SUFFIXES: tuple = (
         ".pem",
         ".key",
         ".crt",
         ".cer",
         ".p12",
         ".pfx",
         ".jks",
         ".keystore"
     );


"""True if `rel` (a project-relative Path) is a build artifact or secret file
that must not be packed into the bundle."""
def is_excluded(rel: Path) -> bool {
    for part in rel.parts {
        if part in _EXCLUDE_DIRS {
            return True;
        }
    }
    name = rel.name;
    if name in _EXCLUDE_FILES {
        return True;
    }
    if name == ".env" or name.startswith(".env.") {
        return True;
    }
    if name.endswith(_EXCLUDE_SUFFIXES) {
        return True;
    }
    return False;
}


"""The project's jac.toml with the [plugins.scale...] tables (deploy creds)
removed, or None when there's no jac.toml."""
def sanitized_jac_toml(base: Path) -> (str | None) {
    src = base / "jac.toml";
    if not src.is_file() {
        return None;
    }
    out: list[str] = [];
    in_scale_section = False;
    at_top_level = True;
    for line in src.read_text().splitlines() {
        stripped = line.lstrip();
        if stripped.startswith("[") {
            # Take the name between the brackets; split on "]" so a trailing
            # inline comment (e.g. `[plugins.scale] # creds`) cannot smuggle the
            # section past the credential check.
            header = stripped.lstrip("[").split("]")[0].strip();
            in_scale_section = header == "plugins.scale"
            or header.startswith("plugins.scale.");
            at_top_level = False;
            if in_scale_section {
                continue;
            }
        } elif at_top_level and stripped.startswith("plugins.scale.") {
            # Top-level dotted-key form of a scale setting (creds); drop it.
            # Only at top level: under another section, `plugins.scale.x` is that
            # section's subkey, not a jac-scale credential.
            continue;
        }
        if not in_scale_section {
            out.append(line);
        }
    }
    return "\n".join(out) + "\n";
}


"""Tar+gzip the project dir (excluding build artifacts + secret files) into raw
bytes, appending a sanitized jac.toml. Deterministic for a given tree so the
content address is stable."""
def pack_source(project_dir: str) -> bytes {
    base = Path(project_dir).resolve();
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        for path in sorted(base.rglob("*")) {
            if not path.is_file() {
                continue;
            }
            rel = path.relative_to(base);
            if is_excluded(rel) {
                continue;
            }
            tar.add(str(path), arcname=str(rel));
        }
        sanitized = sanitized_jac_toml(base);
        if sanitized is not None {
            data = sanitized.encode("utf-8");
            info = tarfile.TarInfo(name="jac.toml");
            info.size = len(data);
            tar.addfile(info, io.BytesIO(data));
        }
    }
    return buf.getvalue();
}


"""sha256 hex digest of the bundle bytes; the immutable content address."""
def content_address(raw: bytes) -> str {
    return hashlib.sha256(raw).hexdigest();
}


"""Object-store key for a bundle: namespaced by app, addressed by digest, so the
same content reuses the same key and a changed tree gets a new one."""
def bundle_object_key(app_name: str, digest: str) -> str {
    return f"bundles/{app_name}/{digest}.tar.gz";
}


"""Shell snippet writing a stub jac.toml when the bundle lacks one (the real
jac.toml is excluded; `jac start <svc>.jac` still requires a project toml)."""
def ensure_jac_toml_cmd -> str {
    return (
        f"[ -f {APP_MOUNT_PATH}/jac.toml ] || "
        f"printf '[project]\\nname = \"app\"\\n' > {APP_MOUNT_PATH}/jac.toml"
    );
}
