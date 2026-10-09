import ast as py_ast;
import gzip;
import io;
import json;
import os;
import tarfile;
import from pathlib { Path }
import from jaclang.jac0core.ext_registry { is_annex }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.project.config { JacConfig }
import from jaclang.dist.publish.metadata { generate_metadata, generate_pyproject_toml }
import from jaclang.dist.publish.py_imports { rewrite_imports, wheel_module_name }
import from jaclang.compiler.driver.source_products { python_source }
import from jaclang.dist.publish.runtime_vendor {
    build_runtime_closure,
    scan_jaclang_imports
}
import from jaclang.dist.publish.wheel_meta {
    generate_wheel_file,
    generate_entry_points,
    wheel_filename,
    dist_info_dirname,
    sdist_filename
}
import from jaclang.dist.publish.record {
    record_entry_from_bytes,
    generate_record,
    RecordEntry
}
import from jaclang.dist.publish.sources {
    collect_source_files,
    read_source_file,
    SourceFile
}
import from jaclang.dist.publish.wheel_archive { BUILD_DATA_FILE, wheel_bytes }

glob _VENDOR_DIRNAME: str = "_jac_vendor";


def _module_is_client_source(source_path: Path) -> bool {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang.compiler.driver.program { JacProgram as JacProgramRt }
    try {
        mod = JacProgramRt().compile(
            str(source_path), options=CompileOptions(symtab_ir_only=True)
        );
        return mod is not None
            and mod.declares_codespace(CodeContext.CLIENT, path_hint=str(source_path));
    } except Exception {
        return False;
    }
}


def _bootstrap_shim(top: str, primary_pkg: str) -> str {
    here = "os.path.dirname(os.path.abspath(__file__))";
    if top == primary_pkg {
        vendor_expr = f"os.path.join({here}, {_VENDOR_DIRNAME!r})";
    } else {
        vendor_expr = (
            f"os.path.join(os.path.dirname({here}), "
            f"{primary_pkg!r}, {_VENDOR_DIRNAME!r})"
        );
    }
    return (
        "# jac bundle: prefer a host jaclang; else use the vendored runtime.\n"
        + "def _jac_use_vendored_runtime():\n"
        + "    import importlib.util\n"
        + "    import os\n"
        + "    import sys\n"
        + "    try:\n"
        + "        if importlib.util.find_spec('jaclang') is not None:\n"
        + "            return\n"
        + "    except (ImportError, ValueError):\n"
        + "        pass\n"
        + "    vendor = "
        + vendor_expr
        + "\n"
        + "    if os.path.isdir(vendor) and vendor not in sys.path:\n"
        + "        sys.path.insert(0, vendor)\n"
        + "\n"
        + "\n"
        + "_jac_use_vendored_runtime()\n"
    );
}

def _with_bootstrap(init_source: str, shim: str) -> str {
    tree = py_ast.parse(init_source);
    insert_at = 1;
    for (i, stmt) in enumerate(tree.body) {
        is_docstring = (
            (i == 0)
            and isinstance(stmt, py_ast.Expr)
            and isinstance(stmt.value, py_ast.Constant)
            and isinstance(stmt.value.value, str)
        );
        is_future = (
            isinstance(stmt, py_ast.ImportFrom) and (stmt.module == "__future__")
        );
        if is_docstring or is_future {
            insert_at = stmt.end_lineno + 1;
        } else {
            break;
        }
    }
    lines = init_source.splitlines();
    lines[insert_at - 1:insert_at - 1] = shim.splitlines();
    return "\n".join(lines) + "\n";
}

impl WheelBuilder.postinit -> None {
    if self.project_root is None {
        self.project_root = self.config.project_root;
    }
}

impl WheelBuilder.source_data -> dict[str, bytes] {
    if self._src_data_cache is None {
        self._src_data_cache = self._assemble_src_data();
    }
    return self._src_data_cache;
}

impl WheelBuilder._assemble_src_data -> dict[str, bytes] {
    if self.config.dependencies {
        raise ValueError(
            "a Python wheel cannot carry Jac package dependencies ("
                + ", ".join(sorted(self.config.dependencies))
                + "); publish the package with 'jac publish' instead"
        );
    }
    source_files = collect_source_files(self.config, project_root=self.project_root);

    self.skipped_codespace = [];
    self.vendored_runtime_modules = 0;

    texts: dict[str, str] = {};
    origins: dict[str, Path] = {};
    raw: dict[str, bytes] = {};
    transpiled: set[str] = set();
    program: JacProgram | None = None;

    def _claim(target: str) {
        if (target in texts) or (target in raw) {
            raise ValueError(
                f"Wheel path collision: '{target}' is produced by more than one "
                f"source file (e.g. a '.jac' and a '.py' sharing the same stem)."
            );
        }
    }

