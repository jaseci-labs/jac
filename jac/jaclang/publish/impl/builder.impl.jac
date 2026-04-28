"""Implementation of the WheelBuilder."""

import io;
import fnmatch;
import zipfile;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.publish.precompile { precompile_package as _do_precompile }
import from jaclang.publish.metadata { generate_metadata }
import from jaclang.publish.wheel_meta {
    generate_wheel_file,
    generate_entry_points,
    wheel_filename,
    dist_info_dirname
}
import from jaclang.publish.record {
    record_entry_from_bytes,
    generate_record,
    RecordEntry
}
import from jaclang.publish.sources {
    collect_source_files,
    read_source_file,
    EXCLUDED_DIRS
}

# ===============================================================================
# WheelBuilder.postinit
# ===============================================================================
impl WheelBuilder.postinit -> None {
    if self.project_root is None {
        self.project_root = self.config.project_root;
    }
}

# ==============================================================================
# WheelBuilder.precompile_package
# ==============================================================================
impl WheelBuilder.precompile_package(pkg_dir: Path) -> None {
    _do_precompile(pkg_dir);
}

# ===============================================================================
# WheelBuilder.build
# ===============================================================================
impl WheelBuilder.build -> bytes {
    if self.config.package is None {
        raise ValueError(
            "Cannot build wheel: [package] section is missing in jac.toml."
        );
    }

    root = self.project_root;
    if root is None {
        raise ValueError("Cannot build wheel: project_root is not set.");
    }

    dist_info = dist_info_dirname(self.config);

    # ── 0. Pre-compile .jac → .jir (optional) ───────────────────────────────
    if self.precompile {
        pkg_include = self.config.package.include;
        package_patterns = pkg_include.packages;

        # When no explicit packages list is given, fall back to a directory
        # whose name matches the package name (normalized: hyphens → underscores).
        if not package_patterns and self.config.package.name {
            package_patterns = [self.config.package.name.replace("-", "_")];
        }

        for pkg_glob in package_patterns {
            for candidate in sorted(root.iterdir()) {
                if not candidate.is_dir() {
                    continue;
                }
                if candidate.name in EXCLUDED_DIRS {
                    continue;
                }
                if not fnmatch.fnmatch(candidate.name, pkg_glob) {
                    continue;
                }
                self.precompile_package(candidate);
            }
        }
    }

    # ── 1. Generate dist-info file content ───────────────────────────────────
    metadata_bytes = generate_metadata(self.config, project_root=root).encode("utf-8");
    wheel_bytes = generate_wheel_file(
        pure_python=self.pure_python,
        python_tag=self.python_tag,
        abi_tag=self.abi_tag,
        platform_tag=self.platform_tag,
    ).encode(
        "utf-8"
    );

    ep_str = generate_entry_points(self.config);
    ep_bytes: bytes | None = ep_str.encode("utf-8") if ep_str else None;

    # Bundle jac.toml so 'jac install' can extract it (Step 12)
    jac_toml_path = root / "jac.toml";
    jac_toml_bytes: bytes | None = (
        jac_toml_path.read_bytes() if jac_toml_path.is_file() else None
    );

    # ── 2. Collect package source files ──────────────────────────────────────
    source_files = collect_source_files(self.config, project_root=root);

    # ── 3. Build RecordEntry list (every file except RECORD itself) ──────────
    entries: list[RecordEntry] = [];

    for sf in source_files {
        data = read_source_file(sf);
        entries.append(record_entry_from_bytes(sf.wheel_path, data));
    }

    entries.append(record_entry_from_bytes(f"{dist_info}/METADATA", metadata_bytes));
    entries.append(record_entry_from_bytes(f"{dist_info}/WHEEL", wheel_bytes));

    if ep_bytes is not None {
        entries.append(
            record_entry_from_bytes(f"{dist_info}/entry_points.txt", ep_bytes)
        );
    }
    if jac_toml_bytes is not None {
        entries.append(
            record_entry_from_bytes(f"{dist_info}/jac.toml", jac_toml_bytes)
        );
    }

    # ── 4. Generate RECORD (must reference all files above) ──────────────────
    record_path = f"{dist_info}/RECORD";
    record_bytes = generate_record(entries, record_path).encode("utf-8");

    # ── 5. Write zip archive in memory ───────────────────────────────────────
    buf = io.BytesIO();
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf {
        def _add(arc_path: str, data: bytes) {
            zi = zipfile.ZipInfo(arc_path, date_time=_WHEEL_TIMESTAMP);
            zf.writestr(zi, data);
        }
        # Source files first
        for sf in source_files {
            _add(sf.wheel_path, read_source_file(sf));
        }
        # dist-info files
        _add(f"{dist_info}/METADATA", metadata_bytes);
        _add(f"{dist_info}/WHEEL", wheel_bytes);
        if ep_bytes is not None {
            _add(f"{dist_info}/entry_points.txt", ep_bytes);
        }
        if jac_toml_bytes is not None {
            _add(f"{dist_info}/jac.toml", jac_toml_bytes);
        }
        # RECORD is always the last entry in a wheel
        _add(record_path, record_bytes);
    }

    return buf.getvalue();
}

# ===============================================================================
# WheelBuilder.build_to
# ===============================================================================
impl WheelBuilder.build_to(output_dir: Path) -> Path {
    output_dir.mkdir(parents=True, exist_ok=True);
    fname = wheel_filename(
        self.config,
        python_tag=self.python_tag,
        abi_tag=self.abi_tag,
        platform_tag=self.platform_tag,
    );
    dest = output_dir / fname;
    dest.write_bytes(self.build());
    return dest;
}
