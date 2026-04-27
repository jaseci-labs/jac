"""Parallel tool-calling engine for byllm.

LLM-driven parallelism: when the LLM emits N tool calls in a single
response, byllm treats that as a signal of independence and runs them
concurrently by default.  Tools that MUST run sequentially opt out
with `serialize=True` on the Tool object.

Design:
  - Shared module-level ThreadPoolExecutor (env-configurable via BYLLM_TOOL_WORKERS)
  - `dispatch_batch(tool_calls)` is a generator that yields (tc, msg, ms)
    as each worker completes, enabling real-time streaming of results
  - Decision tree:
      1. batch size == 1  -> inline (no pool overhead)
      2. any tool has serialize=True -> all run sequentially
      3. else -> parallel via shared pool
  - Async tool support: coroutine functions are run via asyncio.run()
  - Per-tool timeout support via Tool.timeout_sec
  - atexit cleanup of the shared pool
"""

import asyncio;
import atexit;
import inspect;
import logging;
import os;
import time;

import from concurrent.futures { ThreadPoolExecutor, as_completed }
import from byllm.types { ToolCallResultMsg }

glob _plog = logging.getLogger("byllm.parallel"),
     # ---------------------------------------------------------------------------
     # Shared worker pool (module-level, reused across all dispatch_batch calls)
     # ---------------------------------------------------------------------------
     _POOL_SIZE: int = int(
         os.environ.get("BYLLM_TOOL_WORKERS", str(min(32, (os.cpu_count() or 4) * 5)))
     ),
     _WORKER_POOL: ThreadPoolExecutor = ThreadPoolExecutor(
         max_workers=_POOL_SIZE, thread_name_prefix="byllm-tool"
     );

with entry {
    atexit.register(_WORKER_POOL.shutdown);
}

# ---------------------------------------------------------------------------
# System prompt nudge for LLM
# ---------------------------------------------------------------------------
glob _PARALLEL_TOOL_HINT: str = (
         "\n\nWhen you need multiple independent pieces of information, "
         "call all the relevant tools in a single response so they run in parallel. "
         "Call tools sequentially (one per turn) only when a later call depends on "
         "the result of an earlier one."
     );


