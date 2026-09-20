import from pathlib { Path }
import type from jaclang.compiler.frontend.unitree { Module }


def write_native_payload(
    module: Module, directory: Path, relative: Path, memory: str = ""
) -> dict[str, any] {
    import from jaclang.compiler.backends.native.entry_points {
        validate_native_application
    }
    import from jaclang.dist.native_product { write_native_product }
    validate_native_application(module, shared=False, memory=memory, hosted=True);
    return write_native_product(
        module,
        directory,
        relative,
        memory=memory,
        emit_source=False,
        entry_symbol="jac_entry"
    );
}


def write_native_image(module: Module, directory: Path, memory: str = "") {
    import from jaclang.dist.precompile_bytecode { collect_payloads, write_manifest }
    import from jaclang.jac0core.sealed { python_tag }
    import from jaclang.server.sealed_serve { NATIVE_DIR_REL }
    import jaclang.compiler.backends.native.llvm.binding as llvm;

    triple = str(llvm.get_default_triple());
    product = write_native_payload(
        module, directory, Path(NATIVE_DIR_REL) / triple / "app", memory
    );
    precompiled = directory / "_precompiled";
    precompiled.mkdir(parents=True, exist_ok=True);
    write_manifest(
        precompiled,
        "native_app",
        python_tag(),
        {},
        collect_payloads(directory),
        {
            "kind": "cli-native",
            "capabilities": ["has-entry", "has-native", "platform-locked"],
            "triples": [triple],
            "entry": {"path": product["output"], "runtime": "native-shared"}
        }
    );
}


def write_native_application(module: Module, output: str, memory: str = "") {
    import os;
    import tempfile;
    import from jaclang.dist.fused_binary {
        running_executable,
        has_runtime,
        append_overlay
    }
    import from jaclang.dist.seal { tar_gz_dir }

    runtime = running_executable();
    if not has_runtime(runtime) {
        raise ValueError(
            "A Python-hosted native application must be built with a fused Jac runtime"
        );
    }
    destination = Path(output).resolve();
    destination.parent.mkdir(parents=True, exist_ok=True);
    with tempfile.TemporaryDirectory(
        prefix="jac-native-", dir=str(destination.parent)
    ) as work {
        stage = Path(work);
        img = stage / "image";
        write_native_image(module, img, memory);
        bundle = stage / "app.jab";
        bundle.write_bytes(tar_gz_dir(img));
        binary = stage / "app";
        if not append_overlay(runtime, str(bundle), str(binary)) {
            raise ValueError(
                "Cannot attach the native application to the fused Jac runtime"
            );
        }
        os.replace(binary, destination);
    }
}


def run_native_application(path: str, args: list[str]) -> int {
    import sys;
    import from jaclang.runtime.interop_bridge { NativeLibrary, native_callable }
    library = NativeLibrary(path=path, requires_python=True);
    previous_argv = sys.argv;
    sys.argv = [path, *args];
    try {
        invoke = native_callable(library.get_function_address("jac_entry"), True, None);
        invoke();
        return 0;
    } finally {
        sys.argv = previous_argv;
    }
}
