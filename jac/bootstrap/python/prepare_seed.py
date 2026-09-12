"""Build the JacPython seed with the explicitly pinned build-time interpreter.

This program is never shipped as a runtime compiler. Export uses the checkout's
Jac compiler; capture records initialization under the instrumented host Python.
The resulting image contains bytecode and a finite startup-request table.
"""
import sys

# Capture starts before importing the build driver's own dependencies: imports
# such as functools create code dynamically (namedtuple), not only from files.
_startup_requests = {}
_host_compile = compile


def _record_startup(source, filename, mode, flags=0, dont_inherit=False, optimize=-1, *, _feature_version=-1):
    sys._jacpython_compile = None
    try:
        code = _host_compile(source, filename, mode, flags, dont_inherit=True,
                             optimize=optimize, _feature_version=_feature_version)
    finally:
        sys._jacpython_compile = _record_startup
    effective = sys.flags.optimize if optimize == -1 else optimize
    _startup_requests[source, mode, flags, effective, _feature_version] = code
    return code


if sys.argv[1] == "capture":
    sys._jacpython_compile = _record_startup

import builtins
import hashlib
import json
import marshal
import os
from pathlib import Path
import subprocess
import tempfile
import types
import zlib

mode, root_arg, output_arg = sys.argv[1:4]
root = Path(root_arg).resolve()
output = Path(output_arg).resolve()
recipe = root / "bootstrap/python"
pin = json.loads((recipe / "sources.json").read_text())["cpython"]
if tuple(map(int, pin["version"].split("."))) != sys.version_info[:3]:
    raise RuntimeError("The seed must be generated with pinned CPython " + pin["version"])
if not hasattr(sys, "_jacpython_code"):
    raise RuntimeError("The seed requires the instrumented, source-built host interpreter")
sys.path.insert(0, str(root))
os.environ["JAC_NO_DEV_SOURCE"] = "1"
os.environ["JAC_STUBCAT_BUILDING"] = "1"
os.environ["JAC_COMPILER_LIB"] = "off"


def normalized_code(code):
    filename = code.co_filename
    for prefix, label in ((str(root) + "/", ""), (sys.base_prefix + "/", "stdlib/")):
        if filename.startswith(prefix):
            filename = "<jacpython-seed/" + label + filename[len(prefix):] + ">"
            break
    return code.replace(co_filename=filename, co_consts=tuple(
        normalized_code(value) if isinstance(value, types.CodeType) else value
        for value in code.co_consts
    ))


def export():
    executed = {}

    def audit(event, args):
        if event == "exec" and args[0].co_name == "<module>":
            executed[args[0].co_filename] = args[0]

    sys.addaudithook(audit)
    from jaclang.compiler.backends.py.jacpython.code_object import compile_python
    compile_python("pass", "<seed-export>", "exec")
    import jaclang.compiler.frontend.python.compiler_preprocess
    import jaclang.runtime.python.symtable
    import jaclang.runtime.python.tokenize
    prefixes = ("jaclang.runtime.python", "jaclang.compiler.frontend.python",
                "jaclang.compiler.backends.py.jacpython")
    modules = {}
    for name, module in list(sys.modules.items()):
        if name not in ("jaclang.lib", "jaclang.runtime.builtin") and not any(
            name == prefix or name.startswith(prefix + ".") for prefix in prefixes
        ):
            continue
        path = getattr(module, "__file__", "")
        if path.endswith(".jac"):
            code = executed.get(path)
            if code is None:
                code = module.__loader__.get_code(name)
            if not isinstance(code, types.CodeType):
                raise RuntimeError("Missing compiled seed module: " + name)
            modules[name] = (normalized_code(code), hasattr(module, "__path__"))
    output.write_bytes(marshal.dumps(modules))
    print("JacPython seed: exported", len(modules), "Jac modules", flush=True)


