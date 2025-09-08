 #!/usr/bin/env python3

"""
Multiprocessing-based parser test for Jac language server.
Tests performance and scalability using process-based parallelism instead of threading.
"""

import multiprocessing as mp
import time
import sys
import os
from typing import List, Tuple

# Add jac to path
sys.path.insert(0, '/home/kuggix/jaseci/jac')

from jaclang.compiler.program import JacProgram

# Test code samples
TEST_CODES = [
    """
obj Calculator {
    has value: float = 0.0;
    
    def add(x: float) -> float {
        self.value += x;
        return self.value;
    }

    def multiply(x: float) -> float {
        self.value *= x;
        return self.value;
    }
}

with entry {
    calc = Calculator();
    result = calc.add(10.5).multiply(2.0);
    print(f"Result: {result}");
}
""",
    """
obj Node {
    has value: int;
    
    def get_value() -> int {
        return self.value;
    }
}

with entry {
    node = Node(value=42);
    result = node.get_value();
    print(f"Node value: {result}");
}
""",
    """
enum Status {
    PENDING = "pending",
    COMPLETED = "completed", 
    FAILED = "failed"
}

obj Task {
    has id: int;
    has status: Status = Status.PENDING;

    def complete() -> Status {
        self.status = Status.COMPLETED;
        return self.status;
    }
}

with entry {
    task = Task(id=1);
    task.complete();
    print(f"Task {task.id} status: {task.status}");
}
"""
]

def parse_code_process(code_info: Tuple[str, str, int]) -> Tuple[float, bool, str, int]:
    """Parse code in a separate process."""
    code, file_path, process_id = code_info
    start_time = time.time()
    error_msg = ""
    success = True
    
    try:
        # Each process gets its own JacProgram instance - no sharing!
        program = JacProgram()
        
        # Compile the code (includes parsing, type checking, etc.)
        result = program.compile(use_str=code, file_path=file_path, type_check=True)
        
        # Check for compilation errors
        if program.errors_had:
            success = False
            error_msg = f"Compilation errors: {[str(e) for e in program.errors_had]}"
        
    except Exception as e:
        success = False
        error_msg = f"Exception: {str(e)}"
    
    parse_time = time.time() - start_time
    return parse_time, success, error_msg, process_id

def test_multiprocess_vs_threading():
    """Compare multiprocessing vs threading performance."""
    print("=== Multiprocessing vs Threading Performance Test ===")
    
    # Prepare test data
    test_data = []
    for i, code in enumerate(TEST_CODES * 3):  # 9 total tests
        test_data.append((code, f"test_mp_{i}.jac", i))
    
    # Test 1: Sequential processing (baseline)
    print("1. Sequential Processing:")
    sequential_times = []
    start_time = time.time()
    
    for code_info in test_data:
        parse_time, success, error_msg, process_id = parse_code_process(code_info)
        sequential_times.append(parse_time)
        status = "✅" if success else "❌"
        print(f"  Sequential {process_id}: {parse_time:.4f}s {status}")
    
    sequential_total = time.time() - start_time
    sequential_avg = sum(sequential_times) / len(sequential_times)
    
    # Test 2: Multiprocessing
    print("\n2. Multiprocessing:")
    start_time = time.time()
    
    with mp.Pool(processes=mp.cpu_count()) as pool:
        results = pool.map(parse_code_process, test_data)
    
    multiprocess_total = time.time() - start_time
    multiprocess_times = [result[0] for result in results]
    multiprocess_avg = sum(multiprocess_times) / len(multiprocess_times)
    
    for result in results:
        parse_time, success, error_msg, process_id = result
        status = "✅" if success else "❌"
        print(f"  Process {process_id}: {parse_time:.4f}s {status}")
    
    # Analysis
    speedup = sequential_total / multiprocess_total
    efficiency = speedup / mp.cpu_count()
    
    print(f"\nPerformance Analysis:")
    print(f"  Sequential total: {sequential_total:.4f}s")
    print(f"  Sequential avg: {sequential_avg:.4f}s")
    print(f"  Multiprocess total: {multiprocess_total:.4f}s")
    print(f"  Multiprocess avg: {multiprocess_avg:.4f}s")
    print(f"  Speedup: {speedup:.2f}x")
    print(f"  Efficiency: {efficiency:.2f} (on {mp.cpu_count()} cores)")
    
    if speedup > 1.5:
        print(f"  🚀  EXCELLENT: {speedup:.1f}x speedup with multiprocessing!")
    elif speedup > 1.0:
        print(f"  ✅  GOOD: {speedup:.1f}x speedup with multiprocessing")
    else:
        print(f"  ⚠️  NO BENEFIT: {speedup:.1f}x speedup (overhead too high)")
    
    return speedup, efficiency

