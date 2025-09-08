#!/usr/bin/env python3

"""
Test to demonstrate quick check debouncing behavior during rapid typing.
"""

import asyncio
import sys
import time
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

async def test_quick_check_debouncing():
    """Test that quick check debouncing works correctly during rapid typing simulation."""
    
    print("=== Testing Quick Check Debouncing ===")
    print("Simulating rapid typing behavior...\n")
    
    # Create a mock language server
    server = JacLangServer()
    server.workspace = MockWorkspace()
    
    # Track calls to publish_diagnostics
    call_count = 0
    call_times = []
    
    def mock_publish_diagnostics(uri, diagnostics):
        nonlocal call_count
        call_count += 1
        call_times.append(time.time())
        print(f"  📊 Published diagnostics #{call_count} for {uri} at {call_times[-1]:.3f}s")
    
    server.publish_diagnostics = mock_publish_diagnostics
    
    test_file = "/tmp/rapid_typing_test.jac"
    
    # Test 1: Without debouncing (direct calls)
    print("1. Testing WITHOUT debouncing (direct quick_check calls):")
    start_time = time.time()
    call_count = 0
    call_times = []
    
    # Simulate 10 rapid keystrokes
    tasks = []
    for i in range(10):
        # Update document content slightly to simulate typing
        updated_code = f"""
obj TestObj_{i} {{
    has counter: int = {i};
    
    def increment() -> int {{
        self.counter += 1;
        return self.counter;
    }}
}}

with entry {{
    obj = TestObj_{i}();
    result = obj.increment();
}}
"""
        server.workspace.add_document(test_file, updated_code, test_file)
        
        # Direct call without debouncing
        task = asyncio.create_task(server.launch_quick_check(test_file))
        tasks.append(task)
        
        # Small delay to simulate typing rhythm
        await asyncio.sleep(0.05)  # 50ms between keystrokes
    
    # Wait for all direct calls to complete
    await asyncio.gather(*tasks)
    direct_total_time = time.time() - start_time
    direct_calls = call_count
    
    print(f"  Without debouncing: {direct_calls} calls in {direct_total_time:.3f}s")
    print(f"  Average time per call: {direct_total_time/direct_calls:.3f}s")
    
    # Reset counters
    await asyncio.sleep(1)  # Wait for any pending operations
    
    # Test 2: With debouncing
    print(f"\n2. Testing WITH debouncing (debounced_quick_check):")
    start_time = time.time()
    call_count = 0
    call_times = []
    
    # Simulate 10 rapid keystrokes with debouncing
    for i in range(10):
        # Update document content slightly to simulate typing
        updated_code = f"""
obj DebouncedTestObj_{i} {{
    has counter: int = {i * 10};
    
    def increment() -> int {{
        self.counter += 1;
        return self.counter;
    }}
}}

with entry {{
    obj = DebouncedTestObj_{i}();
    result = obj.increment();
}}
"""
        server.workspace.add_document(test_file, updated_code, test_file)
        
        # Use debounced call
        await server.debounced_quick_check(test_file, delay=0.2)  # 200ms delay
        
        # Small delay to simulate typing rhythm
        await asyncio.sleep(0.05)  # 50ms between keystrokes
    
    # Wait for debounced operations to complete
    await asyncio.sleep(0.5)  # Wait for final debounced call
    debounced_total_time = time.time() - start_time
    debounced_calls = call_count
    
    print(f"  With debouncing: {debounced_calls} calls in {debounced_total_time:.3f}s")
    if debounced_calls > 0:
        print(f"  Average time per call: {debounced_total_time/debounced_calls:.3f}s")
    
    # Analysis
    print(f"\n=== DEBOUNCING ANALYSIS ===")
    print(f"Direct calls: {direct_calls} operations")
    print(f"Debounced calls: {debounced_calls} operations")
    
    if debounced_calls < direct_calls:
        reduction = ((direct_calls - debounced_calls) / direct_calls) * 100
        print(f"✅ Debouncing reduced operations by {reduction:.1f}%")
        print(f"✅ Saved {direct_calls - debounced_calls} unnecessary operations")
        
        # Calculate time savings
        estimated_saved_time = (direct_calls - debounced_calls) * (direct_total_time / direct_calls)
        print(f"⚡ Estimated time saved: {estimated_saved_time:.3f}s")
        
        if reduction >= 80:  # Expect significant reduction for rapid typing
            print(f"🎉 EXCELLENT: Debouncing is working very effectively!")
        elif reduction >= 50:
            print(f"✅ GOOD: Debouncing is working well")
        else:
            print(f"⚠️  OKAY: Debouncing is working but could be more aggressive")
            
    else:
        print(f"❌ Debouncing doesn't seem to be working properly")
    
    # Test 3: Different debounce delays
    print(f"\n3. Testing different debounce delays:")
    
    delays_to_test = [0.1, 0.2, 0.5, 1.0]
    for delay in delays_to_test:
        start_time = time.time()
        call_count = 0
        call_times = []
        
        print(f"  Testing {delay}s delay:")
        
        # Simulate 5 rapid keystrokes
        for i in range(5):
            updated_code = f"obj TestDelay_{delay}_{i} {{ has value: int = {i}; }}"
            server.workspace.add_document(test_file, updated_code, test_file)
            await server.debounced_quick_check(test_file, delay=delay)
            await asyncio.sleep(0.05)  # 50ms typing
        
        # Wait for debounced operation
        await asyncio.sleep(delay + 0.1)
        
        test_time = time.time() - start_time
        print(f"    {call_count} calls in {test_time:.3f}s with {delay}s delay")
    
    # Cleanup
    server.executor.shutdown(wait=False)
    
    return debounced_calls < direct_calls

