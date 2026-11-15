import asyncio;
import atexit;
import contextvars;
import inspect;
import logging;
import os;
import time;

import from concurrent.futures { Future, ThreadPoolExecutor, as_completed }

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


def mark_serialize(func: any) -> any;


def _is_async(func: any) -> bool;


def _index_by_identity(seq: list[any], item: any) -> int;


def _call_sync(tc: any, timeout: any) -> any;


def _call_async(tc: any, timeout: any) -> any;


def _run_one(tc: any) -> tuple[any, ...];


def _tool_names(tool_calls: list[any]) -> list[str];


def _any_serialize(tool_calls: list[any]) -> bool;


def dispatch_batch(tool_calls: list[any]) -> any;
