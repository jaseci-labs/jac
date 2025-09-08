#!/usr/bin/env python3

"""
Test to confirm that builtins loading is the bottleneck.
With TypeCheckPass disabled, parsing should be MUCH faster.
"""

import concurrent.futures
import time
import sys
import os

# Add jac to path
sys.path.insert(0, '/home/kuggix/jaseci/jac')

from jaclang.compiler.program import JacProgram

def test_parsing_without_builtins():
    """Test parsing performance with TypeCheckPass disabled."""
    
    test_code = """
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
"""

    def parse_code_thread(code: str, thread_id: int) -> tuple[float, bool, int]:
        """Parse code in a thread."""
        start_time = time.time()
        
        try:
            # Each thread gets its own JacProgram instance
            program = JacProgram()
            
            # Compile WITHOUT type checking (to skip TypeCheckPass)
            result = program.compile(use_str=code, file_path=f"test_{thread_id}.jac", type_check=False)
            
            # Check for compilation errors
            success = len(program.errors_had) == 0
            
        except Exception as e:
            success = False
            print(f"Thread {thread_id} error: {e}")
        
        parse_time = time.time() - start_time
        return parse_time, success, thread_id

    def parse_code_thread_with_typecheck(code: str, thread_id: int) -> tuple[float, bool, int]:
        """Parse code in a thread WITH type checking (disabled TypeCheckPass)."""
        start_time = time.time()
        
        try:
            # Each thread gets its own JacProgram instance
            program = JacProgram()
            
            # Compile WITH type checking (but TypeCheckPass is disabled)
            result = program.compile(use_str=code, file_path=f"test_tc_{thread_id}.jac", type_check=True)
            
            # Check for compilation errors
            success = len(program.errors_had) == 0
            
        except Exception as e:
            success = False
            print(f"Thread {thread_id} error: {e}")
        
        parse_time = time.time() - start_time
        return parse_time, success, thread_id

    print("=== Testing Parsing Performance Without Builtins ===")
    print("TypeCheckPass has been DISABLED to test if builtins is the bottleneck\n")
    
    # Test 1: Sequential parsing without type checking
    print("1. Sequential Parsing (no type checking):")
    sequential_times = []
    for i in range(3):
        parse_time, success, thread_id = parse_code_thread(test_code, i)
        sequential_times.append(parse_time)
        status = "✅" if success else "❌"
        print(f"  Sequential {i}: {parse_time:.4f}s {status}")
    
    # Test 2: Concurrent parsing without type checking
    print("\n2. Concurrent Parsing (no type checking):")
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        start_time = time.time()
        
        futures = []
        for i in range(3):
            future = executor.submit(parse_code_thread, test_code, i)
            futures.append(future)
        
        concurrent_times = []
        for future in concurrent.futures.as_completed(futures):
            parse_time, success, thread_id = future.result()
            concurrent_times.append(parse_time)
            status = "✅" if success else "❌"
            print(f"  Thread {thread_id}: {parse_time:.4f}s {status}")
        
        total_concurrent_time = time.time() - start_time
    
    # Test 3: Sequential parsing WITH disabled type checking
    print("\n3. Sequential Parsing (with disabled TypeCheckPass):")
    sequential_tc_times = []
    for i in range(3):
        parse_time, success, thread_id = parse_code_thread_with_typecheck(test_code, i)
        sequential_tc_times.append(parse_time)
        status = "✅" if success else "❌"
        print(f"  Sequential {i}: {parse_time:.4f}s {status}")
    
    # Test 4: Concurrent parsing WITH disabled type checking
    print("\n4. Concurrent Parsing (with disabled TypeCheckPass):")
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        start_time = time.time()
        
        futures = []
        for i in range(3):
            future = executor.submit(parse_code_thread_with_typecheck, test_code, i)
            futures.append(future)
        
        concurrent_tc_times = []
        for future in concurrent.futures.as_completed(futures):
            parse_time, success, thread_id = future.result()
            concurrent_tc_times.append(parse_time)
            status = "✅" if success else "❌"
            print(f"  Thread {thread_id}: {parse_time:.4f}s {status}")
        
        total_concurrent_tc_time = time.time() - start_time
    
    # Analysis
    seq_avg = sum(sequential_times) / len(sequential_times)
    con_avg = sum(concurrent_times) / len(concurrent_times)
    seq_tc_avg = sum(sequential_tc_times) / len(sequential_tc_times)
    con_tc_avg = sum(concurrent_tc_times) / len(concurrent_tc_times)
    
    slowdown_notc = con_avg / seq_avg
    slowdown_tc = con_tc_avg / seq_tc_avg
    
    print(f"\n=== RESULTS ===")
    print(f"Without Type Checking:")
    print(f"  Sequential avg: {seq_avg:.4f}s")
    print(f"  Concurrent avg: {con_avg:.4f}s")
    print(f"  Slowdown factor: {slowdown_notc:.2f}x")
    
    print(f"\nWith DISABLED TypeCheckPass:")
    print(f"  Sequential avg: {seq_tc_avg:.4f}s")
    print(f"  Concurrent avg: {con_tc_avg:.4f}s")
    print(f"  Slowdown factor: {slowdown_tc:.2f}x")
    
    print(f"\n=== CONCLUSION ===")
    if slowdown_notc < 1.5 and slowdown_tc < 1.5:
        print("🎉 SUCCESS: Minimal slowdown detected!")
        print("✅ This confirms that TypeCheckPass builtins loading was the bottleneck!")
        print("✅ Threading approach should work fine without the builtins race condition!")
        print(f"📊 Performance improvement: {3.7/slowdown_tc:.1f}x better than before")
    elif slowdown_tc < 2.0:
        print("✅ GOOD: Much better performance with disabled TypeCheckPass")
        print("⚠️  There may be other minor bottlenecks, but builtins was the main issue")
    else:
        print("⚠️  HMMMM: Still seeing slowdown even without TypeCheckPass")
        print("🔍 There might be other shared state issues to investigate")
    
    return slowdown_notc, slowdown_tc

