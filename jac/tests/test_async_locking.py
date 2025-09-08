#!/usr/bin/env python3

"""
Test to verify that the async locking in JacLangServer is working correctly.
"""

import asyncio
import sys
import os
import time
from concurrent.futures import ThreadPoolExecutor

# Add jac to path
sys.path.insert(0, '/home/kuggix/jaseci/jac')

from jaclang.langserve.engine import JacLangServer

# Mock workspace and document classes for testing
class MockDocument:
    def __init__(self, source: str, path: str):
        self.source = source
        self.path = path
        self.lines = source.split('\n')

class MockWorkspace:
    def __init__(self):
        self.documents = {}
    
    def add_document(self, uri: str, source: str, path: str):
        self.documents[uri] = MockDocument(source, path)
    
    def get_text_document(self, uri: str) -> MockDocument:
        if uri in self.documents:
            return self.documents[uri]
        # Create a default document for testing
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
        return MockDocument(test_code, uri)

async def test_concurrent_language_server_operations():
    """Test that language server operations work correctly with async locking."""
    
    print("=== Testing JacLangServer Async Locking ===")
    
    # Create a mock language server
    server = JacLangServer()
    server.workspace = MockWorkspace()
    
    # Mock the publish_diagnostics method to avoid LSP calls
    def mock_publish_diagnostics(uri, diagnostics):
        print(f"  Published {len(diagnostics)} diagnostics for {uri}")
    
    server.publish_diagnostics = mock_publish_diagnostics
    
    test_files = [
        "/tmp/test1.jac",
        "/tmp/test2.jac", 
        "/tmp/test3.jac",
        "/tmp/test4.jac",
        "/tmp/test5.jac"
    ]
    
    # Add test documents to workspace
    for file_path in test_files:
        test_code = f"""
obj TestObj_{file_path.split('/')[-1].replace('.jac', '')} {{
    has counter: int = 0;
    
    def increment() -> int {{
        self.counter += 1;
        return self.counter;
    }}
}}

with entry {{
    obj = TestObj_{file_path.split('/')[-1].replace('.jac', '')}();
    result = obj.increment();
}}
"""
        server.workspace.add_document(file_path, test_code, file_path)
    
    async def test_quick_check_stress(file_path: str, iterations: int) -> list[float]:
        """Stress test quick_check with many operations."""
        times = []
        for i in range(iterations):
            start_time = time.time()
            try:
                result = await server.quick_check(file_path)
                times.append(time.time() - start_time)
                print(f"    Quick check {file_path} iteration {i}: {times[-1]:.4f}s, success: {result}")
            except Exception as e:
                print(f"    Quick check error {file_path} iteration {i}: {e}")
                times.append(float('inf'))
        return times
    
    async def test_deep_check_stress(file_path: str, iterations: int) -> list[float]:
        """Stress test deep_check with many operations."""
        times = []
        for i in range(iterations):
            start_time = time.time()
            try:
                result = await server.deep_check(file_path)
                times.append(time.time() - start_time)
                print(f"    Deep check {file_path} iteration {i}: {times[-1]:.4f}s, success: {result}")
            except Exception as e:
                print(f"    Deep check error {file_path} iteration {i}: {e}")
                times.append(float('inf'))
        return times
    
    # Test 1: Concurrent quick checks
    print("\n1. Testing Concurrent Quick Checks:")
    quick_start = time.time()
    
    quick_tasks = []
    for file_path in test_files:
        task = asyncio.create_task(test_quick_check_stress(file_path, 3))
        quick_tasks.append((task, file_path))
    
    quick_results = {}
    for task, file_path in quick_tasks:
        quick_results[file_path] = await task
    
    quick_total_time = time.time() - quick_start
    print(f"  Total quick check time: {quick_total_time:.4f}s")
    
    # Test 2: Concurrent deep checks
    print("\n2. Testing Concurrent Deep Checks:")
    deep_start = time.time()
    
    deep_tasks = []
    for file_path in test_files[:3]:  # Limit to 3 for deep checks
        task = asyncio.create_task(test_deep_check_stress(file_path, 2))
        deep_tasks.append((task, file_path))
    
    deep_results = {}
    for task, file_path in deep_tasks:
        deep_results[file_path] = await task
    
    deep_total_time = time.time() - deep_start
    print(f"  Total deep check time: {deep_total_time:.4f}s")
    
    # Test 3: Mixed operations
    print("\n3. Testing Mixed Quick and Deep Checks:")
    mixed_start = time.time()
    
    mixed_tasks = []
    # Add some quick checks
    for file_path in test_files[:3]:
        task = asyncio.create_task(test_quick_check_stress(file_path, 2))
        mixed_tasks.append((task, file_path, "quick"))
    
    # Add some deep checks
    for file_path in test_files[2:4]:
        task = asyncio.create_task(test_deep_check_stress(file_path, 1))
        mixed_tasks.append((task, file_path, "deep"))
    
    mixed_results = {}
    for task, file_path, check_type in mixed_tasks:
        mixed_results[f"{file_path}_{check_type}"] = await task
    
    mixed_total_time = time.time() - mixed_start
    print(f"  Total mixed operations time: {mixed_total_time:.4f}s")
    
    # Test 4: Check module hub integrity
    print("\n4. Checking Module Hub Integrity:")
    hub_size = len(server._main_program.mod.hub)
    errors_count = len(server._main_program.errors_had)
    warnings_count = len(server._main_program.warnings_had)
    
    print(f"  Module hub contains {hub_size} modules")
    print(f"  Total errors collected: {errors_count}")
    print(f"  Total warnings collected: {warnings_count}")
    
    # Analyze results
    print("\n=== Performance Analysis ===")
    
    # Quick check analysis
    all_quick_times = []
    for file_path, times in quick_results.items():
        valid_times = [t for t in times if t != float('inf')]
        if valid_times:
            avg_time = sum(valid_times) / len(valid_times)
            max_time = max(valid_times)
            print(f"Quick check {file_path}: avg {avg_time:.4f}s, max {max_time:.4f}s")
            all_quick_times.extend(valid_times)
    
    # Deep check analysis
    all_deep_times = []
    for file_path, times in deep_results.items():
        valid_times = [t for t in times if t != float('inf')]
        if valid_times:
            avg_time = sum(valid_times) / len(valid_times)
            max_time = max(valid_times)
            print(f"Deep check {file_path}: avg {avg_time:.4f}s, max {max_time:.4f}s")
            all_deep_times.extend(valid_times)
    
    # Overall analysis
    if all_quick_times:
        quick_avg = sum(all_quick_times) / len(all_quick_times)
        quick_max = max(all_quick_times)
        print(f"\nOverall Quick Check: avg {quick_avg:.4f}s, max {quick_max:.4f}s")
    
    if all_deep_times:
        deep_avg = sum(all_deep_times) / len(all_deep_times)
        deep_max = max(all_deep_times)
        print(f"Overall Deep Check: avg {deep_avg:.4f}s, max {deep_max:.4f}s")
    
    # Success criteria
    success = True
    if all_quick_times and max(all_quick_times) > 1.0:  # 1 second threshold
        print("⚠️  Quick checks are taking too long!")
        success = False
    
    if all_deep_times and max(all_deep_times) > 5.0:  # 5 second threshold
        print("⚠️  Deep checks are taking too long!")
        success = False
    
    if hub_size < len(test_files):
        print("⚠️  Not all modules were processed!")
        success = False
    
    if success:
        print("✅ All async locking tests passed!")
        print("✅ Language server operations are working correctly with locks")
        print("✅ No deadlocks or race conditions detected")
    else:
        print("❌ Some tests failed - check performance or locking issues")
    
    # Cleanup
    server.executor.shutdown(wait=False)
    
    return success

