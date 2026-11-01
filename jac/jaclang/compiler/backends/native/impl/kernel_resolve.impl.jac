impl kernel_lib_name -> str {
    return host_target_spec().kernel_file_name();
}

impl kernel_dir -> str {
    return os.path.join(jaclang_pkg_root(), "compiler", KERNEL_DIR_NAME);
}

impl source_tree_kernel_path -> str {
    return os.path.join(kernel_dir(), kernel_lib_name());
}

impl kernel_path_for(spec: TargetSpec) -> str {
    if spec.osarch == host_target_spec().osarch {
        return source_tree_kernel_path();
    }
    return os.path.join(kernel_dir(), spec.osarch, spec.kernel_file_name());
}

impl _from_sealed_image -> (ResolvedKernel | None) {
    image = sealed._jaclang_image();
    if image is None {
        return None;
    }
    record = image.native_artifact() or {};
    if KERNEL_MODULE_NAME in sys.builtin_module_names {
        return ResolvedKernel(
            path=BUILTIN_KERNEL,
            source="sealed",
            plan_digest=str(record.get("plan_digest", ""))
        );
    }
    if not record {
        raise KernelLoadError(
            "jac: this sealed jac carries no compiler kernel; the installation is "
            "damaged, so reinstall jac"
        );
    }
    return ResolvedKernel(
        path=os.path.join(str(image.pkg_dir), str(record.get("path", ""))),
        source="sealed",
        plan_digest=str(record.get("plan_digest", ""))
    );
}

impl _probe(lib_path: str, source: Source) -> Probe {
    import from jaclang.jac0core.stage0 { NOT_BUILT, kernel_drift, read_record }
    import from pathlib { Path }
    drift = kernel_drift(Path(lib_path));
    if not drift {
        return Probe.hit(source, lib_path, read_record(Path(lib_path)) or {});
    }
    return Probe.missing() if drift == [NOT_BUILT] else Probe.stale(drift);
}

impl KernelArtifact.probe_sealed -> (Probe | None) {
    if not self.for_host() {
        return None;
    }
    sealed_kernel = _from_sealed_image();
    if sealed_kernel is None {
        return None;
    }
    return Probe.hit(
        Source.SEALED, sealed_kernel.path, {"plan_digest": sealed_kernel.plan_digest}
    );
}

impl KernelArtifact.probe_checkout -> Probe {
    return _probe(kernel_path_for(self.spec()), Source.CHECKOUT);
}

impl KernelArtifact.probe_kit -> Probe {
    return Probe.missing("a kit's kernel is its sealed image's");
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
    import from jaclang.jac0core.stage0 { Stage0Error, bootstrap, publish }
    import from pathlib { Path }
    if self.for_host() {
        try {
            bootstrap(force=force, log=log);
        } except Stage0Error as err {
            raise ArtifactUnavailable(f"kernel: stage 0 failed: {err}") from err;
        }
        return;
    }
    spec = self.spec();
    slot = kernel_path_for(spec);
    os.makedirs(os.path.dirname(slot), exist_ok=True);
    staged = os.path.join(os.path.dirname(slot), f".stage.{os.path.basename(slot)}");
    target_file = staged + ".target.json";
    write_kernel_target(running_kernel_target(), target_file);
    try {
        if build_target_kernel(target_file, staged, spec.triple, log) != 0 {
            raise ArtifactUnavailable(f"{self.name}: the kernel build request failed");
        }
        publish(
            Path(staged),
            Path(slot),
            f"built for {spec.osarch} by the kernel of {host_target_spec().osarch}"
        );
    } finally {
        for leftover in (
            target_file,
            staged,
            staged + ".build.json",
            staged + LAYOUT_SIDECAR_SUFFIX
        ) {
            if os.path.exists(leftover) {
                os.remove(leftover);
            }
        }
    }
}

impl Stage0Artifact.pin -> dict[str, str] {
    import from jaclang.jac0core.stage0 { stage0_pin }
    return stage0_pin();
}

impl Stage0Artifact.probe_checkout -> Probe {
    import from jaclang.jac0core.stage0 { Stage0Error, stage0_located }
    try {
        pin = self.pin();
    } except Stage0Error as err {
        return Probe.missing(str(err));
    }
    found = stage0_located(pin);
    if found is None {
        return Probe.missing(f"jac {pin['version']} is not provisioned");
    }
    return Probe.hit(Source.CACHE, str(found), {"version": pin["version"]});
}

impl Stage0Artifact.checkout_path -> str {
    import from jaclang.jac0core.stage0 { stage0_path }
    return str(stage0_path(self.pin()));
}

impl Stage0Artifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    import from jaclang.jac0core.stage0 { Stage0Error, provision_stage0 }
    try {
        provision_stage0(self.pin(), log);
    } except Stage0Error as err {
        raise ArtifactUnavailable(f"stage0: {err}") from err;
    }
}

impl require_kernel -> ResolvedKernel {
    try {
        found = require("kernel").found;
    } except ArtifactUnavailable as err {
        raise KernelLoadError(
            "jac: the compiler kernel is unavailable\n"
            f"  error:  {err}\n"
            "  fix:    run `jac native build kernel`"
        ) from err;
    }
    assert found is not None;
    return ResolvedKernel(
        path=found.path,
        source=found.source.value,
        plan_digest=str(found.record.get("plan_digest", ""))
    );
}

impl load_kernel -> any {
    import from jaclang.jac0core.stage0 { boot_kernel }
    return boot_kernel();
}

impl check_kernel_roster(spec: KernelTarget) {
    if os.path.realpath(spec.root) != os.path.realpath(jaclang_pkg_root()) {
        return;
    }
    running = running_kernel_target(spec.root);
    if roster_of(running) == roster_of(spec) {
        return;
    }
    roster_file = os.path.join(spec.root, KERNEL_ROSTER_REL);
    atomic_write(
        roster_file,
        (json.dumps(roster_of(running), indent=1, sort_keys=True) + "\n").encode()
    );
    raise KernelEntryError(
        f"the kernel roster changed: {roster_file} now records "
        "compiler/native_scope.jac's roster, and stage 1 was built from the old "
        "one; commit it and run `jac native build kernel` again"
    );
}

impl build_target_kernel(
    spec_path: str,
    output: str,
    triple: str = "",
    log: (Callable[[str], None] | None) = None
) -> int {
    import from jaclang.jac0core.stage0 { write_build }
    spec = read_kernel_target(spec_path);
    if spec is None {
        return STAGE0_UNKNOWN_FORMAT;
    }
    check_kernel_roster(spec);

    def quiet(line: str) {}

    say = log if log is not None else quiet;
    say(
        f"  Building the kernel of {spec.root} for {triple or host_target_spec().triple}"
    );
    result = call_build_kernel(
        KernelBuildRequest(
            target=spec,
            output=os.path.abspath(output),
            triple=triple,
            search_paths=list(sys.path),
            package_root=jaclang_pkg_root()
        )
    );
    for diagnostic in result.errors {
        say(
            f"{diagnostic.span.path}:{diagnostic.span.line}:{diagnostic.span.col}: "
            f"{diagnostic.code} {diagnostic.message}"
        );
    }
    if not result.ok() {
        return 1;
    }
    write_build(
        os.path.abspath(output),
        result.artifact_sha256,
        result.triple,
        [read.path for read in result.inputs]
    );
    say(
        f"  Kernel: {result.units} units, sha256 {result.artifact_sha256[:16]}, "
        f"plan {result.plan_digest[:16]}"
    );
    return 0;
}