# ---------------------------------------------------------------------------
# User-facing helpers
# ---------------------------------------------------------------------------
"""Mark a tool function as serialize (must run sequentially, not in parallel).

Sets the _serialize attribute on the function so that Tool.postinit
picks it up automatically when wrapping the function.

Usage (Jac):
    with entry {
        mark_serialize(write_file);
        mark_serialize(run_command);
    }
"""
def mark_serialize(func: Any) -> Any {
    setattr(func, '_serialize', True);
    return func;
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
"""Check if a callable is an async coroutine function."""
def _is_async(func: Any) -> bool {
    return bool(inspect.iscoroutinefunction(func));
}


"""Find the index of `item` in `seq` by object identity (id()), not __eq__."""
def _index_by_identity(seq: list, item: Any) -> int {
    target_id = id(item);
    for (i, elem) in enumerate(seq) {
        if id(elem) == target_id {
            return i;
        }
    }
    return -1;
}


"""Call a synchronous tool, optionally wrapping in a thread with timeout."""
def _call_sync(tc: Any, timeout: Any) -> Any {
    if timeout is None {
        return tc();
    }
    import threading;
    result_box: list = [None];
    error_box: list = [None];
    def _worker {
        try {
            result_box[0] = tc();
        } except Exception as e {
            error_box[0] = e;
        }
    }
    t = threading.Thread(target=_worker, daemon=True);
    t.start();
    t.join(timeout=timeout);
    if t.is_alive() {
        raise TimeoutError(f"Tool '{tc.tool.get_name()}' timed out after {timeout}s");
    }
    if error_box[0] is not None {
        raise error_box[0];
    }
    return result_box[0];
}


"""Call an async tool via asyncio.run() with optional timeout."""
def _call_async(tc: Any, timeout: Any) -> Any {
    async def _run -> Any {
        coro = tc.tool.func(**tc.args);
        if timeout is not None {
            return await asyncio.wait_for(coro, timeout=timeout);
        }
        return await coro;
    }
    result_val = asyncio.run(_run());
    return ToolCallResultMsg(
        content=str(result_val), tool_call_id=tc.call_id, name=tc.tool.get_name()
    );
}


"""Execute a single tool call with optional timeout.

Always returns (ToolCall, ToolCallResultMsg, duration_ms) — never raises.
If the tool is an async function, runs it via asyncio.run().
TimeoutError / asyncio.TimeoutError are reported with a consistent
"timed out after Xs" message; all other errors fall to the generic catch.
"""
def _run_one(tc: Any) -> tuple {
    t0 = time.time();
    timeout = tc.tool.timeout_sec;
    try {
        if _is_async(tc.tool.func) {
            msg = _call_async(tc, timeout);
        } else {
            msg = _call_sync(tc, timeout);
        }
    } except (TimeoutError, asyncio.TimeoutError) as e {
        msg = ToolCallResultMsg(
            content=f"Tool '{tc.tool.get_name()}' timed out after {timeout}s",
            tool_call_id=tc.call_id,
            name=tc.tool.get_name()
        );
    } except Exception as e {
        msg = ToolCallResultMsg(
            content=f"Tool error: {e}", tool_call_id=tc.call_id, name=tc.tool.get_name()
        );
    }
    ms = int((time.time() - t0) * 1000);
    return (tc, msg, ms);
}


"""Return a flat list of tool-name strings from a batch — for logging."""
def _tool_names(tool_calls: list) -> list {
    names: list = [];
    for tc in tool_calls {
        try {
            names.append(tc.tool.get_name());
        } except Exception {
            names.append("?");
        }
    }
    return names;
}


"""Check whether any tool in the batch has serialize=True."""
def _any_serialize(tool_calls: list) -> bool {
    for tc in tool_calls {
        if tc.tool.serialize {
            return True;
        }
    }
    return False;
}


# ---------------------------------------------------------------------------
# Core dispatcher (generator)
# ---------------------------------------------------------------------------
"""Dispatch a batch of tool calls, yielding (tc, result_msg, duration_ms).

Decision tree (first matching rule wins):
  1. Batch size == 1         -> inline execution (no pool overhead)
  2. Any tool has serialize  -> all run sequentially in input order
  3. Otherwise               -> parallel via shared ThreadPoolExecutor

For the parallel path, results are yielded as workers complete
(out of input order). The caller is responsible for reordering
if input-order is needed (e.g. for mt_run.add_message).
"""
def dispatch_batch(tool_calls: list) -> Any {
    n = len(tool_calls);
    if n == 0 {
        return;
    }
    names = _tool_names(tool_calls);

    # --- Single tool: inline, no pool overhead ---
    if n == 1 {
        _plog.debug("batch dispatch=inline size=1 tool=%s", names[0]);
        yield _run_one(tool_calls[0]);
        return;
    }

    # --- Any serialize=True: run all sequentially ---
    if _any_serialize(tool_calls) {
        _plog.info(
            "batch dispatch=sequential reason=serialize size=%d tools=%s", n, names
        );
        for tc in tool_calls {
            yield _run_one(tc);
        }
        return;
    }

    # --- Parallel path ---
    workers = min(n, _POOL_SIZE);
    _plog.info(
        "batch dispatch=parallel size=%d workers=%d tools=%s", n, workers, names
    );
    t_batch = time.time();

    futures: dict = {};
    for tc in tool_calls {
        f = _WORKER_POOL.submit(_run_one, tc);
        futures[f] = tc;
    }
    for f in as_completed(futures) {
        try {
            yield f.result();
        } except Exception as e {
            tc_err = futures[f];
            err_msg = ToolCallResultMsg(
                content=f"Parallel dispatch error: {e}",
                tool_call_id=tc_err.call_id,
                name=tc_err.tool.get_name()
            );
            yield (tc_err, err_msg, 0);
        }
    }

    wall_ms = int((time.time() - t_batch) * 1000);
    _plog.info(
        "batch done=parallel size=%d workers=%d wall_ms=%d", n, workers, wall_ms
    );
}
