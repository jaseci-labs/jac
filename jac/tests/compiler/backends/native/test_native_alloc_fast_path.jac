"""An allocation in a program without regions asks for neither a region nor an id.

Every object allocation asked the region kernel for the thread's current
region (a call, a TLS lookup and `pthread_getspecific`), and every `__rc_alloc`
took the next value of the shared alloc-id counter. A thread has a current
region only after it made its region block, which sets `__jac_region_tls_used`,
so the lookup now runs only once that flag is set; and only a debug build
reads alloc ids, so a release build writes the header magic alone.
"""

import os;
import re;
import from tests.support { NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "unwind_leaf.jac");

"""The fixture's unoptimized IR under the cycle collector."""
def fixture_ir(debug: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, na_gc_mode="cycles", rc_debug_codegen=debug
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The body of the function whose name ends in `name`."""
def body_of(text: str, name: str) -> str {
    found = re.search(r'define [^\n]*' + re.escape(name) + r'"?\(.*?\n}\n', text, re.S);
    assert found is not None , f"{name} not found in the IR";
    return found.group(0);
}

test "allocations ask for the current region only once a thread entered one" {
    make = body_of(fixture_ir(False), ".make");
    assert '@"__jac_region_tls_used"' in make;
    assert "region.cur.read" in make;
}

test "only a debug build numbers its allocations" {
    assert "__rc_alloc_id_counter" not in body_of(fixture_ir(False), '@"__rc_alloc"');
    assert "__rc_alloc_id_counter" in body_of(fixture_ir(True), '@"__rc_alloc"');
}
