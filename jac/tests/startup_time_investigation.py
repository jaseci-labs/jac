#!/usr/bin/env python3

"""
Process Startup Time Investigation for Jac Language Server
Analyzes the startup overhead and warm-up time for multiprocessing workers.
"""

import multiprocessing as mp
import time
import sys
import os
from typing import Dict, List, Tuple
import threading

# Add jac to path
sys.path.insert(0, '/home/kuggix/jaseci/jac')

def startup_worker(return_dict: dict, process_id: int):
    """Worker function that measures its own startup time."""
    process_start = time.time()
    
    # Measure import times
    import_start = time.time()
    from jaclang.compiler.program import JacProgram
    from jaclang.compiler.passes.main.type_checker_pass import TypeCheckPass
    import_time = time.time() - import_start
    
    # Measure JacProgram creation time
    program_start = time.time()
    program = JacProgram()
    program_time = time.time() - program_start
    
    # Measure builtins loading time (warm-up)
    warmup_start = time.time()
    try:
        # Force builtins loading by doing a simple parse
        warmup_code = "obj Test { has x: int; }"
        program.compile(use_str=warmup_code, file_path="warmup.jac", type_check=True)
        warmup_success = True
    except Exception as e:
        warmup_success = False
    warmup_time = time.time() - warmup_start
    
    total_startup_time = time.time() - process_start
    
    return_dict[process_id] = {
        'total_startup': total_startup_time,
        'import_time': import_time,
        'program_time': program_time,
        'warmup_time': warmup_time,
        'warmup_success': warmup_success
    }

def fresh_process_worker(code: str, file_path: str) -> Tuple[float, bool, float]:
    """Worker that creates fresh JacProgram for each request."""
    startup_start = time.time()
    
    from jaclang.compiler.program import JacProgram
    program = JacProgram()
    
    # Warmup
    try:
        warmup_code = "obj Test { has x: int; }"
        program.compile(use_str=warmup_code, file_path="warmup.jac", type_check=True)
        program.errors_had.clear()
        program.warnings_had.clear()
    except:
        pass
    
    startup_time = time.time() - startup_start
    
    # Parse the actual code
    parse_start = time.time()
    try:
        program.compile(use_str=code, file_path=file_path, type_check=True)
        success = len(program.errors_had) == 0
    except Exception:
        success = False
    
    parse_time = time.time() - parse_start
    
    return parse_time, success, startup_time

def simple_parse_task(task_id: int) -> Tuple[float, int]:
    """Simple parsing task for testing."""
    start_time = time.time()
    
    from jaclang.compiler.program import JacProgram
    program = JacProgram()
    
    try:
        code = f"obj Task{task_id} {{ has id: int = {task_id}; }}"
        program.compile(use_str=code, file_path=f"task_{task_id}.jac", type_check=True)
    except:
        pass
    
    return time.time() - start_time, task_id

def measure_process_startup():
    """Measure the time it takes to start a Python process and import Jac."""
    
    print("=== Process Startup Time Analysis ===")
    
    # Test multiple processes to get average startup times
    num_processes = 5
    startup_times = []
    
    for i in range(num_processes):
        manager = mp.Manager()
        return_dict = manager.dict()
        
        process_start = time.time()
        process = mp.Process(target=startup_worker, args=(return_dict, i))
        process.start()
        process.join()
        process_total = time.time() - process_start
        
        if i in return_dict:
            data = return_dict[i]
            startup_times.append(data)
            print(f"Process {i}:")
            print(f"  Total startup: {data['total_startup']:.4f}s")
            print(f"  Import time: {data['import_time']:.4f}s")
            print(f"  Program creation: {data['program_time']:.4f}s")
            print(f"  Warmup time: {data['warmup_time']:.4f}s")
            print(f"  Warmup success: {data['warmup_success']}")
            print(f"  Process overhead: {process_total - data['total_startup']:.4f}s")
        else:
            print(f"Process {i}: Failed to start properly")
    
    if startup_times:
        avg_total = sum(d['total_startup'] for d in startup_times) / len(startup_times)
        avg_import = sum(d['import_time'] for d in startup_times) / len(startup_times)
        avg_program = sum(d['program_time'] for d in startup_times) / len(startup_times)
        avg_warmup = sum(d['warmup_time'] for d in startup_times) / len(startup_times)
        
        print(f"\nAverage Startup Times:")
        print(f"  Total: {avg_total:.4f}s")
        print(f"  Import: {avg_import:.4f}s ({avg_import/avg_total*100:.1f}%)")
        print(f"  Program creation: {avg_program:.4f}s ({avg_program/avg_total*100:.1f}%)")
        print(f"  Warmup: {avg_warmup:.4f}s ({avg_warmup/avg_total*100:.1f}%)")
        
        return avg_total, avg_import, avg_program, avg_warmup
    
    return 0, 0, 0, 0

