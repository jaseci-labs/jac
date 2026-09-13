"""Compilation sessions reuse compatible roots and bound mutable ownership."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from threading { Event }
import from jaclang.compiler.driver.compilation_context {
    CompilationSession,
    context_program
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.dist.precompile_bytecode { precompile_context }
import jaclang.compiler.types.type_evaluator;
import jaclang.compiler.types.stubcat.reader;
import jaclang.compiler.types.stubcat.writer;
import jaclang.compiler.types.stubcat.modiface;

test "two roots share their analyzed dependency until the session budget expires" {
    with TemporaryDirectory() as directory, CompilationSession(
        max_roots=2
    ) as session {
        dependency = Path(directory) / "shared.jac";
        dependency.write_text("def value() -> int { return 40; }\n");
        sources: list[Path] = [];
        for name in ["first", "second"] {
            source = Path(directory) / f"{name}.jac";
            source.write_text(
                "import from shared { value }\n"
                "def answer() -> int { return value() + 2; }\n"
            );
            sources.append(source);
        }
        program = precompile_context(str(sources[0]), directory, session.program);
        assert program.session is session;
        program.iface_registry().ensure(str(sources[0]));
        assert program.get_bytecode(str(sources[0])) is not None;
        shared = program.find_module(str(dependency));
        assert shared is not None;
        assert program.analysis.parse_runs.get(str(dependency)) == 1;
        session.checkpoint();
        assert session.evictions == 0;
        second = precompile_context(str(sources[1]), directory, session.program);
        assert second is program;
        second.iface_registry().ensure(str(sources[1]));
        assert second.get_bytecode(str(sources[1])) is not None;
        assert second.find_module(str(dependency)) is shared;
        assert program.analysis.parse_runs.get(str(dependency)) == 1;
        assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
        session.checkpoint();
        assert session.evictions == 1;
        assert not program.mod.hub;
        assert not program.source_store.units;
        assert program.type_evaluator is None;
        assert not program.analysis.product_tasks;
    }
    assert session.closed;
}

test "session dependency freshness detects edits even when the root is unchanged" {
    with TemporaryDirectory() as directory, CompilationSession() as session {
        source = Path(directory) / "root.jac";
        dependency = Path(directory) / "dependency.jac";
        source.write_text("def answer() -> int { return 42; }\n");
        dependency.write_text("def value() -> int { return 40; }\n");
        program = session.program;
        program.hub.stamp(str(source));
        program.record_dependency(str(source), str(dependency));
        assert program.is_hub_entry_fresh(str(source));
        before = dependency.stat();
        dependency.write_text("def value() -> int { return 41; }\n");
        os.utime(dependency, ns=(before.st_atime_ns, before.st_mtime_ns));
        session.refresh();
        assert not program.is_hub_entry_fresh(str(source));
    }
}

test "session contexts isolate mutable products and never borrow the execution hub" {
    with CompilationSession() as session {
        first = context_program(session.program, CompileOptions(target_app="one"));
        second = context_program(session.program, CompileOptions(target_app="two"));
        assert first is not second;
        assert first.source_store is second.source_store;
        assert first.analysis is not second.analysis;
        compiler = first._get_compiler();
        internal_path = compiler.selfhost.jaclang_root()
            + "/compiler/driver/program.jac";
        assert compiler.selfhost.resolve(internal_path, first) is first;
        assert first._search_hubs() == [first.mod.hub];
        assert second.session is session;
        first.options.cancel_token = Event();
        first.options.cancel_token.set();
        session.checkpoint();
        assert session.evictions == 1;
        assert not session.program.contexts;
    }
}

test "a failed request releases its session state" {
    with TemporaryDirectory() as directory, CompilationSession() as session {
        path = str(Path(directory) / "source.jac");
        session.program.source_store.revisions[path] = "unfinished";
        session.checkpoint(failed=True);
        assert not session.program.source_store.revisions;
        assert session.evictions == 1;
    }
}
