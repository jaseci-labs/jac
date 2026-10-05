"""A store into a field of an object glob another module declares (#9596).

The JacPython zlib and bz2 bindings set each defining-class token with
`Token.handle = type_definition.handle`, where the token is an object glob
imported from the module half and its type comes from a third module. The
emitter raised `'IntType' object has no attribute 'is_opaque'` lowering that
store, so the bindings went through a `ClassToken.bind()` method instead.

The fixture keeps that shape: the glob's type, the glob and the consumer are
three modules, and the stored value is a field of the consumer's own object
glob. It must lower with no seam, and the native binary must read back what
it stored.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { TESTS_DIR, jac_command, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "a store into an imported object glob's field lowers with no seam" {
    prog = JacProgram();
    options = native_force_opts();
    options.skip_native_engine = True;
    options.no_ir_cache = True;
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "glob_field_store_xmod_main.jac"),
        options=options
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    demoted = [
        str(w)
        for w in prog.warnings_had
        if "is_opaque" in str(w) or "E5092" in str(w)
    ];
    assert not demoted , f"the store demoted: {demoted}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the fixture";
}

test "the native binary reads back the stored handles" {
    out_bin = os.path.join(tempfile.mkdtemp(), "glob_field_store.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "glob_field_store_xmod_main.jac"),
            "-o",
            out_bin
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"native build failed: {comp.stderr[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]}";
    lines = [
        line
        for line in proc.stdout.split("\n")
        if line.strip()
    ];
    assert lines == ["0", "True", "True"] , f"native binary printed {lines}";
}
