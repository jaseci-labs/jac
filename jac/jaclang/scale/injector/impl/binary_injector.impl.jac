impl BinaryInjector.prepare(app_name: str, namespace: str, project_dir: str) {
    version = resolve_deploy_version(project_dir, self.channel.value);
    stage_admin_dist(
        project_dir,
        self.channel.value,
        resolve_console_version(project_dir, self.channel.value, version)
    );

    pod_arch = self._pod_arch or node_arch();
    payload = self._fetch_pod_binary(project_dir, pod_arch, version);
    self._pod_arch = pod_arch;
    self._seal_binary_bytes = self._resolve_seal_binary(payload, pod_arch, version);
    super.prepare(app_name, namespace, project_dir);
    self._adopt_pod_binary(app_name, pod_arch, payload);
}

impl BinaryInjector._fetch_pod_binary(
    project_dir: str, pod_arch: str, version: str
) -> bytes {
    if self.channel == Channel.LOCAL {
        return read_local_binary(project_dir);
    }
    return download_release_binary(self.channel.value, pod_arch, version);
}

impl BinaryInjector._adopt_pod_binary(app_name: str, pod_arch: str, payload: bytes) {
    self._pod_arch = pod_arch;
    self._pod_binary_sha256 = hashlib.sha256(payload).hexdigest();
    self._toolchain_bytes = pack_binary_bytes(payload);
    self._toolchain_object_key = toolchain_object_key(
        app_name, content_address(self._toolchain_bytes)
    );
}

impl BinaryInjector._resolve_seal_binary(
    pod_payload: bytes, pod_arch: str, version: str
) -> bytes {
    if self.channel == Channel.LOCAL {
        return pod_payload;
    }
    plat = host_seal_platform();
    arch = host_arch();
    if plat == "linux" and arch == pod_arch {
        return pod_payload;
    }
    return download_release_binary(self.channel.value, arch, version, plat);
}

impl BinaryInjector._seed_artifacts -> list[tuple[str, bytes]] {
    artifacts = super._seed_artifacts();
    artifacts.append((self._toolchain_object_key, self._toolchain_bytes));
    return artifacts;
}

impl BinaryInjector._unpack_bundle_paths -> list[str] {
    paths = super._unpack_bundle_paths();
    paths.append(bundle_pvc_path(self._toolchain_object_key));
    return paths;
}

impl BinaryInjector._skip_when_image_binary -> dict[str, str] {
    if not self._pod_binary_sha256 or not self._toolchain_object_key {
        return {};
    }
    return {bundle_pvc_path(self._toolchain_object_key): self._pod_binary_sha256};
}

impl BinaryInjector.write_build(out_dir: str, app_name: str) -> dict[str, any] {
    if not self._bundle_bytes or not self._pod_binary_sha256 {
        raise ValueError(
            "write_build() needs a prepared injector; there is no bundle or pod "
            "runtime to record."
        );
    }
    record: dict[str, any] = {
        "schema": BUILD_SCHEMA,
        "jac_version": resolve_cli_version().strip(),
        "channel": self.channel.value,
        "pod_arch": self._pod_arch,
        "app_name": app_name,
        "bundle_object_key": self._object_key,
        "bundle_sha256": content_address(self._bundle_bytes),
        "bundle_size": len(self._bundle_bytes),
        "pod_binary_sha256": self._pod_binary_sha256,
        "toolchain_object_key": self._toolchain_object_key,
        "config_sha256": config_digest(sealed_tomls(self._bundle_bytes))
    };
    target = os.path.abspath(out_dir);
    if os.path.islink(target)
        or (os.path.lexists(target) and not os.path.isdir(target)) {
        raise ValueError(
            f"{target} is not a directory `jac scale build` writes; remove it or "
            "choose another --out."
        );
    }
    if os.path.isdir(target) {
        foreign = sorted(
            name
            for name in os.listdir(target)
            if name != BUILD_RECORD
                and not BUILD_BUNDLE_PATTERN.fullmatch(name)
                and not name.startswith(_BUILD_TEMP_PREFIX)
        );
        if foreign {
            raise ValueError(
                f"{target} holds files `jac scale build` does not write "
                f"({', '.join(foreign[:_DRIFT_SHOWN])}); remove them or choose "
                "another --out."
            );
        }
    }
    os.makedirs(target, exist_ok=True);
    bundle_file = f"bundle-{record['bundle_sha256'][:16]}.jab";
    record["bundle_file"] = bundle_file;
    def publish(name: str, data: bytes) {
        (fd, temp) = tempfile.mkstemp(prefix=_BUILD_TEMP_PREFIX, dir=target);
        with os.fdopen(fd, "wb") as f {
            f.write(data);
        }
        os.chmod(temp, 0o644);
        os.replace(temp, os.path.join(target, name));
    }
    previous = "";
    try {
        with open(os.path.join(target, BUILD_RECORD), encoding="utf-8") as f {
            previous = str(json.load(f).get("bundle_file") or "");
        }
    } except (OSError, ValueError, AttributeError) {
        previous = "";
    }
    record_published = False;
    try {
        publish(bundle_file, self._bundle_bytes);
        publish(
            BUILD_RECORD,
            (json.dumps(record, indent=2, sort_keys=True) + "\n").encode("utf-8")
        );
        record_published = True;
    } finally {
        for name in os.listdir(target) {
            kept = bundle_file if record_published else previous;
            stale = name.startswith(_BUILD_TEMP_PREFIX)
                or (name != kept and BUILD_BUNDLE_PATTERN.fullmatch(name));
            if stale {
                os.unlink(os.path.join(target, name));
            }
        }
    }
    return record;
}

