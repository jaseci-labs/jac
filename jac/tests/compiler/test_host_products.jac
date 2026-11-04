"""Host products: the kernel's product table names no host-only pass.

Bytecode, native objects, formatting and the utility products run passes from
modules that do not lower natively, so the pipeline's own table leaves them
out and the Python host registers them on the first lookup. With the kernel on
its floor every product is still found, and a lookup no host can answer names
the product instead of returning an empty schedule.
"""
import os;
import subprocess;
import tempfile;
import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
import from jaclang.compiler.driver.pipeline { PRODUCTS, product_spec, schedule_for }
import from jaclang.compiler.driver.host_products { HOST_PRODUCTS }
import from jaclang.compiler.frontend.host { HostServices, active_host, install_host }
import from tests.support { JAC_ROOT, jac_command }

glob HOST_ONLY_PASSES: list[str] = [
         "JcirBytecodeGenPass",
         "NativeCompilePass",
         "CommentAttachPass",
         "DocIRGenPass",
         "JacFormatPass",
         "PyastBuildPass",
         "GrammarExtractPass",
         "CoalesceBBPass",
         "NormalizePass",
         "UnparsePass"
     ];

test "the kernel's pipeline names no host-only pass" {
    driver = os.path.join(JAC_ROOT, "jaclang", "compiler", "driver");
    for rel in ("pipeline.jac", os.path.join("impl", "pipeline.impl.jac")) {
        with open(os.path.join(driver, rel)) as source {
            text = source.read();
        }
        for name in HOST_ONLY_PASSES {
            assert name not in text , f"{rel} names {name}";
        }
    }
    with open(os.path.join(JAC_ROOT, "jaclang", "archwire.jac")) as wires {
        for line in wires {
            if "driver.pipeline" in line {
                for name in HOST_ONLY_PASSES {
                    assert name not in line , line;
                }
            }
        }
    }
}

test "every host product is found with the kernel on its floor" {
    for product in HOST_PRODUCTS {
        spec = product_spec(product);
        assert spec.passes.__module__.endswith("host_products") , product;
    }
    names = [step.__name__ for step in (schedule_for(CompilationProduct.FORMAT) or [])];
    assert names == ["CommentAttachPass", "DocIRGenPass", "JacFormatPass"] , names;
}

test "a host product no host registered is refused by name" {
    held = PRODUCTS.pop(CompilationProduct.FORMAT);
    previous = active_host();
    install_host(HostServices());
    try {
        failed = "";
        try {
            product_spec(CompilationProduct.FORMAT);
        } except RuntimeError as err {
            failed = str(err);
        }
        assert "format" in failed , failed;
    } finally {
        install_host(previous);
        PRODUCTS[CompilationProduct.FORMAT] = held;
    }
}

test "jac fmt and jac build find their products" {
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "jac.toml"), "w") as manifest {
            manifest.write("[project]\nname = \"hello\"\nversion = \"0.1.0\"\n");
        }
        source = os.path.join(tmp, "hello.jac");
        with open(source, "w") as out {
            out.write("with entry {\n    print(\"hello\");\n}\n");
        }
        fmt = subprocess.run(
            jac_command("fmt", "--check", source), capture_output=True, text=True
        );
        assert fmt.returncode == 0 , fmt.stdout + fmt.stderr;
        build = subprocess.run(
            jac_command("build", source), capture_output=True, text=True, cwd=tmp
        );
        assert build.returncode == 0 , build.stdout + build.stderr;
        assert os.path.isfile(os.path.join(tmp, "dist", "hello.jab"));
    }
}
