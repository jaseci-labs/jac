"""Concurrent expressions: Flow (spawn async task) and wait (await result)."""

import from time { sleep }

def compute(x: int, y: int) -> int {
    print(f"Computing {x} + {y}");
    sleep(1);
    return x + y;
}

def slow_task(n: int) -> int {
    print(f"Task {n} started");
    sleep(1);
    print(f"Task {n} done");
    return n * 2;
}

# Flow - start concurrent execution (returns future/task)
glob task1 = flow compute(
         5, 10
     ) ,
     task2 = flow compute(3, 7) ,
     task3 = flow slow_task(42) ;

with entry {
    print("All tasks started concurrently");
}

# Wait - wait for task completion and get result
glob result1 = wait task1 ,
     result2 = wait task2 ,
     result3 = wait task3 ;

with entry {
    print(f"Results: {result1}, {result2}, {result3}");
}
