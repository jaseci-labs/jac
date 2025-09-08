"""Rapid typing simulator to test language server performance."""
import asyncio
import time
from typing import List
from jaclang.langserve.engine import JacLangServer


class TypingSimulator:
    """Simulates rapid typing events to test language server performance."""
    
    def __init__(self):
        self.server = JacLangServer()
        self.setup_mock_workspace()
    
    def setup_mock_workspace(self):
        """Setup mock workspace for testing."""
        class MockDocument:
            def __init__(self, source: str, path: str):
                self.source = source
                self.path = path
                self.lines = source.splitlines()
        
        class MockWorkspace:
            def __init__(self):
                self.documents = {}
            
            def get_text_document(self, uri: str) -> MockDocument:
                if uri not in self.documents:
                    # Create a new document with sample content
                    content = self.generate_sample_content()
                    path = uri.replace('file://', '')
                    self.documents[uri] = MockDocument(content, path)
                return self.documents[uri]
            
            def generate_sample_content(self) -> str:
                return """
walker rapid_test {
    can walk with `root entry {
        print("Testing rapid typing");
        spawn here ++> node::test_node;
    }
}

node test_node {
    has value: int = 42;
    
    can process with rapid_test entry {
        print(f"Value: {self.value}");
        return self.value;
    }
}
"""
        
        self.server.workspace = MockWorkspace()
        # Mock the publish_diagnostics method
        self.server.publish_diagnostics = lambda uri, diagnostics: None
    
    async def simulate_rapid_typing(self, num_events: int = 10, delay_ms: int = 100) -> List[float]:
        """Simulate rapid typing events and measure response times."""
        uri = "file:///tmp/test_rapid.jac"
        response_times = []
        
        print(f"Simulating {num_events} rapid typing events with {delay_ms}ms delays...")
        
        for i in range(num_events):
            # Simulate a typing event (document change)
            start_time = time.time()
            
            # This simulates what happens on each keystroke
            try:
                result = await self.server.launch_quick_check(uri)
                response_time = time.time() - start_time
                response_times.append(response_time)
                
                print(f"Event {i+1}: {response_time:.4f}s (result: {result})")
                
                # Small delay between typing events (simulating typing speed)
                await asyncio.sleep(delay_ms / 1000.0)
                
            except Exception as e:
                print(f"Error in event {i+1}: {e}")
                response_times.append(float('inf'))
        
        return response_times
    
    async def test_concurrent_typing(self, num_concurrent: int = 3) -> None:
        """Test multiple concurrent typing sessions."""
        print(f"Testing {num_concurrent} concurrent typing sessions...")
        
        async def typing_session(session_id: int) -> List[float]:
            uri = f"file:///tmp/test_session_{session_id}.jac"
            times = []
            
            for i in range(5):  # 5 events per session
                start_time = time.time()
                result = await self.server.launch_quick_check(uri)
                response_time = time.time() - start_time
                times.append(response_time)
                print(f"Session {session_id}, Event {i+1}: {response_time:.4f}s")
                await asyncio.sleep(0.05)  # 50ms between events
            
            return times
        
        # Run concurrent sessions
        tasks = [typing_session(i) for i in range(num_concurrent)]
        all_times = await asyncio.gather(*tasks)
        
        # Analyze results
        flat_times = [t for session_times in all_times for t in session_times]
        avg_time = sum(flat_times) / len(flat_times)
        max_time = max(flat_times)
        
        print(f"\nConcurrent typing results:")
        print(f"  Average response time: {avg_time:.4f}s")
        print(f"  Max response time: {max_time:.4f}s")
        print(f"  Total events: {len(flat_times)}")
        
        return flat_times
    
    async def benchmark_debouncing(self) -> None:
        """Test the debouncing mechanism."""
        uri = "file:///tmp/test_debounce.jac"
        
        print("Testing debouncing behavior...")
        
        # Rapid fire events that should be debounced
        start_time = time.time()
        
        # Fire multiple quick checks rapidly
        tasks = []
        for i in range(5):
            task = self.server.launch_quick_check(uri)
            tasks.append(task)
            await asyncio.sleep(0.01)  # Very fast typing (10ms between events)
        
        # Wait for all to complete
        results = await asyncio.gather(*tasks)
        total_time = time.time() - start_time
        
        print(f"Debouncing test:")
        print(f"  Total time for 5 rapid events: {total_time:.4f}s")
        print(f"  Results: {results}")
        
        # Test debounced deep check
        print("Testing debounced deep check...")
        await self.server.debounced_deep_check(uri, delay=0.1)
        await asyncio.sleep(0.2)  # Wait for debounced operation


async def main():
    """Run the typing simulation tests."""
    simulator = TypingSimulator()
    
    print("=== Rapid Typing Performance Tests ===\n")
    
    # Test 1: Basic rapid typing
    print("1. Basic rapid typing simulation:")
    response_times = await simulator.simulate_rapid_typing(num_events=8, delay_ms=50)
    
    avg_time = sum(response_times) / len(response_times)
    max_time = max(response_times)
    
    print(f"\nBasic typing results:")
    print(f"  Average response: {avg_time:.4f}s")
    print(f"  Max response: {max_time:.4f}s")
    print(f"  Response times: {[round(t, 4) for t in response_times]}")
    
    if max_time > 2.0:
        print(f"⚠️  ISSUE: Max response time {max_time:.4f}s exceeds 2.0s threshold")
    else:
        print("✅ Response times within acceptable range")
    
    print("\n" + "="*50 + "\n")
    
    # Test 2: Concurrent typing sessions
    print("2. Concurrent typing sessions:")
    await simulator.test_concurrent_typing(num_concurrent=3)
    
    print("\n" + "="*50 + "\n")
    
    # Test 3: Debouncing behavior
    print("3. Debouncing mechanism:")
    await simulator.benchmark_debouncing()


if __name__ == "__main__":
    asyncio.run(main())
