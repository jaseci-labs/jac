"""Deferred execution keeps the provider's request context and releases it."""
import asyncio;
import from unittest.mock { patch }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.runtime { JacRuntime }

test "stream resumes in its provider context and releases its session" {
    context = ExecutionContext(base_path_dir='', full_target_path='');
    caller = JacRuntime.peek_context();
    def chunks -> Generator[str, None, None] {
        assert JacRuntime.peek_context() is context;
        yield 'first';
        assert JacRuntime.peek_context() is context;
        yield 'second';
    }
    with patch.object(context.mem, 'close') as close {
        stream: any = context.bind_stream(chunks());
        assert next(stream) == 'first';
        assert JacRuntime.peek_context() is caller;
        assert next(stream) == 'second';
        assert JacRuntime.peek_context() is caller;
        stream.close();
        close.assert_called_once();
    }
}

test "async stream restores the caller context between chunks" {
    context = ExecutionContext(base_path_dir='', full_target_path='');
    async def chunks -> AsyncGenerator[str, None] {
        assert JacRuntime.peek_context() is context;
        yield 'first';
        assert JacRuntime.peek_context() is context;
        yield 'second';
    }
    async def consume {
        caller = JacRuntime.peek_context();
        stream: any = context.bind_stream(chunks());
        assert await stream.__anext__() == 'first';
        assert JacRuntime.peek_context() is caller;
        await stream.aclose();
        assert JacRuntime.peek_context() is caller;
    }
    with patch.object(context.mem, 'close') as close {
        asyncio.run(consume());
        close.assert_called_once();
    }
}
