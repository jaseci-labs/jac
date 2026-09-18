import from pathlib { Path }
import from jaclang.cache.policy { Policy, Retention, SweepReport, KeepMatch, TempLock }

obj Bucket {
    has name: str,
        relpath: str,
        policy: Policy,
        summary: str = "",
        root_env: str = "",
        root_prefix: str = "";

    def path -> Path;
    def ensure -> Path;
    def is_external -> bool;
    def note_hit(item: Path) -> None;
}

obj BucketStatus {
    has name: str,
        path: Path,
        exists: bool,
        entries: int,
        size_bytes: int,
        policy: str,
        external: bool,
        summary: str = "";
}

obj PurgeReport {
    has removed: list[str] = [],
        reclaimed_bytes: int = 0,
        kept: list[str] = [],
        errors: list[str] = [];
}

glob RETIRED: tuple[str, ...] = (
         "seal-tests",
         "timing",
         "timing-baseline",
         "bytecode",
         "bootstrap",
         "toolchains/llvm-cbe",
         "toolchains/cocoapods"
     ),
     GENERATION_PATTERN: str = "[0-9a-f]" * 16,
     BUCKETS: list[Bucket] = [
         Bucket(
             name="rt",
             relpath="rt",
             policy=Policy(ttl_days=30.0, markers=[".used", ".ok"]),
             summary="fused-binary runtimes, one per payload hash"
         ),
         Bucket(
             name="jir-modules",
             relpath="jir/modules",
             policy=Policy(
                 ttl_days=14.0,
                 pattern=GENERATION_PATTERN + "|native|*.jir",
                 ttl_env="JAC_CACHE_GENERATION_TTL_DAYS"
             ),
             summary="compiled modules, one generation per compiler digest"
         ),
         Bucket(
             name="jir-bootstrap",
             relpath="jir/bootstrap",
             policy=Policy(ttl_days=14.0, max_entries=4000, pattern="*.jbc"),
             summary="marshalled bytecode of the bootstrap tier"
         ),
         Bucket(
             name="jir-stubcat",
             relpath="jir/stubcat",
             policy=Policy(ttl_days=14.0, pattern="*.bin"),
             summary="pre-resolved typeshed catalogs"
         ),
         Bucket(
             name="jir-kernel-units",
             relpath="jir/kernel_units",
             policy=Policy(ttl_days=14.0, keep_match=KeepMatch.FRAGMENT),
             summary="native kernel unit sources and their compiled artifacts"
         ),
         Bucket(
             name="jir-digests",
             relpath="jir",
             policy=Policy(ttl_days=14.0, pattern="compiler_digest.*.json"),
             summary="compiler source digests, one per checkout"
         ),
         Bucket(
             name="apps",
             relpath="apps",
             policy=Policy(ttl_days=30.0, markers=[".used"]),
             summary="materialized app images (.jab), content-keyed"
         ),
         Bucket(
             name="scale-binaries",
             relpath="scale-binaries",
             policy=Policy(ttl_days=30.0),
             summary="pinned jac release binaries for deploys",
             root_env="JAC_SCALE_CACHE_DIR",
             root_prefix="scale-binaries"
         ),
         Bucket(
             name="models",
             relpath="models",
             policy=Policy(retention=Retention.PINNED),
             summary="byLLM local model weights (user-consented downloads)",
             root_env="JAC_MODELS_DIR",
             root_prefix="models"
         ),
         Bucket(
             name="toolchains-downloads",
             relpath="toolchains/downloads",
             policy=Policy(
                 ttl_days=14.0, temp_patterns=["*.part"], temp_lock=TempLock.SUFFIX
             ),
             summary="verified toolchain archives (extracted into installed/)",
             root_env="JAC_TOOLCHAIN_DIR",
             root_prefix="toolchains"
         ),
         Bucket(
             name="toolchains-installed",
             relpath="toolchains/installed",
             policy=Policy(
                 ttl_days=90.0,
                 depth=3,
                 markers=[".jac-install.json"],
                 temp_patterns=[".install-*"],
                 temp_lock=TempLock.SIBLINGS
             ),
             summary="installed toolchains by name, version and platform",
             root_env="JAC_TOOLCHAIN_DIR",
             root_prefix="toolchains"
         ),
         Bucket(
             name="toolchains-build",
             relpath="toolchains/build",
             policy=Policy(
                 ttl_days=90.0,
                 depth=3,
                 markers=[".ready"],
                 temp_patterns=["tmp????????"],
                 temp_lock=TempLock.SIBLINGS
             ),
             summary="toolchain builds by source digest",
             root_env="JAC_TOOLCHAIN_DIR",
             root_prefix="toolchains"
         ),
         Bucket(
             name="toolchains-gradle",
             relpath="toolchains/gradle",
             policy=Policy(retention=Retention.EXTERNAL),
             summary="Gradle's own home (GRADLE_USER_HOME)",
             root_env="JAC_TOOLCHAIN_DIR",
             root_prefix="toolchains"
         ),
         Bucket(
             name="toolchains-android-sdk",
             relpath="toolchains/android-sdk",
             policy=Policy(retention=Retention.EXTERNAL),
             summary="the Android SDK (sdkmanager-managed)",
             root_env="JAC_TOOLCHAIN_DIR",
             root_prefix="toolchains"
         ),
         Bucket(
             name="pg",
             relpath="pg",
             policy=Policy(retention=Retention.EXTERNAL),
             summary="the embedded Postgres cluster and distribution (jac db)"
         )
     ];

def bucket(name: str) -> Bucket;

def managed_buckets -> list[Bucket];
def external_buckets -> list[Bucket];

def maybe_sweep(name: str, keep: set[str] | None = None, force: bool = False) -> bool;

def status -> list[BucketStatus];

def unmanaged -> list[tuple[str, int]];

def gc(
    dry_run: bool = False, live: dict[str, set[str]] | None = None
) -> list[SweepReport];

def purge(
    names: list[str] | None = None,
    dry_run: bool = False,
    live: dict[str, set[str]] | None = None
) -> PurgeReport;
