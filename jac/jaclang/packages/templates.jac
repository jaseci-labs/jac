import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.archive { extract_tar_gz }
import from jaclang.packages.artifact {
    MANIFEST_DIR,
    ROLE_TEMPLATE,
    read_package_manifest
}
import from jaclang.packages.index { IndexEntry, RegistryError, registry_named }
import from jaclang.packages.resolve { running_jac_version }
import from jaclang.packages.semver { Requirement, SemverError, Version }
import from jaclang.project.jac_version { satisfies as jac_satisfies }
import from jaclang.project.package_scope { is_package_name }

obj TemplateError(Exception) {}

def is_template_spec(spec: str) -> bool {
    return is_package_name(spec.partition("@")[0].strip());
}

def pick_template(
    entries: list[IndexEntry], requirement: Requirement, jac: Version
) -> IndexEntry | None {
    best: IndexEntry | None = None;
    best_version: Version | None = None;
    for e in entries {
        if e.role != ROLE_TEMPLATE or e.yanked {
            continue;
        }
        try {
            v = Version.parse(e.version);
        } except SemverError {
            continue;
        }
        if not requirement.matches(v) {
            continue;
        }
        if e.jac_version and not jac_satisfies(str(jac), e.jac_version) {
            continue;
        }
        if best_version is None or v > best_version {
            best = e;
            best_version = v;
        }
    }
    return best;
}

def unpack_template(data: bytes, label: str) -> Path {
    stage = Path(tempfile.mkdtemp(prefix="jac-template-"));
    extract_tar_gz(data, stage);
    manifest = read_package_manifest(stage);
    if manifest is None or manifest.get("role") != ROLE_TEMPLATE {
        shutil.rmtree(stage, ignore_errors=True);
        raise TemplateError(f"{label} is not a template package");
    }
    shutil.rmtree(stage / MANIFEST_DIR, ignore_errors=True);
    return stage;
}

def fetch_template(spec: str, registries: dict[str, str] | None = None) -> Path {
    (name, sep, text) = spec.strip().partition("@");
    try {
        requirement = Requirement.parse(text if sep else "*");
    } except SemverError as e {
        raise TemplateError(f"{spec}: {e}");
    }
    try {
        registry = registry_named("", registries);
        item = pick_template(
            registry.entries(name), requirement, running_jac_version()
        );
        if item is None {
            raise TemplateError(
                f"no template '{name}' matching {requirement.text} for this jac in "
                f"{registry.base()}"
            );
        }
        label = f"{item.name} {item.version}";
        data = registry.fetch_blob(item);
    } except RegistryError as e {
        raise TemplateError(str(e));
    }
    return unpack_template(data, label);
}

def load_template_jab(path: Path) -> Path {
    return unpack_template(path.read_bytes(), str(path));
}
