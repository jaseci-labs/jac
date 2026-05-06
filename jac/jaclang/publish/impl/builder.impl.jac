"""Implementation of the WheelBuilder."""

import io;
import json;
import zipfile;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
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
import from jaclang.publish.sources { collect_source_files, read_source_file }

impl WheelBuilder.postinit -> None {
    if self.project_root is None {
        self.project_root = self.config.project_root;
    }
}

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

    metadata_bytes = generate_metadata(self.config, project_root=root).encode("utf-8");
    wheel_bytes = generate_wheel_file(
        pure_python=self.pure_python,
        python_tag=self.python_tag,
        abi_tag=self.abi_tag,
        platform_tag=self.platform_tag,
    ).encode(
        "utf-8"
    );
    ep_bytes: bytes | None = generate_entry_points(self.config).encode("utf-8") or None;
    pkg_name = self.config.package.name.replace("-", "_");
    top_level_bytes = (pkg_name + "\n").encode("utf-8");

    source_files = collect_source_files(self.config, project_root=root);
    src_data: dict[str, bytes] = {
        sf.wheel_path: read_source_file(sf) for sf in source_files
    };

    entries: list[RecordEntry] = [
        record_entry_from_bytes(path, data) for (path, data) in src_data.items()
    ];
    entries.append(record_entry_from_bytes(f"{dist_info}/METADATA", metadata_bytes));
    entries.append(record_entry_from_bytes(f"{dist_info}/WHEEL", wheel_bytes));
    entries.append(
        record_entry_from_bytes(f"{dist_info}/top_level.txt", top_level_bytes)
    );
    if ep_bytes is not None {
        entries.append(
            record_entry_from_bytes(f"{dist_info}/entry_points.txt", ep_bytes)
        );
    }

    record_path = f"{dist_info}/RECORD";
    record_bytes = generate_record(entries, record_path).encode("utf-8");

    buf = io.BytesIO();
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf {
        def _add(arc_path: str, data: bytes) {
            zi = zipfile.ZipInfo(arc_path, date_time=_WHEEL_TIMESTAMP);
            zf.writestr(zi, data);
        }
        for (path, data) in src_data.items() {
            _add(path, data);
        }
        _add(f"{dist_info}/METADATA", metadata_bytes);
        _add(f"{dist_info}/WHEEL", wheel_bytes);
        _add(f"{dist_info}/top_level.txt", top_level_bytes);
        if ep_bytes is not None {
            _add(f"{dist_info}/entry_points.txt", ep_bytes);
        }
        _add(record_path, record_bytes);
    }

    return buf.getvalue();
}

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

impl WheelBuilder.install_editable(src_dir: Path, site_pkgs: Path) -> Path {
    if self.config.package is None {
        raise ValueError(
            "Cannot install editable: [package] section is missing in jac.toml."
        );
    }

    pkg_name = self.config.package.name.replace("-", "_");
    pth_filename = f"__editable__.{pkg_name}-{self.config.package.version}.pth";
    pth_content: bytes = (str(src_dir) + "\n").encode("utf-8");
    pth_path = site_pkgs / pth_filename;
    pth_path.write_bytes(pth_content);

    di_name = dist_info_dirname(self.config);
    dist_info_dir = site_pkgs / di_name;
    dist_info_dir.mkdir(exist_ok=True);

    files: dict[str, bytes] = {
        "METADATA": generate_metadata(self.config, src_dir).encode("utf-8"),
        "WHEEL": generate_wheel_file().encode("utf-8"),
        "INSTALLER": b"jac\n",
        "REQUESTED": b"",
        "top_level.txt": (pkg_name + "\n").encode("utf-8"),
        "direct_url.json": json.dumps(
            {"url": src_dir.as_uri(), "dir_info": {"editable": True}}, indent=2
        ).encode(
            "utf-8"
        ),

    };

    ep_content = generate_entry_points(self.config);
    if ep_content {
        files["entry_points.txt"] = ep_content.encode("utf-8");
    }

    record_entries: list[RecordEntry] = [
        record_entry_from_bytes(pth_filename, pth_content)
    ];
    for (fname, data) in files.items() {
        (dist_info_dir / fname).write_bytes(data);
        record_entries.append(record_entry_from_bytes(f"{di_name}/{fname}", data));
    }
    record_path = f"{di_name}/RECORD";
    (dist_info_dir / "RECORD").write_text(
        generate_record(record_entries, record_path), encoding="utf-8"
    );

    return pth_path;
}