def test_rapid_parsing_simulation():
    """Simulate rapid typing with disabled TypeCheckPass."""
    print("\n=== Rapid Typing Simulation (Disabled TypeCheckPass) ===")
    
    test_code = """
obj TestObj {
    has counter: int = 0;
    
    def increment() -> int {
        self.counter += 1;
        return self.counter;
    }
}

with entry {
    obj1 = TestObj();
    result = obj1.increment();
}
"""
    
    def rapid_parse_worker(worker_id: int, iterations: int) -> list[float]:
        """Worker that performs rapid parsing."""
        times = []
        for i in range(iterations):
            start_time = time.time()
            try:
                program = JacProgram()
                program.compile(use_str=test_code, file_path=f"rapid_{worker_id}_{i}.jac", type_check=True)
            except Exception as e:
                print(f"Worker {worker_id}, iteration {i} error: {e}")
            times.append(time.time() - start_time)
        return times
    
    # Test with multiple workers simulating rapid typing
    iterations_per_worker = 10
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
    
    print(f"\nRapid Parsing Results:")
    print(f"  Total operations: {len(all_times)}")
    print(f"  Overall avg: {overall_avg:.4f}s")
    print(f"  Overall max: {overall_max:.4f}s")
    print(f"  Total time: {total_time:.4f}s")
    
    # Compare to our previous results
    if overall_max < 0.1:  # 100ms threshold
        print(f"  🎉 EXCELLENT: All parses under 100ms!")
        print(f"  🚀 This is MUCH better than the 11+ second delays!")
    elif overall_max < 0.5:  # 500ms threshold
        print(f"  ✅ GOOD: All parses under 500ms!")
    else:
        print(f"  ⚠️  Still some slow parses detected")
    
    return overall_max

if __name__ == "__main__":
    print("Testing Parser Performance with Disabled TypeCheckPass")
    print("=" * 60)
    
    # Test 1: Basic concurrent vs sequential
    slowdown_notc, slowdown_tc = test_parsing_without_builtins()
    
    # Test 2: Rapid parsing simulation
    max_time = test_rapid_parsing_simulation()
    
    # Final summary
    print("\n" + "=" * 60)
    print("BUILTINS BOTTLENECK TEST SUMMARY")
    print("=" * 60)
    print(f"Concurrent slowdown (no type check): {slowdown_notc:.2f}x")
    print(f"Concurrent slowdown (disabled TypeCheckPass): {slowdown_tc:.2f}x")
    print(f"Maximum parse time in rapid test: {max_time:.4f}s")
    
    if slowdown_tc < 1.5 and max_time < 0.1:
        print(f"\n🎉 CONFIRMED: TypeCheckPass builtins loading was the bottleneck!")
        print(f"💡 RECOMMENDATION: Fix the builtins race condition with threading")
        print(f"📈 Expected improvement: 3.7x → {slowdown_tc:.1f}x slowdown")
        print(f"⚡ Threading approach will work great without startup overhead!")
    else:
        print(f"\n🤔 MIXED RESULTS: TypeCheckPass helps but other issues may exist")
        print(f"🔍 Consider investigating other potential bottlenecks")
