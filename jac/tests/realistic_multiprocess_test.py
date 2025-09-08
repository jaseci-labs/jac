#!/usr/bin/env python3

"""
Realistic Language Server Multiprocessing Implementation
Shows how to properly implement multiprocessing for a Jac language server.
"""

import multiprocessing as mp
import queue
import time
import sys
import os
from typing import Dict, Optional, Tuple

# Add jac to path
sys.path.insert(0, '/home/kuggix/jaseci/jac')

class JacParserWorker:
    """Persistent worker process for parsing Jac files."""
    
    def __init__(self, worker_id: int):
        self.worker_id = worker_id
        self.program = None
        self._initialize()
    
    def _initialize(self):
        """Initialize the worker with warm caches."""
        from jaclang.compiler.program import JacProgram
        from jaclang.compiler.passes.main.type_checker_pass import TypeCheckPass
        
        # Create program instance
        self.program = JacProgram()
        
        # Pre-warm the builtins cache by forcing a simple parse
        try:
            warm_code = "obj Test { has x: int; }"
            self.program.compile(use_str=warm_code, file_path="warmup.jac", type_check=True)
            print(f"Worker {self.worker_id}: Initialized and warmed up")
        except Exception as e:
            print(f"Worker {self.worker_id}: Warmup failed: {e}")
    
    def parse_file(self, content: str, file_path: str) -> Tuple[float, bool, str, int]:
        """Parse a Jac file."""
        start_time = time.time()
        error_msg = ""
        success = True
        
        try:
            # Use the pre-initialized program
            result = self.program.compile(use_str=content, file_path=file_path, type_check=True)
            
            # Check for compilation errors
            if self.program.errors_had:
                success = False
                error_msg = f"Compilation errors: {[str(e) for e in self.program.errors_had]}"
                # Clear errors for next use
                self.program.errors_had.clear()
                self.program.warnings_had.clear()
            
        except Exception as e:
            success = False
            error_msg = f"Exception: {str(e)}"
        
        parse_time = time.time() - start_time
        return parse_time, success, error_msg, self.worker_id

def worker_process(worker_id: int, task_queue: mp.Queue, result_queue: mp.Queue):
    """Worker process function."""
    worker = JacParserWorker(worker_id)
    
    while True:
        try:
            # Get task from queue (blocks until available)
            task = task_queue.get(timeout=1.0)
            
            if task is None:  # Poison pill to shutdown
                break
            
            content, file_path = task
            result = worker.parse_file(content, file_path)
            result_queue.put(result)
            
        except queue.Empty:
            continue
        except Exception as e:
            result_queue.put((0.0, False, f"Worker error: {e}", worker_id))

class MultiprocessLanguageServer:
    """Language server using multiprocessing for parsing."""
    
    def __init__(self, num_workers: int = None):
        if num_workers is None:
            num_workers = min(mp.cpu_count(), 4)  # Reasonable default
        
        self.num_workers = num_workers
        self.task_queue = mp.Queue()
        self.result_queue = mp.Queue()
        self.workers = []
        self.active_tasks = {}
        self._start_workers()
    
    def _start_workers(self):
        """Start worker processes."""
        print(f"Starting {self.num_workers} worker processes...")
        
        for i in range(self.num_workers):
            process = mp.Process(
                target=worker_process,
                args=(i, self.task_queue, self.result_queue)
            )
            process.start()
            self.workers.append(process)
        
        # Give workers time to initialize
        time.sleep(2.0)
        print("All workers initialized")
    
    def parse_file_async(self, content: str, file_path: str) -> None:
        """Submit a file for parsing (non-blocking)."""
        self.task_queue.put((content, file_path))
        self.active_tasks[file_path] = time.time()
    
    def get_result(self, timeout: float = 1.0) -> Optional[Tuple[str, float, bool, str]]:
        """Get a parsing result (blocking with timeout)."""
        try:
            parse_time, success, error_msg, worker_id = self.result_queue.get(timeout=timeout)
            
            # Find which file this result is for (simple approach)
            if self.active_tasks:
                file_path = next(iter(self.active_tasks))
                del self.active_tasks[file_path]
                return file_path, parse_time, success, error_msg
            
            return None, parse_time, success, error_msg
            
        except queue.Empty:
            return None
    
    def parse_file_sync(self, content: str, file_path: str, timeout: float = 5.0) -> Tuple[float, bool, str]:
        """Parse a file synchronously."""
        self.parse_file_async(content, file_path)
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            result = self.get_result(timeout=0.1)
            if result and result[0] == file_path:
                return result[1], result[2], result[3]
        
        return 0.0, False, "Timeout waiting for result"
    
    def shutdown(self):
        """Shutdown all worker processes."""
        print("Shutting down workers...")
        
        # Send poison pills
        for _ in range(self.num_workers):
            self.task_queue.put(None)
        
        # Wait for workers to finish
        for process in self.workers:
            process.join(timeout=5.0)
            if process.is_alive():
                process.terminate()
        
        print("All workers shut down")

