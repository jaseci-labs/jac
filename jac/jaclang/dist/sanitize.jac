import os;
import from pathlib { Path }

glob LOCAL_OVERLAY_NAME: str = "jac.local.toml";

def is_secret_path(name: str) -> bool {
    return name == "plugins.scale.secrets"
        or name.startswith("plugins.scale.secrets.")
        or name == "scale.secrets"
        or name.startswith("scale.secrets.");
}

def is_dev_section(name: str) -> bool {
    return name == "dev" or name.startswith("dev.");
}

def sanitize_jac_toml_text(text: str) -> str {
    out: list[str] = [];
    pending: list[str] = [];
    in_stripped_section = False;
    current_section = "";
    for line in text.splitlines() {
        stripped = line.lstrip();
        if stripped.startswith("[") {
            header = stripped.lstrip("[").split("]")[0].strip();
            in_stripped_section = is_secret_path(header) or is_dev_section(header);
            current_section = header;
            if in_stripped_section {
                pending = [];
                continue;
            }
            out.extend(pending);
            pending = [];
            out.append(line);
            continue;
        }
        if in_stripped_section {
            continue;
        }
        if stripped == "" or stripped.startswith("#") {
            pending.append(line);
            continue;
        }
        key = stripped.split("=")[0].strip();
        full_key = key if current_section == "" else f"{current_section}.{key}";
        if is_secret_path(full_key) {
            pending = [];
            continue;
        }
        out.extend(pending);
        pending = [];
        out.append(line);
    }
    out.extend(pending);
    return "\n".join(out) + "\n";
}

def sanitized_jac_toml(base: Path) -> (str | None) {
    src = base / "jac.toml";
    if not src.is_file() {
        return None;
    }
    return sanitize_jac_toml_text(src.read_text());
}

def sanitize_shipped_tree(tree: Path) {
    for (dirpath, dirnames, filenames) in os.walk(str(tree)) {
        dirnames[:] = [
            d
            for d in dirnames
            if d != ".git"
        ];
        folder = Path(str(dirpath));
        if LOCAL_OVERLAY_NAME in filenames {
            (folder / LOCAL_OVERLAY_NAME).unlink();
        }
        if "jac.toml" in filenames {
            text = sanitized_jac_toml(folder);
            if text is not None {
                (folder / "jac.toml").write_text(text, encoding="utf-8");
            }
        }
    }
}