impl BinaryInjector.from_build(
    build_dir: str,
    app_name: str,
    project_dir: str,
    config_tomls: dict[str, str],
    pod_arch: str = "",
    storage_class: str = "",
    access_mode: str = "ReadWriteMany",
    dry_run: bool = False
) -> BinaryInjector {
    record_path = os.path.join(build_dir, BUILD_RECORD);
    if not os.path.isfile(record_path) {
        raise ValueError(
            f"{build_dir} holds no {BUILD_RECORD}; write a build there with "
            f"`jac scale build --out {build_dir}`."
        );
    }
    with open(record_path, encoding="utf-8") as f {
        record = json.load(f);
    }
    if not isinstance(record, dict) or record.get("schema") != BUILD_SCHEMA {
        raise ValueError(
            f"{record_path} is not a schema {BUILD_SCHEMA} build record; rebuild "
            "it with this jac."
        );
    }
    def field(name: str) -> str {
        return str(record.get(name) or "");
    }
    bundle_path = os.path.join(build_dir, field("bundle_file"));
    if not BUILD_BUNDLE_PATTERN.fullmatch(field("bundle_file"))
        or not os.path.isfile(bundle_path) {
        raise ValueError(
            f"{record_path} names no bundle file in {build_dir} "
            f"('{field('bundle_file')}'); rebuild it with `jac scale build`."
        );
    }
    with open(bundle_path, "rb") as f {
        raw = f.read();
    }
    digest = content_address(raw);
    if digest != field("bundle_sha256")
        or field("bundle_object_key") != bundle_object_key(field("app_name"), digest)
        or record.get("bundle_size") != len(raw) {
        raise ValueError(
            f"{bundle_path} (sha256 {digest}) is not the bundle {BUILD_RECORD} "
            f"records ({field('bundle_object_key')}); it changed after the build. "
            "Rebuild it with `jac scale build`."
        );
    }
    channel = resolve_dev_channel(project_dir);
    running = resolve_cli_version().strip();
    problems: list[str] = [];
    if field("jac_version") != running {
        problems.append(
            f"it was built by jac {field('jac_version')} and this is jac {running}"
        );
    }
    if field("app_name") != app_name {
        problems.append(
            f"it was built for app '{field('app_name')}' and this deploy is "
            f"'{app_name}'"
        );
    }
    if pod_arch and field("pod_arch") != pod_arch {
        problems.append(
            f"it was built for {field('pod_arch')} nodes and this deploy targets "
            f"{pod_arch}"
        );
    }
    if field("channel") != channel.value {
        problems.append(
            f"it was built on the '{field('channel')}' jac channel and this deploy "
            f"resolves '{channel.value}'"
        );
    }
    if field("config_sha256") != config_digest(config_tomls) {
        drift = config_drift(sealed_tomls(raw), config_tomls);
        problems.append(
            "the jac.toml files this deploy would ship differ from the ones sealed "
            "into the build "
                + (f"at {', '.join(drift)}" if drift else "in comments or layout only")
        );
    }
    if problems {
        raise ValueError(
            f"Refusing to deploy from {build_dir}: "
                + "; ".join(problems)
                + ". A deploy from a build never rebuilds; run `jac scale build` "
                "again for this deploy."
        );
    }
    injector = BinaryInjector(
        channel=channel, storage_class=storage_class, access_mode=access_mode
    );
    injector._object_key = field("bundle_object_key");
    injector._bundle_bytes = raw;
    if dry_run {
        injector._pod_arch = field("pod_arch");
        injector._pod_binary_sha256 = field("pod_binary_sha256");
        injector._toolchain_object_key = field("toolchain_object_key");
        return injector;
    }
    payload = injector._fetch_pod_binary(
        project_dir,
        field("pod_arch"),
        resolve_deploy_version(project_dir, channel.value)
    );
    injector._adopt_pod_binary(app_name, field("pod_arch"), payload);
    if injector._pod_binary_sha256 != field("pod_binary_sha256") {
        raise ValueError(
            f"The pod jac runtime this deploy fetched (sha256 "
            f"{injector._pod_binary_sha256}) is not the one {build_dir} was built "
            f"with ({field('pod_binary_sha256')}). Rebuild with `jac scale build`."
        );
    }
    return injector;
}