    for sf in source_files {
        wp = sf.wheel_path;
        src_path = sf.source_path;
        if self.transpile_jac and wp.endswith(".jac") {
            if is_annex(wp) {
                continue;
            }
            if src_path is not None and _module_is_client_source(src_path) {
                self.skipped_codespace.append(wp);
                continue;
            }
            if src_path is None {
                raise ValueError(f"Cannot transpile '{wp}': source path is not set.");
            }
            if program is None {
                import from jaclang.compiler.driver.program {
                    JacProgram as JacProgramRt
                }
                program = JacProgramRt();
            }
            target = wp[:-len(".jac")] + ".py";
            _claim(target);
            texts[target] = python_source(str(src_path), program)[0];
            origins[target] = src_path;
            transpiled.add(target);
        } elif self.transpile_jac and wp.endswith(".py") and (src_path is not None) {
            _claim(wp);
            texts[wp] = read_source_file(sf).decode("utf-8");
            origins[wp] = src_path;
        } else {
            _claim(wp);
            raw[wp] = read_source_file(sf);
        }
    }

    if self.skipped_codespace and not self.allow_drop_client {
        raise ValueError(
            "these client-codespace modules cannot ship in a Python wheel: "
                + ", ".join(sorted(self.skipped_codespace))
                + " (pass --allow-drop-client to build without them)"
        );
    }
    module_map: dict[str, str] = {};
    for (target, src_path) in origins.items() {
        module_map[os.path.normpath(os.path.abspath(str(src_path)))] = (
            wheel_module_name(target)
        );
    }

    src_data: dict[str, bytes] = {};
    for (target, text) in texts.items() {
        try {
            texts[target] = rewrite_imports(text, origins[target], module_map);
        } except SyntaxError as e {
            if target in transpiled {
                raise ValueError(
                    f"Transpiled output for '{target}' is not valid Python "
                    f"({e}); refusing to ship a broken wheel."
                );
            }

            texts[target] = text;
        }
        src_data[target] = texts[target].encode("utf-8");
    }
    src_data.update(raw);

    if self.transpile_jac and ("jaclang" not in self.config.pypi_dependencies) {
        self._vendor_runtime_into(src_data, list(texts.values()));
    }

    return src_data;
}

def _primary_package(tops: list[str], pkg_name: str) -> str {
    return pkg_name if pkg_name in tops else tops[0];
}

impl WheelBuilder._vendor_runtime_into(
    src_data: dict[str, bytes], codes: list[str]
) -> None {
    needed: set[str] = set();
    for code in codes {
        needed |= scan_jaclang_imports(code);
    }
    if not needed {
        return;
    }
    include_byllm = bool(
        any(
            (imp == "jaclang.byllm") or imp.startswith("jaclang.byllm.")
            for imp in needed
        )
    );
    closure = build_runtime_closure(
        codes, include_byllm=include_byllm, native_sources=False
    );
    runtime = json.loads(closure['runtime.json']);
    native_records = [
        module['native']
        for module in runtime['modules']
        if module.get('native')
    ];
    if native_records {
        import sysconfig;
        self.pure_python = False;
        self.platform_tag = sysconfig.get_platform().replace('-', '_').replace(
            '.', '_'
        );
    }

    tops = sorted(
        {
            p.split("/")[0]
            for p in src_data
            if p.endswith(".py") and ("/" in p)
        }
    );
    if not tops {
        return;
    }
    pkg_name = self.config.project.name.replace("-", "_");
    primary = _primary_package(tops, pkg_name);
    vendor_root = f"{primary}/{_VENDOR_DIRNAME}";
    for existing in src_data {
        if existing.startswith(vendor_root + "/") {
            raise ValueError(
                f"'{vendor_root}/' is reserved for the vendored jac runtime; "
                "rename that directory in your project."
            );
        }
    }
    for (rel, src) in sorted(closure.items()) {
        src_data[f"{vendor_root}/jaclang/{rel}"] = src;
    }
    self.vendored_runtime_modules = len(
        [
            p
            for (p, src) in closure.items()
            if src and (p != "__init__.py")
        ]
    );

    for top in tops {
        shim = _bootstrap_shim(top, primary);
        init_key = f"{top}/__init__.py";
        if init_key in src_data {
            src_data[init_key] = _with_bootstrap(
                src_data[init_key].decode("utf-8"), shim
            ).encode(
                "utf-8"
            );
        } else {
            src_data[init_key] = shim.encode("utf-8");
        }
    }
}

impl WheelBuilder.build -> bytes {
    if not self.config.project.name {
        raise ValueError("Cannot build wheel: [project] name is missing in jac.toml.");
    }

    proj_root = self.project_root;
    if proj_root is None {
        raise ValueError("Cannot build wheel: project_root is not set.");
    }

    src_data: dict[str, bytes] = self.source_data();
    return wheel_bytes(
        list(src_data.items()),
        dist_info_dirname(self.config),
        self._dist_info_files(src_data),
        _WHEEL_TIMESTAMP
    );
}