def measure_persistent_worker_performance():
    """Measure performance of persistent workers vs fresh processes."""
    
    class PersistentWorker:
        """A worker that stays alive and processes multiple requests."""
        
        def __init__(self, worker_id: int):
            self.worker_id = worker_id
            self.startup_time = time.time()
            
            # Initialize once
            from jaclang.compiler.program import JacProgram
            self.program = JacProgram()
            
            # Warm up
            try:
                warmup_code = "obj Test { has x: int; }"
                self.program.compile(use_str=warmup_code, file_path="warmup.jac", type_check=True)
                self.program.errors_had.clear()
                self.program.warnings_had.clear()
            except:
                pass
            
            self.ready_time = time.time()
            self.init_duration = self.ready_time - self.startup_time
        
        def parse_code(self, code: str, file_path: str) -> Tuple[float, bool]:
            """Parse code using the persistent program instance."""
            start_time = time.time()
            
            try:
                self.program.compile(use_str=code, file_path=file_path, type_check=True)
                success = len(self.program.errors_had) == 0
                
                # Clear for next use
                self.program.errors_had.clear()
                self.program.warnings_had.clear()
                
            except Exception:
                success = False
            
            return time.time() - start_time, success
    
    print("\n=== Persistent vs Fresh Worker Performance ===")
    
    test_code = """
obj Counter {
    has value: int = 0;
    
    def increment() -> int {
        self.value += 1;
        return self.value;
    }
}

with entry {
    counter = Counter();
    result = counter.increment();
}
"""
    
    # Test 1: Persistent worker
    print("1. Persistent Worker Performance:")
    worker = PersistentWorker(0)
    print(f"   Initialization time: {worker.init_duration:.4f}s")
    
    persistent_times = []
    for i in range(10):
        parse_time, success = worker.parse_code(test_code, f"persistent_{i}.jac")
        persistent_times.append(parse_time)
        status = "✅" if success else "❌"
        print(f"   Parse {i}: {parse_time:.4f}s {status}")
    
    # Test 2: Fresh process for each request
    print("\n2. Fresh Process Performance:")
    fresh_times = []
    startup_times = []
    
    for i in range(5):  # Fewer iterations due to overhead
        start_total = time.time()
        
        # Use multiprocessing to simulate fresh process
        with mp.Pool(1) as pool:
            result = pool.apply(fresh_process_worker, (test_code, f"fresh_{i}.jac"))
            parse_time, success, startup_time = result
        
        total_time = time.time() - start_total
        fresh_times.append(total_time)
        startup_times.append(startup_time)
        
        status = "✅" if success else "❌"
        print(f"   Request {i}: {total_time:.4f}s (startup: {startup_time:.4f}s, parse: {parse_time:.4f}s) {status}")
    
    # Analysis
    persistent_avg = sum(persistent_times) / len(persistent_times)
    fresh_avg = sum(fresh_times) / len(fresh_times)
    startup_avg = sum(startup_times) / len(startup_times)
    
    print(f"\nPerformance Comparison:")
    print(f"  Persistent worker avg: {persistent_avg:.4f}s")
    print(f"  Fresh process avg: {fresh_avg:.4f}s")
    print(f"  Fresh process startup overhead: {startup_avg:.4f}s")
    print(f"  Overhead factor: {fresh_avg / persistent_avg:.1f}x")
    
    return persistent_avg, fresh_avg, startup_avg

def measure_pool_startup_vs_ondemand():
    """Compare pre-started process pool vs on-demand process creation."""
    
    print("\n=== Process Pool vs On-Demand Creation ===")
    
    num_tasks = 8
    
    # Test 1: Pre-started process pool
    print("1. Pre-started Process Pool:")
    pool_start = time.time()
    
    with mp.Pool(processes=4) as pool:
        pool_ready_time = time.time()
        print(f"   Pool startup time: {pool_ready_time - pool_start:.4f}s")
        
        # Submit tasks
        task_start = time.time()
        results = pool.map(simple_parse_task, range(num_tasks))
        pool_total_time = time.time() - task_start
    
    pool_times = [result[0] for result in results]
    print(f"   Task execution time: {pool_total_time:.4f}s")
    print(f"   Average task time: {sum(pool_times)/len(pool_times):.4f}s")
    
    # Test 2: On-demand process creation
    print("\n2. On-Demand Process Creation:")
    ondemand_start = time.time()
    
    ondemand_times = []
    for i in range(num_tasks):
        task_start = time.time()
        with mp.Pool(1) as single_pool:
            result = single_pool.apply(simple_parse_task, (i,))
        task_time = time.time() - task_start
        ondemand_times.append(task_time)
        print(f"   Task {i}: {task_time:.4f}s")
    
    ondemand_total_time = time.time() - ondemand_start
    
    # Analysis
    pool_efficiency = (pool_ready_time - pool_start + pool_total_time)
    ondemand_efficiency = ondemand_total_time
    
    print(f"\nComparison:")
    print(f"  Pool (startup + execution): {pool_efficiency:.4f}s")
    print(f"  On-demand total: {ondemand_efficiency:.4f}s")
    print(f"  Pool advantage: {ondemand_efficiency / pool_efficiency:.2f}x faster")
    
    return pool_efficiency, ondemand_efficiency

