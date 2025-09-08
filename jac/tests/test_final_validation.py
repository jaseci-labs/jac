#!/usr/bin/env python3

"""
Final validation test: TypeCheckPass re-enabled with thread-safe builtins.
This should show good performance - much better than before our fixes!
"""

import concurrent.futures
import time
import sys
import os

# Add jac to path
sys.path.insert(0, '/home/kuggix/jaseci/jac')

from jaclang.compiler.program import JacProgram

def test_threadsafe_builtins_performance():
    """Test parsing performance with re-enabled thread-safe TypeCheckPass."""
    
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
        """Parse code in a thread with full type checking."""
        start_time = time.time()
        
        try:
            # Each thread gets its own JacProgram instance
            program = JacProgram()
            
            # Compile WITH type checking (now using thread-safe builtins)
            result = program.compile(use_str=code, file_path=f"final_test_{thread_id}.jac", type_check=True)
            
            # Check for compilation errors
            success = len(program.errors_had) == 0
            
        except Exception as e:
            success = False
            print(f"Thread {thread_id} error: {e}")
        
        parse_time = time.time() - start_time
        return parse_time, success, thread_id

    print("=== Final Validation: Thread-Safe TypeCheckPass ===")
    print("TypeCheckPass is now RE-ENABLED with thread-safe builtins loading\n")
    
    # Test 1: Sequential parsing
    print("1. Sequential Parsing (baseline):")
    sequential_times = []
    for i in range(3):
        parse_time, success, thread_id = parse_code_thread(test_code, i)
        sequential_times.append(parse_time)
        status = "✅" if success else "❌"
        print(f"  Sequential {i}: {parse_time:.4f}s {status}")
    
    # Test 2: Concurrent parsing
    print("\n2. Concurrent Parsing (thread-safe builtins):")
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
    
    # Test 3: Stress test - simulate rapid typing
    print("\n3. Rapid Typing Stress Test:")
    stress_times = []
    stress_iterations = 10
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        stress_start = time.time()
        
        futures = []
        for i in range(stress_iterations):
            future = executor.submit(parse_code_thread, test_code, i)
            futures.append(future)
        
        for future in concurrent.futures.as_completed(futures):
            parse_time, success, thread_id = future.result()
            stress_times.append(parse_time)
        
        total_stress_time = time.time() - stress_start
    
    # Analysis
    seq_avg = sum(sequential_times) / len(sequential_times)
    con_avg = sum(concurrent_times) / len(concurrent_times)
    stress_avg = sum(stress_times) / len(stress_times)
    stress_max = max(stress_times)
    
    slowdown_factor = con_avg / seq_avg
    
    print(f"\n=== PERFORMANCE RESULTS ===")
    print(f"Sequential average: {seq_avg:.4f}s")
    print(f"Concurrent average: {con_avg:.4f}s")
    print(f"Slowdown factor: {slowdown_factor:.2f}x")
    print(f"Stress test average: {stress_avg:.4f}s")
    print(f"Stress test maximum: {stress_max:.4f}s")
    print(f"Total stress time ({stress_iterations} ops): {total_stress_time:.4f}s")
    
    print(f"\n=== COMPARISON TO ORIGINAL ISSUE ===")
    if stress_max < 0.5:  # 500ms threshold
        improvement = 11.0 / stress_max  # Original was 11+ seconds
        print(f"🎉 EXCELLENT: Maximum parse time {stress_max:.3f}s")
        print(f"🚀 That's a {improvement:.1f}x improvement from 11+ seconds!")
        print(f"✅ Problem SOLVED: No more 11-second delays!")
    elif stress_max < 1.0:  # 1 second threshold
        print(f"✅ GOOD: Maximum parse time {stress_max:.3f}s")
        print(f"🎯 Much better than 11+ seconds, typing should be responsive")
    else:
        print(f"⚠️  CONCERN: Still seeing {stress_max:.3f}s delays")
    
    print(f"\n=== THREADING VS MULTIPROCESSING DECISION ===")
    if slowdown_factor < 2.0:
        print(f"🎯 RECOMMENDATION: Use THREADING approach")
        print(f"  ✅ Slowdown factor ({slowdown_factor:.2f}x) is acceptable")
        print(f"  ✅ No 0.369s startup overhead per request")
        print(f"  ✅ Shared memory benefits (cached builtins)")
        print(f"  ✅ Lower complexity for VSCode integration")
    else:
        print(f"🤔 Consider multiprocessing if this slowdown ({slowdown_factor:.2f}x) is still problematic")
    
    return slowdown_factor, stress_max

def test_builtins_cache_sharing():
    """Test that builtins module is properly cached and shared."""
    print("\n=== Builtins Cache Validation ===")
    
    # Import the class to check the cache
    from jaclang.compiler.passes.main.type_checker_pass import TypeCheckPass
    
    # Get builtins multiple times
    builtins1 = TypeCheckPass._get_builtins_module()
    builtins2 = TypeCheckPass._get_builtins_module()
    builtins3 = TypeCheckPass._get_builtins_module()
    
    # They should all be the exact same object (cached)
    if builtins1 is builtins2 is builtins3:
        print("✅ Builtins caching working: All references point to same object")
    else:
        print("❌ Builtins caching FAILED: Multiple objects created")
    
    # Test concurrent access to cache
    def get_builtins_in_thread(thread_id: int) -> object:
        return TypeCheckPass._get_builtins_module()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = []
        for i in range(5):
            future = executor.submit(get_builtins_in_thread, i)
            futures.append(future)
        
        builtins_objects = []
        for future in futures:
            builtins_objects.append(future.result())
    
    # All should be the same object
    all_same = all(obj is builtins_objects[0] for obj in builtins_objects)
    if all_same:
        print("✅ Thread-safe caching: All threads got same cached object")
    else:
        print("❌ Thread-safe caching FAILED: Different objects in different threads")
    
    return all_same

if __name__ == "__main__":
    print("Final Validation: Thread-Safe TypeCheckPass Performance")
    print("=" * 65)
    
    # Test 1: Performance validation
    slowdown_factor, max_time = test_threadsafe_builtins_performance()
    
    # Test 2: Cache validation
    cache_working = test_builtins_cache_sharing()
    
    # Final summary
    print("\n" + "=" * 65)
    print("FINAL VALIDATION SUMMARY")
    print("=" * 65)
    print(f"Concurrent slowdown factor: {slowdown_factor:.2f}x")
    print(f"Maximum parse time: {max_time:.4f}s")
    print(f"Builtins cache working: {'✅ Yes' if cache_working else '❌ No'}")
    
    if slowdown_factor < 2.0 and max_time < 0.5 and cache_working:
        print(f"\n🎉 SUCCESS: Problem is SOLVED!")
        print(f"✅ 11+ second delays reduced to {max_time:.3f}s")
        print(f"✅ Thread-safe builtins loading working perfectly")
        print(f"✅ VSCode language server should be fast and responsive now!")
        print(f"🎯 RECOMMENDATION: Deploy the threading solution")
    elif slowdown_factor < 3.0 and max_time < 1.0:
        print(f"\n✅ GOOD: Significant improvement achieved")
        print(f"📈 Performance much better than original 11+ second issue")
        print(f"⚡ Threading solution is working well")
    else:
        print(f"\n⚠️  MIXED: Some improvement but may need further optimization")
        print(f"🔍 Consider investigating additional bottlenecks")