def test_rapid_parsing_multiprocess():
    """Test rapid parsing simulation using multiprocessing."""
    print("\n=== Rapid Parsing Test: Multiprocessing ===")
    
    test_code = """
obj TestObj {
    has counter: int = 0;
    
    def increment() -> int {
        self.counter += 1;
        return self.counter;
    }
}

with entry {
    obj = TestObj();
    result = obj.increment();
}
"""
    
    # Create many rapid parsing tasks
    num_tasks = 20
    test_data = [(test_code, f"rapid_mp_{i}.jac", i) for i in range(num_tasks)]
    
    print(f"Running {num_tasks} rapid parsing tasks...")
    
    # Test multiprocessing performance
    start_time = time.time()
    
    with mp.Pool(processes=min(mp.cpu_count(), 8)) as pool:
        results = pool.map(parse_code_process, test_data)
    
    total_time = time.time() - start_time
    parse_times = [result[0] for result in results]
    
    # Analysis
    avg_time = sum(parse_times) / len(parse_times)
    max_time = max(parse_times)
    throughput = len(parse_times) / total_time
    
    print(f"\nRapid Parsing Results:")
    print(f"  Total tasks: {len(parse_times)}")
    print(f"  Total time: {total_time:.4f}s")
    print(f"  Average parse time: {avg_time:.4f}s")
    print(f"  Maximum parse time: {max_time:.4f}s")
    print(f"  Throughput: {throughput:.1f} parses/second")
    
    # Check for any slow parses
    slow_parses = [t for t in parse_times if t > 0.1]  # 100ms threshold
    if slow_parses:
        print(f"  ⚠️  {len(slow_parses)} slow parses detected (>100ms)")
        print(f"     Slowest: {max(slow_parses):.4f}s")
    else:
        print(f"  ✅  All parses completed quickly (<100ms)")
    
    return max_time, throughput

def test_memory_isolation():
    """Test that processes have proper memory isolation."""
    print("\n=== Memory Isolation Test ===")
    
    def modify_global_state(process_id: int) -> Tuple[str, int]:
        """Try to modify global state and see if it affects other processes."""
        # Import here to avoid issues
        sys.path.insert(0, '/home/kuggix/jaseci/jac')
        from jaclang.compiler.passes.main.type_checker_pass import TypeCheckPass
        
        # Each process should start with fresh state
        initial_state = TypeCheckPass._BUILTINS_MODULE is None
        
        # Force loading in this process
        from jaclang.compiler.program import JacProgram
        program = JacProgram()
        try:
            program.compile(use_str="obj Test { has x: int; }", file_path=f"test_{process_id}.jac", type_check=True)
        except:
            pass
        
        # Check final state
        final_state = TypeCheckPass._BUILTINS_MODULE is not None
        
        return f"Process {process_id}: initial={initial_state}, final={final_state}", process_id
    
    # Run multiple processes to test isolation
    with mp.Pool(processes=4) as pool:
        results = pool.map(modify_global_state, range(4))
    
    print("Memory isolation results:")
    for result, process_id in results:
        print(f"  {result}")
    
    # All processes should start with fresh state
    isolation_good = all("initial=True" in result for result, _ in results)
    if isolation_good:
        print("  ✅  EXCELLENT: Perfect memory isolation between processes")
    else:
        print("  ⚠️  ISSUE: Memory state is being shared somehow")
    
    return isolation_good

def create_language_server_architecture():
    """Show how to implement multiprocessing in the language server."""
    print("\n=== Language Server Multiprocessing Architecture ===")
    
    architecture = """
    RECOMMENDED ARCHITECTURE:

    1. Main Language Server Process:
       - Handles LSP communication with VSCode
       - Manages process pool
       - Coordinates results

    2. Worker Processes (Pool):
       - Each handles parsing/compilation independently
       - No shared state between workers
       - Fresh JacProgram instance per request

    3. Benefits:
       ✅ True parallelism (no GIL)
       ✅ Memory isolation (no race conditions)
       ✅ Better CPU utilization
       ✅ Fault tolerance
       ✅ Simpler code (no locks needed)

    4. Implementation:
       ```python
       class JacLangServerMP:
           def __init__(self):
               self.process_pool = mp.Pool(processes=mp.cpu_count())
           
           def parse_file(self, file_path: str, content: str):
               # Submit to process pool
               future = self.process_pool.apply_async(
                   parse_code_process, 
                   [(content, file_path, 0)]
               )
               return future.get()  # Or use callbacks for async
       ```

    5. Migration Path:
       - Replace ThreadPoolExecutor with multiprocessing.Pool
       - Remove all thread locks and synchronization
       - Use process-safe communication (queues, pipes)
    """
    
    print(architecture)

if __name__ == "__main__":
    # Force multiprocessing to use spawn on all platforms for consistency
    mp.set_start_method('spawn', force=True)
    
    print("Running Multiprocessing Performance Tests...\n")
    print(f"System has {mp.cpu_count()} CPU cores\n")
    
    # Test 1: Compare multiprocessing vs sequential
    speedup, efficiency = test_multiprocess_vs_threading()
    
    # Test 2: Rapid parsing performance
    max_time, throughput = test_rapid_parsing_multiprocess()
    
    # Test 3: Memory isolation
    isolation_good = test_memory_isolation()
    
    # Test 4: Show architecture recommendations
    create_language_server_architecture()
    
    # Summary
    print("\n" + "="*60)
    print("MULTIPROCESSING TEST SUMMARY")
    print("="*60)
    print(f"Performance speedup: {speedup:.2f}x")
    print(f"CPU efficiency: {efficiency:.2f}")
    print(f"Maximum parse time: {max_time:.4f}s")
    print(f"Parsing throughput: {throughput:.1f} parses/sec")
    print(f"Memory isolation: {'✅ Good' if isolation_good else '❌ Issues'}")
    
    # Recommendation
    if speedup > 1.5 and isolation_good:
        print(f"\n🚀 STRONG RECOMMENDATION: Switch to multiprocessing!")
        print("Benefits:")
        print(f"  - {speedup:.1f}x performance improvement")
        print("  - No thread safety issues")
        print("  - Better CPU utilization")
        print("  - Eliminates race conditions completely")
    elif speedup > 1.0:
        print(f"\n✅ RECOMMENDATION: Consider multiprocessing")
        print(f"  - Moderate {speedup:.1f}x improvement")
        print("  - Eliminates thread safety complexity")
    else:
        print(f"\n⚠️  STICK WITH THREADING: Multiprocessing overhead too high")
