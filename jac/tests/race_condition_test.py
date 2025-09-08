"""Test to confirm the TypeCheckPass._BUILTINS_MODULE race condition."""
import time
import threading
from jaclang.compiler.program import JacProgram
from jaclang.compiler.passes.main.type_checker_pass import TypeCheckPass


def test_builtins_race_condition():
    """Test if multiple threads compete for the shared _BUILTINS_MODULE."""
    print("=== Testing TypeCheckPass._BUILTINS_MODULE Race Condition ===")
    
    # Reset the shared state
    TypeCheckPass._BUILTINS_MODULE = None
    
    # Simple code that triggers type checking
    test_code = """
walker test {
    can walk with `root entry {
        x: int = 42;
        print(f"Value: {x}");
    }
}
"""
    
    parse_times = []
    thread_ids = []
    
    def parse_with_typecheck(thread_id: int):
        """Parse code with type checking enabled."""
        print(f"Thread {thread_id}: Starting parse...")
        start_time = time.time()
        
        program = JacProgram()
        # This will trigger TypeCheckPass and builtins loading
        program.build(use_str=test_code, file_path=f"test_{thread_id}.jac", type_check=True)
        
        parse_time = time.time() - start_time
        parse_times.append(parse_time)
        thread_ids.append(thread_id)
        print(f"Thread {thread_id}: Completed in {parse_time:.4f}s")
    
    # Test 1: Sequential type checking (should be fast)
    print("\n1. Sequential Type Checking:")
    TypeCheckPass._BUILTINS_MODULE = None  # Reset
    
    sequential_times = []
    for i in range(3):
        start = time.time()
        program = JacProgram()
        program.build(use_str=test_code, file_path=f"sequential_{i}.jac", type_check=True)
        sequential_times.append(time.time() - start)
        print(f"  Sequential {i}: {sequential_times[-1]:.4f}s")
    
    sequential_avg = sum(sequential_times) / len(sequential_times)
    
    # Test 2: Concurrent type checking (likely to show slowdown)
    print("\n2. Concurrent Type Checking:")
    TypeCheckPass._BUILTINS_MODULE = None  # Reset to trigger race condition
    
    threads = []
    parse_times.clear()
    
    for i in range(3):
        thread = threading.Thread(target=parse_with_typecheck, args=(i,))
        threads.append(thread)
    
    # Start all threads simultaneously
    start_time = time.time()
    for thread in threads:
        thread.start()
    
    # Wait for completion
    for thread in threads:
        thread.join()
    
    total_time = time.time() - start_time
    concurrent_avg = sum(parse_times) / len(parse_times)
    max_time = max(parse_times)
    
    print(f"\nResults:")
    print(f"  Sequential avg: {sequential_avg:.4f}s")
    print(f"  Concurrent avg: {concurrent_avg:.4f}s") 
    print(f"  Concurrent max: {max_time:.4f}s")
    print(f"  Slowdown factor: {concurrent_avg / sequential_avg:.2f}x")
    print(f"  Total concurrent time: {total_time:.4f}s")
    print(f"  Parse times: {[round(t, 4) for t in sorted(parse_times)]}")
    
    if concurrent_avg > sequential_avg * 2:
        print(f"  ⚠️  CONFIRMED: {concurrent_avg / sequential_avg:.1f}x slowdown due to builtins race condition!")
        return True
    else:
        print(f"  ✅ No significant slowdown detected")
        return False
    
    # Test 3: Concurrent with pre-loaded builtins (should be fast)
    print("\n3. Concurrent with Pre-loaded Builtins:")
    
    # Pre-load builtins by running one parse first
    program = JacProgram()
    program.build(use_str=test_code, file_path="preload.jac", type_check=True)
    print("  Builtins pre-loaded...")
    
    # Now run concurrent parsing again
    threads = []
    parse_times.clear()
    
    for i in range(3):
        thread = threading.Thread(target=parse_with_typecheck, args=(i + 10,))
        threads.append(thread)
    
    start_time = time.time()
    for thread in threads:
        thread.start()
    
    for thread in threads:
        thread.join()
    
    preloaded_avg = sum(parse_times) / len(parse_times)
    print(f"  Pre-loaded concurrent avg: {preloaded_avg:.4f}s")
    print(f"  Improvement: {concurrent_avg / preloaded_avg:.2f}x faster")
    
    if preloaded_avg < concurrent_avg * 0.7:
        print(f"  ✅ CONFIRMED: Pre-loading builtins fixes the race condition!")
    else:
        print(f"  ⚠️  Pre-loading didn't help significantly")


if __name__ == "__main__":
    test_builtins_race_condition()
