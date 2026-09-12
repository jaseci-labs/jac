"""Exercise JacPython's explicit compile API using pinned upstream tests.

Run through the checkout's Jac binary, for example:
    jac run scripts/run_cpython_compiler_tests.jac

With --runtime, the runtime dispatches built-in compilation and source imports
to JacPython. The reduced runtime already uses the embedded JacPython seed;
the runner temporarily instruments dispatch and restores it afterward.
--compile-tests also compiles every definition with the checkout's JacPython.
--symtable-api and --tokenize-api additionally route those public APIs, including
module-level fixtures, through Jac adapters or the patched C entry points.
Without it, tests with no call to the replacement are reported as skipped.
No CPython test corpus is checked into this repository.
"""
import argparse;
import builtins;
import hashlib;
import importlib;
import io;
import json;
import operator;
import from pathlib { Path }
import sys;
import tarfile;
import tempfile;
import types;
import unittest;
import urllib.request;
def fetch_tests(cache: Path) -> Path {
    repo = Path(__file__).resolve().parents[1];
    pin_path = repo / "jac/bootstrap/python/sources.json";
    pin = json.loads(pin_path.read_text())["cpython"];
    destination = cache / pin["sha256"];
    library = destination / f"Python-{pin['version']}" / "Lib";
    marker = destination / ".complete";
    print(
        f"CPython {pin['version']} tests; archive SHA256 {pin['sha256']}", flush=True
    );
    if (
        marker.is_file()
        and (library / "test/test_compile.py").is_file()
        and (library / "ast.py").is_file()
    ) {
        return library;
    }
    with urllib.request.urlopen(pin["url"], timeout=120) as response {
        archive = response.read();
    }
    if (hashlib.sha256(archive).hexdigest() != pin["sha256"]) {
        raise RuntimeError("CPython test archive checksum mismatch");
    }
    destination.mkdir(parents=True, exist_ok=True);
    # AST round-trip tests also need pinned standard-library source fixtures.
    prefix = f"Python-{pin['version']}/Lib/";
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as bundle {
        members = [
            m
            for m in bundle
            if (m.isfile() and m.name.startswith(prefix))
        ];
        bundle.extractall(destination, members=members, filter="data");
    }
    marker.write_text((pin["sha256"] + "\n"));
    return library;
}

