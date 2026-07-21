import asyncio;
import atexit;
import inspect;
import logging;
import os;
import time;

import from concurrent.futures { ThreadPoolExecutor, as_completed }
import from jaclang.byllm.types { ToolCallResultMsg, normalize_tool_result }

glob _plog = logging.getLogger("byllm.parallel"),
     _POOL_SIZE: int = int(
         os.environ.get("BYLLM_TOOL_WORKERS", str(min(32, (os.cpu_count() or 4) * 5)))
     ),
     _WORKER_POOL: ThreadPoolExecutor = ThreadPoolExecutor(
         max_workers=_POOL_SIZE, thread_name_prefix="byllm-tool"
     );

with entry {
    atexit.register(_WORKER_POOL.shutdown);
}

glob _PARALLEL_TOOL_HINT: str = (
         "\n\nWhen you need multiple independent pieces of information, "
         "call all the relevant tools in a single response so they run in parallel. "
         "Call tools sequentially (one per turn) only when a later call depends on "
         "the result of an earlier one."
     );


def mark_serialize(func: any) -> any {
    setattr(func, '_serialize', True);
    return func;
}


def _is_async(func: any) -> bool {
    return bool(inspect.iscoroutinefunction(func));
}


def _index_by_identity(seq: list, item: any) -> int {
    target_id = id(item);
    for (i, elem) in enumerate(seq) {
        if id(elem) == target_id {
            return i;
        }
    }
    return -1;
}


def _call_sync(tc: any, timeout: any) -> any {
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


def _call_async(tc: any, timeout: any) -> any {
    async def _run -> any {
        coro = tc.tool.func(**tc.args);
        if timeout is not None {
            return await asyncio.wait_for(coro, timeout=timeout);
        }
        return await coro;
    }
    result_val = asyncio.run(_run());
    return ToolCallResultMsg(
        content=normalize_tool_result(result_val),
        tool_call_id=tc.call_id,
        name=tc.tool.get_name()
    );
}


def _run_one(tc: any) -> tuple {
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


def _any_serialize(tool_calls: list) -> bool {
    for tc in tool_calls {
        if tc.tool.serialize {
            return True;
        }
    }
    return False;
}


def dispatch_batch(tool_calls: list) -> any {
    n = len(tool_calls);
    if n == 0 {
        return;
    }
    names = _tool_names(tool_calls);

    if n == 1 {
        _plog.debug("batch dispatch=inline size=1 tool=%s", names[0]);
        yield _run_one(tool_calls[0]);
        return;
    }

    if _any_serialize(tool_calls) {
        _plog.info(
            "batch dispatch=sequential reason=serialize size=%d tools=%s", n, names
        );
        for tc in tool_calls {
            yield _run_one(tc);
        }
        return;
    }

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