impl WheelBuilder._dist_info_files(
    src_data: dict[str, bytes]
) -> list[tuple[str, str]] {
    files: list[tuple[str, str]] = [
        ("METADATA", generate_metadata(self.config, project_root=self.project_root)),
        (
            "WHEEL",
            generate_wheel_file(
                pure_python=self.pure_python,
                python_tag=self.python_tag,
                abi_tag=self.abi_tag,
                platform_tag=self.platform_tag,
            )
        ),
        ("top_level.txt", "\n".join(self._top_level_names(src_data)) + "\n")
    ];
    entry_points = generate_entry_points(self.config);
    if entry_points {
        files.append(("entry_points.txt", entry_points));
    }
    return files;
}

impl WheelBuilder.build_to(output_dir: Path) -> Path {
    content = self.build();
    output_dir.mkdir(parents=True, exist_ok=True);
    fname = wheel_filename(
        self.config,
        python_tag=self.python_tag,
        abi_tag=self.abi_tag,
        platform_tag=self.platform_tag,
    );
    dest = output_dir / fname;
    dest.write_bytes(content);
    return dest;
}

impl WheelBuilder.build_sdist -> bytes {
    if not self.config.project.name {
        raise ValueError("Cannot build sdist: [project] name is missing in jac.toml.");
    }

    proj_root = self.project_root;
    if proj_root is None {
        raise ValueError("Cannot build sdist: project_root is not set.");
    }

    pkg_dirname = sdist_filename(self.config)[:-len(".tar.gz")];

    metadata_bytes = generate_metadata(self.config, project_root=proj_root).encode(
        "utf-8"
    );

    jac_toml_path = proj_root / "jac.toml";

    src_data: dict[str, bytes] = self.source_data();

    buf = io.BytesIO();
    with gzip.GzipFile(fileobj=buf, mode="wb", mtime=_SDIST_MTIME) as gz {
        with tarfile.open(fileobj=gz, mode="w|") as tf {
            def _add(arc_name: str, data: bytes) {
                ti = tarfile.TarInfo(name=f"{pkg_dirname}/{arc_name}");
                ti.size = len(data);
                ti.mtime = _SDIST_MTIME;
                ti.mode = 0o644;
                ti.uid = 0;
                ti.gid = 0;
                ti.uname = "";
                ti.gname = "";
                tf.addfile(ti, io.BytesIO(data));
            }
            _add("PKG-INFO", metadata_bytes);
            _add(
                "pyproject.toml", generate_pyproject_toml(self.config).encode("utf-8")
            );
            _add("_jac_build.py", _backend_source().encode("utf-8"));
            _add(BUILD_DATA_FILE, self._build_data(src_data).encode("utf-8"));
            if jac_toml_path.exists() {
                _add("jac.toml", jac_toml_path.read_bytes());
            }
            readme_name = self.config.project.readme;
            if readme_name {
                readme_path = proj_root / readme_name;
                if readme_path.exists() {
                    _add(readme_name, readme_path.read_bytes());
                }
            }
            for (path, data) in src_data.items() {
                _add(path, data);
            }
        }
    }

    return buf.getvalue();
}

impl WheelBuilder._top_level_names(src_data: dict[str, bytes]) -> list[str] {
    tops = sorted(
        {
            p.split("/")[0]
            for p in src_data
            if "/" in p
        }
    );
    if tops {
        return tops;
    }
    return [self.config.project.name.replace("-", "_")];
}

def _backend_source -> str {
    import from jaclang.compiler.driver.program { JacProgram as JacProgramRt }
    import from jaclang.dist.publish { wheel_archive }
    source = python_source(str(wheel_archive.__file__), JacProgramRt())[0];
    leaked = scan_jaclang_imports(source);
    if leaked {
        raise RuntimeError(
            "the sdist build backend must run without jaclang, but its Python "
                + "imports "
                + ", ".join(sorted(leaked))
        );
    }
    return source;
}

impl WheelBuilder._build_data(src_data: dict[str, bytes]) -> str {
    spec = {
        "wheel_name": wheel_filename(
            self.config,
            python_tag=self.python_tag,
            abi_tag=self.abi_tag,
            platform_tag=self.platform_tag,
        ),
        "dist_info": dist_info_dirname(self.config),
        "timestamp": list(_WHEEL_TIMESTAMP),
        "files": list(src_data.keys()),
        "dist_info_files": [list(pair) for pair in self._dist_info_files(src_data)]
    };
    return json.dumps(spec, indent=2, sort_keys=True) + "\n";
}

impl WheelBuilder.build_sdist_to(output_dir: Path) -> Path {
    output_dir.mkdir(parents=True, exist_ok=True);
    fname = sdist_filename(self.config);
    dest = output_dir / fname;
    dest.write_bytes(self.build_sdist());
    return dest;
}

impl WheelBuilder.install_editable(src_dir: Path, site_pkgs: Path) -> Path {
    if not self.config.project.name {
        raise ValueError(
            "Cannot install editable: [project] name is missing in jac.toml."
        );
    }

    pkg_name = self.config.project.name.replace("-", "_");
    pth_filename = f"__editable__.{pkg_name}-{self.config.project.version}.pth";
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