def test_multiprocess_language_server():
    """Test the multiprocessing language server implementation."""
    print("=== Testing Multiprocessing Language Server ===")
    
    # Test code samples
    test_codes = [
        """
obj Calculator {
    has value: float = 0.0;
    
    def add(x: float) -> float {
        self.value += x;
        return self.value;
    }
}

with entry {
    calc = Calculator();
    result = calc.add(10.5);
}
""",
        """
obj Node {
    has id: int;
    
    def get_id() -> int {
        return self.id;
    }
}

with entry {
    node = Node(id=42);
    print(f"Node ID: {node.get_id()}");
}
""",
        """
enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

obj Pixel {
    has color: Color = Color.RED;
}

with entry {
    pixel = Pixel();
    print(f"Pixel color: {pixel.color}");
}
"""
    ]
    
    # Create multiprocess language server
    server = MultiprocessLanguageServer(num_workers=4)
    
    try:
        # Test 1: Sequential processing for baseline
        print("\n1. Sequential Processing (Baseline):")
        sequential_times = []
        start_time = time.time()
        
        for i, code in enumerate(test_codes):
            parse_time, success, error_msg = server.parse_file_sync(code, f"sequential_{i}.jac")
            sequential_times.append(parse_time)
            status = "✅" if success else "❌"
            print(f"  File {i}: {parse_time:.4f}s {status}")
            if not success:
                print(f"    Error: {error_msg}")
        
        sequential_total = time.time() - start_time
        
        # Test 2: Concurrent processing
        print("\n2. Concurrent Processing:")
        start_time = time.time()
        
        # Submit all tasks
        for i, code in enumerate(test_codes * 3):  # 9 total files
            server.parse_file_async(code, f"concurrent_{i}.jac")
        
        # Collect results
        concurrent_times = []
        results_collected = 0
        while results_collected < len(test_codes) * 3:
            result = server.get_result(timeout=2.0)
            if result:
                file_path, parse_time, success, error_msg = result
                concurrent_times.append(parse_time)
                status = "✅" if success else "❌"
                print(f"  {file_path}: {parse_time:.4f}s {status}")
                results_collected += 1
            else:
                print("  Timeout waiting for result")
                break
        
        concurrent_total = time.time() - start_time
        
        # Analysis
        if concurrent_times:
            sequential_avg = sum(sequential_times) / len(sequential_times)
            concurrent_avg = sum(concurrent_times) / len(concurrent_times)
            speedup = sequential_total / concurrent_total
            
            print(f"\nPerformance Analysis:")
            print(f"  Sequential total: {sequential_total:.4f}s")
            print(f"  Sequential avg: {sequential_avg:.4f}s")
            print(f"  Concurrent total: {concurrent_total:.4f}s")
            print(f"  Concurrent avg: {concurrent_avg:.4f}s")
            print(f"  Wall-clock speedup: {speedup:.2f}x")
            
            if speedup > 1.5:
                print(f"  🚀  EXCELLENT: {speedup:.1f}x wall-clock speedup!")
            elif speedup > 1.0:
                print(f"  ✅  GOOD: {speedup:.1f}x wall-clock speedup")
            else:
                print(f"  ⚠️  NO BENEFIT: {speedup:.1f}x speedup")
                
            return speedup
        else:
            print("  ❌  FAILED: No results collected")
            return 0.0
    
    finally:
        server.shutdown()

