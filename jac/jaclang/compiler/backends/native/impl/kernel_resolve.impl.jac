impl kernel_lib_name -> str {
    return host_target_spec().kernel_file_name();
}

impl source_tree_kernel_path -> str {
    return os.path.join(jaclang_pkg_root(), "compiler", kernel_lib_name());
}

impl kernel_path_for(spec: TargetSpec) -> str {
    if spec.osarch == host_target_spec().osarch {
        return source_tree_kernel_path();
    }
    return os.path.join(
        os.path.dirname(source_tree_kernel_path()),
        "kernels",
        spec.osarch,
        spec.kernel_file_name()
    );
}

impl read_sidecar(lib_path: str) -> (dict[str, any] | None) {
    data: any = None;
    try {
        with open(lib_path + LAYOUT_SIDECAR_SUFFIX, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
    } except Exception {
        return None;
    }
    if not isinstance(data, dict) or not isinstance(data.get("classes"), dict) {
        return None;
    }
    return data;
}

impl sealed_link_refusal(record: dict[str, any], sidecar: dict[str, any]) -> str {
    mode = str(record.get("mode", KERNEL_LINK_MODE));
    linked = str(sidecar.get("link_mode", KERNEL_LINK_MODE));
    if linked != mode {
        return f"the manifest records a {mode} link but the sidecar a {linked} link";
    }
    if mode == KERNEL_LINK_MODE {
        return "";
    }
    return f"a sealed image carries a {KERNEL_LINK_MODE} link, not a {mode} link";
}

impl _from_sealed_image -> (ResolvedKernel | None) {
    image = sealed._jaclang_image();
    if image is None {
        return None;
    }
    record = image.native_artifact();
    if record is None {
        raise KernelUnavailable(
            "sealed jaclang image carries no native compiler kernel; the image "
            "is immutable, so rebuild the payload"
        );
    }
    lib_path = str(image.pkg_dir / record["path"]);
    sidecar = read_sidecar(lib_path);
    if not os.path.isfile(lib_path) or sidecar is None {
        raise KernelUnavailable(
            f"sealed jaclang image names kernel {lib_path} but it or its "
            f"{LAYOUT_SIDECAR_SUFFIX} sidecar is missing"
        );
    }
    if _sha256_file(lib_path) != record.get("sha256") {
        raise KernelUnavailable(
            f"sealed kernel {lib_path} does not match its manifest sha256"
        );
    }
    refusal = sealed_link_refusal(record, sidecar);
    if refusal {
        raise KernelUnavailable(f"sealed kernel {lib_path}: {refusal}");
    }
    if str(sidecar.get("plan_digest", "")) != str(record.get("plan_digest", "")) {
        raise KernelUnavailable(
            f"sealed kernel {lib_path}: sidecar plan digest disagrees with the manifest"
        );
    }
    built_for = triple_osarch(
        str(record.get("triple", "") or sidecar.get("triple", ""))
    );
    host = host_target_spec().osarch;
    if built_for != host {
        raise KernelUnavailable(
            f"sealed kernel {lib_path} was built for {built_for}, not this {host} host"
        );
    }
    python = f"{sys.version_info.major}.{sys.version_info.minor}";
    if str(sidecar.get("python", python)) != python {
        raise KernelUnavailable(
            f"sealed kernel {lib_path} was built for Python {sidecar.get('python')}, "
            f"not {python}"
        );
    }
    return ResolvedKernel(
        lib_path=lib_path,
        layout=sidecar["classes"],
        source="sealed",
        plan_digest=str(record.get("plan_digest", ""))
    );
}

impl kernel_options(spec: (TargetSpec | None) = None) -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        native_require=[],
        native_link_mode=KERNEL_LINK_MODE,
        na_debug=False,
        default_codespace="native",
        native_unit=True,
        kernel_build=True,
        skip_native_engine=True,
        native_target=(spec or host_target_spec()).triple,
        na_gc_mode="cycles",
        memory_profile="managed",
        nogc_enforce_all=False,
        memory_enforce=[],
        memory_exempt=[],
        native_threads=4,
        rc_debug_codegen=False,
        native_debug=False,
        opt_level=2,
        dump_ir_path="",
        debug_ir=False,
        rc_stats=False,
        nogc_debug=False
    );
}

