"""Stage 0 of the compiler kernel, and the kernel every jac process boots on.

The kernel is the only compiler, so no ``.jac`` module (the CLI included) can
load until a kernel is loaded. This module is therefore plain Python with no
``.jac`` imports, like its siblings ``sealed.py`` and ``cache_paths.py``.

Booting: a release links the kernel into the interpreter (``jac_kernel`` is a
built-in module); a kit or sealed image carries it as the native artifact its
manifest names; a checkout loads the one ``jac native build kernel`` placed in
``compiler/_kernel``. A missing or stale checkout kernel is an error naming
that command: nothing falls back to another compiler.

Stage 0: a checkout's kernel is built by the previous release, pinned in
``bootstrap/pins.json`` (``stage0``). Its built-in kernel compiles this tree's
kernel units (stage 1); the new kernel rebuilds itself (stage 2) and again
(stage 3), and stages 2 and 3 must be byte-identical. Every stage is the same
build request, ``jac native build kernel --target-spec SPEC --output OUT``,
which every release and every checkout answers with its loaded kernel; it
writes ``OUT`` and ``OUT.build.json`` (the artifact's sha256, its target
triple and the sources the build read).

A published kernel carries a record, ``<kernel>.record.json``: the digest of
every source the build read, so the boot can tell when the kernel no longer
matches its sources.
"""

from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import os
import platform
import subprocess
import sys
import types
import urllib.request
from pathlib import Path
from typing import Any, Callable

from jaclang.jac0core import sealed
from jaclang.jac0core.cache_paths import FileLock, atomic_write, file_sha256, get_cache_home

KERNEL_MODULE = "jac_kernel"
KERNEL_DIR_NAME = "_kernel"
LAYOUT_SUFFIX = ".layout.json"
RECORD_SUFFIX = ".record.json"
BUILD_SUFFIX = ".build.json"
RECORD_FORMAT = 1
BUILD_FORMAT = 1
KERNEL_TARGET_FORMAT = 1
ROSTER_REL = ("compiler", "kernel_roster.json")
ROSTER_FIELDS = (
    "root_module",
    "scope_modules",
    "kernel_unit_rel",
    "native_lowered_rel",
    "native_only_rel",
    "native_host_rel",
)
NOT_BUILT = "not built"
FIX = "run `jac native build kernel`"


class KernelUnavailable(SystemExit):
    """No kernel this process can boot on; the message names the fix."""


class Stage0Error(RuntimeError):
    """Stage 0 could not build the kernel; the message says which stage failed."""


def package_root() -> Path:
    """The jaclang package this module belongs to."""
    return Path(__file__).resolve().parent.parent


def host_osarch() -> str:
    """The release platform name of this host, e.g. ``linux-x86_64``."""
    machine = platform.machine().lower()
    arch = "aarch64" if machine in ("aarch64", "arm64") else "x86_64"
    if sys.platform == "darwin":
        return f"macos-{arch}"
    if sys.platform == "win32":
        return f"windows-{arch}"
    return f"linux-{arch}"


def kernel_file_name(osarch: str) -> str:
    return "jac_kernel.pyd" if osarch.startswith("windows") else "jac_kernel.so"


def slot_path(osarch: str = "", pkg: Path | None = None) -> Path:
    """Where this package keeps the kernel for ``osarch`` (default: this host)."""
    root = (pkg or package_root()) / "compiler" / KERNEL_DIR_NAME
    target = osarch or host_osarch()
    if target == host_osarch():
        return root / kernel_file_name(target)
    return root / target / kernel_file_name(target)


def python_version() -> str:
    return f"{sys.version_info.major}.{sys.version_info.minor}"


def process_executable() -> str:
    """The running jac binary, which stage 2 and stage 3 run again."""
    if sys.platform.startswith("linux"):
        return os.path.realpath("/proc/self/exe")
    if sys.platform == "darwin":
        import ctypes

        size = ctypes.c_uint32(0)
        libc = ctypes.CDLL(None)
        libc._NSGetExecutablePath(None, ctypes.byref(size))
        buf = ctypes.create_string_buffer(size.value)
        if libc._NSGetExecutablePath(buf, ctypes.byref(size)) == 0:
            return os.path.realpath(buf.value.decode())
        raise Stage0Error("cannot find the running jac binary")
    return os.path.realpath(sys.executable)


# ---------------------------------------------------------------------------
# The record: what a published kernel was built from
# ---------------------------------------------------------------------------


def _record_key(path: str, pkg: Path) -> str:
    real = os.path.realpath(path)
    base = os.path.realpath(pkg.parent) + os.sep
    return real[len(base):].replace(os.sep, "/") if real.startswith(base) else real


