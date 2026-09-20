"""Execute C projections of optimizer intrinsics against their LLVM semantics."""

import ctypes;
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest { SkipTest }
import from jaclang.compiler.backends.native.c_emit { emit_c }

test "C projection preserves pointer mask index width" {
    if not os.environ.get("JAC_LLVM_CBE") and not shutil.which("llvm-config-22") {
        raise SkipTest("LLVM C backend development toolchain is not installed");
    }
    compiler = shutil.which("cc");
    if compiler is None or ctypes.sizeof(ctypes.c_void_p) != 8 {
        raise SkipTest("this execution probe requires a 64-bit C compiler");
    }
    for width in [64, 32] {
        ir = f"""
target datalayout = "e-p:64:64:64:{width}"
declare ptr @llvm.ptrmask.p0.i{width}(ptr, i{width})
define i64 @masked(i64 %value, i{width} %mask) {{
  %pointer = inttoptr i64 %value to ptr
  %result = call ptr @llvm.ptrmask.p0.i{width}(ptr %pointer, i{width} %mask)
  %integer = ptrtoint ptr %result to i64
  ret i64 %integer
}}
""";
        with TemporaryDirectory() as temporary {
            directory = Path(temporary);
            source = directory / "mask.c";
            library = directory / "mask.so";
            source.write_text(emit_c(ir));
            subprocess.run(
                [compiler, "-shared", "-fPIC", "-O2", str(source), "-o", str(library)],
                check=True,
                capture_output=True,
                text=True
            );
            loaded = ctypes.CDLL(str(library));
            masked = loaded.masked;
            masked.argtypes = [
                ctypes.c_uint64,
                ctypes.c_uint64 if width == 64 else ctypes.c_uint32
            ];
            masked.restype = ctypes.c_uint64;
            for value in [0, 15, 0x12345678ABCDEF07, 0xFFFFFFFFFFFFFFFF] {
                for mask in [0, 0xFFFFFFF0, 0x7FFFFFFF, (1 << width) - 1] {
                    high = value & ~((1 << width) - 1);
                    assert masked(value, mask) == high | (value & mask);
                }
            }
        }
    }
}