async def test_mixed_quick_and_deep_debouncing():
    """Test that quick and deep check debouncing work independently."""
    
    print(f"\n=== Testing Mixed Quick + Deep Check Debouncing ===")
    
    server = JacLangServer()
    server.workspace = MockWorkspace()
    
    quick_calls = 0
    deep_calls = 0
    
    def mock_publish_diagnostics(uri, diagnostics):
        # We can't easily distinguish quick vs deep from diagnostics,
        # so we'll track by monitoring the methods directly
        pass
    
    server.publish_diagnostics = mock_publish_diagnostics
    
    # Override methods to count calls
    original_quick_check = server.quick_check
    original_deep_check = server.deep_check
    
    async def counting_quick_check(*args, **kwargs):
        nonlocal quick_calls
        quick_calls += 1
        print(f"    Quick check #{quick_calls} started")
        return await original_quick_check(*args, **kwargs)
    
    async def counting_deep_check(*args, **kwargs):
        nonlocal deep_calls
        deep_calls += 1
        print(f"    Deep check #{deep_calls} started")
        return await original_deep_check(*args, **kwargs)
    
    server.quick_check = counting_quick_check
    server.deep_check = counting_deep_check
    
    test_file = "/tmp/mixed_test.jac"
    server.workspace.add_document(test_file, "obj Test { }", test_file)
    
    print("Triggering multiple debounced operations:")
    
    # Trigger multiple quick and deep checks rapidly
    for i in range(3):
        print(f"  Triggering batch {i+1}...")
        await server.debounced_quick_check(test_file, delay=0.2)
        await server.debounced_deep_check(test_file, delay=0.3)
        await asyncio.sleep(0.1)  # Rapid triggering
    
    # Wait for all debounced operations
    await asyncio.sleep(0.5)
    
    print(f"\nResults:")
    print(f"  Quick checks executed: {quick_calls}")
    print(f"  Deep checks executed: {deep_calls}")
    
    # Both should be minimal due to debouncing
    if quick_calls <= 2 and deep_calls <= 2:
        print(f"✅ Mixed debouncing working correctly")
        return True
    else:
        print(f"⚠️  Mixed debouncing may need tuning")
        return False

async def main():
    """Run debouncing tests."""
    print("Testing JacLangServer Quick Check Debouncing")
    print("=" * 50)
    
    try:
        # Test 1: Basic debouncing
        test1_success = await test_quick_check_debouncing()
        
        # Test 2: Mixed debouncing
        test2_success = await test_mixed_quick_and_deep_debouncing()
        
        # Summary
        print("\n" + "=" * 50)
        print("DEBOUNCING TEST SUMMARY")
        print("=" * 50)
        
        if test1_success and test2_success:
            print("🎉 SUCCESS: Quick check debouncing is working perfectly!")
            print("✅ Rapid typing will no longer trigger excessive operations")
            print("✅ Both quick and deep check debouncing work independently")
            print("⚡ Performance should be much better during coding")
            print(f"\n💡 RECOMMENDATION:")
            print(f"   - Use debounced_quick_check() for text change events")
            print(f"   - Use debounced_deep_check() for save events")
            print(f"   - Quick check delay: 0.2s (responsive but efficient)")
            print(f"   - Deep check delay: 0.5s (avoids expensive operations)")
        else:
            print("⚠️  Some debouncing tests failed - check implementation")
            
    except Exception as e:
        print(f"❌ Test error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