def _record_path(key: str, pkg: Path) -> str:
    return key if os.path.isabs(key) else str(pkg.parent / key)


def read_build(output: Path) -> dict[str, Any]:
    """The ``OUT.build.json`` a build request wrote beside its kernel."""
    side = Path(str(output) + BUILD_SUFFIX)
    try:
        data = json.loads(side.read_bytes())
    except (OSError, ValueError) as exc:
        raise Stage0Error(f"{side}: the build request left no readable result ({exc})") from exc
    if not isinstance(data, dict) or data.get("format") != BUILD_FORMAT:
        raise Stage0Error(f"{side}: not a format-{BUILD_FORMAT} build result")
    actual = file_sha256(str(output))
    if actual != data.get("artifact_sha256"):
        raise Stage0Error(f"{output} does not match the sha256 its build result records")
    return data


def write_build(output: str, artifact_sha256: str, triple: str, inputs: list[str]) -> None:
    """Write the result of a build request (``jac native build kernel --target-spec``)."""
    data = {
        "format": BUILD_FORMAT,
        "artifact_sha256": artifact_sha256,
        "triple": triple,
        "inputs": sorted(set(inputs)),
    }
    atomic_write(output + BUILD_SUFFIX, json.dumps(data, indent=1, sort_keys=True).encode())


def publish(output: Path, slot: Path, producer: str, pkg: Path | None = None) -> None:
    """Install a built kernel into ``slot`` with its layout and record."""
    root = pkg or package_root()
    build = read_build(output)
    record = {
        "format": RECORD_FORMAT,
        "artifact_sha256": build["artifact_sha256"],
        "triple": build["triple"],
        "python": python_version(),
        "producer": producer,
        "inputs": {
            _record_key(path, root): file_sha256(path) for path in build["inputs"]
        },
    }
    slot.parent.mkdir(parents=True, exist_ok=True)
    with FileLock(str(slot) + ".lock"):
        atomic_write(slot, output.read_bytes(), mode=0o755)
        layout = Path(str(output) + LAYOUT_SUFFIX)
        if layout.is_file():
            atomic_write(str(slot) + LAYOUT_SUFFIX, layout.read_bytes(), mode=0o644)
        atomic_write(
            str(slot) + RECORD_SUFFIX,
            json.dumps(record, indent=1, sort_keys=True).encode(),
            mode=0o644,
        )


def read_record(slot: Path) -> dict[str, Any] | None:
    try:
        data = json.loads(Path(str(slot) + RECORD_SUFFIX).read_bytes())
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as exc:
        raise KernelUnavailable(
            f"jac: the kernel record {slot}{RECORD_SUFFIX} is unreadable ({exc})\n  fix:    {FIX}"
        ) from exc
    if not isinstance(data, dict) or data.get("format") != RECORD_FORMAT:
        raise KernelUnavailable(
            f"jac: the kernel record {slot}{RECORD_SUFFIX} is not format {RECORD_FORMAT}\n"
            f"  fix:    {FIX}"
        )
    return data


def kernel_drift(slot: Path, pkg: Path | None = None) -> list[str]:
    """Why the kernel in ``slot`` does not match its sources; empty when current."""
    root = pkg or package_root()
    record = read_record(slot)
    if record is None or not slot.is_file():
        return [NOT_BUILT]
    if file_sha256(str(slot)) != record.get("artifact_sha256"):
        return ["the kernel does not match the sha256 its record carries"]
    drift: list[str] = []
    if record.get("python") != python_version():
        drift.append(f"built for Python {record.get('python')}, not {python_version()}")
    inputs = record.get("inputs")
    if not isinstance(inputs, dict) or not inputs:
        return drift + ["the kernel's record names no sources"]
    for key, digest in sorted(inputs.items()):
        path = _record_path(key, root)
        if not os.path.isfile(path):
            drift.append(f"{key} is gone")
        elif file_sha256(path) != digest:
            drift.append(f"{key} changed")
    return drift


# ---------------------------------------------------------------------------
# Booting
# ---------------------------------------------------------------------------


def _load_extension(path: Path) -> types.ModuleType:
    loader = importlib.machinery.ExtensionFileLoader(KERNEL_MODULE, str(path))
    spec = importlib.util.spec_from_file_location(KERNEL_MODULE, str(path), loader=loader)
    if spec is None:
        raise KernelUnavailable(f"jac: {path} is not a loadable kernel\n  fix:    {FIX}")
    module = importlib.util.module_from_spec(spec)
    try:
        loader.exec_module(module)
    except ImportError as exc:
        raise KernelUnavailable(
            f"jac: the compiler kernel cannot be loaded\n  kernel: {path}\n"
            f"  error:  {exc}\n  fix:    {FIX}"
        ) from exc
    sys.modules[KERNEL_MODULE] = module
    return module


