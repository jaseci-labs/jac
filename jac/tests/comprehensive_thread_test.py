#!/usr/bin/env python3

"""
Comprehensive thread safety test for Jac parsing and compilation.
Tests all levels of the compilation pipeline for race conditions.
"""

import concurrent.futures
import time
import threading
from typing import List
import sys
import os

# Add jac to path
sys.path.insert(0, '/home/kuggix/jaseci/jac')

from jaclang.compiler.program import JacProgram
from jaclang.compiler.passes.main.type_checker_pass import TypeCheckPass

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
walker DataProcessor {
    has processed_count: int = 0;
    
    can process with `root entry {
        visit [obj-->];
    }
    
    can process with Node entry {
        self.processed_count += 1;
        print(f"Processing node with value: {value}");
    }
}

obj Node {
    has value: int;
}

with entry {
    processor = DataProcessor();
    <>node = Node(value=42);
    processor.process();
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
    
    def fail() -> Status {
        self.status = Status.FAILED;
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

def parse_code_threadsafe(code: str, file_path: str, thread_id: int) -> tuple[float, bool, str]:
    """Parse code in a thread-safe manner."""
    start_time = time.time()
    error_msg = ""
    success = True
    
    try:
        # Each thread gets its own JacProgram instance
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
    return parse_time, success, error_msg

def test_builtin_module_race_condition():
    """Test if TypeCheckPass._BUILTINS_MODULE still has race conditions."""
    print("=== Testing TypeCheckPass._BUILTINS_MODULE Race Condition ===")
    
    # Reset builtins module to ensure fresh test
    TypeCheckPass._BUILTINS_MODULE = None
    
    def parse_with_builtins(thread_id: int) -> tuple[float, int]:
        """Parse code that requires builtins loading."""
        start_time = time.time()
        
        code = f"""
obj TestClass{thread_id} {{
    has value: int = {thread_id};
    
    def get_value() -> int {{
        return self.value;
    }}
}}

with entry {{
    <>test = TestClass{thread_id}();
    result = <>test.get_value();
    print(f"Thread {thread_id} result: {{result}}");
}}
"""
        
        program = JacProgram()
        try:
            program.compile(use_str=code, file_path=f"test_thread_{thread_id}.jac", type_check=True)
        except Exception as e:
            print(f"Thread {thread_id} error: {e}")
        
        return time.time() - start_time, thread_id
    
    # Test sequential parsing
    print("1. Sequential Parsing:")
    TypeCheckPass._BUILTINS_MODULE = None
    sequential_times = []
    for i in range(3):
        parse_time, thread_id = parse_with_builtins(i)
        sequential_times.append(parse_time)
        print(f"  Sequential {i}: {parse_time:.4f}s")
    
    # Test concurrent parsing
    print("\n2. Concurrent Parsing:")
    TypeCheckPass._BUILTINS_MODULE = None
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = []
        start_time = time.time()
        
        for i in range(3):
            future = executor.submit(parse_with_builtins, i)
            futures.append(future)
        
        concurrent_times = []
        for future in concurrent.futures.as_completed(futures):
            parse_time, thread_id = future.result()
            concurrent_times.append(parse_time)
            print(f"  Thread {thread_id}: {parse_time:.4f}s")
        
        total_concurrent_time = time.time() - start_time
    
    # Analysis
    sequential_avg = sum(sequential_times) / len(sequential_times)
    concurrent_avg = sum(concurrent_times) / len(concurrent_times)
    slowdown_factor = concurrent_avg / sequential_avg
    
    print(f"\nResults:")
    print(f"  Sequential avg: {sequential_avg:.4f}s")
    print(f"  Concurrent avg: {concurrent_avg:.4f}s")
    print(f"  Concurrent max: {max(concurrent_times):.4f}s")
    print(f"  Slowdown factor: {slowdown_factor:.2f}x")
    print(f"  Total concurrent time: {total_concurrent_time:.4f}s")
    
    if slowdown_factor > 2.0:
        print(f"  ⚠️  PERFORMANCE ISSUE: {slowdown_factor:.1f}x slowdown detected!")
    else:
        print(f"  ✅  GOOD: Minimal slowdown of {slowdown_factor:.1f}x")
    
    return slowdown_factor

def test_comprehensive_compilation():
    """Test comprehensive compilation pipeline under concurrent load."""
    print("\n=== Testing Comprehensive Compilation Pipeline ===")
    
    # Test sequential compilation
    print("1. Sequential Compilation:")
    sequential_times = []
    for i, code in enumerate(TEST_CODES):
        start_time = time.time()
        parse_time, success, error_msg = parse_code_threadsafe(code, f"test_sequential_{i}.jac", i)
        sequential_times.append(parse_time)
        status = "✅" if success else "❌"
        print(f"  Sequential {i}: {parse_time:.4f}s {status}")
        if not success:
            print(f"    Error: {error_msg}")
    
    # Test concurrent compilation
    print("\n2. Concurrent Compilation:")
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(TEST_CODES)) as executor:
        start_time = time.time()
        
        futures = []
        for i, code in enumerate(TEST_CODES):
            future = executor.submit(parse_code_threadsafe, code, f"test_concurrent_{i}.jac", i)
            futures.append((future, i))
        
        concurrent_times = []
        for future, thread_id in futures:
            parse_time, success, error_msg = future.result()
            concurrent_times.append(parse_time)
            status = "✅" if success else "❌"
            print(f"  Thread {thread_id}: {parse_time:.4f}s {status}")
            if not success:
                print(f"    Error: {error_msg}")
        
        total_concurrent_time = time.time() - start_time
    
    # Analysis
    sequential_avg = sum(sequential_times) / len(sequential_times)
    concurrent_avg = sum(concurrent_times) / len(concurrent_times)
    slowdown_factor = concurrent_avg / sequential_avg
    
    print(f"\nResults:")
    print(f"  Sequential avg: {sequential_avg:.4f}s")
    print(f"  Concurrent avg: {concurrent_avg:.4f}s")
    print(f"  Concurrent max: {max(concurrent_times):.4f}s")
    print(f"  Slowdown factor: {slowdown_factor:.2f}x")
    print(f"  Total concurrent time: {total_concurrent_time:.4f}s")
    
    if slowdown_factor > 2.0:
        print(f"  ⚠️  PERFORMANCE ISSUE: {slowdown_factor:.1f}x slowdown detected!")
    else:
        print(f"  ✅  GOOD: Minimal slowdown of {slowdown_factor:.1f}x")
    
    return slowdown_factor

def stress_test_rapid_parsing():
    """Simulate rapid typing scenario with high-frequency parsing."""
    print("\n=== Stress Test: Rapid Parsing Simulation ===")
    
    test_code = """
obj TestObj {
    has counter: int = 0;
    
    can increment() -> int {
        self.counter += 1;
        return self.counter;
    }
}

with entry {
    obj = TestObj();
    result = obj.increment();
}
"""
    
    def rapid_parse_worker(worker_id: int, iterations: int) -> List[float]:
        """Worker that performs rapid parsing like during typing."""
        times = []
        for i in range(iterations):
            start_time = time.time()
            program = JacProgram()
            try:
                program.compile(use_str=test_code, file_path=f"rapid_{worker_id}_{i}.jac", type_check=True)
            except Exception as e:
                print(f"Worker {worker_id}, iteration {i} error: {e}")
            times.append(time.time() - start_time)
        return times
    
    # Test with multiple workers simulating rapid typing
    iterations_per_worker = 5
    num_workers = 3
    
    print(f"Running {num_workers} workers, {iterations_per_worker} iterations each...")
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_workers) as executor:
        start_time = time.time()
        
        futures = []
        for worker_id in range(num_workers):
            future = executor.submit(rapid_parse_worker, worker_id, iterations_per_worker)
            futures.append((future, worker_id))
        
        all_times = []
        for future, worker_id in futures:
            worker_times = future.result()
            all_times.extend(worker_times)
            avg_time = sum(worker_times) / len(worker_times)
            max_time = max(worker_times)
            print(f"  Worker {worker_id}: avg {avg_time:.4f}s, max {max_time:.4f}s")
        
        total_time = time.time() - start_time
    
    # Analysis
    overall_avg = sum(all_times) / len(all_times)
    overall_max = max(all_times)
    
    print(f"\nStress Test Results:")
    print(f"  Total operations: {len(all_times)}")
    print(f"  Overall avg: {overall_avg:.4f}s")
    print(f"  Overall max: {overall_max:.4f}s")
    print(f"  Total time: {total_time:.4f}s")
    
    # Check if any parse took longer than our 11-second threshold
    slow_parses = [t for t in all_times if t > 1.0]  # 1 second threshold
    if slow_parses:
        print(f"  ⚠️  {len(slow_parses)} slow parses detected (>1.0s)!")
        print(f"     Slowest: {max(slow_parses):.4f}s")
    else:
        print(f"  ✅  All parses completed quickly (<1.0s)")
    
    return overall_max

if __name__ == "__main__":
    print("Running Comprehensive Thread Safety Tests...\n")
    
    # Test 1: Builtins module race condition
    builtins_slowdown = test_builtin_module_race_condition()
    
    # Test 2: Comprehensive compilation pipeline  
    compilation_slowdown = test_comprehensive_compilation()
    
    # Test 3: Stress test rapid parsing
    max_parse_time = stress_test_rapid_parsing()
    
    # Summary
    print("\n" + "="*60)
    print("COMPREHENSIVE TEST SUMMARY")
    print("="*60)
    print(f"Builtins race condition slowdown: {builtins_slowdown:.2f}x")
    print(f"Compilation pipeline slowdown: {compilation_slowdown:.2f}x")
    print(f"Maximum parse time in stress test: {max_parse_time:.4f}s")
    
    # Overall assessment
    issues = []
    if builtins_slowdown > 2.0:
        issues.append(f"Builtins race condition ({builtins_slowdown:.1f}x slowdown)")
    if compilation_slowdown > 2.0:
        issues.append(f"Compilation pipeline contention ({compilation_slowdown:.1f}x slowdown)")
    if max_parse_time > 1.0:
        issues.append(f"Slow parsing detected ({max_parse_time:.1f}s max time)")
    
    if issues:
        print(f"\n⚠️  ISSUES DETECTED:")
        for issue in issues:
            print(f"   - {issue}")
        print("\nRecommendation: Additional thread safety fixes needed")
    else:
        print(f"\n✅  ALL TESTS PASSED: Thread safety appears good!")
        print("Your 11-second parsing delay issue should be resolved")
