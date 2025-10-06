"""Concurrent expressions: Flow (spawn async task) and wait (await result)."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl
from time import sleep

def compute(x: int, y: int) -> int:
    print(f'Computing {x} + {y}')
    sleep(1)
    return x + y

def slow_task(n: int) -> int:
    print(f'Task {n} started')
    sleep(1)
    print(f'Task {n} done')
    return n * 2
task1 = _jl.thread_run(lambda: compute(5, 10))
task2 = _jl.thread_run(lambda: compute(3, 7))
task3 = _jl.thread_run(lambda: slow_task(42))
print('All tasks started concurrently')
result1 = _jl.thread_wait(task1)
result2 = _jl.thread_wait(task2)
result3 = _jl.thread_wait(task3)
print(f'Results: {result1}, {result2}, {result3}')
