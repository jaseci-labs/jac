import ctypes;
import os;
import tempfile;
import shutil;
import from concurrent.futures { ThreadPoolExecutor }
import from tests.support { TESTS_DIR, native_build }

test "native error slots are isolated between concurrent library callers" {
    source = os.path.join(
        TESTS_DIR,
        "compiler",
        "backends",
        "native",
        "fixtures",
        "nogc_error_threads.jac"
    );
    with tempfile.TemporaryDirectory() as tmp {
        library = os.path.join(tmp, "errors.so");
        fixture = os.path.join(tmp, "errors.jac");
        shutil.copyfile(source, fixture);
        # Preserve the error-slot traffic rather than letting inlining fold
        # this tiny raising function into a pure arithmetic expression.
        with open(os.path.join(tmp, "jac.toml"), "w") as config {
            config.write("[native]\nopt = 0\n");
        }
        native_build(fixture, library, memory="nogc", extra=["--lib"]);
        handle = ctypes.CDLL(library);
        recover = handle.recover;
        recover.argtypes = [ctypes.c_int64];
        recover.restype = ctypes.c_int64;
        def check_worker(worker: int) -> bool {
            for i in range(2000) {
                v = i + worker;
                if recover(v) != 2 + v % 2 {
                    return False;
                }
            }
            return True;
        }
        with ThreadPoolExecutor(max_workers=4) as pool {
            assert all(list(pool.map(check_worker, range(4))));
        }
    }
}