def main -> int {
    parser = argparse.ArgumentParser(description=__doc__);
    parser.add_argument(
        "--cache",
        `type=Path,
        `default=(Path(tempfile.gettempdir()) / "jac-cpython-tests")
    );
    parser.add_argument(
        "--tests", nargs="+", help="TestSpecifics method names; default: entire class"
    );
    parser.add_argument(
        "--runtime",
        action="store_true",
        help="Exercise the patched C runtime instead of module-local wrappers"
    );
    parser.add_argument("--module", `default="test.test_compile");
    parser.add_argument(
        "--ast-api",
        action="store_true",
        help="Also route stdlib ast.parse through the direct replacement API"
    );
    parser.add_argument(
        "--compile-tests",
        action="store_true",
        help="Compile the upstream test module itself with JacPython"
    );
    parser.add_argument(
        "--symtable-api",
        action="store_true",
        help="Route symbol-table construction through JacPython, including fixtures"
    );
    parser.add_argument(
        "--tokenize-api",
        action="store_true",
        help="Route the public streaming tokenizer through JacPython"
    );
    args = parser.parse_args();
    calls: list[int] = [0];
    restorations: list[tuple[any, str, bool, any]] = [];
    try {
        if args.symtable_api {
            import _symtable;
            import from jaclang.runtime.python.symtable { symtable }
            def replacement_symtable(
                source: any, filename: any, mode: any, /
            ) -> object {
                calls[0] += 1;
                return symtable(source, filename, mode);
            }
            restorations.append(
                install_api(
                    _symtable,
                    "symtable",
                    replacement_symtable,
                    "_jacpython_symtable",
                    "_PyJac_SymtableBridgeVersion",
                    args.runtime
                )
            );
        }
        if args.tokenize_api {
            import _tokenize;
            import from jaclang.runtime.python.tokenize { TokenizerIter }
            def replacement_tokenizer(readline: any, /, **kwargs: any) -> object {
                calls[0] += 1;
                return TokenizerIter(readline, **kwargs);
            }
            restorations.append(
                install_api(
                    _tokenize,
                    "TokenizerIter",
                    replacement_tokenizer,
                    "_jacpython_tokenize",
                    "_PyJac_TokenizeBridgeVersion",
                    args.runtime
                )
            );
        }
        return run_tests(args, calls);
    } finally {
        for (target, name, existed, original) in reversed(restorations) {
            if existed {
                setattr(target, name, original);
            } else {
                delattr(target, name);
            }
        }
    }
}

def install_api(
    module: any,
    name: str,
    replacement: any,
    hook: str,
    version_symbol: str,
    runtime: bool
) -> tuple[any, str, bool, any] {
    target = module;
    if runtime {
        import ctypes;
        try {
            bridge_version = getattr(ctypes.pythonapi, version_symbol);
        } except AttributeError as error {
            raise RuntimeError(
                f"Rebuild the runtime with the {hook} bridge"
            ) from error;
        }
        if bridge_version() != 1 {
            raise RuntimeError(f"Unsupported {hook} bridge version");
        }
        target = sys;
        name = hook;
    }
    restoration = (target, name, hasattr(target, name), getattr(target, name, None));
    setattr(target, name, replacement);
    return restoration;
}

def run_tests(args: any, calls: list[int]) -> int {
    library = fetch_tests(args.cache);
    sys.path.insert(0, str(library));
    try {
        importlib.import_module("test");
    } finally {
        # Keep test.__path__, while runtime stdlib imports use the installed tree.
        sys.path.pop(0);
    }
    support = importlib.import_module("test.support");
    # Resource decorators are evaluated when the test module is imported.
    support.use_resources = [];
    import from jaclang.compiler.backends.py.jacpython.code_object { compile_python }
    reference_module = importlib.import_module(args.module);
    test_module: any = reference_module;
    # Warm the compiler before individual tests and their timers.
    compile_python("pass", "<warmup>", "exec", dont_inherit=True);
    compiled_codes: set[int] = set();
    if args.compile_tests {
        assert reference_module.__file__ is not None;
        path = Path(reference_module.__file__);
        test_module = types.ModuleType(reference_module.__name__);
        test_module.__file__ = str(path);
        test_module.__package__ = reference_module.__package__;
        test_module.__spec__ = reference_module.__spec__;
        code = compile_python(path.read_bytes(), str(path), "exec", dont_inherit=True);
        pending = [code];
        while pending {
            item = pending.pop();
            compiled_codes.add(id(item));
            pending.extend(
                c
                for c in item.co_consts
                if isinstance(c, types.CodeType)
            );
        }
        sys.modules[args.module] = test_module;
        try {
            exec(code, test_module.__dict__);
        } finally {
            sys.modules[args.module] = reference_module;
        }
        print(f"JACPYTHON_TEST_MODULE {args.module}", flush=True);
    }
    if args.symtable_api or args.tokenize_api {
        print(f"JACPYTHON_API_FIXTURE_CALLS {calls[0]}", flush=True);
    }
    if (args.module == "test.test_ast.test_ast") {
        test_module.STDLIB = str(library);
        test_module.STDLIB_FILES = [path.name for path in library.glob("*.py")];
        test_module.STDLIB_FILES.extend(
            ["test/test_grammar.py", "test/test_unpack_ex.py"]
        );
    }
    def replacement_compile(
        source: any,
        filename: any,
        mode: any,
        flags: any = 0,
        dont_inherit: any = False,
        optimize: any = -1,
        **kwargs: any
    ) -> object {
        calls[0] += 1;
        flags = operator.index(flags);
        dont_inherit = bool(dont_inherit);
        if not dont_inherit {
            flags |= sys._getframe(1).f_code.co_flags & 0x1FE0000;
        }
        # Inherit only the test caller's flags, not this Jac module's future flags.
        return compile_python(source, filename, mode, flags, True, optimize, **kwargs);
    }
    def replacement_eval(
        source: any, globals: any = None, locals: any = None
    ) -> object {
        frame = sys._getframe(1);
        if (globals is None) {
            globals = frame.f_globals;
            if (locals is None) {
                locals = frame.f_locals;
            }
        }
        if isinstance(source, (str, `bytes, bytearray, memoryview)) {
            source = replacement_compile(
                source, "<string>", "eval", (frame.f_code.co_flags & 0x1FE0000), True
            );
        }
        return builtins.eval(source, globals, locals);
    }
    def replacement_exec(
        source: any, globals: any = None, locals: any = None, *, closure: any = None
    ) -> object {
        frame = sys._getframe(1);
        if (globals is None) {
            globals = frame.f_globals;
            if (locals is None) {
                locals = frame.f_locals;
            }
        }
        if isinstance(source, (str, `bytes, bytearray, memoryview)) {
            source = replacement_compile(
                source, "<string>", "exec", (frame.f_code.co_flags & 0x1FE0000), True
            );
        }
        return builtins.exec(source, globals, locals, closure=closure);
    }
    class Result(unittest.TextTestResult) {
        has compiled_test: bool = False;

        def startTest(self: Result, test_case: any) {
            calls[0] = 0;
            method = getattr(
                test_case, getattr(test_case, "_testMethodName", "runTest"), None
            );
            seen: set[int] = set();
            self.compiled_test = False;
            while ((method is not None) and (id(method) not in seen)) {
                seen.add(id(method));
                if (id(method?.__code__) in compiled_codes) {
                    self.compiled_test = True;
                    break;
                }
                method = method?.__wrapped__;
            }
            super.startTest(test_case);
        }

        def addSuccess(self: Result, test_case: any) {
            if (calls[0] or self.compiled_test) {
                super.addSuccess(test_case);
            } else {
                self.addSkip(test_case, "no direct call to JacPython in this test");
            }
        }

        def stopTest(self: Result, test_case: any) {
            print(f"JACPYTHON_CALLS {test_case.id()} {calls[0]}", flush=True);
            super.stopTest(test_case);
        }
    }
    original = {
        name: test_module.__dict__.get(name) for name in ("compile", "eval", "exec")
    };
    original_defaults = [];
    import ast;
    original_ast_compile = ast.__dict__.get("compile");
    original_runtime_compile = (
        hasattr(sys, "_jacpython_compile"),
        sys?._jacpython_compile
    );
    if args.runtime {
        import ctypes;
        try {
            bridge_version = ctypes.pythonapi._PyJac_CompilerBridgeVersion;
        } except AttributeError as error {
            raise RuntimeError(
                "Rebuild the Python runtime with the JacPython bridge"
            ) from error;
        }
        if (bridge_version() != 2) {
            raise RuntimeError("Unsupported JacPython runtime bridge version");
        }
        setattr(sys, "_jacpython_compile", replacement_compile);
    } else {
        if args.ast_api {
            setattr(ast, "compile", replacement_compile);
        }
        test_module.compile = replacement_compile;
        test_module.eval = replacement_eval;
        test_module.exec = replacement_exec;
        replacements = (
            (builtins.compile, replacement_compile),
            (builtins.eval, replacement_eval),
            (builtins.exec, replacement_exec)
        );
        def replace_default(value: any) -> object {
            return next(
                (
                    new
                    for (old, new) in replacements
                    if (value is old)
                ),
                value
            );
        }
        for candidate_value in `list(vars(test_module).values()) {
            candidates = [candidate_value];
            if (
                isinstance(candidate_value, `type)
                and (candidate_value.__module__ == args.module)
            ) {
                candidates.extend(vars(candidate_value).values());
            }
            for fn in candidates {
                if (
                    not isinstance(fn, types.FunctionType)
                    or (fn.__module__ != args.module)
                ) {
                    continue;
                }
                original_defaults.append((fn, fn.__defaults__, fn.__kwdefaults__));
                if fn.__defaults__ {
                    fn.__defaults__ = `tuple(
                        replace_default(v) for v in fn.__defaults__
                    );
                }
                if fn.__kwdefaults__ {
                    fn.__kwdefaults__ = {
                        k: replace_default(v) for (k, v) in fn.__kwdefaults__.items()
                    };
                }
            }
        }
    }
    print(
        "Compiler path:",
        "C runtime dispatch" if args.runtime else "direct API",
        flush=True
    );
    try {
        sys.modules[args.module] = test_module;
        if args.tests {
            names = [
                f"TestSpecifics.{name}"
                    if (
                        name.startswith("test_")
                        and hasattr(test_module, "TestSpecifics")
                    )
                    else name for name in args.tests
            ];
            suite = unittest.defaultTestLoader.loadTestsFromNames(names, test_module);
        } elif (not args.compile_tests and (args.module == "test.test_compile")) {
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(
                test_module.TestSpecifics
            );
        } else {
            suite = unittest.defaultTestLoader.loadTestsFromModule(test_module);
        }
        result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(suite);
        return int(not result.wasSuccessful());
    } finally {
        sys.modules[args.module] = reference_module;
        for (fn, defaults, kwdefaults) in original_defaults {
            (fn.__defaults__, fn.__kwdefaults__) = (defaults, kwdefaults);
        }
        if args.runtime {
            if original_runtime_compile[0] {
                setattr(sys, "_jacpython_compile", original_runtime_compile[1]);
            } else {
                delattr(sys, "_jacpython_compile");
            }
        } elif args.ast_api {
            if (original_ast_compile is None) {
                ast.__dict__.pop("compile", None);
            } else {
                setattr(ast, "compile", original_ast_compile);
            }
        }
        for (name, value) in original.items() {
            if (value is None) {
                test_module.__dict__.pop(name, None);
            } else {
                setattr(test_module, name, value);
            }
        }
    }
}

with entry:__main__ {
    sys.exit(main());
}