def _image_kernel(image: sealed.SealedImage) -> types.ModuleType:
    if KERNEL_MODULE in sys.builtin_module_names:
        return importlib.import_module(KERNEL_MODULE)
    record = image.native_artifact()
    if not record:
        raise KernelUnavailable(
            f"jac: the sealed image {image.pkg_dir} carries no compiler kernel; "
            "the installation is damaged, so reinstall jac"
        )
    path = Path(image.pkg_dir) / str(record["path"])
    if not path.is_file() or file_sha256(str(path)) != record.get("sha256"):
        raise KernelUnavailable(
            f"jac: the compiler kernel {path} does not match its sealed image; "
            "the installation is damaged, so reinstall jac"
        )
    return _load_extension(path)


def boot_kernel() -> types.ModuleType:
    """The kernel this process compiles with, loaded once.

    A sealed image's kernel is trusted by its manifest; a checkout's must
    match the sources its record names.
    """
    loaded = sys.modules.get(KERNEL_MODULE)
    if loaded is not None:
        return loaded
    image = sealed._jaclang_image()
    if image is not None:
        return _image_kernel(image)
    slot = slot_path()
    drift = kernel_drift(slot)
    if drift == [NOT_BUILT]:
        raise KernelUnavailable(
            f"jac: this checkout has no compiler kernel ({slot})\n  fix:    {FIX}"
        )
    if drift:
        listed = "\n".join(f"          - {line}" for line in drift[:8])
        more = f"\n          ... and {len(drift) - 8} more" if len(drift) > 8 else ""
        raise KernelUnavailable(
            f"jac: the compiler kernel is stale ({slot})\n{listed}{more}\n  fix:    {FIX}"
        )
    return _load_extension(slot)


# ---------------------------------------------------------------------------
# The stage-0 release
# ---------------------------------------------------------------------------


def pins_file(pkg: Path | None = None) -> Path:
    """The pins a payload stages beside its tools, else the checkout's."""
    root = pkg or package_root()
    staged = root / "dist" / "payload" / "pins.json"
    return staged if staged.is_file() else root.parent / "bootstrap" / "pins.json"


def stage0_pin(osarch: str = "") -> dict[str, str]:
    """The pinned previous release for ``osarch``: version, url and sha256."""
    path = pins_file()
    try:
        pin = json.loads(path.read_bytes())["stage0"]
    except (OSError, ValueError, KeyError) as exc:
        raise Stage0Error(f"{path}: no readable `stage0` pin ({exc})") from exc
    target = osarch or host_osarch()
    version = str(pin["version"])
    digest = str(pin["assets"].get(target, {}).get("sha256", ""))
    if not digest:
        raise Stage0Error(
            f"{path}: stage 0 (jac {version}) has no pinned sha256 for {target}; "
            "see the `stage0` comment there for how the pin is bumped"
        )
    asset = f"jac-{version}-{target}"
    return {
        "version": version,
        "osarch": target,
        "asset": asset,
        "url": f"{pin['release_base'].rstrip('/')}/v{version}/{asset}",
        "sha256": digest,
    }


def stage0_path(pin: dict[str, str]) -> Path:
    return get_cache_home() / "stage0" / pin["version"] / pin["asset"]


def stage0_located(pin: dict[str, str]) -> Path | None:
    """The pinned release binary when it is on disk and matches its pin."""
    path = stage0_path(pin)
    if path.is_file() and file_sha256(str(path)) == pin["sha256"]:
        return path
    return None


def provision_stage0(pin: dict[str, str], log: Callable[[str], None]) -> Path:
    """Download the pinned release binary once and check it against its pin."""
    found = stage0_located(pin)
    if found is not None:
        return found
    path = stage0_path(pin)
    with FileLock(str(path) + ".lock"):
        found = stage0_located(pin)
        if found is not None:
            return found
        log(f"  fetching stage 0: {pin['url']}")
        try:
            with urllib.request.urlopen(pin["url"], timeout=300) as response:
                data = response.read()
        except OSError as exc:
            raise Stage0Error(f"cannot download stage 0 from {pin['url']}: {exc}") from exc
        import hashlib

        actual = hashlib.sha256(data).hexdigest()
        if actual != pin["sha256"]:
            raise Stage0Error(
                f"{pin['url']} has sha256 {actual}, not the pinned {pin['sha256']}"
            )
        atomic_write(path, data, mode=0o755)
    return path


