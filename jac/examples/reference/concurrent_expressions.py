"""Concurrent expressions: Flow (spawn async task) and wait (await result)."""

from __future__ import annotations
from jaclang.lib import thread_run, thread_wait
from time import sleep


def compute(x: int, y: int) -> int:
    print(f"Computing {x} + {y}")
    sleep(1)
    return x + y


def slow_task(n: int) -> int:
    print(f"Task {n} started")
    sleep(1)
    print(f"Task {n} done")
    return n * 2


task1 = thread_run(lambda: compute(5, 10))
task2 = thread_run(lambda: compute(3, 7))
task3 = thread_run(lambda: slow_task(42))
print("All tasks started concurrently")
result1 = thread_wait(task1)
result2 = thread_wait(task2)
result3 = thread_wait(task3)
print(f"Results: {result1}, {result2}, {result3}")
