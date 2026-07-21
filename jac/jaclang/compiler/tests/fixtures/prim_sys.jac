"""sys module cross-backend equivalence fixture (issue #6404, v1).

Covers the deterministic, value-stable members (maxsize/byteorder/platform).
sys.argv is non-deterministic under the JIT harness and is exercised separately
by the "sys argv via nacompile" test. ES/JS opts out.
"""

import sys;

def sys_py() -> dict {
    stdout_n = sys.stdout.write("eq-out\n");
    stderr_n = sys.stderr.write("eq-err\n");
    sys.stdout.flush();
    sys.stderr.flush();
    return {
        "maxsize": sys.maxsize,
        "byteorder": sys.byteorder,
        "platform": sys.platform,
        "maxsize_is_i64max": sys.maxsize == 9223372036854775807,
        "stdout_n": stdout_n,
        "stderr_n": stderr_n,
    };
}

cl def sys_cl() -> dict {
    return {};
}

na {
    def sys_na() -> dict[str, any] {
        maxsize_is_i64max: int = sys.maxsize == 9223372036854775807;
        stdout_n = sys.stdout.write("eq-out\n");
        stderr_n = sys.stderr.write("eq-err\n");
        sys.stdout.flush();
        sys.stderr.flush();
        return {
            "maxsize": sys.maxsize,
            "byteorder": sys.byteorder,
            "platform": sys.platform,
            "maxsize_is_i64max": maxsize_is_i64max,
            "stdout_n": stdout_n,
            "stderr_n": stderr_n,
        };
    }
}