def capture():
    from jaclang import jac0, bootstrap_manifest
    exported = marshal.loads(output.with_name("modules.marshal").read_bytes())
    requests = _startup_requests
    reference_compile = builtins.compile

    def build_compile(source, filename, flags=0):
        callback = getattr(sys, "_jacpython_compile", None)
        sys._jacpython_compile = None
        try:
            return reference_compile(source, filename, "exec", flags, dont_inherit=True)
        finally:
            sys._jacpython_compile = callback

    def record(source, filename, mode, flags=0, dont_inherit=False, optimize=-1, *, _feature_version=-1):
        sys._jacpython_compile = None
        try:
            code = reference_compile(source, filename, mode, flags, dont_inherit=True,
                                     optimize=optimize, _feature_version=_feature_version)
        finally:
            sys._jacpython_compile = record
        effective = sys.flags.optimize if optimize == -1 else optimize
        requests[source, mode, flags, effective, _feature_version] = normalized_code(code)
        return code

    class Records(dict):
        def get(self, name, default=None):
            if name not in self:
                base = root / name.replace(".", "/")
                package = base.is_dir()
                candidates = [base / "__init__.py", base / "__init__.jac"] if package else [
                    base.with_suffix(".py"), base.with_suffix(".jac")]
                path = next((path for path in candidates if path.is_file()), None)
                if path is None:
                    if not package:
                        raise ImportError("Missing seed dependency: " + name)
                    self[name] = (None, True)
                elif path.suffix == ".py":
                    self[name] = (normalized_code(build_compile(path.read_bytes(), str(path))), package)
                else:
                    relative = path.relative_to(root / "jaclang").as_posix()
                    if path.read_text().strip() and not bootstrap_manifest.is_seed_source(relative):
                        raise ImportError("Unexported Jac compiler dependency: " + name)
                    impls = [(Path(p).read_text(), str(p)) for p in jac0.discover_impl_files(str(path))]
                    source = jac0.compile_jac(path.read_text(), str(path), impl_sources=impls)
                    self[name] = (normalized_code(build_compile(source, str(path), 16777216)), package)
            return self[name]

    image = {"modules": Records(exported), "preparing": True}
    loader = types.ModuleType("_jacpython_seed")
    loader.image = image
    sys.modules[loader.__name__] = loader
    code = build_compile((recipe / "seed_runtime.py").read_bytes(), "<jacpython-seed-loader>")
    sys._jacpython_compile = record
    try:
        exec(code, loader.__dict__)
    finally:
        del sys._jacpython_compile
    # Include the startup modules that loaded before Python could install the
    # recording callback, notably encodings. Frozen modules need no requests.
    library = Path(sys.base_prefix) / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}"
    startup_paths = set(library.glob("encodings/*.py"))
    for module in list(sys.modules.values()):
        filename = getattr(module, "__file__", "") or ""
        path = Path(filename)
        if path.suffix != ".py" or not path.is_relative_to(library) or not path.is_file():
            continue
        startup_paths.add(path)
    # Locale-selected codecs can be imported before the interpreter is ready
    # to load the Jac compiler. Their source must also have prepared bytecode.
    for path in sorted(startup_paths):
        source = path.read_bytes()
        key = (source, "exec", 0, sys.flags.optimize, sys.version_info.minor)
        requests[key] = normalized_code(build_compile(source, str(path)))
    image.pop("preparing")
    image["modules"] = dict(image["modules"])
    image["requests"] = {key: normalized_code(value) for key, value in requests.items()}
    image["loader"] = code
    output.write_bytes(marshal.dumps(image))
    print("JacPython seed: captured", len(image["modules"]), "modules and", len(requests),
          "startup requests at optimization", sys.flags.optimize, flush=True)


def prepare():
    output.mkdir(parents=True, exist_ok=True)
    script = str(Path(__file__).resolve())
    subprocess.run([sys.executable, "-I", script, "export", str(root), str(output / "modules.marshal")], check=True)
    images = []
    for optimize in range(3):
        path = output / f"seed-{optimize}.marshal"
        with tempfile.TemporaryDirectory(prefix="jacpython-seed-") as cache:
            command = [sys.executable, "-I", "-B", "-X", "pycache_prefix=" + cache]
            if optimize:
                command.append("-" + "O" * optimize)
            subprocess.run(command + [script, "capture", str(root), str(path)], check=True)
        images.append(marshal.loads(path.read_bytes()))
    image = {"version": pin["version"], "loader": images[0]["loader"],
             "modules_by_optimization": [value["modules"] for value in images], "requests": {}}
    for value in images:
        image["requests"].update(value["requests"])
    data = marshal.dumps(image)
    compressed = zlib.compress(data, 9)
    header = output / "jac_seed.h"
    with header.open("w") as stream:
        stream.write("/* Generated JacPython bytecode; no C compiler implementation. */\n")
        stream.write(f"#define JAC_SEED_SIZE {len(data)}\nstatic const unsigned char jac_seed_data[] = {{\n")
        for offset in range(0, len(compressed), 24):
            stream.write(",".join(str(byte) for byte in compressed[offset:offset+24]) + ",\n")
        stream.write("};\n")
    (output / "seed.marshal").write_bytes(data)
    (output / "sha256").write_text(hashlib.sha256(data).hexdigest() + "\n")
    print("JacPython seed:", len(data), "bytes;", len(compressed), "compressed bytes", flush=True)


{"export": export, "capture": capture, "prepare": prepare}[mode]()
