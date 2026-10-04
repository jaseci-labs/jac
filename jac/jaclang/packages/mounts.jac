import json;
import os;
import shutil;
import from pathlib { Path }
import from jaclang.project.package_scope { mounts_dir }

glob MOUNTS_RECORD: str = ".jac-mounts.json",
     COPY_MARKER: str = ".jac-mount-copy";

def _current_target(item: Path) -> str {
    if item.is_symlink() {
        return os.path.realpath(str(item));
    }
    marker = item / COPY_MARKER;
    if marker.is_file() {
        return marker.read_text(encoding="utf-8").strip();
    }
    return "";
}

def _remove(item: Path) {
    if item.is_symlink() or item.is_file() {
        item.unlink();
    } elif item.is_dir() {
        shutil.rmtree(item);
    }
}

def _link(item: Path, target: Path) {
    item.parent.mkdir(parents=True, exist_ok=True);
    try {
        os.symlink(str(target), str(item), target_is_directory=True);
    } except OSError {
        shutil.copytree(target, item, ignore=shutil.ignore_patterns(".jac", ".git"));
        (item / COPY_MARKER).write_text(str(target), encoding="utf-8");
    }
}

def link_mounts(build_dir: Path, targets: dict[str, Path]) -> Path {
    root_dir = mounts_dir(build_dir);
    root_dir.mkdir(parents=True, exist_ok=True);
    wanted = {
        name: os.path.realpath(str(target)) for (name, target) in targets.items()
    };
    for org_dir in sorted(root_dir.iterdir()) {
        if not org_dir.is_dir() or org_dir.is_symlink() {
            continue;
        }
        for item in sorted(org_dir.iterdir()) {
            name = f"{org_dir.name}/{item.name}";
            if wanted.get(name) != _current_target(item) {
                _remove(item);
            }
        }
        if not any(org_dir.iterdir()) {
            org_dir.rmdir();
        }
    }
    for (name, target) in sorted(wanted.items()) {
        (org, pkg) = name.split("/", 1);
        item = root_dir / org / pkg;
        if not item.exists() and not item.is_symlink() {
            _link(item, Path(target));
        }
    }
    (root_dir / MOUNTS_RECORD).write_text(
        json.dumps(wanted, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
    return root_dir;
}

def read_mounts(build_dir: Path) -> dict[str, str] {
    record = mounts_dir(build_dir) / MOUNTS_RECORD;
    if not record.is_file() {
        return {};
    }
    try {
        return {
            str(k): str(v)
            for (k, v) in json.loads(record.read_text(encoding="utf-8")).items()
        };
    } except (OSError, ValueError) {
        return {};
    }
}
