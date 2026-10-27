"""Under the rc profile, a release that only decrements is inlined; the rest stays out of line.

`__rc_release_simple`, the release every owned reference goes through, used
to wrap `__rc_release_impl`, which holds the destructor call, the free and the
live-list unlink. Inlined whole, that was too big for LLVM to inline into a
large function, and every release there became a call. In an `rc` build
without refcount debug codegen the wrapper is now the checks and a plain
decrement, `alwaysinline`, and it calls `__rc_release_impl` (`noinline`) only
for the last reference or once a thread has started. Cycle-collector and
debug builds keep the old wrapper: under the collector a release whose count
stays above zero may still have to buffer the object as a cycle root. These
tests pin the helpers' shape in the IR (the threaded-flag test reads only
`__rc_release_impl`, so it would pass with the old wrapper) and run the
fixture as an `rc` executable, where every release that is not the last one
takes the inlined decrement.
"""

import os;
import re;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "rc_release_fast_path.jac");

"""The fixture's unoptimized IR under `gc_mode`, with or without refcount debug codegen."""
def fixture_ir(gc_mode: str, debug: bool = False) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, na_gc_mode=gc_mode, rc_debug_codegen=debug
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The `define` line of helper `name` ("" when absent)."""
def signature(text: str, name: str) -> str {
    for line in text.splitlines() {
        if line.startswith("define") and f'@"{name}"(' in line {
            return line;
        }
    }
    return "";
}

"""The blocks of helper `name`: label -> lines."""
def blocks_of(text: str, name: str) -> dict[str, list[str]] {
    found = re.search(
        r'define [^\n]*@"' + re.escape(name) + r'"\([^\n]*\n\{\n(.*?)\n}\n', text, re.S
    );
    assert found is not None , f"{name} not found in the IR";
    blocks: dict[str, list[str]] = {};
    label = "";
    for line in found.group(1).splitlines() {
        head = re.`match(r'^"?([\w.]+)"?:$', line);
        if head is not None {
            label = head.group(1);
            blocks[label] = [];
        } elif label {
            blocks[label].append(line.strip());
        }
    }
    return blocks;
}

"""The refcount helper calls `churn` makes, as (callee, `may_cycle` or "")."""
def churn_calls(text: str) -> list[tuple[str, str]] {
    found = re.search(r'define [^\n]*\.churn"?\(.*?\n}\n', text, re.S);
    assert found is not None , "churn not found in the IR";
    return re.findall(
        r'call void @"(__rc_release_simple|__rc_release_impl|__rc_retain)"\([^,)]*(?:, i1 (\d))?\)',
        found.group(0)
    );
}

"""Whether the wrapper is the old one: one call of the full release, then return."""
def is_old_wrapper(text: str) -> bool {
    return blocks_of(text, "__rc_release_simple")
        == {"entry": ['call void @"__rc_release_impl"(i8* %"ptr", i1 1)', "ret void"]};
}

test "an rc build inlines the plain decrement and keeps the full release out of line" {
    text = fixture_ir("rc");
    assert "alwaysinline" in signature(text, "__rc_release_simple") , signature(
        text, "__rc_release_simple"
    );
    assert "noinline" in signature(text, "__rc_release_impl") , signature(
        text, "__rc_release_impl"
    );
    assert "alwaysinline" in signature(text, "__rc_retain") , signature(
        text, "__rc_retain"
    );
    blocks = blocks_of(text, "__rc_release_simple");
    lines = [line for block in blocks.values() for line in block];
    # the decrement: count - 1 stored back, in a block that calls nothing
    dec = [
        label
        for (label, block) in blocks.items()
        if any(re.search(r' = sub i64 %"?[\w.]+"?, 1$', line) for line in block)
    ];
    assert len(dec) == 1 , f"no single decrement block: {blocks}";
    dec_block = blocks[dec[0]];
    subs = [
        line
        for line in dec_block
        if " = sub i64 " in line
    ];
    new_rc = subs[0].split(" = ")[0];
    assert any(line.startswith(f"store i64 {new_rc},") for line in dec_block) , f"the decrement is not stored: {dec_block}";
    assert not any("call " in line for line in dec_block) , f"the decrement block calls: {dec_block}";
    # the full release is called once, and the choice reads the threaded flag
    impl_calls = [
        line
        for line in lines
        if '@"__rc_release_impl"' in line
    ];
    assert impl_calls
        == ['call void @"__rc_release_impl"(i8* %"ptr", i1 1)'] , impl_calls;
    assert any('@"__jac_rc_threaded"' in line for line in lines) , "the fast path does not test the threaded flag";
}

test "an rc build releases an acyclic object through the inlined fast path" {
    calls = churn_calls(fixture_ir("rc"));
    assert ("__rc_release_simple", "") in calls , calls;
    assert not any(callee == "__rc_release_impl" for (callee, _) in calls) , calls;
}

test "a cycle-collector build keeps the old release" {
    text = fixture_ir("cycles");
    assert is_old_wrapper(text) , blocks_of(text, "__rc_release_simple");
    assert "alwaysinline" not in signature(text, "__rc_release_simple");
    assert "noinline" not in signature(text, "__rc_release_impl");
    # an acyclic object's release tells the collector it cannot be a cycle root
    calls = churn_calls(text);
    assert ("__rc_release_impl", "0") in calls , calls;
    assert not any(callee == "__rc_release_simple" for (callee, _) in calls) , calls;
}

test "an rc build with refcount debug codegen keeps the old release and retain" {
    text = fixture_ir("rc", debug=True);
    assert is_old_wrapper(text) , blocks_of(text, "__rc_release_simple");
    assert "alwaysinline" not in signature(text, "__rc_release_simple");
    assert "noinline" not in signature(text, "__rc_release_impl");
    assert "alwaysinline" not in signature(text, "__rc_retain");
}

test "an rc executable, which takes the inlined decrement, matches the Python backend" {
    # `held` keeps the previous `cur` alive across its reassignment, so the
    # reassignment's release only decrements, and the next `held = cur` drops
    # the last reference; reading `held.v` after both checks neither freed early
    assert assert_native_identity(FIXTURE, profiles=["rc"]) == "81\n";
}
