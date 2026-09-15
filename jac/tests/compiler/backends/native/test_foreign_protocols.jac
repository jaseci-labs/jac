"""Checked native bodies must preserve their declared external error protocol."""

import re;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module }

def compile_protocol(source: str, rejected: str = "", memory: str = "nogc") -> Module | None {
    program = JacProgram();
    module = program.compile(
        file_path="foreign_protocol.jac", use_str=source,
        options=CompileOptions(force_codespace="native", force_target_program=True,
            native_required=True, skip_native_engine=True, memory_profile=memory,
            no_ir_cache=True, opt_level=0)
    );
    errors = "\n".join(str(error) for error in program.errors_had);
    if rejected {
        assert rejected in errors , errors;
    } else {
        assert not errors , errors;
        assert module is not None and module.gen.llvm_ir is not None;
    }
    return module;
}

test "native external error bodies compose without touching Jac exception state" {
    module = compile_protocol(
        '@foreign_call(errors="none", reentrant=False) '
        'def step(value: i64) -> i64 { return wrapping_add(value, 1); } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64) -> i64 { return step(value); }'
    );
    assert module is not None;
    text = str(module.gen.llvm_ir);
    body = re.search(r'(?ms)^define [^\n]*@"probe"[^\n]*\n\{.*?^}', text);
    assert body is not None , text;
    assert 'call i64 @"step"' in body.group() , body.group();
    assert "__jac_" not in body.group() , body.group();
}

test "external error bodies retain checked arithmetic diagnostics" {
    compile_protocol(
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64, divisor: i64) -> i64 { return value // divisor; }',
        "without an external error contract"
    );
}

test "constant bounded shifts need no Jac error machinery" {
    compile_protocol(
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64) -> i64 { return value >> 1; }'
    );
    compile_protocol(
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64, count: i64) -> i64 { return value >> count; }',
        "without an external error contract"
    );
}

test "source raises inference does not authorize external error calls" {
    compile_protocol(
        'def unannotated(value: i64) -> i64 { return wrapping_add(value, 1); } '
        '@foreign_call(errors="python", reentrant=False) '
        'def probe(value: i64) -> i64 { return unannotated(value); }',
        "without an external error contract"
    );
}

test "errors none cannot absorb a Python error producer" {
    compile_protocol(
        'import from c { @foreign_call(errors="python", reentrant=False) '
        'def external(value: i64) -> i64; } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64) -> i64 { return external(value); }',
        "errors=none cannot call"
    );
}

test "external body checks transitive GIL and reentry requirements" {
    compile_protocol(
        'import from c { @foreign_call(requires=["gil"], errors="none", reentrant=False) '
        'def external(value: i64) -> i64; } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64) -> i64 { return external(value); }',
        "requires undeclared capabilities"
    );
    compile_protocol(
        'import from c { @foreign_call(errors="none", reentrant=True) '
        'def external(value: i64) -> i64; } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64) -> i64 { return external(value); }',
        "can reenter through a call or cleanup"
    );
}

test "external body protocol requires native nogc even for scalar functions" {
    compile_protocol(
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(value: i64) -> i64 { return value; }',
        "checked foreign_call bodies require native nogc ownership", memory="managed"
    );
}

test "resource cleanup participates in checked external protocols" {
    compile_protocol(
        'import from jaclang.runtime.python.references { PyObjectRef, jacpy_ref_new } '
        '@foreign_call(requires=["gil"], errors="none", reentrant=False) '
        'def probe(value: &PyObjectRef) { owner: own PyObjectRef = jacpy_ref_new(value); }',
        "can reenter through a call or cleanup"
    );
}

test "a borrowed dependent owner cannot escape through its parent contract" {
    compile_protocol(
        '@foreign_resource(abi="pointer", empty=0, drop=close_cursor, '
        'aliasing="shared", reentrant_drop=False) obj Cursor; '
        'import from c { obj Connection; '
        '@foreign_call(errors="none", reentrant=False) def close_cursor(cursor: own Cursor); '
        '@foreign_call(errors="none", reentrant=False) '
        'def open_cursor(connection: &Connection) -> own Cursor from connection; } '
        'def probe(connection: &Connection) -> &Cursor from connection { '
        'cursor: own Cursor from connection = open_cursor(connection); return &cursor; }',
        "returned value depends on an owner absent from the return contract"
    );
}

test "transferring the dependent owner preserves its parent contract" {
    compile_protocol(
        '@foreign_resource(abi="pointer", empty=0, drop=close_cursor, '
        'aliasing="shared", reentrant_drop=False) obj Cursor; '
        'import from c { obj Connection; '
        '@foreign_call(errors="none", reentrant=False) def close_cursor(cursor: own Cursor); '
        '@foreign_call(errors="none", reentrant=False) '
        'def open_cursor(connection: &Connection) -> own Cursor from connection; } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(connection: &Connection) -> own Cursor from connection { '
        'cursor: own Cursor from connection = open_cursor(connection); return cursor; }'
    );
}