def test_sustained_performance():
    """Test performance over sustained use (simulating real language server)."""
    print("\n=== Sustained Performance Test ===")
    
    server = MultiprocessLanguageServer(num_workers=3)
    
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
    
    try:
        print("Running sustained parsing test (simulating rapid typing)...")
        
        parse_times = []
        num_iterations = 50
        
        for i in range(num_iterations):
            start_time = time.time()
            parse_time, success, error_msg = server.parse_file_sync(test_code, f"sustained_{i}.jac", timeout=2.0)
            total_time = time.time() - start_time
            
            if success:
                parse_times.append(total_time)
            else:
                print(f"  Iteration {i} failed: {error_msg}")
        
        if parse_times:
            avg_time = sum(parse_times) / len(parse_times)
            max_time = max(parse_times)
            min_time = min(parse_times)
            throughput = len(parse_times) / sum(parse_times)
            
            print(f"\nSustained Performance Results:")
            print(f"  Successful parses: {len(parse_times)}/{num_iterations}")
            print(f"  Average time: {avg_time:.4f}s")
            print(f"  Min time: {min_time:.4f}s")
            print(f"  Max time: {max_time:.4f}s")
            print(f"  Throughput: {throughput:.1f} parses/second")
            
            # Check for consistent performance
            if max_time < 0.1:  # 100ms threshold
                print(f"  ✅  EXCELLENT: All parses under 100ms")
            elif max_time < 0.5:  # 500ms threshold
                print(f"  ✅  GOOD: All parses under 500ms")
            else:
                print(f"  ⚠️  SLOW: Some parses over 500ms")
            
            return avg_time, max_time
        else:
            print("  ❌  FAILED: No successful parses")
            return 0.0, 0.0
    
    finally:
        server.shutdown()

if __name__ == "__main__":
    # Force spawn method for consistency
    mp.set_start_method('spawn', force=True)
    
    print("Testing Realistic Multiprocessing Language Server...\n")
    print(f"System has {mp.cpu_count()} CPU cores\n")
    
    # Test 1: Basic functionality and speedup
    speedup = test_multiprocess_language_server()
    
    # Test 2: Sustained performance
    avg_time, max_time = test_sustained_performance()
    
    # Summary and recommendation
    print("\n" + "="*60)
    print("MULTIPROCESSING LANGUAGE SERVER SUMMARY")
    print("="*60)
    print(f"Wall-clock speedup: {speedup:.2f}x")
    print(f"Average sustained parse time: {avg_time:.4f}s")
    print(f"Maximum sustained parse time: {max_time:.4f}s")
    
    # Final recommendation
    if speedup > 1.5 and max_time < 0.1:
        print(f"\n🚀 STRONG RECOMMENDATION: Use multiprocessing!")
        print("  ✅ Excellent performance improvement")
        print("  ✅ Eliminates all thread safety issues")
        print("  ✅ Better CPU utilization")
        print("  ✅ Fault isolation")
    elif speedup > 1.0 and max_time < 0.5:
        print(f"\n✅ RECOMMENDATION: Consider multiprocessing")
        print("  ✅ Good performance improvement")
        print("  ✅ Eliminates thread safety complexity")
    else:
        print(f"\n⚠️  RECOMMENDATION: Stick with improved threading")
        print("  - Multiprocessing overhead still too high")
        print("  - Your threading fixes are sufficient")