impl kernel_plan(
    prog: (JacProgram | None) = None,
    mode: str = "",
    target: (KernelTarget | None) = None,
    spec: (TargetSpec | None) = None
) -> LinkPlan {
    program = prog if prog is not None else JacProgram();
    options = kernel_options(spec);
    root_path = target.root_module_path() if target is not None else kernel_root_path();
    return build_link_plan(program, [root_path], options, mode=mode, native_unit=True);
}

impl _sha256_file(path: str) -> str {
    import from jaclang.jac0core.cache_paths { file_sha256 }
    return file_sha256(path);
}

impl _unit_label(path: str) -> str {
    try {
        return os.path.relpath(path, os.path.dirname(jaclang_pkg_root()));
    } except ValueError {
        return path;
    }
}

impl unit_drift(
    sidecar: dict[str, any],
    recorded: dict[str, any],
    units: list[str],
    spec: (TargetSpec | None) = None
) -> list[str] {
    options = kernel_options(spec);
    drift: list[str] = [];
    if str(sidecar.get("compiler_digest", ""))
        not in (
            running_compiler_digest(),
            native_producer_digest(options.kernel_build)
        ) {
        drift.append("the compiler's native ABI changed");
    }
    if str(sidecar.get("codegen_identity", "")) != options.base_codegen_identity() {
        drift.append("native code generation changed");
    }
    triple = options.effective_triple();
    if str(sidecar.get("triple", "")) != triple {
        drift.append(
            f"built for {sidecar.get('triple') or 'another target'}, not {triple}"
        );
    }
    python = f"{sys.version_info.major}.{sys.version_info.minor}";
    if str(sidecar.get("python", "")) != python {
        drift.append(f"built for Python {sidecar.get('python') or '?'}, not {python}");
    }
    ids = sidecar.get("unit_ids");
    idents = (
        [str(i) for i in ids]
            if isinstance(ids, list) and len(ids) == len(units)
            else [native_unit_identity(u) for u in units]
    );
    if len(recorded) != len(idents) {
        drift.append("the kernel's unit set changed");
        return drift;
    }
    policy = sidecar.get("unit_policy");
    recorded_policy: dict[str, any] = policy if isinstance(policy, dict) else {};
    for (ident, path) in zip(idents, units) {
        if recorded.get(ident) != unit_source_digest(path) {
            drift.append(f"{_unit_label(path)} changed");
        } elif int(recorded_policy.get(ident, 0))
            != int(options.native_required_for(path)) {
            drift.append(f"{_unit_label(path)} changed native placement");
        }
    }
    return drift;
}

impl _inspect(
    lib_path: str, expected_sha: str = "", spec: (TargetSpec | None) = None
) -> tuple[(dict[str, any] | None), list[str]] {
    sidecar = read_sidecar(lib_path);
    if sidecar is None or not os.path.isfile(lib_path) {
        return (None, [NOT_BUILT]);
    }
    try {
        actual = _sha256_file(lib_path);
    } except OSError as e {
        return (None, [f"the kernel is unreadable ({e})"]);
    }
    if actual != (expected_sha or sidecar.get("artifact_sha256")) {
        return (None, ["the kernel does not match the hash its record carries"]);
    }

    units = sidecar_unit_paths(sidecar);
    recorded = sidecar.get("unit_sources");
    if not units or not isinstance(recorded, dict) or not recorded {
        return (None, ["the kernel's record names no unit sources"]);
    }
    drift = unit_drift(sidecar, recorded, units, spec);
    return ((None if drift else sidecar), drift);
}

impl _bundled_kernel -> tuple[str, dict[str, any]] | None {
    found = kit_image();
    if found is None {
        return None;
    }
    (site_pkg, image) = found;
    record = image.native_artifact();
    if not record {
        return None;
    }
    return (os.path.join(site_pkg, str(record.get("path", ""))), dict(record));
}