test "consuming a dependent through a borrowed source alias preserves its root" {
    compile_protocol(
        '@foreign_resource(abi="pointer", empty=0, drop=close_cursor, '
        'aliasing="shared", reentrant_drop=False) obj Cursor; '
        'import from c { obj Connection; '
        '@foreign_call(errors="none", reentrant=False) def close_cursor(cursor: own Cursor); '
        '@foreign_call(errors="none", reentrant=False) '
        'def alias(connection: &Connection) -> &Connection from connection; '
        '@foreign_call(errors="none", reentrant=False) '
        'def open_cursor(connection: &Connection) -> lin Cursor from connection; '
        '@foreign_call(errors="none", reentrant=False) '
        'def finish(connection: &Connection, cursor: lin Cursor from connection); } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(connection: &Connection) { '
        'view: &Connection from connection = alias(connection); '
        'cursor: lin Cursor from connection = open_cursor(view); finish(connection, cursor); }'
    );
}

test "consuming a dependent cannot replace an owned source with its parent" {
    compile_protocol(
        '@foreign_resource(abi="pointer", empty=0, drop=close_cursor, '
        'aliasing="shared", reentrant_drop=False) obj Cursor; '
        'import from c { obj Connection; '
        '@foreign_call(errors="none", reentrant=False) def close_cursor(cursor: own Cursor); '
        '@foreign_call(errors="none", reentrant=False) '
        'def open_cursor(connection: &Connection) -> own Cursor from connection; '
        '@foreign_call(errors="none", reentrant=False) '
        'def child(parent: &Cursor) -> own Cursor from parent; '
        '@foreign_call(errors="none", reentrant=False) '
        'def finish(connection: &Connection, cursor: own Cursor from connection); } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(connection: &Connection) { '
        'parent: own Cursor from connection = open_cursor(connection); '
        'cursor: own Cursor from parent = child(&parent); finish(connection, cursor); }',
        "would erase a lifetime dependency"
    );
}

test "a declared view can accompany its consumed owner for its last use" {
    compile_protocol(
        '@foreign_resource(abi="pointer", empty=0, drop=close_handle, '
        'aliasing="shared", reentrant_drop=False) obj Handle; '
        'import from c { '
        '@foreign_call(errors="none", reentrant=False) def close_handle(value: own Handle); '
        '@foreign_call(errors="none", reentrant=False) def make_handle() -> own Handle; '
        '@foreign_call(errors="none", reentrant=False) '
        'def finish(owner: lin Handle, view: &Handle from owner); } '
        '@foreign_call(errors="none", reentrant=False) def probe() { '
        'owner: own Handle = make_handle(); view: &Handle from owner = &owner; '
        'finish(owner, view); }'
    );
}

test "a view passed with its consumed owner cannot be used afterward" {
    compile_protocol(
        '@foreign_resource(abi="pointer", empty=0, drop=close_handle, '
        'aliasing="shared", reentrant_drop=False) obj Handle; '
        'import from c { '
        '@foreign_call(errors="none", reentrant=False) def close_handle(value: own Handle); '
        '@foreign_call(errors="none", reentrant=False) def make_handle() -> own Handle; '
        '@foreign_call(errors="none", reentrant=False) def read(value: &Handle); '
        '@foreign_call(errors="none", reentrant=False) '
        'def finish(owner: lin Handle, view: &Handle from owner); } '
        '@foreign_call(errors="none", reentrant=False) def probe() { '
        'owner: own Handle = make_handle(); view: &Handle from owner = &owner; '
        'finish(owner, view); read(view); }',
        "E1304"
    );
}

test "a returned view cannot hide a consumed parameter behind a borrowed one" {
    compile_protocol(
        '@foreign_resource(abi="pointer", empty=0, drop=close_handle, '
        'aliasing="shared", reentrant_drop=False) obj Handle; '
        'import from c { '
        '@foreign_call(errors="none", reentrant=False) def close_handle(value: own Handle); } '
        'def invalid(owner: own Handle, view: &Handle from owner) -> &Handle from view { return view; }',
        "returned value depends on a consumed parameter"
    );
}

test "a borrowed parameter cannot substitute an unrelated source" {
    compile_protocol(
        'import from c { obj Handle; '
        '@foreign_call(errors="none", reentrant=False) '
        'def pass_view(owner: &Handle, view: &Handle from owner) -> &Handle from owner; } '
        '@foreign_call(errors="none", reentrant=False) '
        'def probe(a: &Handle, b: &Handle) -> &Handle from a { return pass_view(a, b); }',
        "does not satisfy its declared lifetime sources"
    );
}