impl build_output_names -> list[str] {
    return [BUILD_RECORD, "bundle-0000000000000000.jab", f"{_BUILD_TEMP_PREFIX}0"];
}

impl config_digest(tomls: dict[str, str]) -> str {
    return hashlib.sha256(
        json.dumps(tomls, sort_keys=True).encode("utf-8")
    ).hexdigest();
}

impl config_drift(sealed: dict[str, str], applying: dict[str, str]) -> list[str] {
    def flat(tomls: dict[str, str]) -> dict[str, any] {
        out: dict[str, any] = {};
        def walk(rel: str, prefix: str, value: any) {
            if isinstance(value, dict) {
                for (key, item) in value.items() {
                    walk(rel, f"{prefix}.{key}" if prefix else str(key), item);
                }
            } else {
                out[f"{rel}: {prefix}"] = value;
            }
        }
        for (rel, text) in tomls.items() {
            walk(rel, "", tomllib.loads(text));
        }
        return out;
    }
    before = flat(sealed);
    after = flat(applying);
    absent = object();
    keys = sorted(
        key
        for key in set(before) | set(after)
        if before.get(key, absent) != after.get(key, absent)
    );
    if len(keys) > _DRIFT_SHOWN {
        return keys[:_DRIFT_SHOWN] + [f"{len(keys) - _DRIFT_SHOWN} more"];
    }
    return keys;
}

impl select_injector(
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str,
    dry_run: bool = False,
    access_mode: str = "ReadWriteMany",
    fleet: any = None,
    client_ready: any = None,
    bake_client: bool = False,
    pod_arch: str = ""
) -> tuple[BinaryInjector, str] {
    channel = resolve_dev_channel(project_dir);
    blurbs = {
        Channel.LOCAL: "shipping the local jac binary",
        Channel.DEV: "downloading the rolling `dev` (main HEAD) jac binary",
        Channel.STABLE: "downloading the latest published (stable) jac release",
        Channel.EXPERIMENTAL: "downloading the `dev` jac binary to seal .jir (pods run the PR's experimental image)"
    };
    if dry_run {
        injector = BinaryInjector(
            channel=channel,
            storage_class=storage_class,
            access_mode=access_mode,
            _fleet=fleet
        );
        injector._object_key = bundle_object_key(app_name, DRY_RUN_DIGEST);
        injector._toolchain_object_key = toolchain_object_key(app_name, DRY_RUN_DIGEST);
        console.print(
            f"dry-run: skipped preparing the '{channel.value}' jac runtime "
            f"({blurbs[channel]}); a real deploy computes the content digests."
        );
        return (injector, injector._toolchain_object_key);
    }
    try {
        console.print(f"Preparing the '{channel.value}' jac runtime for pods.");
        injector = BinaryInjector(
            channel=channel,
            storage_class=storage_class,
            access_mode=access_mode,
            _fleet=fleet,
            _client_ready=client_ready,
            _bake_client=bake_client,
            _pod_arch=pod_arch
        );
        injector.prepare(app_name, namespace, project_dir);
        console.print(f"Ready: {blurbs[channel]}.");
        return (injector, injector._toolchain_object_key);
    } except Exception as exc {
        logger.warning(f"[{channel.value}] binary prep failed: {exc}");
        raise RuntimeError(
            f"Could not prepare the '{channel.value}' jac runtime: {exc}. Check "
            "network access to github.com/jaseci-labs/jac releases (and "
            "JAC_NODE_ARCH for cross-arch nodes)."
        );
    }
}
