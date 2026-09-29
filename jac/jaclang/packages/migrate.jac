import copy;
import tomllib;
import from pathlib { Path }
import from jaclang.project.config { serialize_toml, toml_minimal_update }
import from jaclang.project.dependencies { migrate_dependency_table }

glob DEP_TABLES: tuple[str, ...] = ("dependencies", "dev-dependencies");

obj ManifestMigration {
    has path: Path,
        moved: list[str] = [],
        text: str = "",
        lossless: bool = True;
}

def _migrate_scope(scope: dict[str, any], prefix: str, moved: list[str]) {
    for table_name in DEP_TABLES {
        table = scope.get(table_name);
        if not isinstance(table, dict) {
            continue;
        }
        migrated = migrate_dependency_table(table);
        if migrated != table {
            before = set(table.keys()) - {"pypi"};
            after = set(migrated.keys()) - {"pypi"};
            for key in sorted(before - after) {
                moved.append(f"{prefix}{table_name}.{key}");
            }
            scope[table_name] = migrated;
        }
    }
}

def migrate_manifest(path: Path) -> ManifestMigration {
    text = path.read_text(encoding="utf-8");
    old_doc = tomllib.loads(text);
    new_doc = copy.deepcopy(old_doc);
    result = ManifestMigration(path=path);
    _migrate_scope(new_doc, "", result.moved);
    for (group, prefix) in (("environments", "environments."), ("apps", "apps.")) {
        section = new_doc.get(group);
        if isinstance(section, dict) {
            for (name, scope) in section.items() {
                if isinstance(scope, dict) {
                    _migrate_scope(scope, f"{prefix}{name}.", result.moved);
                }
            }
        }
    }
    if not result.moved {
        result.text = text;
        return result;
    }
    roots = [
        k
        for k in [*DEP_TABLES, "environments", "apps"]
        if k in old_doc or k in new_doc
    ];
    updated = toml_minimal_update(text, old_doc, new_doc, roots);
    if updated is None {
        result.lossless = False;
        updated = serialize_toml(new_doc);
    }
    result.text = updated;
    return result;
}

def find_manifests(paths: list[str]) -> list[Path] {
    found: list[Path] = [];
    for raw in paths {
        p = Path(raw);
        if p.is_file() and p.name == "jac.toml" {
            found.append(p);
        } elif p.is_dir() {
            for candidate in sorted(p.rglob("jac.toml")) {
                parts = set(candidate.parts);
                if not parts & {".jac", "node_modules", ".git"} {
                    found.append(candidate);
                }
            }
        }
    }
    return found;
}
