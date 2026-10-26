"""Write a JacPython build's build-details.json (PEP 739).

CPython's `make all` runs Tools/build/generate-build-details.py with the
interpreter it just built, and `make install` copies the file it writes into
the library directory. JacPython keeps no Tools/build: build_jacpython.zig
runs this generator with the pinned build-time CPython between those two
steps. The
values the upstream script reads from sysconfig come from the build's own
sysconfig data (the _sysconfigdata module in the build directory); those it
reads from the running interpreter (sys.version_info, sys.implementation and
importlib's suffix lists) are the host's, which is the same CPython release
built with the same configuration, as a cross build's build Python is.

    jac run scripts/jacpython/gen_build_details.jac \\
        --sysconfig <build dir>/_sysconfigdata_<...>.py --output <build dir>/build-details.json
"""
import argparse;
import importlib.machinery;
import json;
import os;
import sys;
import sysconfig;
import from pathlib { Path }

glob COMMAND: str = "scripts/jacpython/gen_build_details.jac",
     SCHEMA_VERSION: str = "1.0",
     VERSION_FIELDS: tuple[str, ...] = (
         "major",
         "minor",
         "micro",
         "releaselevel",
         "serial"
     );

def version_info_to_dict(version: any) -> dict[str, any] {
    return {field: getattr(version, field) for field in VERSION_FIELDS};
}

# The build_time_vars of a _sysconfigdata module, read without importing it.
def build_time_vars(path: Path) -> dict[str, any] {
    namespace: dict[str, any] = {};
    exec(compile(path.read_text(), str(path), "exec"), namespace);
    return namespace["build_time_vars"];
}

# generate-build-details.py's generate_data() for POSIX, with `config` in
# place of sysconfig.get_config_var. installed_base is the build's prefix:
# the interpreter that script runs from the build directory reports its
# configured prefix as sys.base_prefix.
def generate_data(config: dict[str, any]) -> dict[str, any] {
    prefix = config["prefix"];
    data: dict[str, any] = {
        "schema_version": SCHEMA_VERSION,
        "base_prefix": prefix,
        "base_interpreter": os.path.join(prefix, "bin", "python" + config["VERSION"]),
        "platform": sysconfig.get_platform(),
        "language": {
            "version": sysconfig.get_python_version(),
            "version_info": version_info_to_dict(sys.version_info)
        }
    };
    implementation = vars(sys.implementation).copy();
    implementation["version"] = version_info_to_dict(sys.implementation.version);
    if "_multiarch" in implementation {
        implementation["_multiarch"] = config.get("MULTIARCH");
    }
    data["implementation"] = implementation;
    abi: dict[str, any] = {"flags": list(config.get("ABIFLAGS", ""))};
    data["abi"] = abi;
    data["suffixes"] = {
        "source": importlib.machinery.SOURCE_SUFFIXES,
        "bytecode": importlib.machinery.BYTECODE_SUFFIXES,
        "extensions": importlib.machinery.EXTENSION_SUFFIXES
    };
    libdir: str = config["LIBDIR"];
    ldlibrary: str = config["LDLIBRARY"];
    library: str = config["LIBRARY"];
    py3library: str = config.get("PY3LIBRARY") or "";
    libpython: dict[str, any] = {};
    # LIBRARY is always the static library; LDLIBRARY is the shared one when
    # the build enables it.
    if ldlibrary != library {
        abi["extension_suffix"] = config.get("EXT_SUFFIX");
        for suffix in importlib.machinery.EXTENSION_SUFFIXES {
            if suffix.startswith(".abi") {
                abi["stable_abi_suffix"] = suffix;
                break;
            }
        }
        libpython["dynamic"] = os.path.join(libdir, ldlibrary);
        if py3library {
            libpython["dynamic_stableabi"] = os.path.join(libdir, py3library);
        }
        libpython["link_extensions"] = bool(config.get("LIBPYTHON"));
    }
    if config.get("STATIC_LIBPYTHON") {
        libpython["static"] = os.path.join(libdir, library);
    }
    if libpython {
        data["libpython"] = libpython;
    }
    c_api: dict[str, any] = {"headers": config.get("INCLUDEPY")};
    if config.get("LIBPC") {
        c_api["pkgconfig_path"] = config.get("LIBPC");
    }
    data["c_api"] = c_api;
    return data;
}

def main(argv: list[str]) {
    parser = argparse.ArgumentParser(
        prog=COMMAND, description="Write build-details.json for a JacPython build."
    );
    parser.add_argument(
        "--sysconfig", required=True, help="the build's _sysconfigdata module"
    );
    parser.add_argument("--output", required=True, help="the file to write");
    args = parser.parse_args(argv);
    config = build_time_vars(Path(args.sysconfig));
    if config["VERSION"] != sysconfig.get_python_version() {
        sys.exit(
            f"{COMMAND}: run with CPython {config['VERSION']}, the release this build "
            f"configured (running {sysconfig.get_python_version()})"
        );
    }
    output = Path(args.output);
    output.write_text(json.dumps(generate_data(config), indent=2) + "\n");
    print(f"{COMMAND}: wrote {output}");
}

with entry:__main__ {
    main(sys.argv[1:]);
}
