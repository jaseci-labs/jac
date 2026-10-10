"""Bundled native ``platform`` cross-backend equivalence fixture.

The SAME `import platform` / `import from platform { ... }` binds CPython's
``platform`` on the sv (Python) backend and the bundled
`na_stdlib/platform.jac` Mechanism-B module (over the per-OS
`_platform_native.<os>.jac` uname(2)/libc FFI floor) on the na (native LLVM)
backend. Every pinned value is host-derived rather than constant, but both
lanes run on the same host and probe the same sources -- uname(2) fields for
system/node/release/version/machine, the `uname -p` subprocess for processor
(with CPython 3.14's "unknown"->'' blanking), confstr/gnu_get_libc_version
for libc_ver, and the '64bit'/'ELF' architecture pair -- so the lanes agree.
``python_version`` is the exception: the native module carries a fixed
"3.14.x" claim matching the bundled sv runtime's major.minor, so only the
major/minor tuple members and the version<->tuple self-consistency are
pinned, not the patchlevel. ``node`` and ``platform`` are reached
module-qualified because `node` is a Jac keyword (the bundled module exports
it under a `` `node `` escape) and `platform` would shadow the module name;
the ``uname()`` result is compared field by field because the na surface is
an archetype, not a namedtuple. ES/JS opts out.
"""

import platform;
import from platform {
    system,
    release,
    version,
    machine,
    processor,
    uname,
    architecture,
    libc_ver,
    python_version,
    python_version_tuple
}


def platform_py -> dict[any, any] {
    u = uname();
    vt = python_version_tuple();
    arch = architecture();
    libc = libc_ver();
    d: dict[any, any] = {
        "system": system(),
        "node": platform.node(),
        "release": release(),
        "version": version(),
        "machine": machine(),
        "processor": processor(),
        "u_system": u.system,
        "u_node": u.node,
        "u_release": u.release,
        "u_version": u.version,
        "u_machine": u.machine,
        "u_processor": u.processor,
        "uname_self": u.system == system(),
        "arch": arch[0] + "|" + arch[1],
        "libc": libc[0] + "|" + libc[1],
        "platform": platform.platform(),
        "platform_terse": platform.platform(terse=True),
        "platform_aliased": platform.platform(aliased=True),
        "pyver_self": (vt[0] + "." + vt[1] + "." + vt[2]) == python_version(),
        "pyv_major": vt[0],
        "pyv_minor": vt[1],
        "pyv_len": len([vt[0], vt[1], vt[2]])
    };
    return d;
}


def platform_cl -> dict[any, any] {
    return {};
}


def platform_na -> dict[str, any] {
    u = uname();
    vt = python_version_tuple();
    arch = architecture();
    libc = libc_ver();
    d: dict[str, any] = {
        "system": system(),
        "node": platform.node(),
        "release": release(),
        "version": version(),
        "machine": machine(),
        "processor": processor(),
        "u_system": u.system,
        "u_node": u.node,
        "u_release": u.release,
        "u_version": u.version,
        "u_machine": u.machine,
        "u_processor": u.processor,
        "uname_self": u.system == system(),
        "arch": arch[0] + "|" + arch[1],
        "libc": libc[0] + "|" + libc[1],
        "platform": platform.platform(),
        "platform_terse": platform.platform(terse=True),
        "platform_aliased": platform.platform(aliased=True),
        "pyver_self": (vt[0] + "." + vt[1] + "." + vt[2]) == python_version(),
        "pyv_major": vt[0],
        "pyv_minor": vt[1],
        "pyv_len": len([vt[0], vt[1], vt[2]])
    };
    return d;
}