def analyze_language_server_implications():
    """Analyze what these startup times mean for a real language server."""
    
    print("\n=== Language Server Implications ===")
    
    # Simulate different usage patterns
    usage_patterns = {
        "Heavy typing session": {
            "description": "User types rapidly for 5 minutes",
            "requests_per_minute": 60,  # 1 per second
            "duration_minutes": 5
        },
        "Moderate editing": {
            "description": "Normal editing with pauses",
            "requests_per_minute": 20,
            "duration_minutes": 30
        },
        "Light usage": {
            "description": "Occasional edits",
            "requests_per_minute": 5,
            "duration_minutes": 60
        }
    }
    
    # Assume startup times from previous tests
    startup_time = 1.0  # seconds (estimated from previous tests)
    persistent_parse_time = 0.005  # seconds
    fresh_parse_time = startup_time + persistent_parse_time
    
    print(f"Assumptions:")
    print(f"  Process startup time: {startup_time:.3f}s")
    print(f"  Persistent worker parse time: {persistent_parse_time:.3f}s")
    print(f"  Fresh process parse time: {fresh_parse_time:.3f}s")
    
    for pattern_name, pattern in usage_patterns.items():
        print(f"\n{pattern_name}: {pattern['description']}")
        
        total_requests = pattern['requests_per_minute'] * pattern['duration_minutes']
        
        # Persistent workers (language server with process pool)
        persistent_total = total_requests * persistent_parse_time
        
        # Fresh processes (naive approach)
        fresh_total = total_requests * fresh_parse_time
        
        print(f"  Total requests: {total_requests}")
        print(f"  Persistent workers: {persistent_total:.2f}s total processing time")
        print(f"  Fresh processes: {fresh_total:.2f}s total processing time")
        print(f"  Overhead saved: {fresh_total - persistent_total:.2f}s")
        print(f"  Efficiency gain: {fresh_total / persistent_total:.1f}x")

def recommend_optimal_architecture():
    """Provide recommendations based on startup time analysis."""
    
    print("\n=== Optimal Architecture Recommendations ===")
    
    recommendations = """
    Based on startup time analysis:

    1. 🚀 USE PERSISTENT PROCESS POOL:
       - Pre-start 2-4 worker processes
       - Keep them alive for the session
       - Amortize startup cost across many requests

    2. ⚡ OPTIMIZE STARTUP TIME:
       - Pre-compile critical modules
       - Use lazy imports where possible
       - Cache compiled builtins globally

    3. 🎯 HYBRID APPROACH:
       - Keep small persistent pool (2-4 workers)
       - Use on-demand for occasional heavy tasks
       - Balance memory usage vs responsiveness

    4. 📊 MONITORING:
       - Track worker utilization
       - Monitor startup times
       - Adjust pool size based on usage

    5. 🔄 WORKER LIFECYCLE:
       - Restart workers periodically (avoid memory leaks)
       - Handle worker crashes gracefully
       - Implement health checks
    """
    
    print(recommendations)

if __name__ == "__main__":
    # Force spawn method for consistency
    mp.set_start_method('spawn', force=True)
    
    print("Process Startup Time Investigation for Jac Language Server")
    print("=" * 60)
    print(f"System has {mp.cpu_count()} CPU cores\n")
    
    # Test 1: Basic startup time measurement
    avg_total, avg_import, avg_program, avg_warmup = measure_process_startup()
    
    # Test 2: Persistent vs fresh worker performance
    persistent_avg, fresh_avg, startup_overhead = measure_persistent_worker_performance()
    
    # Test 3: Pool startup vs on-demand
    pool_time, ondemand_time = measure_pool_startup_vs_ondemand()
    
    # Test 4: Language server implications
    analyze_language_server_implications()
    
    # Test 5: Recommendations
    recommend_optimal_architecture()
    
    # Summary
    print("\n" + "=" * 60)
    print("STARTUP TIME ANALYSIS SUMMARY")
    print("=" * 60)
    print(f"Average process startup time: {avg_total:.4f}s")
    print(f"  - Import overhead: {avg_import:.4f}s")
    print(f"  - Program creation: {avg_program:.4f}s")
    print(f"  - Warmup time: {avg_warmup:.4f}s")
    print(f"Persistent vs fresh overhead: {fresh_avg / persistent_avg:.1f}x")
    print(f"Pool vs on-demand efficiency: {ondemand_time / pool_time:.1f}x")
    
    # Final recommendation
    if avg_total < 0.5:
        print(f"\n✅ STARTUP TIME ACCEPTABLE: {avg_total:.3f}s is reasonable for persistent workers")
    elif avg_total < 1.0:
        print(f"\n⚠️  STARTUP TIME MODERATE: {avg_total:.3f}s - use persistent pools")
    else:
        print(f"\n❌ STARTUP TIME HIGH: {avg_total:.3f}s - definitely need persistent workers")
    
    print("\n🚀 RECOMMENDATION: Use persistent process pool for Jac language server!")
