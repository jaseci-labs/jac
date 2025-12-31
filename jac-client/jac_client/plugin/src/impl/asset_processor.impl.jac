"""Copy custom asset files (based on jac.toml configuration) from source to destination recursively."""

impl AssetProcessor.copy_custom_asset_types(
    self: AssetProcessor,
    src_dir: Path,
    dest_dir: Path,
    preserve_structure: bool = True
) -> None {
    if not src_dir.exists() {
        return;
    }
    dest_dir.mkdir(parents=True, exist_ok=True);
    def copy_recursive(
        source: Path, destination: Path, base: (Path | None) = None
    ) -> None {
        if not source.exists() {
            return;
        }
        if (base is None) {
            base = source;
        }
        for item in source.iterdir() {
            if (item.is_file() and (item.suffix.lower() in custom_asset_extensions)) {
                if preserve_structure {
                    relative_path = item.relative_to(base);
                    dest_file = destination / relative_path;
                } else {
                    dest_file = destination / item.name;
                }
                dest_file.parent.mkdir(parents=True, exist_ok=True);
                with contextlib.suppress(OSError, shutil.Error) {
                    shutil.copy2(item, dest_file);
                }
            } elif item.is_dir() {
                copy_recursive(item, destination, base);
            }
        }
    }
    config = get_config();
    assets_config = config.get_plugin_config("client").get("assets", {});
    custom_asset_extensions = set(assets_config.get("custom_extensions", []));
    if custom_asset_extensions {
        copy_recursive(src_dir, dest_dir);
    }
    return;
}

"""Copy TypeScript files (.ts, .tsx) from source to destination recursively."""
impl AssetProcessor.copy_typescript_files(
    self: AssetProcessor,
    src_dir: Path,
    dest_dir: Path,
    preserve_structure: bool = True
) -> None {
    if not src_dir.exists() {
        return;
    }
    dest_dir.mkdir(parents=True, exist_ok=True);
    ts_extensions = {'.ts','.tsx'};
    def copy_recursive(
        source: Path, destination: Path, base: (Path | None) = None
    ) -> None {
        if not source.exists() {
            return;
        }
        if (base is None) {
            base = source;
        }
        for item in source.iterdir() {
            if (item.is_file() and (item.suffix.lower() in ts_extensions)) {
                if preserve_structure {
                    relative_path = item.relative_to(base);
                    dest_file = destination / relative_path;
                } else {
                    dest_file = destination / item.name;
                }
                dest_file.parent.mkdir(parents=True, exist_ok=True);
                with contextlib.suppress(OSError, shutil.Error) {
                    shutil.copy2(item, dest_file);
                }
            } elif item.is_dir() {
                copy_recursive(item, destination, base);
            }
        }
    }
    copy_recursive(src_dir, dest_dir);
}

"""Copy CSS and other asset files from source to destination recursively."""
impl AssetProcessor.copy_assets(
    self: AssetProcessor,
    src_dir: Path,
    dest_dir: Path,
    preserve_structure: bool = True
) -> None {
    if not src_dir.exists() {
        return;
    }
    dest_dir.mkdir(parents=True, exist_ok=True);
    def copy_recursive(
        source: Path, destination: Path, base: (Path | None) = None
    ) -> None {
        if not source.exists() {
            return;
        }
        if (base is None) {
            base = source;
        }
        for item in source.iterdir() {
            if (item.is_file() and (item.suffix.lower() in self.ASSET_EXTENSIONS)) {
                if preserve_structure {
                    relative_path = item.relative_to(base);
                    dest_file = destination / relative_path;
                } else {
                    dest_file = destination / item.name;
                }
                dest_file.parent.mkdir(parents=True, exist_ok=True);
                with contextlib.suppress(OSError, shutil.Error) {
                    shutil.copy2(item, dest_file);
                }
            } elif item.is_dir() {
                copy_recursive(item, destination, base);
            }
        }
    }
    copy_recursive(src_dir, dest_dir);
}
