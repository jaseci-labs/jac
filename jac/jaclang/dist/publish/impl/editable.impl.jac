import json;

impl install_editable(config: JacConfig, src_dir: Path, site_pkgs: Path) -> Path {
    if not config.project.name {
        raise ValueError(
            "Cannot install editable: [project] name is missing in jac.toml."
        );
    }

    pkg_name = config.project.name.replace("-", "_");
    pth_filename = f"__editable__.{pkg_name}-{config.project.version}.pth";
    pth_content: bytes = (str(src_dir) + "\n").encode("utf-8");
    pth_path = site_pkgs / pth_filename;
    pth_path.write_bytes(pth_content);

    di_name = dist_info_dirname(config);
    dist_info_dir = site_pkgs / di_name;
    dist_info_dir.mkdir(exist_ok=True);

    files: dict[str, bytes] = {
        "METADATA": generate_metadata(config, src_dir).encode("utf-8"),
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

    ep_content = generate_entry_points(config);
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