impl _probe(
    lib_path: str,
    source: Source,
    expected_sha: str = "",
    spec: (TargetSpec | None) = None
) -> Probe {
    (sidecar, drift) = _inspect(lib_path, expected_sha=expected_sha, spec=spec);
    if sidecar is not None {
        return Probe.hit(source, lib_path, sidecar);
    }
    return Probe.missing() if drift == [NOT_BUILT] else Probe.stale(drift);
}

impl KernelArtifact.unavailable_reason -> str {
    try {
        import from jaclang.compiler.driver.toolchain { native_pipeline_available }
        (ok, why) = native_pipeline_available();
    } except Exception as e {
        return f"the native toolchain is unavailable ({e})";
    }
    return "" if ok else (why or "the native toolchain is unavailable");
}

impl KernelArtifact.probe_sealed -> (Probe | None) {
    if not self.for_host() {
        return None;
    }
    sealed = _from_sealed_image();
    if sealed is None {
        return None;
    }
    record = dict(read_sidecar(sealed.lib_path) or {});
    record["plan_digest"] = sealed.plan_digest;
    return Probe.hit(Source.SEALED, sealed.lib_path, record);
}

impl KernelArtifact.probe_checkout -> Probe {
    spec = self.spec();
    return _probe(kernel_path_for(spec), Source.CHECKOUT, spec=spec);
}

impl KernelArtifact.probe_kit -> Probe {
    if not self.for_host() {
        return Probe.missing("a kit carries only its own target's kernel");
    }
    found = _bundled_kernel();
    if found is None {
        return Probe.missing("this process runs on no kit that carries one");
    }
    (lib_path, record) = found;
    return _probe(lib_path, Source.KIT, expected_sha=str(record.get("sha256", "")));
}

impl KernelArtifact.checkout_path -> str {
    return kernel_path_for(self.spec());
}

impl KernelArtifact.spec -> TargetSpec {
    return target_spec(self.variant) if self.variant else host_target_spec();
}

impl KernelArtifact.for_host -> bool {
    return self.spec().osarch == host_target_spec().osarch;
}

impl KernelArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    if exact {
        import from jaclang.compiler.driver.jir { require_exact_compiler_products }
        require_exact_compiler_products();
    }
    spec = self.spec();
    build_kernel(kernel_path_for(spec), log=log, spec=spec);
}

impl refuse_unloadable {
    failed = load_failure();
    if failed is None {
        return;
    }
    (lib_path, source, err) = failed;
    if source in ("sealed", "kit") {
        remedy = "this jac installation is damaged; reinstall jac";
    } else {
        remedy = (
            "rebuild it with `jac native build kernel --force`, or delete "
            f"{lib_path} and {lib_path}{LAYOUT_SIDECAR_SUFFIX} to compile on the "
            "bytecode compiler"
        );
    }
    raise KernelLoadError(
        "jac: the native compiler kernel cannot be loaded\n"
        f"  kernel: {lib_path}\n"
        f"  error:  {err}\n"
        f"  fix:    {remedy}"
    );
}

impl resolve_kernel -> (ResolvedKernel | None) {
    found = resolve("kernel").found;
    if found is None {
        return None;
    }
    return ResolvedKernel(
        lib_path=found.path,
        layout=found.record["classes"],
        source=found.source.value,
        plan_digest=str(found.record.get("plan_digest", ""))
    );
}

impl build_kernel(
    dst: str = "",
    log: (Callable[[str], None] | None) = None,
    link_mode: str = KERNEL_LINK_MODE,
    spec: (TargetSpec | None) = None
) -> LinkResult {
    import shutil;
    destination = dst or source_tree_kernel_path();
    staging = os.path.join(
        os.path.dirname(os.path.abspath(destination)), f".kernel-build.{os.getpid()}"
    );
    os.makedirs(staging, exist_ok=True);
    tmp = os.path.join(staging, os.path.basename(destination));
    try {
        result = link_kernel(tmp, log=log, link_mode=link_mode, spec=spec);
        publish(tmp, destination, companions=(LAYOUT_SIDECAR_SUFFIX, ));
        result.output_path = destination;
    } finally {
        shutil.rmtree(staging, ignore_errors=True);
    }
    return result;
}