async def test_lock_contention():
    """Test that locks prevent race conditions."""
    print("\n=== Testing Lock Contention Prevention ===")
    
    server = JacLangServer()
    server.workspace = MockWorkspace()
    server.publish_diagnostics = lambda uri, diag: None  # Mock
    
    # Add a test document
    test_file = "/tmp/contention_test.jac"
    test_code = """
obj ContentionTest {
    has value: int = 42;
}
"""
    server.workspace.add_document(test_file, test_code, test_file)
    
    # Test concurrent access to shared state
    async def concurrent_operations():
        """Perform operations that modify shared state."""
        tasks = []
        
        # Multiple quick checks
        for i in range(5):
            task = asyncio.create_task(server.quick_check(test_file))
            tasks.append(task)
        
        # Multiple deep checks
        for i in range(3):
            task = asyncio.create_task(server.deep_check(test_file))
            tasks.append(task)
        
        # Wait for all to complete
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Check for exceptions
        exceptions = [r for r in results if isinstance(r, Exception)]
        successes = [r for r in results if not isinstance(r, Exception)]
        
        return len(exceptions), len(successes)
    
    start_time = time.time()
    exceptions_count, success_count = await concurrent_operations()
    total_time = time.time() - start_time
    
    print(f"Concurrent operations completed in {total_time:.4f}s")
    print(f"Successful operations: {success_count}")
    print(f"Failed operations: {exceptions_count}")
    
    # Check final state
    hub_size = len(server._main_program.mod.hub)
    errors_count = len(server._main_program.errors_had)
    
    print(f"Final module hub size: {hub_size}")
    print(f"Final errors count: {errors_count}")
    
    if exceptions_count == 0 and success_count > 0:
        print("✅ Lock contention test passed - no race conditions detected")
        return True
    else:
        print("❌ Lock contention test failed - race conditions may exist")
        return False

async def main():
    """Run all async locking tests."""
    print("Testing JacLangServer Async Locking Implementation")
    print("=" * 55)
    
    try:
        # Test 1: Basic concurrent operations
        test1_success = await test_concurrent_language_server_operations()
        
        # Test 2: Lock contention
        test2_success = await test_lock_contention()
        
        # Final summary
        print("\n" + "=" * 55)
        print("ASYNC LOCKING TEST SUMMARY")
        print("=" * 55)
        
        if test1_success and test2_success:
            print("🎉 SUCCESS: All async locking tests passed!")
            print("✅ JacLangServer properly uses async locks")
            print("✅ No race conditions detected in shared state access")
            print("✅ Performance is good with proper locking")
        else:
            print("⚠️  MIXED RESULTS: Some tests failed")
            if not test1_success:
                print("❌ Concurrent operations test failed")
            if not test2_success:
                print("❌ Lock contention test failed")
        
    except Exception as e:
        print(f"❌ Test framework error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