# ---------------------------------------------------------------------------
# The bootstrap
# ---------------------------------------------------------------------------


def target_spec(pkg: Path) -> dict[str, Any]:
    """The KernelTarget for ``pkg``, from its checked-in kernel roster."""
    roster_file = pkg.joinpath(*ROSTER_REL)
    try:
        roster = json.loads(roster_file.read_bytes())
    except (OSError, ValueError) as exc:
        raise Stage0Error(f"{roster_file}: no readable kernel roster ({exc})") from exc
    spec: dict[str, Any] = {"format": KERNEL_TARGET_FORMAT, "root": str(pkg), "link_mode": ""}
    for name in ROSTER_FIELDS:
        if name not in roster:
            raise Stage0Error(f"{roster_file}: the roster has no `{name}`")
        spec[name] = roster[name]
    return spec


def _run_stage(
    label: str, binary: str, spec: Path, output: Path, log: Callable[[str], None]
) -> None:
    argv = [
        binary, "native", "build", "kernel",
        "--target-spec", str(spec), "--output", str(output),
    ]
    log(f"  {label}: {' '.join(argv)}")
    done = subprocess.run(argv)
    if done.returncode != 0:
        raise Stage0Error(f"{label} failed (`{' '.join(argv)}` exited {done.returncode})")
    read_build(output)


def bootstrap(force: bool = False, log: Callable[[str], None] | None = None) -> Path:
    """Build this checkout's kernel from the pinned previous release."""
    say = log or (lambda line: print(line, file=sys.stderr, flush=True))
    pkg = package_root()
    slot = slot_path(pkg=pkg)
    if not force and not kernel_drift(slot, pkg):
        say(f"kernel: current ({slot})")
        return slot
    pin = stage0_pin()
    stage0 = provision_stage0(pin, say)
    host = process_executable()
    slot.parent.mkdir(parents=True, exist_ok=True)
    with FileLock(str(slot.parent / ".bootstrap.lock")):
        spec = slot.parent / ".stage-target.json"
        staged = [slot.parent / f".stage{n}.{slot.name}" for n in (1, 2, 3)]
        try:
            spec.write_text(json.dumps(target_spec(pkg), indent=1, sort_keys=True))
            _run_stage(f"stage 1 (jac {pin['version']})", str(stage0), spec, staged[0], say)
            publish(staged[0], slot, f"stage 1, built by jac {pin['version']}", pkg)
            _run_stage("stage 2 (the new kernel)", host, spec, staged[1], say)
            publish(staged[1], slot, f"stage 2, built by stage 1 of jac {pin['version']}", pkg)
            _run_stage("stage 3 (the rebuilt kernel)", host, spec, staged[2], say)
            two = read_build(staged[1])["artifact_sha256"]
            three = read_build(staged[2])["artifact_sha256"]
            if two != three:
                for leftover in (slot, Path(str(slot) + RECORD_SUFFIX)):
                    leftover.unlink(missing_ok=True)
                raise Stage0Error(
                    "the kernel does not reproduce itself: stage 2 built "
                    f"{two} and stage 3 built {three} from the same sources"
                )
        finally:
            for path in [spec] + staged:
                for leftover in (path, Path(str(path) + BUILD_SUFFIX), Path(str(path) + LAYOUT_SUFFIX)):
                    leftover.unlink(missing_ok=True)
    say(f"kernel: {slot} (stage 2 == stage 3, sha256 {two[:16]})")
    return slot


def requested_bootstrap(argv: list[str]) -> bool | None:
    """``--force`` when ``argv`` asks for this host's kernel to be bootstrapped.

    Only ``jac native build kernel [--force]`` does; a build request
    (``--target-spec``) or another target's kernel (``kernel@os-arch``) runs on
    the booted kernel instead. None when ``argv`` asks for something else.
    """
    args = argv[1:]
    if args[:3] != ["native", "build", "kernel"]:
        return None
    rest = args[3:]
    if any(flag not in ("--force", "-f") for flag in rest):
        return None
    return bool(rest)


def run_requested_bootstrap(argv: list[str]) -> None:
    """Run stage 0 when ``argv`` asks for it, and exit; otherwise return."""
    force = requested_bootstrap(argv)
    if force is None or sealed._jaclang_image() is not None:
        return
    try:
        bootstrap(force=force)
    except Stage0Error as exc:
        raise SystemExit(f"jac: stage 0 failed\n  error:  {exc}") from exc
    raise SystemExit(0)
